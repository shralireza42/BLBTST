export const dailyDrawAbi = [
  "function currentRoundId() view returns (uint256)",
  "function ticketThreshold() view returns (uint32)",
  "function requiredOperationalTopUp(uint256 roundId) view returns (uint256)",
  "function rounds(uint256 roundId) view returns (uint256 id,uint64 openedAt,uint64 expiresAt,uint64 closedAt,uint32 eligibleTicketCount,uint32 uniqueWalletCount,uint256 grossTicketRevenue,uint256 prizePool,uint256 jackpotContribution,uint256 operationalTopUp,uint256 dailyPrizePaid,uint256 jackpotPaid,address dailyWinner,address jackpotWinner,uint256 vrfRequestId,bool jackpotEligible,uint8 status)",
  "function openRound() returns (uint256)",
  "function closeRound(uint256 roundId) returns (uint256)",
  "function topUpAndClose(uint256 roundId,uint256 maxTopUp)",
  "event RoundOpened(uint256 indexed roundId,uint64 openedAt,uint64 expiresAt)",
  "event TicketsPurchased(uint256 indexed roundId,address indexed buyer,uint32 quantity,uint32 startInclusive,uint32 endExclusive,uint256 blobbyPaid,uint256 jackpotContribution)",
  "event OperationalTopUp(uint256 indexed roundId,address indexed payer,uint256 amount)",
  "event RoundCloseRequested(uint256 indexed roundId,uint256 indexed requestId,bool jackpotEligible)",
  "event RoundFulfilled(uint256 indexed roundId,address indexed dailyWinner,uint256 dailyPrizePaid,address indexed jackpotWinner,uint256 jackpotPaid)",
  "event RoundCancelled(uint256 indexed roundId,address indexed recipient,uint256 topUpRefunded)"
] as const;
