import { Injectable, NotFoundException } from "@nestjs/common";
import { PrismaService } from "../../common/prisma/prisma.service.js";
import { serializeForJson } from "../../common/utils/serialize.js";

@Injectable()
export class PublicVerifyService {
  constructor(private readonly prisma: PrismaService) {}

  async round(roundId: string) {
    const id = BigInt(roundId);
    const round = await this.prisma.client.drawRound.findUnique({ where: { id } });
    if (!round) throw new NotFoundException("Round not found");
    const [entries, winners, settlements] = await Promise.all([
      this.prisma.client.drawEntry.findMany({ where: { roundId: id }, orderBy: { createdAt: "asc" } }),
      this.prisma.client.drawWinner.findMany({ where: { roundId: id }, orderBy: { slot: "asc" } }),
      this.prisma.client.drawSettlement.findMany({ where: { roundId: id }, orderBy: { createdAt: "asc" } })
    ]);
    return serializeForJson({ round, entries, winners, settlements });
  }

  async jackpot(cycleId: string) {
    const id = BigInt(cycleId);
    const cycle = await this.prisma.client.jackpotCycle.findUnique({ where: { id } });
    if (!cycle) throw new NotFoundException("Jackpot cycle not found");
    const [entries, contributions, winner] = await Promise.all([
      this.prisma.client.jackpotEntry.findMany({ where: { cycleId: id }, orderBy: { createdAt: "asc" } }),
      this.prisma.client.jackpotContribution.findMany({ where: { cycleId: id }, orderBy: { createdAt: "asc" } }),
      this.prisma.client.jackpotWinner.findUnique({ where: { cycleId: id } })
    ]);
    return serializeForJson({ cycle, entries, contributions, winner });
  }

  async roundCsv(roundId: string) {
    const data = await this.round(roundId) as { entries: Array<Record<string, unknown>>; winners: Array<Record<string, unknown>> };
    const lines = ["type,walletAddress,quantity,slot,amount,txHash"];
    for (const entry of data.entries) lines.push(["entry", entry.walletAddress, entry.quantity, "", entry.blobbyPaid, entry.txHash].map(csv).join(","));
    for (const winner of data.winners) lines.push(["winner", winner.walletAddress || winner.winner, "", winner.slot, winner.amount, winner.txHash].map(csv).join(","));
    return lines.join("\n");
  }
}
function csv(value: unknown) { return `"${String(value ?? "").replaceAll('"', '""')}"`; }
