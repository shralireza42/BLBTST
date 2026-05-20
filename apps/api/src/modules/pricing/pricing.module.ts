import { Module } from "@nestjs/common";
import { ContractsModule } from "../contracts/contracts.module.js";
import { PricingController } from "./pricing.controller.js";
import { PricingService } from "./pricing.service.js";

@Module({ imports: [ContractsModule], controllers: [PricingController], providers: [PricingService], exports: [PricingService] })
export class PricingModule {}
