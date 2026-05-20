import { Injectable } from "@nestjs/common";
import { PaginationDto, paginationArgs } from "../../common/dto/pagination.dto.js";
import { PrismaService } from "../../common/prisma/prisma.service.js";

@Injectable()
export class JackpotRepository {
  constructor(private readonly prisma: PrismaService) {}
  current() { return this.prisma.client.jackpotCycle.findFirst({ orderBy: { id: "desc" } }); }
  async list(pagination: PaginationDto) {
    const { page, limit, skip, take } = paginationArgs(pagination);
    const [data,total]= await Promise.all([
      this.prisma.client.jackpotCycle.findMany({ orderBy: { id: "desc" }, skip, take }),
      this.prisma.client.jackpotCycle.count()
    ]);
    return { data,total,page,limit };
  }
  find(cycleId: bigint) { return this.prisma.client.jackpotCycle.findUnique({ where: { id: cycleId } }); }
  audit(cycleId: bigint) {
    return Promise.all([
      this.prisma.client.jackpotCycle.findUnique({ where: { id: cycleId } }),
      this.prisma.client.jackpotEntry.findMany({ where: { cycleId }, orderBy: { createdAt: "asc" } }),
      this.prisma.client.jackpotContribution.findMany({ where: { cycleId }, orderBy: { createdAt: "asc" } }),
      this.prisma.client.jackpotWinner.findUnique({ where: { cycleId } })
    ]).then(([cycle, entries, contributions, winner]) => ({ cycle, entries, contributions, winner }));
  }
}
