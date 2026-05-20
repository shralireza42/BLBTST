import { Router } from "express";
import { z } from "zod";
import { prisma } from "../db/prisma.js";
import { readDrawConfig, readRound, serializeBigInts } from "../services/dailyDrawContract.js";

export const publicRouter = Router();

publicRouter.get("/health", (_req, res) => {
  res.json({ ok: true });
});

publicRouter.get("/daily-draw/config", async (_req, res, next) => {
  try {
    res.json(await readDrawConfig());
  } catch (error) {
    next(error);
  }
});

publicRouter.get("/daily-draw/rounds/current", async (_req, res, next) => {
  try {
    const config = await readDrawConfig();
    const currentRoundId = BigInt(config.currentRoundId);
    const [chainRound, indexedRound] = await Promise.all([
      currentRoundId === 0n ? null : readRound(currentRoundId),
      currentRoundId === 0n ? null : prisma.drawRound.findUnique({ where: { id: currentRoundId } })
    ]);
    res.json(serializeBigInts({ chain: chainRound, indexed: indexedRound }));
  } catch (error) {
    next(error);
  }
});

publicRouter.get("/daily-draw/rounds/:roundId", async (req, res, next) => {
  try {
    const { roundId } = z.object({ roundId: z.coerce.bigint().positive() }).parse(req.params);
    const [chainRound, indexedRound] = await Promise.all([
      readRound(roundId),
      prisma.drawRound.findUnique({ where: { id: roundId } })
    ]);
    res.json(serializeBigInts({ chain: chainRound, indexed: indexedRound }));
  } catch (error) {
    next(error);
  }
});

publicRouter.get("/daily-draw/rounds/:roundId/audit", async (req, res, next) => {
  try {
    const { roundId } = z.object({ roundId: z.coerce.bigint().positive() }).parse(req.params);
    const [round, purchases, topUps, winners, events] = await Promise.all([
      prisma.drawRound.findUnique({ where: { id: roundId } }),
      prisma.ticketPurchase.findMany({ where: { roundId }, orderBy: [{ blockNumber: "asc" }, { logIndex: "asc" }] }),
      prisma.drawTopUp.findMany({ where: { roundId }, orderBy: [{ blockNumber: "asc" }, { logIndex: "asc" }] }),
      prisma.drawWinner.findMany({ where: { roundId }, orderBy: [{ blockNumber: "asc" }, { logIndex: "asc" }] }),
      prisma.chainEvent.findMany({
        where: { payload: { path: ["roundId"], equals: roundId.toString() } },
        orderBy: [{ blockNumber: "asc" }, { logIndex: "asc" }]
      })
    ]);

    res.json(serializeBigInts({ round, purchases, topUps, winners, events }));
  } catch (error) {
    next(error);
  }
});
