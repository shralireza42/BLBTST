// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IBlobbieDailyDraw {
    enum RoundStatus {
        OPEN,
        CLOSED,
        VRF_REQUESTED,
        DRAWING,
        SETTLING,
        FINALIZED,
        PAUSED,
        FAILED_NEEDS_ADMIN_REVIEW
    }

    struct DrawConfig {
        uint32 ticketThreshold;
        uint64 roundDuration;
        uint256 ticketUsdPriceE18;
        uint16 jackpotContributionBps;
        address treasury;
    }

    struct VrfConfig {
        address coordinator;
        bytes32 keyHash;
        uint256 subscriptionId;
        uint16 requestConfirmations;
        uint32 callbackGasLimit;
        bytes extraArgs;
    }

    struct Round {
        uint256 id;
        uint64 openedAt;
        uint64 expiresAt;
        uint64 closedAt;
        uint32 eligibleTicketCount;
        uint32 uniqueWalletCount;
        uint256 grossTicketRevenue;
        uint256 operationalTopUp;
        uint256 jackpotContribution;
        uint256 prizePool;
        uint256 topUpRequired;
        uint256 vrfRequestId;
        uint256 randomness;
        uint256 jackpotAllocated;
        uint256 freeEntryReserveAllocated;
        uint256 burnTreasuryAllocated;
        uint16 winnersPaid;
        RoundStatus status;
    }

    struct TicketRange {
        address account;
        uint32 startInclusive;
        uint32 endExclusive;
        uint256 amountPaid;
    }

    event DrawConfigUpdated(DrawConfig config);
    event VrfConfigUpdated(VrfConfig config);
    event RoundStarted(uint256 indexed roundId, uint64 openedAt, uint64 expiresAt);
    event TicketPurchased(
        uint256 indexed roundId,
        address indexed buyer,
        uint256 quantity,
        uint256 startInclusive,
        uint256 endExclusive,
        uint256 amountPaid
    );
    event RoundClosed(uint256 indexed roundId, uint256 eligibleTicketCount, uint256 prizePool);
    event OperationalTopUpRequired(uint256 indexed roundId, uint256 amount);
    event OperationalTopUpReceived(uint256 indexed roundId, address indexed payer, uint256 amount);
    event RandomnessRequested(uint256 indexed roundId, uint256 indexed requestId);
    event RandomnessFulfilled(uint256 indexed roundId, uint256 indexed requestId, uint256 randomness);
    event WinnerSelected(uint256 indexed roundId, uint256 indexed slot, address indexed winner, uint256 amount);
    event PrizePaid(uint256 indexed roundId, uint256 indexed slot, address indexed winner, uint256 amount);
    event JackpotAllocated(uint256 indexed roundId, uint256 amount);
    event FreeEntryReserveAllocated(uint256 indexed roundId, uint256 amount);
    event BurnTreasuryAllocated(uint256 indexed roundId, uint256 amount);
    event RoundFinalized(uint256 indexed roundId);
    event RoundFailed(uint256 indexed roundId, string reason);
    event WalletStatusUpdated(address indexed user, bool banned, bool fraudRejected);

    error InvalidConfig();
    error InvalidRound();
    error InvalidQuantity();
    error InvalidPayment();
    error RoundNotOpen();
    error RoundNotClosable();
    error TopUpRequired(uint256 amount);
    error NoEligibleTickets();
    error UnauthorizedCoordinator();
    error UnknownRequest();
    error AlreadySettled();
    error TopUpIncomplete(uint256 amount);
    error WalletExcluded();
    error DuplicateSettlement();
    error NoRandomness();
    error TransferFailed();

    function startNextRound() external returns (uint256 roundId);

    function openRound() external returns (uint256 roundId);

    function buyTickets(uint256 quantity, uint256 maxBlobbieCost) external returns (uint256 amountPaid);

    function closeRoundByThreshold(uint256 roundId) external;

    function closeRoundByTimeout(uint256 roundId) external;

    function provideOperationalTopUp(uint256 roundId, uint256 amount) external;

    function requestRandomness(uint256 roundId) external returns (uint256 requestId);

    function settleRound(uint256 roundId) external;

    function rawFulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) external;

    function currentRoundId() external view returns (uint256);

    function getRound(uint256 roundId) external view returns (Round memory round);

    function requiredOperationalTopUp(uint256 roundId) external view returns (uint256 amount);

    function quoteTickets(uint256 quantity) external view returns (uint256 amount);
}
