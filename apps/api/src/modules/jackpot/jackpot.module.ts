import { Module } from "@nestjs/common";
import { JackpotController } from "./jackpot.controller.js";
import { JackpotRepository } from "./jackpot.repository.js";
import { JackpotService } from "./jackpot.service.js";

@Module({ controllers: [JackpotController], providers: [JackpotRepository, JackpotService], exports: [JackpotService, JackpotRepository] })
export class JackpotModule {}
