export const QUEUE_NAMES = {
  roundTimeoutMonitor: "round-timeout-monitor",
  roundCloseWorker: "round-close-worker",
  settlementMonitor: "settlement-monitor",
  vrfMonitor: "vrf-monitor",
  jackpotThresholdMonitor: "jackpot-threshold-monitor",
  oracleHealthMonitor: "oracle-health-monitor",
  priceSnapshotWorker: "price-snapshot-worker",
  auditExportWorker: "audit-export-worker"
} as const;

export type QueueName = (typeof QUEUE_NAMES)[keyof typeof QUEUE_NAMES];
