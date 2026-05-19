import { Injectable } from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import { PrismaService } from "../../common/prisma/prisma.service.js";
import { serializeForJson } from "../../common/utils/serialize.js";
import { ContractsService } from "../contracts/contracts.service.js";
import { DrawConfigDto, JackpotConfigDto, WalletFraudDto } from "./dto/admin.dto.js";

@Injectable()
export class AdminService {
  constructor(private readonly prisma: PrismaService, private readonly contracts: ContractsService, private readonly config: ConfigService) {}

  async draws() { return serializeForJson(await this.prisma.client.drawRound.findMany({ orderBy: { id: "desc" }, take: 100 })); }
  async drawConfig(dto: DrawConfigDto) { return this.log("draws.config", dto); }
  async pauseDraws() { return this.log("draws.pause", { requested: true }); }
  async unpauseDraws() { return this.log("draws.unpause", { requested: true }); }
  async jackpot() { return serializeForJson(await this.prisma.client.jackpotCycle.findFirst({ orderBy: { id: "desc" } })); }
  async jackpotConfig(dto: JackpotConfigDto) { return this.log("jackpot.config", dto); }
  async fraudCases() { return serializeForJson(await this.prisma.client.fraudCase.findMany({ orderBy: { createdAt: "desc" }, take: 100 })); }
  async systemHealth() { return { ok: true, nodeEnv: this.config.get("NODE_ENV") || "development" }; }
  async syncStatus() { const cursors = await this.prisma.client.contractSyncCursor.findMany(); return serializeForJson({ ...this.contracts.syncStatus(), cursors }); }

  async excludeWallet(dto: WalletFraudDto) {
    const address = dto.walletAddress.toLowerCase();
    const wallet = await this.prisma.client.wallet.upsert({ where: { chainId_address: { chainId: this.contracts.chainId(), address } }, update: { status: "BANNED", fraudExcluded: true, bannedAt: new Date() }, create: { chainId: this.contracts.chainId(), address, status: "BANNED", fraudExcluded: true, bannedAt: new Date() } });
    await this.prisma.client.fraudSignal.create({ data: { type: "ADMIN_FLAG", severity: 5, walletId: wallet.id, walletAddress: address, source: "admin", payload: { reason: dto.reason || null } } });
    return serializeForJson(wallet);
  }

  async clearWallet(dto: WalletFraudDto) {
    const address = dto.walletAddress.toLowerCase();
    const wallet = await this.prisma.client.wallet.upsert({ where: { chainId_address: { chainId: this.contracts.chainId(), address } }, update: { status: "ACTIVE", fraudExcluded: false, bannedAt: null, fraudRejectedAt: null }, create: { chainId: this.contracts.chainId(), address, status: "ACTIVE" } });
    return serializeForJson(wallet);
  }

  private async log(action: string, payload: unknown) {
    const entry = await this.prisma.client.adminActionLog.create({ data: { action, payload: payload as object, status: "SUCCESS" } });
    return serializeForJson({ ok: true, action, auditId: entry.id });
  }
}
