import cors from "cors";
import express, { NextFunction, Request, Response } from "express";
import helmet from "helmet";
import pinoHttpImport from "pino-http";
import { ZodError } from "zod";
import { env } from "./config/env.js";
import { logger } from "./logger.js";

const pinoHttp = pinoHttpImport as unknown as (options: { logger: typeof logger }) => express.RequestHandler;
import { adminRouter } from "./routes/admin.js";
import { publicRouter } from "./routes/public.js";

export function createApp() {
  const app = express();

  app.use(helmet());
  app.use(cors({ origin: env.CORS_ORIGIN === "*" ? true : env.CORS_ORIGIN }));
  app.use(express.json({ limit: "1mb" }));
  app.use(pinoHttp({ logger }));

  app.use(publicRouter);
  app.use(adminRouter);

  app.use((error: unknown, _req: Request, res: Response, _next: NextFunction) => {
    if (error instanceof ZodError) {
      res.status(400).json({ error: "Invalid request", details: error.issues });
      return;
    }

    const statusCode = typeof error === "object" && error !== null && "statusCode" in error
      ? Number((error as { statusCode: unknown }).statusCode)
      : 500;
    const message = error instanceof Error ? error.message : "Internal server error";
    logger.error({ error }, message);
    res.status(statusCode >= 400 && statusCode < 600 ? statusCode : 500).json({ error: message });
  });

  return app;
}
