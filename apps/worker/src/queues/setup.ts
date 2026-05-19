import { Queue, QueueEvents, Worker } from "bullmq";
import pino from "pino";
import { createRedisConnection } from "./connection.js";
import { QUEUE_NAMES, QueueName } from "./names.js";
import { env } from "../env.js";
import { createProcessor, ProcessorContext } from "../processors/index.js";
import { recordJobLog, snapshotQueueHealth } from "../services/jobLog.js";

const repeatEvery: Record<QueueName, number> = {
  [QUEUE_NAMES.roundTimeoutMonitor]: env.ROUND_TIMEOUT_MONITOR_INTERVAL_MS,
  [QUEUE_NAMES.roundCloseWorker]: env.ROUND_CLOSE_WORKER_INTERVAL_MS,
  [QUEUE_NAMES.settlementMonitor]: env.SETTLEMENT_MONITOR_INTERVAL_MS,
  [QUEUE_NAMES.vrfMonitor]: env.VRF_MONITOR_INTERVAL_MS,
  [QUEUE_NAMES.jackpotThresholdMonitor]: env.JACKPOT_THRESHOLD_MONITOR_INTERVAL_MS,
  [QUEUE_NAMES.oracleHealthMonitor]: env.ORACLE_HEALTH_MONITOR_INTERVAL_MS,
  [QUEUE_NAMES.priceSnapshotWorker]: env.PRICE_SNAPSHOT_INTERVAL_MS,
  [QUEUE_NAMES.auditExportWorker]: env.AUDIT_EXPORT_INTERVAL_MS
};

export async function setupQueues(ctx: ProcessorContext & { logger: pino.Logger }) {
  const connection = createRedisConnection();
  const queues: Queue[] = [];
  const workers: Worker[] = [];
  const events: QueueEvents[] = [];

  for (const name of Object.values(QUEUE_NAMES)) {
    const queue = new Queue(name, { connection, defaultJobOptions: defaultJobOptions() });
    queues.push(queue);
    await queue.add(name, {}, { jobId: `${name}:repeatable`, repeat: { every: repeatEvery[name] }, ...defaultJobOptions() });

    const queueEvents = new QueueEvents(name, { connection });
    events.push(queueEvents);
    queueEvents.on("failed", async ({ jobId, failedReason }) => {
      await recordJobLog(name, jobId || "unknown", "failed", { failedReason });
    });
    queueEvents.on("completed", async ({ jobId }) => {
      await recordJobLog(name, jobId || "unknown", "completed", {});
    });

    workers.push(new Worker(name, createProcessor(name, ctx), { connection, concurrency: 1, lockDuration: 120_000 }));
  }

  await snapshotQueueHealth(queues);
  ctx.logger.info({ queues: Object.values(QUEUE_NAMES), dryRun: env.WORKER_DRY_RUN }, "BullMQ workers registered");
  return { queues, workers, events, connection };
}

function defaultJobOptions() {
  return {
    attempts: 5,
    backoff: { type: "exponential", delay: 10_000 },
    removeOnComplete: { age: 86_400, count: 1000 },
    removeOnFail: { age: 604_800, count: 5000 }
  } as const;
}
