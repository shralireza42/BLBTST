import { JsonRpcProvider } from "ethers";
import pino from "pino";
import { checkIndexerHealth, syncContracts } from "./jobs/contractIndexer.js";
import { env } from "./env.js";
import { setupQueues } from "./queues/setup.js";

const logger = pino({ level: env.LOG_LEVEL });
const provider = new JsonRpcProvider(env.BSC_RPC_URL, env.BSC_CHAIN_ID);

async function main() {
  logger.info({ chainId: env.BSC_CHAIN_ID, dryRun: env.WORKER_DRY_RUN }, "BLOBBIE BullMQ worker starting");
  await setupQueues({ provider, logger });

  // Run an immediate bootstrap sync before repeatable jobs take over.
  await syncContracts({ provider, logger });
  await checkIndexerHealth({ provider, logger });
}

main().catch((error) => {
  logger.fatal({ error }, "worker crashed");
  process.exitCode = 1;
});
