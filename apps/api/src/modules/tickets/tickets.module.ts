import { Module } from "@nestjs/common";
import { TicketsService } from "./tickets.service.js";

@Module({ providers: [TicketsService], exports: [TicketsService] })
export class TicketsModule {}
