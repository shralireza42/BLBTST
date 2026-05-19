import "dotenv/config";
import { z } from "zod";

const envSchema = z.object({
  NODE_ENV: z.string().default("development"),
  PORT: z.coerce.number().int().positive().default(3001),
  LOG_LEVEL: z.string().default("info"),
  CORS_ORIGIN: z.string().default("*"),
  DATABASE_URL: z.string().min(1),
  BSC_RPC_URL: z.string().url(),
  BSC_CHAIN_ID: z.coerce.number().int().positive().default(56),
  DAILY_DRAW_ADDRESS: z.string().regex(/^0x[a-fA-F0-9]{40}$/),
  BLOBBIE_TOKEN_ADDRESS: z.string().regex(/^0x[a-fA-F0-9]{40}$/),
  ADMIN_PRIVATE_KEY: z.string().optional(),
  ADMIN_API_KEY: z.string().optional()
});

export const env = envSchema.parse(process.env);
