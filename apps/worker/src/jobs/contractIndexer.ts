import { prisma } from "@blobby/database";
import { Contract, Interface, JsonRpcProvider, Log } from "ethers";
import pino from "pino";
import { dailyDrawAbi, jackpotAbi } from "../abis.js";
import { env } from "../env.js";

export type IndexerContext = {
  provider: JsonRpcProvider;
  logger: pino.Logger;
};

type ContractTarget = {
  cursorName: "daily-draw" | "jackpot-vault";
  address: string;
  abi: readonly string[];
  processor: (event: DecodedEvent) => Promise<void>;
};

type DecodedEvent = {
  name: string;
  args: Record<string, unknown>;
  txHash: string;
  logIndex: number;
  blockNumber: bigint;
  contractAddress: string;
  chainId: number;
};

export async function syncContracts(ctx: IndexerContext) {
  await syncDrawEvents(ctx);
  await syncJackpotEvents(ctx);
}

export async function syncDrawEvents(ctx: IndexerContext) {
  await syncTarget(ctx, {
    cursorName: "daily-draw",
    address: env.DAILY_DRAW_ADDRESS,
    abi: dailyDrawAbi,
    processor: processDailyDrawEvent
  });
}

export async function syncJackpotEvents(ctx: IndexerContext) {
  await syncTarget(ctx, {
    cursorName: "jackpot-vault",
    address: env.JACKPOT_VAULT_ADDRESS,
    abi: jackpotAbi,
    processor: processJackpotEvent
  });
}

export async function checkIndexerHealth(ctx: IndexerContext) {
  const latestBlock = await ctx.provider.getBlockNumber();
  const safeBlock = Math.max(0, latestBlock - env.CONTRACT_CONFIRMATION_DEPTH);
  const cursors = await prisma.contractSyncCursor.findMany({ where: { chainId: env.BSC_CHAIN_ID } });
  const unhealthy = cursors.filter((cursor) => Number(cursor.lastBlockNumber) < safeBlock - env.EVENT_SYNC_CHUNK_SIZE * 2);
  const status = unhealthy.length === 0 ? "ok" : "lagging";
  await prisma.systemConfig.upsert({
    where: { key: "indexer.health" },
    update: { value: jsonify({ status, latestBlock, safeBlock, checkedAt: new Date().toISOString(), cursors }) },
    create: { key: "indexer.health", value: jsonify({ status, latestBlock, safeBlock, checkedAt: new Date().toISOString(), cursors }) }
  });
  return { status, latestBlock, safeBlock, cursors };
}

async function syncTarget(ctx: IndexerContext, target: ContractTarget) {
  const latestBlock = await ctx.provider.getBlockNumber();
  const safeBlock = latestBlock - env.CONTRACT_CONFIRMATION_DEPTH;
  if (safeBlock < 0) return;

  const startBlock = env.CONTRACT_SYNC_START_BLOCK ?? env.DEPLOY_BLOCK;
  const cursor = await prisma.contractSyncCursor.findUnique({
    where: {
      chainId_contractAddress_cursorName: {
        chainId: env.BSC_CHAIN_ID,
        contractAddress: target.address.toLowerCase(),
        cursorName: target.cursorName
      }
    }
  });
  let fromBlock = cursor ? Number(cursor.lastBlockNumber) + 1 : startBlock;
  const iface = new Interface(target.abi);

  while (fromBlock <= safeBlock) {
    const toBlock = Math.min(fromBlock + env.EVENT_SYNC_CHUNK_SIZE - 1, safeBlock);
    const logs = await ctx.provider.getLogs({ address: target.address, fromBlock, toBlock });
    for (const log of logs) {
      await processLog(iface, log, target);
    }
    await prisma.contractSyncCursor.upsert({
      where: {
        chainId_contractAddress_cursorName: {
          chainId: env.BSC_CHAIN_ID,
          contractAddress: target.address.toLowerCase(),
          cursorName: target.cursorName
        }
      },
      update: { lastBlockNumber: BigInt(toBlock), lastTxHash: logs.at(-1)?.transactionHash, lastLogIndex: logs.at(-1)?.index },
      create: {
        chainId: env.BSC_CHAIN_ID,
        contractAddress: target.address.toLowerCase(),
        cursorName: target.cursorName,
        lastBlockNumber: BigInt(toBlock),
        lastTxHash: logs.at(-1)?.transactionHash,
        lastLogIndex: logs.at(-1)?.index
      }
    });
    fromBlock = toBlock + 1;
  }
}

