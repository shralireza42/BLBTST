import { Module } from "@nestjs/common";
import { APP_GUARD } from "@nestjs/core";
import { ConfigModule } from "@nestjs/config";
import { ThrottlerGuard, ThrottlerModule } from "@nestjs/throttler";
import { AdminModule } from "./modules/admin/admin.module.js";
import { AuthModule } from "./modules/auth/auth.module.js";
import { ContractsModule } from "./modules/contracts/contracts.module.js";
import { DrawsModule } from "./modules/draws/draws.module.js";
import { FraudModule } from "./modules/fraud/fraud.module.js";
import { HealthModule } from "./modules/health/health.module.js";
import { JackpotModule } from "./modules/jackpot/jackpot.module.js";
import { PricingModule } from "./modules/pricing/pricing.module.js";
import { PrismaModule } from "./common/prisma/prisma.module.js";
import { PublicVerifyModule } from "./modules/public-verify/public-verify.module.js";
import { TicketsModule } from "./modules/tickets/tickets.module.js";
import { UsersModule } from "./modules/users/users.module.js";
import { WalletsModule } from "./modules/wallets/wallets.module.js";

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    ThrottlerModule.forRoot([{ ttl: 60_000, limit: 120 }]),
    PrismaModule,
    AuthModule,
    UsersModule,
    WalletsModule,
    DrawsModule,
    TicketsModule,
    JackpotModule,
    PricingModule,
    ContractsModule,
    AdminModule,
    FraudModule,
    PublicVerifyModule,
    HealthModule
  ],
  providers: [{ provide: APP_GUARD, useClass: ThrottlerGuard }]
})
export class AppModule {}
