import { JsonRpcProvider } from "ethers";
import pino from "pino";
import { checkIndexerHealth, syncContracts } from "./jobs/contractIndexer.js";
import { env } from "./env.js";

const logger = pino({ level: env.LOG_LEVEL });
const provider = new JsonRpcProvider(env.BSC_RPC_URL, env.BSC_CHAIN_ID);

async function main() {
  logger.info({ chainId: env.BSC_CHAIN_ID }, "BLOBBIE contract indexer starting");
  while (true) {
    try {
      await syncContracts({ provider, logger });
      await checkIndexerHealth({ provider, logger });
    } catch (error) {
      logger.error({ error }, "contract indexer loop failed");
    }
    await sleep(env.POLL_INTERVAL_MS);
  }
}

function sleep(ms: number) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

main().catch((error) => {
  logger.fatal({ error }, "worker crashed");
  process.exitCode = 1;
});
