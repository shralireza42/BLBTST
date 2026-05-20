// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IBlobbieJackpotVault {
    enum TicketExclusion {
        None,
        Referral,
        Promotional,
        TaskReward,
        OperationalTopUp
    }

    struct JackpotConfig {
        uint256 thresholdUsdE18;
        uint16 contributionBps;
        address priceAdapter;
        address treasury;
    }

    struct JackpotCycle {
        uint256 id;
        uint256 startedAt;
        uint256 endedAt;
        uint256 reserveBalance;
        uint256 totalContributed;
        uint256 eligibleTicketCount;
        uint256 randomnessRequestId;
        address winner;
        uint256 paidAmount;
        bool randomnessRequested;
        bool settled;
    }

    event JackpotConfigUpdated(uint256 thresholdUsdE18, uint16 contributionBps, address indexed priceAdapter);
    event JackpotCycleStarted(uint256 indexed cycleId, uint256 startedAt);
    event JackpotContributionReceived(uint256 indexed cycleId, address indexed draw, uint256 amount);
    event JackpotEligibleTicketsRecorded(
        uint256 indexed cycleId, address indexed user, uint256 ticketCount, uint256 startInclusive, uint256 endExclusive
    );
    event JackpotTicketsExcluded(
        uint256 indexed cycleId, address indexed user, uint256 ticketCount, TicketExclusion indexed exclusion
    );
    event JackpotWalletStatusUpdated(address indexed user, bool banned, bool fraudRejected);
    event JackpotThresholdReached(uint256 indexed cycleId, uint256 reserveBalance, uint256 thresholdAmount);
    event JackpotRandomnessRequested(uint256 indexed cycleId, uint256 indexed roundId, uint256 indexed requestId);
    event JackpotWinnerSelected(uint256 indexed cycleId, address indexed winner, uint256 amount);
    event JackpotPaid(uint256 indexed cycleId, address indexed winner, uint256 amount);
    event JackpotCycleReset(uint256 indexed previousCycleId, uint256 indexed newCycleId);
    event EmergencyRecovery(address indexed token, address indexed recipient, uint256 amount, string reason);

    error InvalidConfig();
    error InvalidRecipient();
    error InvalidAmount();
    error InsufficientReserve();
    error UnsupportedToken();
    error ThresholdNotMet();
    error NoEligibleEntries();
    error NoEligibleWinner();
    error SettlementAlreadyRequested();
    error SettlementAlreadyCompleted();
    error SettlementNotRequested();
    error WalletExcluded();
    error ReserveAccountingMismatch();

    function reserve() external view returns (uint256);

    function config() external view returns (JackpotConfig memory);

    function currentCycleId() external view returns (uint256);

    function getCycle(uint256 cycleId) external view returns (JackpotCycle memory);

    function contributeFromDraw(uint256 amount) external;

    function recordEligibleTickets(address user, uint256 ticketCount) external;

    function recordExcludedTickets(address user, uint256 ticketCount, TicketExclusion exclusion) external;

    function isThresholdMet() external view returns (bool);

    function jackpotThresholdInBlobbie() external view returns (uint256);

    function requestJackpotRandomness(uint256 roundId, uint256 requestId) external returns (uint256 cycleId);

    function settleJackpotWinner(uint256 cycleId, uint256 randomness) external returns (address winner, uint256 amount);
}