async function processLog(iface: Interface, log: Log, target: ContractTarget) {
  const parsed = iface.parseLog({ topics: [...log.topics], data: log.data });
  if (!parsed) return;
  const decoded: DecodedEvent = {
    name: parsed.name,
    args: namedArgs(parsed.args as unknown as Record<string, unknown>),
    txHash: log.transactionHash,
    logIndex: log.index,
    blockNumber: BigInt(log.blockNumber),
    contractAddress: target.address.toLowerCase(),
    chainId: env.BSC_CHAIN_ID
  };

  await prisma.contractEvent.upsert({
    where: { chainId_txHash_logIndex: { chainId: decoded.chainId, txHash: decoded.txHash, logIndex: decoded.logIndex } },
    update: { status: "PROCESSED", processedAt: new Date(), payload: jsonify(decoded.args), eventName: decoded.name },
    create: {
      chainId: decoded.chainId,
      contractAddress: decoded.contractAddress,
      eventName: decoded.name,
      txHash: decoded.txHash,
      logIndex: decoded.logIndex,
      blockNumber: decoded.blockNumber,
      payload: jsonify(decoded.args),
      status: "PROCESSED",
      processedAt: new Date()
    }
  });
  await target.processor(decoded);
}

async function processDailyDrawEvent(event: DecodedEvent) {
  if (event.name === "RoundStarted") {
    const roundId = asBigInt(event.args.roundId);
    await prisma.drawRound.upsert({
      where: { id: roundId },
      update: {
        chainId: event.chainId,
        contractAddress: event.contractAddress,
        status: "OPEN",
        openedAt: secondsToDate(event.args.openedAt),
        expiresAt: secondsToDate(event.args.expiresAt),
        txHash: event.txHash,
        blockNumber: event.blockNumber
      },
      create: {
        id: roundId,
        chainId: event.chainId,
        contractAddress: event.contractAddress,
        status: "OPEN",
        openedAt: secondsToDate(event.args.openedAt),
        expiresAt: secondsToDate(event.args.expiresAt),
        txHash: event.txHash,
        blockNumber: event.blockNumber
      }
    });
    return;
  }

  if (event.name === "TicketPurchased") {
    const roundId = asBigInt(event.args.roundId);
    await ensureDrawRound(roundId, event);
    const buyer = String(event.args.buyer).toLowerCase();
    const quantity = Number(event.args.quantity);
    const amountPaid = asBigInt(event.args.amountPaid).toString();
    await prisma.drawEntry.upsert({
      where: { chainId_txHash_logIndex: { chainId: event.chainId, txHash: event.txHash, logIndex: event.logIndex } },
      update: {},
      create: {
        roundId,
        chainId: event.chainId,
        contractAddress: event.contractAddress,
        walletAddress: buyer,
        source: "PAID",
        status: "ELIGIBLE",
        quantity,
        eligibleQuantity: quantity,
        startInclusive: Number(event.args.startInclusive),
        endExclusive: Number(event.args.endExclusive),
        blobbyPaid: amountPaid,
        usdValueE18: (BigInt(quantity) * 10n ** 18n).toString(),
        txHash: event.txHash,
        logIndex: event.logIndex,
        blockNumber: event.blockNumber
      }
    });
    await prisma.ticketPurchase.upsert({
      where: { txHash_logIndex: { txHash: event.txHash, logIndex: event.logIndex } },
      update: {},
      create: {
        roundId,
        buyer,
        quantity,
        startInclusive: Number(event.args.startInclusive),
        endExclusive: Number(event.args.endExclusive),
        blobbyPaid: amountPaid,
        jackpotContribution: "0",
        txHash: event.txHash,
        logIndex: event.logIndex,
        blockNumber: event.blockNumber
      }
    });
    await prisma.drawRound.update({
      where: { id: roundId },
      data: { eligibleTicketCount: { increment: quantity }, totalEntryCount: { increment: quantity }, grossTicketRevenue: { increment: amountPaid }, prizePool: { increment: amountPaid } }
    });
    return;
  }

  if (event.name === "RoundClosed") {
    const roundId = asBigInt(event.args.roundId);
    await ensureDrawRound(roundId, event);
    await prisma.drawRound.update({
      where: { id: roundId },
      data: { status: "CLOSED", eligibleTicketCount: Number(event.args.eligibleTicketCount), prizePool: asBigInt(event.args.prizePool).toString(), closeTxHash: event.txHash, closeBlockNumber: event.blockNumber, closedAt: new Date() }
    });
    return;
  }

  if (event.name === "OperationalTopUpRequired") {
    const roundId = asBigInt(event.args.roundId);
    await ensureDrawRound(roundId, event);
    await prisma.drawRound.update({ where: { id: roundId }, data: { topUpRequired: asBigInt(event.args.amount).toString() } });
    return;
  }

  if (event.name === "OperationalTopUpReceived") {
    const roundId = asBigInt(event.args.roundId);
    await ensureDrawRound(roundId, event);
    const amount = asBigInt(event.args.amount).toString();
    await prisma.drawTopUp.upsert({
      where: { txHash_logIndex: { txHash: event.txHash, logIndex: event.logIndex } },
      update: {},
      create: { roundId, payer: String(event.args.payer).toLowerCase(), amount, txHash: event.txHash, logIndex: event.logIndex, blockNumber: event.blockNumber }
    });
    await prisma.drawRound.update({ where: { id: roundId }, data: { operationalTopUp: { increment: amount }, prizePool: { increment: amount }, topUpRequired: "0" } });
    return;
  }

  if (event.name === "RandomnessRequested") {
    const roundId = asBigInt(event.args.roundId);
    await ensureDrawRound(roundId, event);
    await prisma.drawRound.update({ where: { id: roundId }, data: { status: "VRF_REQUESTED", vrfRequestId: asBigInt(event.args.requestId).toString() } });
    await prisma.drawSettlement.upsert({
      where: { id: `${event.chainId}:${event.txHash}:${event.logIndex}` },
      update: { status: "VRF_REQUESTED", vrfRequestId: asBigInt(event.args.requestId).toString(), requestedTxHash: event.txHash, blockNumber: event.blockNumber },
      create: { id: `${event.chainId}:${event.txHash}:${event.logIndex}`, roundId, status: "VRF_REQUESTED", vrfRequestId: asBigInt(event.args.requestId).toString(), requestedTxHash: event.txHash, blockNumber: event.blockNumber }
    });
    return;
  }

  if (event.name === "RandomnessFulfilled") {
    const roundId = asBigInt(event.args.roundId);
    await ensureDrawRound(roundId, event);
    await prisma.drawRound.update({ where: { id: roundId }, data: { status: "DRAWING", randomness: asBigInt(event.args.randomness).toString() } });
    return;
  }

  if (event.name === "WinnerSelected" || event.name === "PrizePaid") {
    const roundId = asBigInt(event.args.roundId);
    await ensureDrawRound(roundId, event);
    const slot = Number(event.args.slot);
    const winner = String(event.args.winner).toLowerCase();
    await prisma.drawWinner.upsert({
      where: { roundId_slot: { roundId, slot } },
      update: { paid: event.name === "PrizePaid" ? true : undefined, txHash: event.txHash, logIndex: event.logIndex, blockNumber: event.blockNumber },
      create: { roundId, walletAddress: winner, winner, slot, tier: tierForSlot(slot), prizeType: event.name === "PrizePaid" ? "PAID" : "SELECTED", amount: asBigInt(event.args.amount).toString(), usdValueE18: "0", paid: event.name === "PrizePaid", txHash: event.txHash, logIndex: event.logIndex, blockNumber: event.blockNumber }
    });
    return;
  }

  if (event.name === "JackpotAllocated") {
    const roundId = asBigInt(event.args.roundId);
    await ensureDrawRound(roundId, event);
    await prisma.drawRound.update({ where: { id: roundId }, data: { jackpotContribution: { increment: asBigInt(event.args.amount).toString() } } });
    return;
  }

  if (event.name === "FreeEntryReserveAllocated") {
    await prisma.drawRound.update({ where: { id: asBigInt(event.args.roundId) }, data: { freeEntryReserve: { increment: asBigInt(event.args.amount).toString() } } });
    return;
  }

  if (event.name === "BurnTreasuryAllocated") {
    await prisma.drawRound.update({ where: { id: asBigInt(event.args.roundId) }, data: { burnTreasuryReserve: { increment: asBigInt(event.args.amount).toString() } } });
    return;
  }

  if (event.name === "RoundFinalized") {
    await prisma.drawRound.update({ where: { id: asBigInt(event.args.roundId) }, data: { status: "FINALIZED", finalizedAt: new Date(), settlementTxHash: event.txHash, settlementBlockNumber: event.blockNumber } });
    return;
  }

  if (event.name === "RoundFailed") {
    await prisma.drawRound.update({ where: { id: asBigInt(event.args.roundId) }, data: { status: "FAILED_NEEDS_ADMIN_REVIEW", reviewStatus: "PENDING", reviewReason: String(event.args.reason) } });
  }
}

