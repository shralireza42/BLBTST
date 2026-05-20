import { prisma } from "@blobby/database";
import { Queue } from "bullmq";
import { QueueName } from "../queues/names.js";

export async function recordJobLog(queueName: string, jobId: string, status: string, payload: unknown) {
  await prisma.adminActionLog.create({
    data: {
      action: `worker.${queueName}.${status}`,
      status: status === "failed" ? "FAILED" : "SUCCESS",
      targetType: "bullmq-job",
      targetId: jobId,
      payload: toJson(payload)
    }
  });
}

export async function snapshotQueueHealth(queues: Queue[]) {
  const snapshots = [];
  for (const queue of queues) {
    const counts = await queue.getJobCounts("waiting", "active", "completed", "failed", "delayed", "paused");
    snapshots.push({ name: queue.name, counts });
  }
  await prisma.systemConfig.upsert({
    where: { key: "worker.queues.health" },
    update: { value: toJson({ checkedAt: new Date().toISOString(), queues: snapshots }) },
    create: { key: "worker.queues.health", value: toJson({ checkedAt: new Date().toISOString(), queues: snapshots }) }
  });
}

export async function runLogged<T>(queueName: QueueName, jobId: string, fn: () => Promise<T>): Promise<T> {
  await recordJobLog(queueName, jobId, "started", {});
  try {
    const result = await fn();
    await recordJobLog(queueName, jobId, "succeeded", result);
    return result;
  } catch (error) {
    await recordJobLog(queueName, jobId, "failed", { message: error instanceof Error ? error.message : String(error) });
    throw error;
  }
}

function toJson(value: unknown) {
  return JSON.parse(JSON.stringify(value, (_key, innerValue) => (typeof innerValue === "bigint" ? innerValue.toString() : innerValue)));
}
