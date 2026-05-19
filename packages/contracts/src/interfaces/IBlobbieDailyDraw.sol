// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IBlobbieDailyDraw {
    enum RoundStatus {
        None,
        Open,
        Closing,
        RandomnessRequested,
        Fulfilled,
        Cancelled
    }

    struct DrawConfig {
        uint32 ticketThreshold;
        uint64 roundDuration;
        uint256 ticketUsdPrice8;
        uint16 jackpotContributionBps;
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
        uint256 vrfRequestId;
        bool jackpotEligible;
        address dailyWinner;
        address jackpotWinner;
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
    event RoundOpened(uint256 indexed roundId, uint64 openedAt, uint64 expiresAt);
    event TicketsPurchased(
        uint256 indexed roundId,
        address indexed buyer,
        uint32 quantity,
        uint32 startInclusive,
        uint32 endExclusive,
        uint256 amountPaid
    );
    event OperationalTopUp(uint256 indexed roundId, address indexed payer, uint256 amount);
    event RoundCloseRequested(uint256 indexed roundId, uint256 indexed requestId, bool jackpotEligible);
    event RoundFulfilled(uint256 indexed roundId, address indexed dailyWinner, address indexed jackpotWinner);
    event RoundCancelled(uint256 indexed roundId);

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

    function openRound() external returns (uint256 roundId);

    function buyTickets(uint32 quantity, uint256 maxPayment) external returns (uint256 amountPaid);

    function topUpRound(uint256 roundId, uint256 amount) external;

    function closeRound(uint256 roundId) external returns (uint256 requestId);

    function rawFulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) external;

    function currentRoundId() external view returns (uint256);

    function getRound(uint256 roundId) external view returns (Round memory round);

    function requiredOperationalTopUp(uint256 roundId) external view returns (uint256 amount);

    function quoteTickets(uint32 quantity) external view returns (uint256 amount);
}
