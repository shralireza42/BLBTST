import crypto from "node:crypto";
import { NextFunction, Request, Response } from "express";
import { env } from "../config/env.js";

export function requireAdmin(req: Request, res: Response, next: NextFunction) {
  if (!env.ADMIN_API_KEY) {
    res.status(503).json({ error: "ADMIN_API_KEY is not configured" });
    return;
  }

  const provided = req.header("x-admin-key") || "";
  const expected = env.ADMIN_API_KEY;
  const valid =
    provided.length === expected.length
    && crypto.timingSafeEqual(Buffer.from(provided), Buffer.from(expected));

  if (!valid) {
    res.status(401).json({ error: "Unauthorized" });
    return;
  }

  next();
}
