import { Contract, JsonRpcProvider, Wallet } from "ethers";
import { env } from "../config/env.js";
import { dailyDrawAbi } from "./dailyDrawAbi.js";

export const provider = new JsonRpcProvider(env.BSC_RPC_URL, env.BSC_CHAIN_ID);

export function getDailyDrawReadContract() {
  return new Contract(env.DAILY_DRAW_ADDRESS, dailyDrawAbi, provider);
}

export function getDailyDrawWriteContract() {
  if (!env.ADMIN_PRIVATE_KEY) {
    throw Object.assign(new Error("ADMIN_PRIVATE_KEY is not configured"), { statusCode: 503 });
  }
  return new Contract(env.DAILY_DRAW_ADDRESS, dailyDrawAbi, new Wallet(env.ADMIN_PRIVATE_KEY, provider));
}

export function serializeBigInts<T>(value: T): T {
  return JSON.parse(
    JSON.stringify(value, (_key, innerValue) => (typeof innerValue === "bigint" ? innerValue.toString() : innerValue))
  ) as T;
}

export async function readRound(roundId: bigint) {
  const contract = getDailyDrawReadContract();
  const round = await contract.rounds(roundId);
  return serializeBigInts({
    id: round.id,
    openedAt: round.openedAt,
    expiresAt: round.expiresAt,
    closedAt: round.closedAt,
    eligibleTicketCount: round.eligibleTicketCount,
    uniqueWalletCount: round.uniqueWalletCount,
    grossTicketRevenue: round.grossTicketRevenue,
    prizePool: round.prizePool,
    jackpotContribution: round.jackpotContribution,
    operationalTopUp: round.operationalTopUp,
    dailyPrizePaid: round.dailyPrizePaid,
    jackpotPaid: round.jackpotPaid,
    dailyWinner: round.dailyWinner,
    jackpotWinner: round.jackpotWinner,
    vrfRequestId: round.vrfRequestId,
    jackpotEligible: round.jackpotEligible,
    status: Number(round.status)
  });
}

export async function readDrawConfig() {
  const contract = getDailyDrawReadContract();
  const [currentRoundId, ticketThreshold, roundDuration, jackpotBps, jackpotTriggerAmount, jackpotReserve] =
    await Promise.all([
      contract.currentRoundId(),
      contract.ticketThreshold(),
      contract.roundDuration(),
      contract.jackpotBps(),
      contract.jackpotTriggerAmount(),
      contract.jackpotReserve()
    ]);

  return serializeBigInts({
    chainId: env.BSC_CHAIN_ID,
    dailyDrawAddress: env.DAILY_DRAW_ADDRESS,
    blobbyTokenAddress: env.BLOBBIE_TOKEN_ADDRESS,
    currentRoundId,
    ticketThreshold,
    roundDuration,
    jackpotBps,
    jackpotTriggerAmount,
    jackpotReserve
  });
}
