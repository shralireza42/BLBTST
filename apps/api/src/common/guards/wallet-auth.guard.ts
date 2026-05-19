import { CanActivate, ExecutionContext, Injectable, UnauthorizedException } from "@nestjs/common";
import { SessionTokenService } from "../../modules/auth/session-token.service.js";

@Injectable()
export class WalletAuthGuard implements CanActivate {
  constructor(private readonly sessions: SessionTokenService) {}

  canActivate(context: ExecutionContext): boolean {
    const req = context.switchToHttp().getRequest<{ headers: Record<string, string | undefined>; user?: unknown }>();
    const header = req.headers.authorization || "";
    const [scheme, token] = header.split(" ");
    if (scheme !== "Bearer" || !token) throw new UnauthorizedException("Bearer token required");
    req.user = this.sessions.verify(token);
    return true;
  }
}
