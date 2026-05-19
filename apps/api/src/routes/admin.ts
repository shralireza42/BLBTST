import { Router } from "express";
import { z } from "zod";
import { prisma } from "../db/prisma.js";
import { getDailyDrawWriteContract, serializeBigInts } from "../services/dailyDrawContract.js";
import { requireAdmin } from "./adminAuth.js";

export const adminRouter = Router();

adminRouter.use(requireAdmin);

adminRouter.post("/admin/daily-draw/rounds/open", async (req, res, next) => {
  try {
    const contract = getDailyDrawWriteContract();
    const tx = await contract.openRound();
    const receipt = await tx.wait();
    await audit("openRound", req.ip, { txHash: receipt?.hash });
    res.status(202).json({ txHash: receipt?.hash });
  } catch (error) {
    next(error);
  }
});

adminRouter.post("/admin/daily-draw/rounds/:roundId/close", async (req, res, next) => {
  try {
    const { roundId } = z.object({ roundId: z.coerce.bigint().positive() }).parse(req.params);
    const contract = getDailyDrawWriteContract();
    const tx = await contract.closeRound(roundId);
    const receipt = await tx.wait();
    await audit("closeRound", req.ip, { roundId: roundId.toString(), txHash: receipt?.hash });
    res.status(202).json({ txHash: receipt?.hash });
  } catch (error) {
    next(error);
  }
});

adminRouter.post("/admin/daily-draw/rounds/:roundId/top-up", async (req, res, next) => {
  try {
    const { roundId } = z.object({ roundId: z.coerce.bigint().positive() }).parse(req.params);
    const body = z.object({ amount: z.string().regex(/^\d+$/) }).parse(req.body);
    const contract = getDailyDrawWriteContract();
    const tx = await contract.topUpRound(roundId, BigInt(body.amount));
    const receipt = await tx.wait();
    await audit("topUpRound", req.ip, { roundId: roundId.toString(), amount: body.amount, txHash: receipt?.hash });
    res.status(202).json({ txHash: receipt?.hash });
  } catch (error) {
    next(error);
  }
});

adminRouter.post("/admin/daily-draw/rounds/:roundId/top-up-and-close", async (req, res, next) => {
  try {
    const { roundId } = z.object({ roundId: z.coerce.bigint().positive() }).parse(req.params);
    const body = z.object({ maxTopUp: z.string().regex(/^\d+$/) }).parse(req.body);
    const contract = getDailyDrawWriteContract();
    const tx = await contract.topUpAndClose(roundId, BigInt(body.maxTopUp));
    const receipt = await tx.wait();
    await audit("topUpAndClose", req.ip, { roundId: roundId.toString(), maxTopUp: body.maxTopUp, txHash: receipt?.hash });
    res.status(202).json({ txHash: receipt?.hash });
  } catch (error) {
    next(error);
  }
});

adminRouter.post("/admin/daily-draw/config", async (req, res, next) => {
  try {
    const body = z
      .object({
        ticketThreshold: z.number().int().positive().optional(),
        roundDuration: z.number().int().positive().optional(),
        jackpotBps: z.number().int().min(0).max(5000).optional(),
        jackpotTriggerAmount: z.string().regex(/^\d+$/).optional()
      })
      .parse(req.body);

    const contract = getDailyDrawWriteContract();
    const txHashes: string[] = [];

    if (body.ticketThreshold !== undefined || body.roundDuration !== undefined) {
      const currentThreshold = body.ticketThreshold ?? Number(await contract.ticketThreshold());
      const currentDuration = body.roundDuration ?? Number(await contract.roundDuration());
      const tx = await contract.setRoundConfig(currentThreshold, currentDuration);
      const receipt = await tx.wait();
      txHashes.push(receipt?.hash);
    }

    if (body.jackpotBps !== undefined || body.jackpotTriggerAmount !== undefined) {
      const currentBps = body.jackpotBps ?? Number(await contract.jackpotBps());
      const currentTrigger = BigInt(body.jackpotTriggerAmount ?? (await contract.jackpotTriggerAmount()).toString());
      const tx = await contract.setJackpotConfig(currentBps, currentTrigger);
      const receipt = await tx.wait();
      txHashes.push(receipt?.hash);
    }

    await audit("setConfig", req.ip, serializeBigInts({ body, txHashes }));
    res.status(202).json({ txHashes });
  } catch (error) {
    next(error);
  }
});

async function audit(action: string, actor: string | undefined, payload: unknown) {
  await prisma.adminAuditLog.create({
    data: {
      action,
      actor: actor || "unknown",
      payload: serializeBigInts(payload)
    }
  });
}
