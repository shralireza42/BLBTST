import { Body, Controller, Get, Post, UseGuards } from "@nestjs/common";
import { RbacGuard } from "../../common/guards/rbac.guard.js";
import { Roles } from "../../common/guards/roles.decorator.js";
import { AdminService } from "./admin.service.js";
import { DrawConfigDto, JackpotConfigDto, WalletFraudDto } from "./dto/admin.dto.js";

@Controller("admin")
@UseGuards(RbacGuard)
@Roles("admin")
export class AdminController {
  constructor(private readonly admin: AdminService) {}
  @Get("draws") draws() { return this.admin.draws(); }
  @Post("draws/config") drawConfig(@Body() dto: DrawConfigDto) { return this.admin.drawConfig(dto); }
  @Post("draws/pause") pauseDraws() { return this.admin.pauseDraws(); }
  @Post("draws/unpause") unpauseDraws() { return this.admin.unpauseDraws(); }
  @Get("jackpot") jackpot() { return this.admin.jackpot(); }
  @Post("jackpot/config") jackpotConfig(@Body() dto: JackpotConfigDto) { return this.admin.jackpotConfig(dto); }
  @Get("fraud/cases") fraudCases() { return this.admin.fraudCases(); }
  @Post("fraud/exclude-wallet") exclude(@Body() dto: WalletFraudDto) { return this.admin.excludeWallet(dto); }
  @Post("fraud/clear-wallet") clear(@Body() dto: WalletFraudDto) { return this.admin.clearWallet(dto); }
  @Get("system/health") health() { return this.admin.systemHealth(); }
  @Get("contracts/sync-status") syncStatus() { return this.admin.syncStatus(); }
}
