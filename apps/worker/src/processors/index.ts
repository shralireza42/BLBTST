import { prisma } from "@blobby/database";
import { Job } from "bullmq";
import { JsonRpcProvider } from "ethers";
import pino from "pino";
import { checkIndexerHealth, syncContracts } from "../jobs/contractIndexer.js";
import { env } from "../env.js";
import { QueueName, QUEUE_NAMES } from "../queues/names.js";
import { readContracts, sendIfEnabled, writeContracts } from "../services/contracts.js";
import { runLogged, snapshotQueueHealth } from "../services/jobLog.js";
import { Contract } from "ethers";

export type ProcessorContext = {
  provider: JsonRpcProvider;
  logger: pino.Logger;
};

type RoundStruct = {
  id: bigint;
  expiresAt: bigint;
  eligibleTicketCount: bigint;
  topUpRequired: bigint;
  vrfRequestId: bigint;
  randomness: bigint;
  status: bigint;
};

export function createProcessor(queueName: QueueName, ctx: ProcessorContext) {
  return async (job: Job) => runLogged(queueName, String(job.id), () => dispatch(queueName, ctx));
}

async function dispatch(queueName: QueueName, ctx: ProcessorContext) {
  switch (queueName) {
    case QUEUE_NAMES.roundTimeoutMonitor:
      return roundTimeoutMonitor(ctx);
    case QUEUE_NAMES.roundCloseWorker:
      return roundCloseWorker(ctx);
    case QUEUE_NAMES.settlementMonitor:
      return settlementMonitor(ctx);
    case QUEUE_NAMES.vrfMonitor:
      return vrfMonitor(ctx);
    case QUEUE_NAMES.jackpotThresholdMonitor:
      return jackpotThresholdMonitor(ctx);
    case QUEUE_NAMES.oracleHealthMonitor:
      return oracleHealthMonitor(ctx);
    case QUEUE_NAMES.priceSnapshotWorker:
      return priceSnapshotWorker(ctx);
    case QUEUE_NAMES.auditExportWorker:
      return auditExportWorker();
  }
}

async function roundTimeoutMonitor(ctx: ProcessorContext) {
  const { dailyDraw } = readContracts(ctx.provider);
  const roundId = await dailyDraw.currentRoundId() as bigint;
  if (roundId === 0n) return { skipped: "no-round" };
  const round = await getRound(dailyDraw, roundId);
  if (Number(round.status) !== 0) return { skipped: "not-open", roundId };
  if (Date.now() / 1000 < Number(round.expiresAt)) return { skipped: "not-expired", roundId };
  const writes = writeMaybe(ctx.provider);
  return sendIfEnabled("closeRoundByTimeout", () => writes.dailyDraw.closeRoundByTimeout(roundId));
}

async function roundCloseWorker(ctx: ProcessorContext) {
  await syncContracts(ctx);
  const { dailyDraw } = readContracts(ctx.provider);
  const roundId = await dailyDraw.currentRoundId() as bigint;
  if (roundId === 0n) return { skipped: "no-round" };
  const round = await getRound(dailyDraw, roundId);
  if (Number(round.status) !== 0) return { skipped: "not-open", roundId };
  if (round.eligibleTicketCount < 300n) return { skipped: "below-threshold", roundId, eligible: round.eligibleTicketCount };
  const writes = writeMaybe(ctx.provider);
  return sendIfEnabled("closeRoundByThreshold", () => writes.dailyDraw.closeRoundByThreshold(roundId));
}

async function settlementMonitor(ctx: ProcessorContext) {
  const rows = await prisma.drawRound.findMany({ where: { status: "DRAWING" }, orderBy: { id: "asc" }, take: 10 });
  const writes = writeMaybe(ctx.provider);
  const results = [];
  for (const row of rows) {
    const round = await getRound(readContracts(ctx.provider).dailyDraw, row.id);
    if (Number(round.status) !== 3) continue;
    if (await prisma.drawSettlement.findFirst({ where: { roundId: row.id, status: "FINALIZED" } })) continue;
    results.push(await sendIfEnabled("settleRound", () => writes.dailyDraw.settleRound(row.id)));
  }
  return { settled: results };
}

