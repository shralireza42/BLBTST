import { PrismaClient } from "@prisma/client";
import { Contract, JsonRpcProvider, Wallet } from "ethers";
import pino from "pino";
import { dailyDrawAbi } from "./dailyDrawAbi.js";
import { env } from "./env.js";

const prisma = new PrismaClient();
const logger = pino({ level: env.LOG_LEVEL });
const provider = new JsonRpcProvider(env.BSC_RPC_URL, env.BSC_CHAIN_ID);
const signer = env.WORKER_PRIVATE_KEY ? new Wallet(env.WORKER_PRIVATE_KEY, provider) : undefined;
const readContract = new Contract(env.DAILY_DRAW_ADDRESS, dailyDrawAbi, provider);
const writeContract = signer ? new Contract(env.DAILY_DRAW_ADDRESS, dailyDrawAbi, signer) : undefined;

const ROUND_STATUS = ["NONE", "OPEN", "CALCULATING", "FULFILLED", "CANCELLED"] as const;

async function main() {
  logger.info("BLOBBIE worker starting");
  while (true) {
    try {
      await syncEvents();
      await automateRound();
    } catch (error) {
      logger.error({ error }, "worker loop failed");
    }
    await sleep(env.POLL_INTERVAL_MS);
  }
}

async function automateRound() {
  const currentRoundId = BigInt(await readContract.currentRoundId());

  if (currentRoundId === 0n) {
    if (env.AUTO_OPEN_ROUND) {
      await requireWriteContract().openRound().then(waitForTx("openRound"));
    }
    return;
  }

  const round = await readContract.rounds(currentRoundId);
  const status = Number(round.status);

  if ((status === 3 || status === 4) && env.AUTO_OPEN_ROUND) {
    await requireWriteContract().openRound().then(waitForTx("openRound"));
    return;
  }

  if (status !== 1) {
    return;
  }

  const threshold = Number(await readContract.ticketThreshold());
  const eligibleTicketCount = Number(round.eligibleTicketCount);
  const expiresAtMs = Number(round.expiresAt) * 1000;

  if (eligibleTicketCount >= threshold) {
    await requireWriteContract().closeRound(currentRoundId).then(waitForTx("closeRound"));
    return;
  }

  if (Date.now() >= expiresAtMs) {
    const missingTopUp = BigInt(await readContract.requiredOperationalTopUp(currentRoundId));
    if (missingTopUp === 0n) {
      await requireWriteContract().closeRound(currentRoundId).then(waitForTx("closeExpiredRound"));
      return;
    }

    const maxTopUp = BigInt(env.MAX_TOP_UP_WEI);
    if (maxTopUp === 0n || missingTopUp > maxTopUp) {
      logger.warn(
        { roundId: currentRoundId.toString(), missingTopUp: missingTopUp.toString(), maxTopUp: maxTopUp.toString() },
        "expired round needs operational top-up before close"
      );
      return;
    }

    await requireWriteContract().topUpAndClose(currentRoundId, maxTopUp).then(waitForTx("topUpAndClose"));
  }
}

async function syncEvents() {
  const latestBlock = await provider.getBlockNumber();
  const state = await prisma.appConfig.findUnique({ where: { key: "worker.lastSyncedBlock" } });
  let fromBlock = state ? Number((state.value as { blockNumber: number }).blockNumber) + 1 : env.DEPLOY_BLOCK;

  while (fromBlock <= latestBlock) {
    const toBlock = Math.min(fromBlock + env.EVENT_SYNC_CHUNK_SIZE - 1, latestBlock);
    const logs = await provider.getLogs({
      address: env.DAILY_DRAW_ADDRESS,
      fromBlock,
      toBlock
    });

    for (const log of logs) {
      const parsed = readContract.interface.parseLog(log);
      if (!parsed) {
        continue;
      }
      await indexParsedEvent(parsed.name, parsed.args, log.transactionHash, log.index, BigInt(log.blockNumber));
    }

    await prisma.appConfig.upsert({
      where: { key: "worker.lastSyncedBlock" },
      update: { value: { blockNumber: toBlock } },
      create: { key: "worker.lastSyncedBlock", value: { blockNumber: toBlock } }
    });
    fromBlock = toBlock + 1;
  }
}

