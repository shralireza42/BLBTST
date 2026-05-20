import { Injectable } from "@nestjs/common";
import { PrismaService } from "../../common/prisma/prisma.service.js";

@Injectable()
export class TicketsService { constructor(public readonly prisma: PrismaService) {} }
