import crypto from "node:crypto";
import { BadRequestException, Injectable, UnauthorizedException } from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import { verifyMessage } from "ethers";
import { PrismaService } from "../../common/prisma/prisma.service.js";
import { AuthVerifyResponse, NonceResponse } from "./dto/auth.dto.js";
import { SessionTokenService } from "./session-token.service.js";

@Injectable()
export class AuthService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly config: ConfigService,
    private readonly sessions: SessionTokenService
  ) {}

  async createNonce(walletAddress: string): Promise<NonceResponse> {
    const normalized = walletAddress.toLowerCase();
    const nonce = crypto.randomBytes(16).toString("hex");
    const expiresAt = new Date(Date.now() + 10 * 60 * 1000);
    const message = this.message(normalized, nonce);
    await this.prisma.client.systemConfig.upsert({
      where: { key: `auth.nonce.${normalized}` },
      update: { value: { nonce, expiresAt: expiresAt.toISOString(), message } },
      create: { key: `auth.nonce.${normalized}`, value: { nonce, expiresAt: expiresAt.toISOString(), message } }
    });
    return { walletAddress: normalized, nonce, message, expiresAt: expiresAt.toISOString() };
  }

  async verify(walletAddress: string, signature: string): Promise<AuthVerifyResponse> {
    const normalized = walletAddress.toLowerCase();
    const record = await this.prisma.client.systemConfig.findUnique({ where: { key: `auth.nonce.${normalized}` } });
    if (!record) throw new BadRequestException("Nonce not found");
    const value = record.value as { nonce: string; expiresAt: string; message: string };
    if (new Date(value.expiresAt).getTime() < Date.now()) throw new BadRequestException("Nonce expired");

    const recovered = verifyMessage(value.message, signature).toLowerCase();
    if (recovered !== normalized) throw new UnauthorizedException("Invalid signature");

    await this.prisma.client.wallet.upsert({
      where: { chainId_address: { chainId: Number(this.config.get("BSC_CHAIN_ID") || 56), address: normalized } },
      update: { lastSeenAt: new Date() },
      create: { chainId: Number(this.config.get("BSC_CHAIN_ID") || 56), address: normalized, lastSeenAt: new Date() }
    });
    await this.prisma.client.systemConfig.delete({ where: { key: `auth.nonce.${normalized}` } }).catch(() => undefined);

    const role = this.adminWallets().includes(normalized) ? "admin" : "user";
    return { walletAddress: normalized, role, token: this.sessions.sign({ walletAddress: normalized, role }) };
  }

  private message(walletAddress: string, nonce: string) {
    return `Sign in to BLOBBIE\nWallet: ${walletAddress}\nNonce: ${nonce}`;
  }

  private adminWallets(): string[] {
    return (this.config.get<string>("ADMIN_WALLETS") || "").split(",").map((w) => w.trim().toLowerCase()).filter(Boolean);
  }
}
