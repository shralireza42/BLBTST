// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IDailyDrawPriceOracle} from "./interfaces/IDailyDrawPriceOracle.sol";
import {IVRFCoordinatorV2Plus} from "./interfaces/IVRFCoordinatorV2Plus.sol";

contract DailyDraw is AccessControl, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    bytes32 public constant TOP_UP_ROLE = keccak256("TOP_UP_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    uint256 public constant USD_PER_TICKET_8 = 1e8;
    uint256 public constant BPS_DENOMINATOR = 10_000;

    enum RoundStatus {
        None,
        Open,
        Calculating,
        Fulfilled,
        Cancelled
    }

    struct Round {
        uint256 id;
        uint64 openedAt;
        uint64 expiresAt;
        uint64 closedAt;
        uint32 eligibleTicketCount;
        uint32 uniqueWalletCount;
        uint256 grossTicketRevenue;
        uint256 prizePool;
        uint256 jackpotContribution;
        uint256 operationalTopUp;
        uint256 dailyPrizePaid;
        uint256 jackpotPaid;
        address dailyWinner;
        address jackpotWinner;
        uint256 vrfRequestId;
        bool jackpotEligible;
        RoundStatus status;
    }

    struct TicketRange {
        address buyer;
        uint32 startInclusive;
        uint32 endExclusive;
        uint256 blobbyPaid;
    }

    struct VrfConfig {
        address coordinator;
        bytes32 keyHash;
        uint256 subscriptionId;
        uint16 requestConfirmations;
        uint32 callbackGasLimit;
        bytes extraArgs;
    }

    IERC20 public immutable blobby;
    IDailyDrawPriceOracle public priceOracle;

    VrfConfig public vrfConfig;
    uint32 public ticketThreshold;
    uint64 public roundDuration;
    uint16 public jackpotBps;
    uint256 public jackpotTriggerAmount;
    uint256 public jackpotReserve;
    uint256 public currentRoundId;

    mapping(uint256 => Round) public rounds;
    mapping(uint256 => TicketRange[]) private roundTicketRanges;
    mapping(uint256 => address[]) private roundParticipants;
    mapping(uint256 => mapping(address => bool)) public hasEligibleEntry;
    mapping(uint256 => uint256) public requestIdToRoundId;

    event OracleUpdated(address indexed oracle);
    event VrfConfigUpdated(address indexed coordinator, bytes32 keyHash, uint256 subscriptionId);
    event RoundConfigUpdated(uint32 ticketThreshold, uint64 roundDuration);
    event JackpotConfigUpdated(uint16 jackpotBps, uint256 jackpotTriggerAmount);
    event RoundOpened(uint256 indexed roundId, uint64 openedAt, uint64 expiresAt);
    event TicketsPurchased(
        uint256 indexed roundId,
        address indexed buyer,
        uint32 quantity,
        uint32 startInclusive,
        uint32 endExclusive,
        uint256 blobbyPaid,
        uint256 jackpotContribution
    );
    event OperationalTopUp(uint256 indexed roundId, address indexed payer, uint256 amount);
    event RoundCloseRequested(uint256 indexed roundId, uint256 indexed requestId, bool jackpotEligible);
    event RoundFulfilled(
        uint256 indexed roundId,
        address indexed dailyWinner,
        uint256 dailyPrizePaid,
        address indexed jackpotWinner,
        uint256 jackpotPaid
    );
    event RoundCancelled(uint256 indexed roundId, address indexed recipient, uint256 topUpRefunded);

    error InvalidAddress();
    error InvalidConfig();
    error InvalidQuantity();
    error InvalidRoundStatus();
    error RoundNotClosable();
    error PaymentAboveLimit(uint256 payment, uint256 maxPayment);
    error TicketThresholdExceeded();
    error TopUpNotAllowed();
    error TopUpRequired(uint256 missingAmount);
    error NoEligibleEntries();
    error UnknownVrfRequest();
    error OnlyVrfCoordinator();
    error UnsupportedTokenRecovery();

    constructor(
        address admin,
        address blobbyToken,
        address initialPriceOracle,
        VrfConfig memory initialVrfConfig,
        uint32 initialTicketThreshold,
        uint64 initialRoundDuration,
        uint16 initialJackpotBps,
        uint256 initialJackpotTriggerAmount
    ) {
        if (admin == address(0) || blobbyToken == address(0) || initialPriceOracle == address(0)) {
            revert InvalidAddress();
        }
        blobby = IERC20(blobbyToken);
        priceOracle = IDailyDrawPriceOracle(initialPriceOracle);

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(OPERATOR_ROLE, admin);
        _grantRole(TOP_UP_ROLE, admin);
        _grantRole(PAUSER_ROLE, admin);

        _setVrfConfig(initialVrfConfig);
        _setRoundConfig(initialTicketThreshold, initialRoundDuration);
        _setJackpotConfig(initialJackpotBps, initialJackpotTriggerAmount);
    }

    function openRound() external onlyRole(OPERATOR_ROLE) whenNotPaused returns (uint256 roundId) {
        if (currentRoundId != 0) {
            RoundStatus status = rounds[currentRoundId].status;
            if (status == RoundStatus.Open || status == RoundStatus.Calculating) {
                revert InvalidRoundStatus();
            }
        }

        roundId = currentRoundId + 1;
        currentRoundId = roundId;
        uint64 openedAt = uint64(block.timestamp);
        uint64 expiresAt = openedAt + roundDuration;
        rounds[roundId] = Round({
            id: roundId,
            openedAt: openedAt,
            expiresAt: expiresAt,
            closedAt: 0,
            eligibleTicketCount: 0,
            uniqueWalletCount: 0,
            grossTicketRevenue: 0,
            prizePool: 0,
            jackpotContribution: 0,
            operationalTopUp: 0,
            dailyPrizePaid: 0,
            jackpotPaid: 0,
            dailyWinner: address(0),
            jackpotWinner: address(0),
            vrfRequestId: 0,
            jackpotEligible: false,
            status: RoundStatus.Open
        });

        emit RoundOpened(roundId, openedAt, expiresAt);
    }

    function buyTickets(uint32 quantity, uint256 maxPayment) external nonReentrant whenNotPaused {
        if (quantity == 0) {
            revert InvalidQuantity();
        }

        Round storage round = rounds[currentRoundId];
        if (round.status != RoundStatus.Open || block.timestamp >= round.expiresAt) {
            revert InvalidRoundStatus();
        }
        if (round.eligibleTicketCount + quantity > ticketThreshold) {
            revert TicketThresholdExceeded();
        }

        uint256 payment = quoteTickets(quantity);
        if (payment > maxPayment) {
            revert PaymentAboveLimit(payment, maxPayment);
        }

        blobby.safeTransferFrom(msg.sender, address(this), payment);

        uint256 contribution = (payment * jackpotBps) / BPS_DENOMINATOR;
        uint32 start = round.eligibleTicketCount;
        uint32 end = start + quantity;

        roundTicketRanges[currentRoundId].push(
            TicketRange({buyer: msg.sender, startInclusive: start, endExclusive: end, blobbyPaid: payment})
        );

        if (!hasEligibleEntry[currentRoundId][msg.sender]) {
            hasEligibleEntry[currentRoundId][msg.sender] = true;
            roundParticipants[currentRoundId].push(msg.sender);
            round.uniqueWalletCount += 1;
        }

        round.eligibleTicketCount = end;
        round.grossTicketRevenue += payment;
        round.jackpotContribution += contribution;
        round.prizePool += payment - contribution;
        jackpotReserve += contribution;

        emit TicketsPurchased(currentRoundId, msg.sender, quantity, start, end, payment, contribution);
    }

    function topUpRound(uint256 roundId, uint256 amount) public onlyRole(TOP_UP_ROLE) nonReentrant whenNotPaused {
        if (amount == 0) {
            revert InvalidQuantity();
        }
        Round storage round = rounds[roundId];
        if (!_canTopUp(round)) {
            revert TopUpNotAllowed();
        }

        blobby.safeTransferFrom(msg.sender, address(this), amount);
        round.operationalTopUp += amount;
        round.prizePool += amount;

        emit OperationalTopUp(roundId, msg.sender, amount);
    }

    function topUpAndClose(uint256 roundId, uint256 maxTopUp) external onlyRole(TOP_UP_ROLE) whenNotPaused {
        uint256 missingTopUp = requiredOperationalTopUp(roundId);
        if (missingTopUp > maxTopUp) {
            revert PaymentAboveLimit(missingTopUp, maxTopUp);
        }
        if (missingTopUp != 0) {
            topUpRound(roundId, missingTopUp);
        }
        closeRound(roundId);
    }

    function closeRound(uint256 roundId) public nonReentrant whenNotPaused returns (uint256 requestId) {
        Round storage round = rounds[roundId];
        if (round.status != RoundStatus.Open) {
            revert InvalidRoundStatus();
        }
        if (round.eligibleTicketCount == 0) {
            revert NoEligibleEntries();
        }

        bool reachedThreshold = round.eligibleTicketCount == ticketThreshold;
        bool expired = block.timestamp >= round.expiresAt;
        if (!reachedThreshold && !expired) {
            revert RoundNotClosable();
        }

        if (expired && !reachedThreshold) {
            uint256 missingTopUp = requiredOperationalTopUp(roundId);
            if (missingTopUp != 0) {
                revert TopUpRequired(missingTopUp);
            }
        }

        round.status = RoundStatus.Calculating;
        round.closedAt = uint64(block.timestamp);
        round.jackpotEligible =
            jackpotTriggerAmount != 0 && jackpotReserve >= jackpotTriggerAmount && round.uniqueWalletCount > 1;

        VrfConfig memory config = vrfConfig;
        requestId = IVRFCoordinatorV2Plus(config.coordinator).requestRandomWords(
            IVRFCoordinatorV2Plus.RandomWordsRequest({
                keyHash: config.keyHash,
                subId: config.subscriptionId,
                requestConfirmations: config.requestConfirmations,
                callbackGasLimit: config.callbackGasLimit,
                numWords: 2,
                extraArgs: config.extraArgs
            })
        );
        round.vrfRequestId = requestId;
        requestIdToRoundId[requestId] = roundId;

        emit RoundCloseRequested(roundId, requestId, round.jackpotEligible);
    }

    function rawFulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) external nonReentrant {
        if (msg.sender != vrfConfig.coordinator) {
            revert OnlyVrfCoordinator();
        }
        uint256 roundId = requestIdToRoundId[requestId];
        if (roundId == 0) {
            revert UnknownVrfRequest();
        }
        _fulfillRound(roundId, randomWords);
    }

    function cancelExpiredRoundWithoutEntries(uint256 roundId, address refundRecipient)
        external
        onlyRole(OPERATOR_ROLE)
        nonReentrant
    {
        if (refundRecipient == address(0)) {
            revert InvalidAddress();
        }
        Round storage round = rounds[roundId];
        if (round.status != RoundStatus.Open || block.timestamp < round.expiresAt || round.eligibleTicketCount != 0) {
            revert InvalidRoundStatus();
        }

        uint256 refund = round.operationalTopUp;
        round.status = RoundStatus.Cancelled;
        round.closedAt = uint64(block.timestamp);
        round.prizePool = 0;
        round.operationalTopUp = 0;

        if (refund != 0) {
            blobby.safeTransfer(refundRecipient, refund);
        }

        emit RoundCancelled(roundId, refundRecipient, refund);
    }

    function setPriceOracle(address newOracle) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (newOracle == address(0)) {
            revert InvalidAddress();
        }
        priceOracle = IDailyDrawPriceOracle(newOracle);
        emit OracleUpdated(newOracle);
    }

    function setVrfConfig(VrfConfig calldata newConfig) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _setVrfConfig(newConfig);
    }

    function setRoundConfig(uint32 newTicketThreshold, uint64 newRoundDuration)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _setRoundConfig(newTicketThreshold, newRoundDuration);
    }

    function setJackpotConfig(uint16 newJackpotBps, uint256 newJackpotTriggerAmount)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _setJackpotConfig(newJackpotBps, newJackpotTriggerAmount);
    }

    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function recoverUnsupportedToken(address token, address recipient, uint256 amount)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        if (token == address(blobby)) {
            revert UnsupportedTokenRecovery();
        }
        if (recipient == address(0)) {
            revert InvalidAddress();
        }
        IERC20(token).safeTransfer(recipient, amount);
    }

    function quoteTickets(uint32 quantity) public view returns (uint256) {
        return priceOracle.blobbiesForUsd(uint256(quantity) * USD_PER_TICKET_8);
    }

    function requiredOperationalTopUp(uint256 roundId) public view returns (uint256) {
        Round storage round = rounds[roundId];
        if (round.status != RoundStatus.Open || round.eligibleTicketCount >= ticketThreshold) {
            return 0;
        }
        uint256 requiredGrossTopUp = quoteTickets(ticketThreshold - round.eligibleTicketCount);
        if (round.operationalTopUp >= requiredGrossTopUp) {
            return 0;
        }
        return requiredGrossTopUp - round.operationalTopUp;
    }

    function ticketRangeCount(uint256 roundId) external view returns (uint256) {
        return roundTicketRanges[roundId].length;
    }

    function participantCount(uint256 roundId) external view returns (uint256) {
        return roundParticipants[roundId].length;
    }

    function getTicketRange(uint256 roundId, uint256 index) external view returns (TicketRange memory) {
        return roundTicketRanges[roundId][index];
    }

    function getParticipant(uint256 roundId, uint256 index) external view returns (address) {
        return roundParticipants[roundId][index];
    }

    function _fulfillRound(uint256 roundId, uint256[] calldata randomWords) internal {
        Round storage round = rounds[roundId];
        if (round.status != RoundStatus.Calculating) {
            revert InvalidRoundStatus();
        }
        if (randomWords.length == 0) {
            revert InvalidQuantity();
        }

        address dailyWinner = _ticketOwnerAt(roundId, uint32(randomWords[0] % round.eligibleTicketCount));
        uint256 dailyPrize = round.prizePool;
        address jackpotWinner;
        uint256 jackpotPaid;

        round.status = RoundStatus.Fulfilled;
        round.dailyWinner = dailyWinner;
        round.dailyPrizePaid = dailyPrize;
        round.prizePool = 0;

        if (round.jackpotEligible) {
            uint256 jackpotRandomness =
                randomWords.length > 1 ? randomWords[1] : uint256(keccak256(abi.encode(randomWords[0], roundId)));
            jackpotWinner = _pickDistinctWinner(roundId, dailyWinner, jackpotRandomness);
            if (jackpotWinner != address(0)) {
                jackpotPaid = jackpotReserve;
                jackpotReserve = 0;
                round.jackpotWinner = jackpotWinner;
                round.jackpotPaid = jackpotPaid;
            }
        }

        if (dailyPrize != 0) {
            blobby.safeTransfer(dailyWinner, dailyPrize);
        }
        if (jackpotPaid != 0) {
            blobby.safeTransfer(jackpotWinner, jackpotPaid);
        }

        emit RoundFulfilled(roundId, dailyWinner, dailyPrize, jackpotWinner, jackpotPaid);
    }

    function _pickDistinctWinner(uint256 roundId, address excluded, uint256 randomness) internal view returns (address) {
        Round storage round = rounds[roundId];
        if (round.uniqueWalletCount <= 1) {
            return address(0);
        }

        for (uint256 i = 0; i < 20; i++) {
            address candidate = _ticketOwnerAt(
                roundId,
                uint32(uint256(keccak256(abi.encode(randomness, i))) % round.eligibleTicketCount)
            );
            if (candidate != excluded) {
                return candidate;
            }
        }

        address[] storage participants = roundParticipants[roundId];
        for (uint256 i = 0; i < participants.length; i++) {
            if (participants[i] != excluded) {
                return participants[i];
            }
        }
        return address(0);
    }

    function _ticketOwnerAt(uint256 roundId, uint32 ticketIndex) internal view returns (address) {
        TicketRange[] storage ranges = roundTicketRanges[roundId];
        for (uint256 i = 0; i < ranges.length; i++) {
            if (ticketIndex >= ranges[i].startInclusive && ticketIndex < ranges[i].endExclusive) {
                return ranges[i].buyer;
            }
        }
        revert NoEligibleEntries();
    }

    function _canTopUp(Round storage round) internal view returns (bool) {
        return round.status == RoundStatus.Open && block.timestamp >= round.expiresAt
            && round.eligibleTicketCount < ticketThreshold;
    }

    function _setVrfConfig(VrfConfig memory newConfig) internal {
        if (
            newConfig.coordinator == address(0) || newConfig.keyHash == bytes32(0) || newConfig.subscriptionId == 0
                || newConfig.requestConfirmations == 0 || newConfig.callbackGasLimit == 0
        ) {
            revert InvalidConfig();
        }
        vrfConfig = newConfig;
        emit VrfConfigUpdated(newConfig.coordinator, newConfig.keyHash, newConfig.subscriptionId);
    }

    function _setRoundConfig(uint32 newTicketThreshold, uint64 newRoundDuration) internal {
        if (newTicketThreshold == 0 || newRoundDuration == 0) {
            revert InvalidConfig();
        }
        ticketThreshold = newTicketThreshold;
        roundDuration = newRoundDuration;
        emit RoundConfigUpdated(newTicketThreshold, newRoundDuration);
    }

    function _setJackpotConfig(uint16 newJackpotBps, uint256 newJackpotTriggerAmount) internal {
        if (newJackpotBps > 5_000) {
            revert InvalidConfig();
        }
        jackpotBps = newJackpotBps;
        jackpotTriggerAmount = newJackpotTriggerAmount;
        emit JackpotConfigUpdated(newJackpotBps, newJackpotTriggerAmount);
    }
}
