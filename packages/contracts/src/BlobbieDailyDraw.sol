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

    uint256 public constant FIRST_PRIZE_USD_E18 = 102e18;
    uint256 public constant SECOND_TIER_PRIZE_USD_E18 = 4e18;
    uint256 public constant THIRD_TIER_PRIZE_USD_E18 = 1e18;
    uint256 public constant FREE_ENTRY_RESERVE_USD_E18 = 10e18;
    uint256 public constant JACKPOT_ALLOCATION_USD_E18 = 5e18;
    uint256 public constant BURN_TREASURY_ALLOCATION_USD_E18 = 7e18;
    uint16 public constant MAX_WINNER_SLOTS = 150;

    IERC20 public immutable blobbyToken;
    IBlobbiePriceAdapter public priceAdapter;
    IBlobbieJackpotVault public jackpotVault;

    DrawConfig public drawConfig;
    VrfConfig public vrfConfig;
    uint256 public override currentRoundId;
    uint256 public freeEntryReserveBalance;
    uint256 public burnTreasuryReserveBalance;

    mapping(uint256 roundId => Round round) internal _rounds;
    mapping(uint256 roundId => TicketRange[] ranges) internal _ticketRanges;
    mapping(uint256 requestId => uint256 roundId) public requestToRound;
    mapping(uint256 roundId => mapping(address account => bool entered)) public hasEligibleEntry;
    mapping(uint256 roundId => mapping(address account => bool won)) public hasWonRound;
    mapping(uint256 roundId => mapping(uint256 slot => address winner)) public winnerAtSlot;
    mapping(uint256 roundId => mapping(uint256 slot => uint256 amount)) public prizeAtSlot;
    mapping(uint256 roundId => address[] accounts) internal _participants;
    mapping(address account => bool banned) public bannedWallet;
    mapping(address account => bool fraudRejected) public fraudRejectedWallet;

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

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(DRAW_ADMIN_ROLE, admin);
        _grantRole(OPERATOR_ROLE, admin);
        _grantRole(TOP_UP_ROLE, admin);
        _grantRole(PAUSER_ROLE, admin);

        _setDrawConfig(initialDrawConfig);
        _setVrfConfig(initialVrfConfig);
        _startRound();
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

    function setWalletStatus(address account, bool banned, bool fraudRejected) external onlyRole(DRAW_ADMIN_ROLE) {
        if (account == address(0)) revert InvalidConfig();
        bannedWallet[account] = banned;
        fraudRejectedWallet[account] = fraudRejected;
        emit WalletStatusUpdated(account, banned, fraudRejected);
    }

    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function startNextRound() public onlyRole(OPERATOR_ROLE) whenNotPaused returns (uint256 roundId) {
        RoundStatus status = _rounds[currentRoundId].status;
        if (status != RoundStatus.FINALIZED && currentRoundId != 0) revert InvalidRound();
        return _startRound();
    }

    function openRound() external onlyRole(OPERATOR_ROLE) whenNotPaused returns (uint256 roundId) {
        return startNextRound();
    }

    function buyTickets(uint256 quantity, uint256 maxBlobbieCost)
        external
        nonReentrant
        whenNotPaused
        returns (uint256 amountPaid)
    {
        if (quantity == 0 || quantity > type(uint32).max) revert InvalidQuantity();
        if (bannedWallet[msg.sender] || fraudRejectedWallet[msg.sender]) revert WalletExcluded();

        Round storage round = _rounds[currentRoundId];
        if (round.status != RoundStatus.OPEN) revert RoundNotOpen();
        if (block.timestamp >= round.expiresAt) revert RoundNotOpen();
        if (uint256(round.eligibleTicketCount) + quantity > drawConfig.ticketThreshold) revert InvalidQuantity();

        amountPaid = quoteTickets(quantity);
        if (amountPaid > maxBlobbieCost) revert InvalidPayment();

        blobbyToken.safeTransferFrom(msg.sender, address(this), amountPaid);
        jackpotVault.recordEligibleTickets(msg.sender, quantity);

        uint256 start = round.eligibleTicketCount;
        uint256 end = start + quantity;
        round.eligibleTicketCount = uint32(end);
        round.grossTicketRevenue += amountPaid;
        round.prizePool += amountPaid;
        _ticketRanges[currentRoundId].push(
            TicketRange({
                account: msg.sender, startInclusive: uint32(start), endExclusive: uint32(end), amountPaid: amountPaid
            })
        );

        if (!hasEligibleEntry[currentRoundId][msg.sender]) {
            hasEligibleEntry[currentRoundId][msg.sender] = true;
            _participants[currentRoundId].push(msg.sender);
            round.uniqueWalletCount += 1;
        }

        emit TicketPurchased(currentRoundId, msg.sender, quantity, start, end, amountPaid);

        if (round.eligibleTicketCount == drawConfig.ticketThreshold) {
            _closeRound(currentRoundId);
        }
    }

    function closeRoundByThreshold(uint256 roundId) public onlyRole(OPERATOR_ROLE) whenNotPaused {
        Round storage round = _rounds[roundId];
        if (round.status != RoundStatus.OPEN) revert RoundNotOpen();
        if (round.eligibleTicketCount < drawConfig.ticketThreshold) revert RoundNotClosable();
        _closeRound(roundId);
    }

    function closeRoundByTimeout(uint256 roundId) external onlyRole(OPERATOR_ROLE) whenNotPaused {
        Round storage round = _rounds[roundId];
        if (round.status != RoundStatus.OPEN) revert RoundNotOpen();
        if (block.timestamp < round.expiresAt) revert RoundNotClosable();
        _closeRound(roundId);
        uint256 requiredTopUp = _requiredOperationalTopUp(roundId);
        if (requiredTopUp != 0) {
            round.topUpRequired = requiredTopUp;
            emit OperationalTopUpRequired(roundId, requiredTopUp);
        }
    }

    function provideOperationalTopUp(uint256 roundId, uint256 amount)
        public
        onlyRole(TOP_UP_ROLE)
        nonReentrant
        whenNotPaused
    {
        if (amount == 0) revert InvalidPayment();
        Round storage round = _rounds[roundId];
        if (round.status != RoundStatus.CLOSED) revert InvalidRound();
        if (round.topUpRequired == 0) revert InvalidPayment();

        blobbyToken.safeTransferFrom(msg.sender, address(this), amount);
        round.operationalTopUp += amount;
        round.prizePool += amount;
        round.topUpRequired = amount >= round.topUpRequired ? 0 : round.topUpRequired - amount;
        emit OperationalTopUpReceived(roundId, msg.sender, amount);
    }

    function topUpRound(uint256 roundId, uint256 amount) external {
        provideOperationalTopUp(roundId, amount);
    }

    function requestRandomness(uint256 roundId)
        public
        onlyRole(OPERATOR_ROLE)
        whenNotPaused
        returns (uint256 requestId)
    {
        Round storage round = _rounds[roundId];
        if (round.status != RoundStatus.CLOSED) revert InvalidRound();
        if (round.topUpRequired != 0) revert TopUpIncomplete(round.topUpRequired);
        if (round.eligibleTicketCount == 0) revert NoEligibleTickets();

        requestId = IVRFCoordinatorV2PlusLike(vrfConfig.coordinator)
            .requestRandomWords(
                IVRFCoordinatorV2PlusLike.RandomWordsRequest({
                keyHash: vrfConfig.keyHash,
                subId: vrfConfig.subscriptionId,
                requestConfirmations: vrfConfig.requestConfirmations,
                callbackGasLimit: vrfConfig.callbackGasLimit,
                numWords: 1,
                extraArgs: vrfConfig.extraArgs
            })
            );
        round.status = RoundStatus.VRF_REQUESTED;
        round.vrfRequestId = requestId;
        requestToRound[requestId] = roundId;
        emit RandomnessRequested(roundId, requestId);
    }

    function closeRound(uint256 roundId) external onlyRole(OPERATOR_ROLE) whenNotPaused returns (uint256 requestId) {
        closeRoundByThreshold(roundId);
        return requestRandomness(roundId);
    }

    function rawFulfillRandomWords(uint256 requestId, uint256[] calldata randomWords)
        external
        nonReentrant
        whenNotPaused
    {
        if (msg.sender != vrfConfig.coordinator) revert UnauthorizedCoordinator();
        uint256 roundId = requestToRound[requestId];
        if (roundId == 0) revert UnknownRequest();
        if (randomWords.length == 0) revert NoRandomness();

        Round storage round = _rounds[roundId];
        if (round.status != RoundStatus.VRF_REQUESTED) revert InvalidRound();
        round.status = RoundStatus.DRAWING;
        round.randomness = randomWords[0];
        emit RandomnessFulfilled(roundId, requestId, randomWords[0]);
    }

    function settleRound(uint256 roundId) external onlyRole(OPERATOR_ROLE) nonReentrant whenNotPaused {
        Round storage round = _rounds[roundId];
        if (round.status == RoundStatus.FINALIZED) revert DuplicateSettlement();
        if (round.status != RoundStatus.DRAWING) revert InvalidRound();

        round.status = RoundStatus.SETTLING;
        uint256 unusedPrizeUsdE18;
        uint16 winnersPaid;

        for (uint16 slot = 0; slot < MAX_WINNER_SLOTS; slot++) {
            uint256 prizeUsdE18 = _slotPrizeUsdE18(slot);
            address winner = _selectWinner(roundId, uint256(keccak256(abi.encode(round.randomness, slot))));
            if (winner == address(0)) {
                unusedPrizeUsdE18 += prizeUsdE18;
                continue;
            }

            uint256 prizeAmount = priceAdapter.getBlobbieAmountForUsd(prizeUsdE18);
            if (prizeAmount > round.prizePool) {
                round.status = RoundStatus.FAILED_NEEDS_ADMIN_REVIEW;
                emit RoundFailed(roundId, "INSUFFICIENT_PRIZE_POOL");
                return;
            }
            round.prizePool -= prizeAmount;
            hasWonRound[roundId][winner] = true;
            winnerAtSlot[roundId][slot] = winner;
            prizeAtSlot[roundId][slot] = prizeAmount;
            winnersPaid += 1;
            blobbyToken.safeTransfer(winner, prizeAmount);
            emit WinnerSelected(roundId, slot, winner, prizeAmount);
            emit PrizePaid(roundId, slot, winner, prizeAmount);
        }

        round.winnersPaid = winnersPaid;
        _allocateReserves(roundId, unusedPrizeUsdE18);
        if (round.status == RoundStatus.FAILED_NEEDS_ADMIN_REVIEW) return;
        round.status = RoundStatus.FINALIZED;
        emit RoundFinalized(roundId);
    }

    function getRound(uint256 roundId) external view returns (Round memory round) {
        return _rounds[roundId];
    }

    function ticketRangeCount(uint256 roundId) external view returns (uint256) {
        return _ticketRanges[roundId].length;
    }

    function getTicketRange(uint256 roundId, uint256 index) external view returns (TicketRange memory) {
        return _ticketRanges[roundId][index];
    }

    function participantCount(uint256 roundId) external view returns (uint256) {
        return _participants[roundId].length;
    }

    function getParticipant(uint256 roundId, uint256 index) external view returns (address) {
        return _participants[roundId][index];
    }

    function requiredOperationalTopUp(uint256 roundId) public view returns (uint256 amount) {
        Round storage round = _rounds[roundId];
        if (round.topUpRequired != 0) return round.topUpRequired;
        return _requiredOperationalTopUp(roundId);
    }

    function quoteTickets(uint256 quantity) public view returns (uint256 amount) {
        if (quantity == 0) revert InvalidQuantity();
        return priceAdapter.getBlobbieAmountForUsd(quantity * drawConfig.ticketUsdPriceE18);
    }

    function _startRound() internal returns (uint256 roundId) {
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
            topUpRequired: 0,
            vrfRequestId: 0,
            randomness: 0,
            jackpotAllocated: 0,
            freeEntryReserveAllocated: 0,
            burnTreasuryAllocated: 0,
            winnersPaid: 0,
            status: RoundStatus.OPEN
        });
        emit RoundStarted(roundId, openedAt, expiresAt);
    }

    function _closeRound(uint256 roundId) internal {
        Round storage round = _rounds[roundId];
        if (round.eligibleTicketCount == 0) revert NoEligibleTickets();
        round.status = RoundStatus.CLOSED;
        round.closedAt = uint64(block.timestamp);
        emit RoundClosed(roundId, round.eligibleTicketCount, round.prizePool);
    }

    function _requiredOperationalTopUp(uint256 roundId) internal view returns (uint256 amount) {
        Round storage round = _rounds[roundId];
        if (round.eligibleTicketCount >= drawConfig.ticketThreshold) return 0;
        uint256 missingTickets = uint256(drawConfig.ticketThreshold) - uint256(round.eligibleTicketCount);
        uint256 requiredAmount = quoteTickets(missingTickets);
        if (round.operationalTopUp >= requiredAmount) return 0;
        return requiredAmount - round.operationalTopUp;
    }

    function _allocateReserves(uint256 roundId, uint256 unusedPrizeUsdE18) internal {
        Round storage round = _rounds[roundId];
        uint256 freeReserveAmount = priceAdapter.getBlobbieAmountForUsd(FREE_ENTRY_RESERVE_USD_E18);
        uint256 jackpotAmount = priceAdapter.getBlobbieAmountForUsd(JACKPOT_ALLOCATION_USD_E18);
        uint256 burnTreasuryAmount = priceAdapter.getBlobbieAmountForUsd(BURN_TREASURY_ALLOCATION_USD_E18);

        if (unusedPrizeUsdE18 != 0) {
            uint256 unusedAmount = priceAdapter.getBlobbieAmountForUsd(unusedPrizeUsdE18);
            uint256 jackpotShare = (unusedAmount * 70) / 100;
            jackpotAmount += jackpotShare;
            burnTreasuryAmount += unusedAmount - jackpotShare;
        }

        uint256 totalAllocation = freeReserveAmount + jackpotAmount + burnTreasuryAmount;
        if (totalAllocation > round.prizePool) {
            round.status = RoundStatus.FAILED_NEEDS_ADMIN_REVIEW;
            emit RoundFailed(roundId, "INSUFFICIENT_ALLOCATION_POOL");
            return;
        }

        round.prizePool -= totalAllocation;
        round.freeEntryReserveAllocated = freeReserveAmount;
        round.jackpotAllocated = jackpotAmount;
        round.burnTreasuryAllocated = burnTreasuryAmount;
        freeEntryReserveBalance += freeReserveAmount;
        burnTreasuryReserveBalance += burnTreasuryAmount;

        blobbyToken.forceApprove(address(jackpotVault), jackpotAmount);
        jackpotVault.contributeFromDraw(jackpotAmount);
        blobbyToken.safeTransfer(drawConfig.treasury, burnTreasuryAmount);

        emit FreeEntryReserveAllocated(roundId, freeReserveAmount);
        emit JackpotAllocated(roundId, jackpotAmount);
        emit BurnTreasuryAllocated(roundId, burnTreasuryAmount);
    }

    function _selectWinner(uint256 roundId, uint256 randomness) internal view returns (address) {
        Round storage round = _rounds[roundId];
        if (round.uniqueWalletCount <= round.winnersPaid) return address(0);

        address firstCandidate = _ticketOwnerAt(roundId, randomness % round.eligibleTicketCount);
        if (_canWin(roundId, firstCandidate)) return firstCandidate;

        address[] storage participants = _participants[roundId];
        uint256 start = randomness % participants.length;
        for (uint256 i = 0; i < participants.length; i++) {
            address candidate = participants[(start + i) % participants.length];
            if (_canWin(roundId, candidate)) return candidate;
        }
        return address(0);
    }

    function _ticketOwnerAt(uint256 roundId, uint256 ticketIndex) internal view returns (address) {
        TicketRange[] storage ranges = _ticketRanges[roundId];
        for (uint256 i = 0; i < ranges.length; i++) {
            if (ticketIndex >= ranges[i].startInclusive && ticketIndex < ranges[i].endExclusive) {
                return ranges[i].account;
            }
        }
        return address(0);
    }

    function _canWin(uint256 roundId, address account) internal view returns (bool) {
        return account != address(0) && !hasWonRound[roundId][account] && !bannedWallet[account]
            && !fraudRejectedWallet[account];
    }

    function _slotPrizeUsdE18(uint16 slot) internal pure returns (uint256) {
        if (slot == 0) return FIRST_PRIZE_USD_E18;
        if (slot < 10) return SECOND_TIER_PRIZE_USD_E18;
        return THIRD_TIER_PRIZE_USD_E18;
    }

    function _setDrawConfig(DrawConfig memory newConfig) internal {
        if (
            newConfig.ticketThreshold == 0 || newConfig.roundDuration == 0 || newConfig.ticketUsdPriceE18 == 0
                || newConfig.jackpotContributionBps > 10_000 || newConfig.treasury == address(0)
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
