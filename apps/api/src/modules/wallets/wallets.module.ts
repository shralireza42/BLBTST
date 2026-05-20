import { Module } from "@nestjs/common";
import { WalletsService } from "./wallets.service.js";

@Module({ providers: [WalletsService], exports: [WalletsService] })
export class WalletsModule {}
