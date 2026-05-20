import { Module } from "@nestjs/common";
import { ContractsModule } from "../contracts/contracts.module.js";
import { AdminController } from "./admin.controller.js";
import { AdminService } from "./admin.service.js";

@Module({ imports: [ContractsModule], controllers: [AdminController], providers: [AdminService] })
export class AdminModule {}
