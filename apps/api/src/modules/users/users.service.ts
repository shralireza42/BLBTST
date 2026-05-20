import { Injectable } from "@nestjs/common";
import { PrismaService } from "../../common/prisma/prisma.service.js";

@Injectable()
export class UsersService { constructor(public readonly prisma: PrismaService) {} }