async function indexParsedEvent(
  name: string,
  args: Record<string, unknown>,
  txHash: string,
  logIndex: number,
  blockNumber: bigint
) {
  const payload = jsonify(namedArgs(args));
  await prisma.chainEvent.upsert({
    where: { txHash_logIndex: { txHash, logIndex } },
    update: { name, blockNumber, payload },
    create: { name, txHash, logIndex, blockNumber, payload }
  });

  if (name === "RoundOpened") {
    const roundId = BigInt(args.roundId as bigint);
    await prisma.drawRound.upsert({
      where: { id: roundId },
      update: {
        status: "OPEN",
        openedAt: secondsToDate(args.openedAt),
        expiresAt: secondsToDate(args.expiresAt),
        txHash
      },
      create: {
        id: roundId,
        status: "OPEN",
        openedAt: secondsToDate(args.openedAt),
        expiresAt: secondsToDate(args.expiresAt),
        grossTicketRevenue: "0",
        prizePool: "0",
        jackpotContribution: "0",
        operationalTopUp: "0",
        dailyPrizePaid: "0",
        jackpotPaid: "0",
        txHash
      }
    });
    return;
  }

  if (name === "TicketsPurchased") {
    const roundId = BigInt(args.roundId as bigint);
    await prisma.ticketPurchase.upsert({
      where: { txHash_logIndex: { txHash, logIndex } },
      update: {},
      create: {
        roundId,
        buyer: String(args.buyer),
        quantity: Number(args.quantity),
        startInclusive: Number(args.startInclusive),
        endExclusive: Number(args.endExclusive),
        blobbyPaid: (args.blobbyPaid as bigint).toString(),
        jackpotContribution: (args.jackpotContribution as bigint).toString(),
        txHash,
        logIndex,
        blockNumber
      }
    });
    await refreshRound(roundId);
    return;
  }

  if (name === "OperationalTopUp") {
    const roundId = BigInt(args.roundId as bigint);
    await prisma.drawTopUp.upsert({
      where: { txHash_logIndex: { txHash, logIndex } },
      update: {},
      create: {
        roundId,
        payer: String(args.payer),
        amount: (args.amount as bigint).toString(),
        txHash,
        logIndex,
        blockNumber
      }
    });
    await refreshRound(roundId);
    return;
  }

  if (name === "RoundCloseRequested") {
    await refreshRound(BigInt(args.roundId as bigint));
    return;
  }

  if (name === "RoundFulfilled") {
    const roundId = BigInt(args.roundId as bigint);
    const dailyPrizePaid = args.dailyPrizePaid as bigint;
    const jackpotPaid = args.jackpotPaid as bigint;

    if (dailyPrizePaid > 0n) {
      await prisma.drawWinner.upsert({
        where: { txHash_logIndex_prizeType: { txHash, logIndex, prizeType: "DAILY" } },
        update: {},
        create: {
          roundId,
          winner: String(args.dailyWinner),
          prizeType: "DAILY",
          amount: dailyPrizePaid.toString(),
          txHash,
          logIndex,
          blockNumber
        }
      });
    }

    if (jackpotPaid > 0n) {
      await prisma.drawWinner.upsert({
        where: { txHash_logIndex_prizeType: { txHash, logIndex, prizeType: "JACKPOT" } },
        update: {},
        create: {
          roundId,
          winner: String(args.jackpotWinner),
          prizeType: "JACKPOT",
          amount: jackpotPaid.toString(),
          txHash,
          logIndex,
          blockNumber
        }
      });
    }

    await refreshRound(roundId);
    return;
  }

  if (name === "RoundCancelled") {
    await refreshRound(BigInt(args.roundId as bigint));
  }
}

async function refreshRound(roundId: bigint) {
  const round = await readContract.rounds(roundId);
  await prisma.drawRound.upsert({
    where: { id: roundId },
    update: roundData(round),
    create: {
      id: roundId,
      ...roundData(round)
    }
  });
}

function roundData(round: Record<string, unknown>) {
  return {
    status: ROUND_STATUS[Number(round.status)] as "OPEN" | "CALCULATING" | "FULFILLED" | "CANCELLED",
    openedAt: secondsToDate(round.openedAt),
    expiresAt: secondsToDate(round.expiresAt),
    closedAt: Number(round.closedAt) === 0 ? null : secondsToDate(round.closedAt),
    eligibleTicketCount: Number(round.eligibleTicketCount),
    uniqueWalletCount: Number(round.uniqueWalletCount),
    grossTicketRevenue: (round.grossTicketRevenue as bigint).toString(),
    prizePool: (round.prizePool as bigint).toString(),
    jackpotContribution: (round.jackpotContribution as bigint).toString(),
    operationalTopUp: (round.operationalTopUp as bigint).toString(),
    dailyPrizePaid: (round.dailyPrizePaid as bigint).toString(),
    jackpotPaid: (round.jackpotPaid as bigint).toString(),
    dailyWinner: zeroToNull(String(round.dailyWinner)),
    jackpotWinner: zeroToNull(String(round.jackpotWinner)),
    vrfRequestId: (round.vrfRequestId as bigint) === 0n ? null : (round.vrfRequestId as bigint).toString(),
    jackpotEligible: Boolean(round.jackpotEligible)
  };
}

function requireWriteContract() {
  if (!writeContract) {
    throw new Error("WORKER_PRIVATE_KEY is required for automation transactions");
  }
  return writeContract;
}

function waitForTx(action: string) {
  return async (tx: { wait: () => Promise<{ hash?: string } | null>; hash?: string }) => {
    logger.info({ action, txHash: tx.hash }, "submitted worker transaction");
    const receipt = await tx.wait();
    logger.info({ action, txHash: receipt?.hash || tx.hash }, "confirmed worker transaction");
  };
}

function namedArgs(args: Record<string, unknown>) {
  return Object.fromEntries(Object.entries(args).filter(([key]) => Number.isNaN(Number(key))));
}

function jsonify(value: unknown) {
  return JSON.parse(JSON.stringify(value, (_key, innerValue) => (typeof innerValue === "bigint" ? innerValue.toString() : innerValue)));
}

function secondsToDate(value: unknown) {
  return new Date(Number(value) * 1000);
}

function zeroToNull(value: string) {
  return value === "0x0000000000000000000000000000000000000000" ? null : value;
}

function sleep(ms: number) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

main().catch((error) => {
  logger.fatal({ error }, "worker crashed");
  process.exitCode = 1;
});
