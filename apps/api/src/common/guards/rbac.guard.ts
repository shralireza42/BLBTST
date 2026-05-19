import { CanActivate, ExecutionContext, Injectable, UnauthorizedException } from "@nestjs/common";
import { Reflector } from "@nestjs/core";
import { ConfigService } from "@nestjs/config";
import { ROLES_KEY, Role } from "./roles.decorator.js";

@Injectable()
export class RbacGuard implements CanActivate {
  constructor(private readonly reflector: Reflector, private readonly config: ConfigService) {}

  canActivate(context: ExecutionContext): boolean {
    const roles = this.reflector.getAllAndOverride<Role[]>(ROLES_KEY, [context.getHandler(), context.getClass()]) || [];
    if (!roles.length) return true;

    const req = context.switchToHttp().getRequest<{ headers: Record<string, string | undefined>; user?: { role?: Role } }>();
    if (roles.includes("admin")) {
      const configuredKey = this.config.get<string>("ADMIN_API_KEY");
      const providedKey = req.headers["x-admin-key"];
      if (configuredKey && providedKey && providedKey === configuredKey) return true;
      if (req.user?.role === "admin") return true;
      throw new UnauthorizedException("Admin credentials required");
    }
    return true;
  }
}