async function vrfMonitor(ctx: ProcessorContext) {
  const rows = await prisma.drawRound.findMany({ where: { status: "CLOSED", topUpRequired: "0" }, orderBy: { id: "asc" }, take: 10 });
  const writes = writeMaybe(ctx.provider);
  const results = [];
  for (const row of rows) {
    const round = await getRound(readContracts(ctx.provider).dailyDraw, row.id);
    if (Number(round.status) !== 1 || round.topUpRequired !== 0n) continue;
    if (round.vrfRequestId !== 0n) continue;
    results.push(await sendIfEnabled("requestRandomness", () => writes.dailyDraw.requestRandomness(row.id)));
  }
  return { requested: results };
}

async function jackpotThresholdMonitor(ctx: ProcessorContext) {
  const { jackpot } = readContracts(ctx.provider);
  const thresholdMet = await jackpot.isThresholdMet() as boolean;
  if (!thresholdMet) return { skipped: "threshold-not-met" };
  const cycleId = await jackpot.currentCycleId() as bigint;
  const cycle = await jackpot.getCycle(cycleId) as { randomnessRequested: boolean; settled: boolean };
  if (cycle.randomnessRequested || cycle.settled) return { skipped: "already-requested-or-settled", cycleId };
  await prisma.jackpotCycle.updateMany({ where: { id: cycleId, status: "OPEN" }, data: { status: "THRESHOLD_MET", thresholdMetAt: new Date() } });
  return { thresholdMet: true, cycleId };
}

async function oracleHealthMonitor(ctx: ProcessorContext) {
  const started = Date.now();
  try {
    const blockNumber = await ctx.provider.getBlockNumber();
    await prisma.oracleHealthCheck.create({ data: { chainId: env.BSC_CHAIN_ID, oracleAddress: env.DAILY_DRAW_ADDRESS.toLowerCase(), status: "OK", latencyMs: Date.now() - started, error: `latestBlock=${blockNumber}` } });
    return { status: "OK", blockNumber };
  } catch (error) {
    await prisma.oracleHealthCheck.create({ data: { chainId: env.BSC_CHAIN_ID, oracleAddress: env.DAILY_DRAW_ADDRESS.toLowerCase(), status: "ERROR", error: error instanceof Error ? error.message : String(error), latencyMs: Date.now() - started } });
    throw error;
  }
}

async function priceSnapshotWorker(ctx: ProcessorContext) {
  const { dailyDraw } = readContracts(ctx.provider);
  const amount = await dailyDraw.quoteTickets?.(1).catch(() => undefined);
  await prisma.priceSnapshot.create({ data: { chainId: env.BSC_CHAIN_ID, oracleAddress: env.DAILY_DRAW_ADDRESS.toLowerCase(), tokenAddress: env.DAILY_DRAW_ADDRESS.toLowerCase(), priceE18: amount ? String(amount) : "0", source: "worker.ticket.quote", observedAt: new Date() } });
  return { quote: amount?.toString() ?? null };
}

async function auditExportWorker() {
  const finalized = await prisma.drawRound.findMany({ where: { status: "FINALIZED" }, orderBy: { id: "desc" }, take: 25 });
  await prisma.systemConfig.upsert({
    where: { key: "audit.export.latest" },
    update: { value: { generatedAt: new Date().toISOString(), roundIds: finalized.map((r) => r.id.toString()) } },
    create: { key: "audit.export.latest", value: { generatedAt: new Date().toISOString(), roundIds: finalized.map((r) => r.id.toString()) } }
  });
  return { exportedRounds: finalized.length };
}

function writeMaybe(provider: JsonRpcProvider) {
  return env.WORKER_DRY_RUN ? mockWriteContracts() : writeContracts(provider);
}

function mockWriteContracts(): any {
  const tx = async () => ({ hash: "dry-run", wait: async () => ({}) });
  return { dailyDraw: { closeRoundByTimeout: tx, closeRoundByThreshold: tx, requestRandomness: tx, settleRound: tx }, jackpot: { requestJackpotRandomness: tx, settleJackpotWinner: tx } };
}

async function getRound(dailyDraw: Contract, roundId: bigint): Promise<RoundStruct> {
  const round = await dailyDraw.getRound(roundId);
  return { id: round.id, expiresAt: round.expiresAt, eligibleTicketCount: round.eligibleTicketCount, topUpRequired: round.topUpRequired, vrfRequestId: round.vrfRequestId, randomness: round.randomness, status: round.status };
}
