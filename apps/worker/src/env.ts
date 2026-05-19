import "dotenv/config";
import { z } from "zod";

const envSchema = z.object({
  NODE_ENV: z.string().default("development"),
  LOG_LEVEL: z.string().default("info"),
  DATABASE_URL: z.string().min(1),
  BSC_RPC_URL: z.string().url(),
  BSC_CHAIN_ID: z.coerce.number().int().positive().default(56),
  DAILY_DRAW_ADDRESS: z.string().regex(/^0x[a-fA-F0-9]{40}$/),
  JACKPOT_VAULT_ADDRESS: z.string().regex(/^0x[a-fA-F0-9]{40}$/),
  DEPLOY_BLOCK: z.coerce.number().int().nonnegative().default(0),
  CONTRACT_SYNC_START_BLOCK: z.coerce.number().int().nonnegative().optional(),
  CONTRACT_CONFIRMATION_DEPTH: z.coerce.number().int().nonnegative().default(12),
  WORKER_PRIVATE_KEY: z.string().optional(),
  POLL_INTERVAL_MS: z.coerce.number().int().positive().default(30_000),
  EVENT_SYNC_CHUNK_SIZE: z.coerce.number().int().positive().default(2_000),
  AUTO_OPEN_ROUND: z.coerce.boolean().default(true),
  MAX_TOP_UP_WEI: z.string().regex(/^\d+$/).default("0")
});

export const env = envSchema.parse(process.env);
