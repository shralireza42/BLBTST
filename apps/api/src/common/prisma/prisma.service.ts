import { Injectable, OnModuleDestroy } from "@nestjs/common";
import { prisma } from "@blobby/database";

@Injectable()
export class PrismaService implements OnModuleDestroy {
  public readonly client = prisma;

  async onModuleDestroy() {
    await this.client.$disconnect();
  }
}
