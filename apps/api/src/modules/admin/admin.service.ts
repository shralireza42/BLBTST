import { BadRequestException, Injectable, NotFoundException } from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import { Prisma } from "@blobby/database";
import { paginationArgs } from "../../common/dto/pagination.dto.js";
import { PrismaService } from "../../common/prisma/prisma.service.js";
import { serializeForJson } from "../../common/utils/serialize.js";
import { ContractsService } from "../contracts/contracts.service.js";
import {
  AdminLogsQueryDto,
  AdminPauseDto,
  DrawConfigDto,
  JackpotConfigDto,
  PrizeConfigDto,
  WalletFraudDto
} from "./dto/admin.dto.js";

@Injectable()
export class AdminService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly contracts: ContractsService,
    private readonly config: ConfigService
  ) {}

  async draws() {
    const result = await this.prisma.client.drawRound.findMany({ orderBy: { id: "desc" }, take: 100 });
    await this.log("admin.draws.view", {}, "draw-round", undefined);
    return serializeForJson(result);
  }

  async drawHealth() {
    const [current, pendingReview, latestSettlement] = await Promise.all([
      this.prisma.client.drawRound.findFirst({ orderBy: { id: "desc" } }),
      this.prisma.client.drawRound.count({ where: { OR: [{ reviewStatus: "PENDING" }, { status: "FAILED_NEEDS_ADMIN_REVIEW" }] } }),
      this.prisma.client.drawSettlement.findFirst({ orderBy: { updatedAt: "desc" } })
    ]);
    await this.log("admin.draws.health.view", {}, "draw-health", undefined);
    return serializeForJson({ current, pendingReview, latestSettlement });
  }

  async drawConfig(dto: DrawConfigDto) {
    const value = sanitize(dto);
    await this.prisma.client.systemConfig.upsert({
      where: { key: "draw.config" },
      update: { value, updatedBy: "admin" },
      create: { key: "draw.config", value, description: "Admin-requested draw configuration", updatedBy: "admin" }
    });
    return this.log("admin.draws.config.update", value, "system-config", "draw.config");
  }

  async prizeConfig(dto: PrizeConfigDto) {
    if (dto.slotEnd < dto.slotStart) throw new BadRequestException("slotEnd must be >= slotStart");
    const created = await this.prisma.client.$transaction(async (tx) => {
      if (dto.isActive !== false) {
        await tx.drawPrizeConfig.updateMany({ where: { tier: dto.tier as never, isActive: true }, data: { isActive: false, effectiveTo: new Date() } });
      }
      return tx.drawPrizeConfig.create({
        data: {
          name: dto.name,
          tier: dto.tier as never,
          slotStart: dto.slotStart,
          slotEnd: dto.slotEnd,
          usdValueE18: dto.usdValueE18,
          isActive: dto.isActive ?? true
        }
      });
    });
    await this.log("admin.draws.prize-config.update", sanitize(dto), "draw-prize-config", created.id);
    return serializeForJson(created);
  }

  async pauseDraws(dto: AdminPauseDto) {
    await this.prisma.client.featureFlag.upsert({
      where: { key: "draw.paused" },
      update: { enabled: true, rules: sanitize({ reason: dto.reason || null }) },
      create: { key: "draw.paused", enabled: true, description: "Admin pause flag for draw system", rules: sanitize({ reason: dto.reason || null }) }
    });
    return this.log("admin.draws.pause", sanitize(dto), "feature-flag", "draw.paused");
  }

  async unpauseDraws(dto: AdminPauseDto) {
    await this.prisma.client.featureFlag.upsert({
      where: { key: "draw.paused" },
      update: { enabled: false, rules: sanitize({ reason: dto.reason || null }) },
      create: { key: "draw.paused", enabled: false, description: "Admin pause flag for draw system", rules: sanitize({ reason: dto.reason || null }) }
    });
    return this.log("admin.draws.unpause", sanitize(dto), "feature-flag", "draw.paused");
  }

  async jackpot() {
    const [current, config] = await Promise.all([
      this.prisma.client.jackpotCycle.findFirst({ orderBy: { id: "desc" } }),
      this.prisma.client.systemConfig.findUnique({ where: { key: "jackpot.config" } })
    ]);
    await this.log("admin.jackpot.view", {}, "jackpot", undefined);
    return serializeForJson({ current, config: config?.value ?? null });
  }

  async jackpotConfig(dto: JackpotConfigDto) {
    const value = sanitize(dto);
    await this.prisma.client.systemConfig.upsert({
      where: { key: "jackpot.config" },
      update: { value, updatedBy: "admin" },
      create: { key: "jackpot.config", value, description: "Admin-requested jackpot configuration", updatedBy: "admin" }
    });
    return this.log("admin.jackpot.config.update", value, "system-config", "jackpot.config");
  }

  async fraudCases() {
    const cases = await this.prisma.client.fraudCase.findMany({ orderBy: { createdAt: "desc" }, take: 100 });
    await this.log("admin.fraud.cases.view", {}, "fraud-case", undefined);
    return serializeForJson(cases);
  }

  async systemHealth() {
    const [indexer, queues, failedRounds, openFraudCases] = await Promise.all([
      this.prisma.client.systemConfig.findUnique({ where: { key: "indexer.health" } }),
      this.prisma.client.systemConfig.findUnique({ where: { key: "worker.queues.health" } }),
      this.prisma.client.drawRound.count({ where: { status: "FAILED_NEEDS_ADMIN_REVIEW" } }),
      this.prisma.client.fraudCase.count({ where: { status: { in: ["OPEN", "INVESTIGATING"] } } })
    ]);
    await this.log("admin.system.health.view", {}, "system", "health");
    return serializeForJson({ ok: true, nodeEnv: this.config.get("NODE_ENV") || "development", indexer: indexer?.value ?? null, queues: queues?.value ?? null, failedRounds, openFraudCases });
  }

  async syncStatus() {
    const cursors = await this.prisma.client.contractSyncCursor.findMany({ orderBy: [{ chainId: "asc" }, { cursorName: "asc" }] });
    await this.log("admin.contracts.sync-status.view", {}, "contract-sync", undefined);
    return serializeForJson({ ...this.contracts.syncStatus(), cursors });
  }

  async oracleHealth() {
    const checks = await this.prisma.client.oracleHealthCheck.findMany({ orderBy: { checkedAt: "desc" }, take: 50 });
    await this.log("admin.oracle.health.view", {}, "oracle-health", undefined);
    return serializeForJson(checks);
  }

  async workerHealth() {
    const queues = await this.prisma.client.systemConfig.findUnique({ where: { key: "worker.queues.health" } });
    await this.log("admin.worker.health.view", {}, "worker-health", undefined);
    return serializeForJson({ queues: queues?.value ?? null });
  }

  async actionLogs(query: AdminLogsQueryDto) {
    const { page, limit, skip, take } = paginationArgs(query);
    const where = query.action ? { action: { contains: query.action } } : {};
    const [data, total] = await Promise.all([
      this.prisma.client.adminActionLog.findMany({ where, orderBy: { createdAt: "desc" }, skip, take }),
      this.prisma.client.adminActionLog.count({ where })
    ]);
    await this.log("admin.action-logs.view", sanitize({ action: query.action, page, limit }), "admin-action-log", undefined);
    return serializeForJson({ data, total, page, limit });
  }

  async excludeWallet(dto: WalletFraudDto) {
    const address = dto.walletAddress.toLowerCase();
    const wallet = await this.prisma.client.wallet.upsert({
      where: { chainId_address: { chainId: this.contracts.chainId(), address } },
      update: { status: "BANNED", fraudExcluded: true, bannedAt: new Date() },
      create: { chainId: this.contracts.chainId(), address, status: "BANNED", fraudExcluded: true, bannedAt: new Date() }
    });
    await this.prisma.client.fraudSignal.create({
      data: { type: "ADMIN_FLAG", severity: 5, walletId: wallet.id, walletAddress: address, source: "admin", payload: sanitize({ reason: dto.reason || null }) }
    });
    await this.prisma.client.fraudCase.create({
      data: { status: "CONFIRMED", walletId: wallet.id, walletAddress: address, title: "Admin wallet exclusion", description: dto.reason || null, riskScore: 100, resolution: "Excluded by admin" }
    });
    await this.log("admin.fraud.exclude-wallet", sanitize({ walletAddress: address, reason: dto.reason || null }), "wallet", wallet.id);
    return serializeForJson(wallet);
  }

  async clearWallet(dto: WalletFraudDto) {
    const address = dto.walletAddress.toLowerCase();
    const wallet = await this.prisma.client.wallet.upsert({
      where: { chainId_address: { chainId: this.contracts.chainId(), address } },
      update: { status: "ACTIVE", fraudExcluded: false, bannedAt: null, fraudRejectedAt: null },
      create: { chainId: this.contracts.chainId(), address, status: "ACTIVE" }
    });
    await this.prisma.client.fraudCase.updateMany({ where: { walletAddress: address, status: { in: ["OPEN", "INVESTIGATING", "CONFIRMED"] } }, data: { status: "CLOSED", closedAt: new Date(), resolution: dto.reason || "Cleared by admin" } });
    await this.log("admin.fraud.clear-wallet", sanitize({ walletAddress: address, reason: dto.reason || null }), "wallet", wallet.id);
    return serializeForJson(wallet);
  }

  private async log(action: string, payload: unknown, targetType?: string, targetId?: string) {
    const entry = await this.prisma.client.adminActionLog.create({ data: { action, payload: sanitize(payload), status: "SUCCESS", targetType, targetId } });
    return serializeForJson({ ok: true, action, auditId: entry.id });
  }
}

function sanitize(value: unknown): Prisma.InputJsonValue {
  const redactedKeys = new Set(["privateKey", "apiKey", "secret", "authorization", "x-admin-key"]);
  return JSON.parse(JSON.stringify(value ?? {}, (key, innerValue) => redactedKeys.has(key) ? "[REDACTED]" : innerValue)) as Prisma.InputJsonValue;
}