async function processJackpotEvent(event: DecodedEvent) {
  if (event.name === "JackpotCycleStarted" || event.name === "JackpotCycleReset") {
    const cycleId = event.name === "JackpotCycleReset" ? asBigInt(event.args.newCycleId) : asBigInt(event.args.cycleId);
    await ensureJackpotCycle(cycleId, event);
    return;
  }

  if (event.name === "JackpotContributionReceived") {
    const cycleId = asBigInt(event.args.cycleId);
    await ensureJackpotCycle(cycleId, event);
    const amount = asBigInt(event.args.amount).toString();
    await prisma.jackpotContribution.upsert({
      where: { chainId_txHash_logIndex: { chainId: event.chainId, txHash: event.txHash, logIndex: event.logIndex } },
      update: {},
      create: { cycleId, amount, source: "DRAW", chainId: event.chainId, contractAddress: event.contractAddress, txHash: event.txHash, logIndex: event.logIndex, blockNumber: event.blockNumber }
    });
    await prisma.jackpotCycle.update({ where: { id: cycleId }, data: { reserveBalance: { increment: amount }, totalContributed: { increment: amount } } });
    return;
  }

  if (event.name === "JackpotThresholdReached") {
    await prisma.jackpotCycle.update({ where: { id: asBigInt(event.args.cycleId) }, data: { status: "THRESHOLD_MET", thresholdMetAt: new Date(), reserveBalance: asBigInt(event.args.reserveBalance).toString(), thresholdBlobbie: asBigInt(event.args.thresholdAmount).toString() } });
    return;
  }

  if (event.name === "JackpotWinnerSelected") {
    const cycleId = asBigInt(event.args.cycleId);
    await ensureJackpotCycle(cycleId, event);
    await prisma.jackpotCycle.update({ where: { id: cycleId }, data: { status: "SETTLING", winnerWalletAddress: String(event.args.winner).toLowerCase(), paidAmount: event.args.amount ? asBigInt(event.args.amount).toString() : "0" } });
    return;
  }

  if (event.name === "JackpotPaid") {
    const cycleId = asBigInt(event.args.cycleId);
    await ensureJackpotCycle(cycleId, event);
    const winner = String(event.args.winner).toLowerCase();
    const amount = asBigInt(event.args.amount).toString();
    await prisma.jackpotWinner.upsert({
      where: { cycleId },
      update: { walletAddress: winner, amount, txHash: event.txHash, logIndex: event.logIndex, blockNumber: event.blockNumber, paidAt: new Date() },
      create: { cycleId, walletAddress: winner, amount, txHash: event.txHash, logIndex: event.logIndex, blockNumber: event.blockNumber, paidAt: new Date() }
    });
    await prisma.jackpotCycle.update({ where: { id: cycleId }, data: { status: "PAID", winnerWalletAddress: winner, paidAmount: amount, reserveBalance: "0", settlementTxHash: event.txHash, endedAt: new Date() } });
    return;
  }

  if (event.name === "JackpotRandomnessRequested") {
    await prisma.jackpotCycle.update({ where: { id: asBigInt(event.args.cycleId) }, data: { status: "VRF_REQUESTED", vrfRequestId: asBigInt(event.args.requestId).toString(), randomnessRequestedAt: new Date() } });
  }
}

