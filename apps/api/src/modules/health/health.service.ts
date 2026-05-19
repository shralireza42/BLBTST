import { Injectable } from "@nestjs/common";
import { PrismaService } from "../../common/prisma/prisma.service.js";
import { serializeForJson } from "../../common/utils/serialize.js";

@Injectable()
export class HealthService {
  constructor(private readonly prisma: PrismaService) {}

  basic() {
    return { ok: true };
  }

  async indexer() {
    const [health, queueHealth, cursors] = await Promise.all([
      this.prisma.client.systemConfig.findUnique({ where: { key: "indexer.health" } }),
      this.prisma.client.systemConfig.findUnique({ where: { key: "worker.queues.health" } }),
      this.prisma.client.contractSyncCursor.findMany({ orderBy: [{ chainId: "asc" }, { cursorName: "asc" }] })
    ]);
    return serializeForJson({ ok: true, health: health?.value ?? null, queues: queueHealth?.value ?? null, cursors });
  }
}
