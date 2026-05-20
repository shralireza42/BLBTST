export const dailyDrawAbi = [
  "event RoundStarted(uint256 indexed roundId,uint64 openedAt,uint64 expiresAt)",
  "event TicketPurchased(uint256 indexed roundId,address indexed buyer,uint256 quantity,uint256 startInclusive,uint256 endExclusive,uint256 amountPaid)",
  "event RoundClosed(uint256 indexed roundId,uint256 eligibleTicketCount,uint256 prizePool)",
  "event OperationalTopUpRequired(uint256 indexed roundId,uint256 amount)",
  "event OperationalTopUpReceived(uint256 indexed roundId,address indexed payer,uint256 amount)",
  "event RandomnessRequested(uint256 indexed roundId,uint256 indexed requestId)",
  "event RandomnessFulfilled(uint256 indexed roundId,uint256 indexed requestId,uint256 randomness)",
  "event WinnerSelected(uint256 indexed roundId,uint256 indexed slot,address indexed winner,uint256 amount)",
  "event PrizePaid(uint256 indexed roundId,uint256 indexed slot,address indexed winner,uint256 amount)",
  "event JackpotAllocated(uint256 indexed roundId,uint256 amount)",
  "event FreeEntryReserveAllocated(uint256 indexed roundId,uint256 amount)",
  "event BurnTreasuryAllocated(uint256 indexed roundId,uint256 amount)",
  "event RoundFinalized(uint256 indexed roundId)",
  "event RoundFailed(uint256 indexed roundId,string reason)"
] as const;

export const jackpotAbi = [
  "event JackpotCycleStarted(uint256 indexed cycleId,uint256 startedAt)",
  "event JackpotContributionReceived(uint256 indexed cycleId,address indexed draw,uint256 amount)",
  "event JackpotThresholdReached(uint256 indexed cycleId,uint256 reserveBalance,uint256 thresholdAmount)",
  "event JackpotWinnerSelected(uint256 indexed cycleId,address indexed winner,uint256 amount)",
  "event JackpotPaid(uint256 indexed cycleId,address indexed winner,uint256 amount)",
  "event JackpotCycleReset(uint256 indexed previousCycleId,uint256 indexed newCycleId)",
  "event JackpotRandomnessRequested(uint256 indexed cycleId,uint256 indexed roundId,uint256 indexed requestId)"
] as const;
