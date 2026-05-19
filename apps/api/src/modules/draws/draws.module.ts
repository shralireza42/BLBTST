import { Module } from "@nestjs/common";
import { ContractsModule } from "../contracts/contracts.module.js";
import { DrawsController } from "./draws.controller.js";
import { DrawsRepository } from "./draws.repository.js";
import { DrawsService } from "./draws.service.js";

@Module({ imports: [ContractsModule], controllers: [DrawsController], providers: [DrawsRepository, DrawsService], exports: [DrawsService, DrawsRepository] })
export class DrawsModule {}
