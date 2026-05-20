import { Injectable } from "@nestjs/common";
import { PrismaService } from "../../common/prisma/prisma.service.js";
import { PaginationDto, paginationArgs } from "../../common/dto/pagination.dto.js";

@Injectable()
export class DrawsRepository {
  constructor(private readonly prisma: PrismaService) {}

  current() {
    return this.prisma.client.drawRound.findFirst({ orderBy: { id: "desc" } });
  }

  async list(pagination: PaginationDto) {
    const { page, limit, skip, take } = paginationArgs(pagination);
    const [data, total] = await Promise.all([
      this.prisma.client.drawRound.findMany({ orderBy: { id: "desc" }, skip, take }),
      this.prisma.client.drawRound.count()
    ]);
    return { data, total, page, limit };
  }

  find(roundId: bigint) {
    return this.prisma.client.drawRound.findUnique({ where: { id: roundId } });
  }

  audit(roundId: bigint) {
    return Promise.all([
      this.prisma.client.drawRound.findUnique({ where: { id: roundId } }),
      this.prisma.client.drawEntry.findMany({ where: { roundId }, orderBy: { createdAt: "asc" } }),
      this.prisma.client.drawWinner.findMany({ where: { roundId }, orderBy: { slot: "asc" } }),
      this.prisma.client.drawSettlement.findMany({ where: { roundId }, orderBy: { createdAt: "asc" } }),
      this.prisma.client.ticketPurchase.findMany({ where: { roundId }, orderBy: [{ blockNumber: "asc" }, { logIndex: "asc" }] }),
      this.prisma.client.drawTopUp.findMany({ where: { roundId }, orderBy: [{ blockNumber: "asc" }, { logIndex: "asc" }] })
    ]).then(([round, entries, winners, settlements, legacyPurchases, topUps]) => ({ round, entries, winners, settlements, legacyPurchases, topUps }));
  }

  winners(roundId: bigint) {
    return this.prisma.client.drawWinner.findMany({ where: { roundId }, orderBy: { slot: "asc" } });
  }

  my(walletAddress: string) {
    const normalized = walletAddress.toLowerCase();
    return this.prisma.client.drawEntry.findMany({ where: { walletAddress: normalized }, orderBy: { createdAt: "desc" } });
  }
}