async function ensureDrawRound(roundId: bigint, event: DecodedEvent) {
  await prisma.drawRound.upsert({
    where: { id: roundId },
    update: {},
    create: {
      id: roundId,
      chainId: event.chainId,
      contractAddress: event.contractAddress,
      status: "OPEN",
      openedAt: new Date(0),
      expiresAt: new Date(0),
      blockNumber: event.blockNumber
    }
  });
}

async function ensureJackpotCycle(cycleId: bigint, event: DecodedEvent) {
  await prisma.jackpotCycle.upsert({
    where: { id: cycleId },
    update: { chainId: event.chainId, contractAddress: event.contractAddress },
    create: { id: cycleId, chainId: event.chainId, contractAddress: event.contractAddress, status: "OPEN", startedAt: new Date(), blockNumber: event.blockNumber }
  });
}

function namedArgs(args: Record<string, unknown>) {
  return Object.fromEntries(Object.entries(args).filter(([key]) => Number.isNaN(Number(key))));
}

function jsonify(value: unknown) {
  return JSON.parse(JSON.stringify(value, (_key, innerValue) => (typeof innerValue === "bigint" ? innerValue.toString() : innerValue)));
}

function asBigInt(value: unknown): bigint {
  return typeof value === "bigint" ? value : BigInt(String(value || 0));
}

function secondsToDate(value: unknown) {
  return new Date(Number(asBigInt(value)) * 1000);
}

function tierForSlot(slot: number) {
  if (slot === 0) return "FIRST" as const;
  if (slot < 10) return "SECOND_TO_TENTH" as const;
  return "ELEVENTH_TO_ONE_FIFTIETH" as const;
}
