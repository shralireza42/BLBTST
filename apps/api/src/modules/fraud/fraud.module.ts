import { Module } from "@nestjs/common";
import { FraudService } from "./fraud.service.js";

@Module({ providers: [FraudService], exports: [FraudService] })
export class FraudModule {}
