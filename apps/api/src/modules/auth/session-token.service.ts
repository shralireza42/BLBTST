import crypto from "node:crypto";
import { Injectable, ServiceUnavailableException, UnauthorizedException } from "@nestjs/common";
import { ConfigService } from "@nestjs/config";

export type SessionPayload = {
  walletAddress: string;
  role: "admin" | "user";
  exp: number;
};

@Injectable()
export class SessionTokenService {
  constructor(private readonly config: ConfigService) {}

  sign(payload: Omit<SessionPayload, "exp">): string {
    const secret = this.secret();
    const body: SessionPayload = { ...payload, exp: Math.floor(Date.now() / 1000) + 60 * 60 * 12 };
    const encoded = Buffer.from(JSON.stringify(body)).toString("base64url");
    const sig = crypto.createHmac("sha256", secret).update(encoded).digest("base64url");
    return `${encoded}.${sig}`;
  }

  verify(token: string): SessionPayload {
    const secret = this.secret();
    const [encoded, sig] = token.split(".");
    if (!encoded || !sig) throw new UnauthorizedException("Invalid token");
    const expected = crypto.createHmac("sha256", secret).update(encoded).digest("base64url");
    if (!crypto.timingSafeEqual(Buffer.from(sig), Buffer.from(expected))) {
      throw new UnauthorizedException("Invalid token signature");
    }
    const payload = JSON.parse(Buffer.from(encoded, "base64url").toString()) as SessionPayload;
    if (payload.exp < Math.floor(Date.now() / 1000)) throw new UnauthorizedException("Token expired");
    return payload;
  }

  private secret(): string {
    const secret = this.config.get<string>("AUTH_SESSION_SECRET") || this.config.get<string>("ADMIN_API_KEY");
    if (!secret) throw new ServiceUnavailableException("AUTH_SESSION_SECRET is not configured");
    return secret;
  }
}
