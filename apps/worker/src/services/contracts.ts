import { Contract, JsonRpcProvider, Wallet } from "ethers";
import { env } from "../env.js";

export const dailyDrawAutomationAbi = [
  "function currentRoundId() view returns (uint256)",
  "function getRound(uint256 roundId) view returns (uint256 id,uint64 openedAt,uint64 expiresAt,uint64 closedAt,uint32 eligibleTicketCount,uint32 uniqueWalletCount,uint256 grossTicketRevenue,uint256 operationalTopUp,uint256 jackpotContribution,uint256 prizePool,uint256 topUpRequired,uint256 vrfRequestId,uint256 randomness,uint256 jackpotAllocated,uint256 freeEntryReserveAllocated,uint256 burnTreasuryAllocated,uint16 winnersPaid,uint8 status)",
  "function requiredOperationalTopUp(uint256 roundId) view returns (uint256)",
  "function closeRoundByTimeout(uint256 roundId)",
  "function closeRoundByThreshold(uint256 roundId)",
  "function provideOperationalTopUp(uint256 roundId,uint256 amount)",
  "function requestRandomness(uint256 roundId) returns (uint256)",
  "function settleRound(uint256 roundId)",
  "function quoteTickets(uint256 quantity) view returns (uint256)",
  "function pause()",
  "function unpause()"
] as const;

export const jackpotAutomationAbi = [
  "function currentCycleId() view returns (uint256)",
  "function getCycle(uint256 cycleId) view returns (uint256 id,uint256 startedAt,uint256 endedAt,uint256 reserveBalance,uint256 totalContributed,uint256 eligibleTicketCount,uint256 randomnessRequestId,address winner,uint256 paidAmount,bool randomnessRequested,bool settled)",
  "function isThresholdMet() view returns (bool)",
  "function requestJackpotRandomness(uint256 roundId,uint256 requestId) returns (uint256)",
  "function settleJackpotWinner(uint256 cycleId,uint256 randomness) returns (address,uint256)"
] as const;

export function readContracts(provider: JsonRpcProvider) {
  return {
    dailyDraw: new Contract(env.DAILY_DRAW_ADDRESS, dailyDrawAutomationAbi, provider),
    jackpot: new Contract(env.JACKPOT_VAULT_ADDRESS, jackpotAutomationAbi, provider)
  };
}

export function writeContracts(provider: JsonRpcProvider) {
  if (!env.WORKER_PRIVATE_KEY) throw new Error("WORKER_PRIVATE_KEY is required when WORKER_DRY_RUN=false");
  const signer = new Wallet(env.WORKER_PRIVATE_KEY, provider);
  return {
    dailyDraw: new Contract(env.DAILY_DRAW_ADDRESS, dailyDrawAutomationAbi, signer),
    jackpot: new Contract(env.JACKPOT_VAULT_ADDRESS, jackpotAutomationAbi, signer)
  };
}

export async function sendIfEnabled(label: string, txFactory: () => Promise<{ hash: string; wait: () => Promise<unknown> }>) {
  if (env.WORKER_DRY_RUN) return { dryRun: true, label };
  const tx = await txFactory();
  await tx.wait();
  return { dryRun: false, label, txHash: tx.hash };
}
