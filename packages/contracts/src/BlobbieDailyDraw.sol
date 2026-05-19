// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { IBlobbieDailyDraw } from "./interfaces/IBlobbieDailyDraw.sol";
import { IBlobbieJackpotVault } from "./interfaces/IBlobbieJackpotVault.sol";
import { IBlobbiePriceAdapter } from "./interfaces/IBlobbiePriceAdapter.sol";

interface IVRFCoordinatorV2PlusLike {
    struct RandomWordsRequest {
        bytes32 keyHash;
        uint256 subId;
        uint16 requestConfirmations;
        uint32 callbackGasLimit;
        uint32 numWords;
        bytes extraArgs;
    }

    function requestRandomWords(RandomWordsRequest calldata request) external returns (uint256 requestId);
}

contract BlobbieDailyDraw is AccessControl, Pausable, ReentrancyGuard, IBlobbieDailyDraw {
    using SafeERC20 for IERC20;

    bytes32 public constant DRAW_ADMIN_ROLE = keccak256("DRAW_ADMIN_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    bytes32 public constant TOP_UP_ROLE = keccak256("TOP_UP_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    IERC20 public immutable blobbyToken;
    IBlobbiePriceAdapter public priceAdapter;
    IBlobbieJackpotVault public jackpotVault;

    DrawConfig public drawConfig;
    VrfConfig public vrfConfig;
    uint256 public override currentRoundId;

    mapping(uint256 roundId => Round round) internal _rounds;
    mapping(uint256 roundId => TicketRange[] ranges) internal _ticketRanges;
    mapping(uint256 requestId => uint256 roundId) public requestToRound;
    mapping(uint256 roundId => mapping(address account => bool entered)) public hasEligibleEntry;
    mapping(uint256 roundId => address[] accounts) internal _participants;

    constructor(
        address admin,
        address blobbyToken_,
        address priceAdapter_,
        address jackpotVault_,
        DrawConfig memory initialDrawConfig,
        VrfConfig memory initialVrfConfig
    ) {
        if (
            admin == address(0) || blobbyToken_ == address(0) || priceAdapter_ == address(0)
                || jackpotVault_ == address(0)
        ) {
            revert InvalidConfig();
        }

        blobbyToken = IERC20(blobbyToken_);
        priceAdapter = IBlobbiePriceAdapter(priceAdapter_);
        jackpotVault = IBlobbieJackpotVault(jackpotVault_);
        _setDrawConfig(initialDrawConfig);
        _setVrfConfig(initialVrfConfig);

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(DRAW_ADMIN_ROLE, admin);
        _grantRole(OPERATOR_ROLE, admin);
        _grantRole(TOP_UP_ROLE, admin);
        _grantRole(PAUSER_ROLE, admin);
    }

    function setDrawConfig(DrawConfig calldata newConfig) external onlyRole(DRAW_ADMIN_ROLE) {
        _setDrawConfig(newConfig);
    }

    function setVrfConfig(VrfConfig calldata newConfig) external onlyRole(DRAW_ADMIN_ROLE) {
        _setVrfConfig(newConfig);
    }

    function setAdapters(address priceAdapter_, address jackpotVault_) external onlyRole(DRAW_ADMIN_ROLE) {
        if (priceAdapter_ == address(0) || jackpotVault_ == address(0)) revert InvalidConfig();
        priceAdapter = IBlobbiePriceAdapter(priceAdapter_);
        jackpotVault = IBlobbieJackpotVault(jackpotVault_);
    }

    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function openRound() external onlyRole(OPERATOR_ROLE) whenNotPaused returns (uint256 roundId) {
        roundId = ++currentRoundId;
        uint64 openedAt = uint64(block.timestamp);
        uint64 expiresAt = openedAt + drawConfig.roundDuration;
        _rounds[roundId] = Round({
            id: roundId,
            openedAt: openedAt,
            expiresAt: expiresAt,
            closedAt: 0,
            eligibleTicketCount: 0,
            uniqueWalletCount: 0,
            grossTicketRevenue: 0,
            operationalTopUp: 0,
            jackpotContribution: 0,
            prizePool: 0,
            vrfRequestId: 0,
            jackpotEligible: false,
            dailyWinner: address(0),
            jackpotWinner: address(0),
            status: RoundStatus.Open
        });
        emit RoundOpened(roundId, openedAt, expiresAt);
    }

    function buyTickets(uint32 quantity, uint256 maxPayment)
        external
        nonReentrant
        whenNotPaused
        returns (uint256 amountPaid)
    {
        if (quantity == 0) revert InvalidQuantity();
        Round storage round = _rounds[currentRoundId];
        if (round.status != RoundStatus.Open) revert RoundNotOpen();

        amountPaid = quoteTickets(quantity);
        if (amountPaid > maxPayment) revert InvalidPayment();
        blobbyToken.safeTransferFrom(msg.sender, address(this), amountPaid);

        uint32 start = round.eligibleTicketCount;
        uint32 end = start + quantity;
        round.eligibleTicketCount = end;
        round.grossTicketRevenue += amountPaid;
        _ticketRanges[currentRoundId].push(
            TicketRange({ account: msg.sender, startInclusive: start, endExclusive: end, amountPaid: amountPaid })
        );

        if (!hasEligibleEntry[currentRoundId][msg.sender]) {
            hasEligibleEntry[currentRoundId][msg.sender] = true;
            _participants[currentRoundId].push(msg.sender);
            round.uniqueWalletCount += 1;
        }

        emit TicketsPurchased(currentRoundId, msg.sender, quantity, start, end, amountPaid);
    }

    function topUpRound(uint256 roundId, uint256 amount) external onlyRole(TOP_UP_ROLE) nonReentrant whenNotPaused {
        if (amount == 0) revert InvalidPayment();
        Round storage round = _rounds[roundId];
        if (round.status != RoundStatus.Open) revert RoundNotOpen();
        blobbyToken.safeTransferFrom(msg.sender, address(this), amount);
        round.operationalTopUp += amount;
        emit OperationalTopUp(roundId, msg.sender, amount);
    }

    function closeRound(uint256 roundId) external onlyRole(OPERATOR_ROLE) whenNotPaused returns (uint256 requestId) {
        Round storage round = _rounds[roundId];
        if (round.status != RoundStatus.Open) revert RoundNotOpen();
        if (round.eligibleTicketCount == 0) revert NoEligibleTickets();

        round.status = RoundStatus.RandomnessRequested;
        round.closedAt = uint64(block.timestamp);
        requestId = IVRFCoordinatorV2PlusLike(vrfConfig.coordinator)
            .requestRandomWords(
                IVRFCoordinatorV2PlusLike.RandomWordsRequest({
                keyHash: vrfConfig.keyHash,
                subId: vrfConfig.subscriptionId,
                requestConfirmations: vrfConfig.requestConfirmations,
                callbackGasLimit: vrfConfig.callbackGasLimit,
                numWords: 2,
                extraArgs: vrfConfig.extraArgs
            })
            );
        round.vrfRequestId = requestId;
        requestToRound[requestId] = roundId;
        emit RoundCloseRequested(roundId, requestId, round.jackpotEligible);
    }

    function rawFulfillRandomWords(uint256 requestId, uint256[] calldata) external nonReentrant whenNotPaused {
        if (msg.sender != vrfConfig.coordinator) revert UnauthorizedCoordinator();
        uint256 roundId = requestToRound[requestId];
        if (roundId == 0) revert UnknownRequest();
        Round storage round = _rounds[roundId];
        round.status = RoundStatus.Fulfilled;
        emit RoundFulfilled(roundId, round.dailyWinner, round.jackpotWinner);
    }

    function getRound(uint256 roundId) external view returns (Round memory round) {
        return _rounds[roundId];
    }

    function ticketRangeCount(uint256 roundId) external view returns (uint256) {
        return _ticketRanges[roundId].length;
    }

    function participantCount(uint256 roundId) external view returns (uint256) {
        return _participants[roundId].length;
    }

    function requiredOperationalTopUp(uint256) public pure returns (uint256 amount) {
        return 0;
    }

    function quoteTickets(uint32 quantity) public view returns (uint256 amount) {
        if (quantity == 0) revert InvalidQuantity();
        return priceAdapter.quoteTokenAmountForUsd(uint256(quantity) * drawConfig.ticketUsdPrice8);
    }

    function _setDrawConfig(DrawConfig memory newConfig) internal {
        if (
            newConfig.ticketThreshold == 0 || newConfig.roundDuration == 0 || newConfig.ticketUsdPrice8 == 0
                || newConfig.jackpotContributionBps > 10_000
        ) {
            revert InvalidConfig();
        }
        drawConfig = newConfig;
        emit DrawConfigUpdated(newConfig);
    }

    function _setVrfConfig(VrfConfig memory newConfig) internal {
        if (
            newConfig.coordinator == address(0) || newConfig.keyHash == bytes32(0) || newConfig.subscriptionId == 0
                || newConfig.requestConfirmations == 0 || newConfig.callbackGasLimit == 0
        ) {
            revert InvalidConfig();
        }
        vrfConfig = newConfig;
        emit VrfConfigUpdated(newConfig);
    }
}
