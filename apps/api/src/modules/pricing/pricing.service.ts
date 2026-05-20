import { Injectable } from "@nestjs/common";
import { PrismaService } from "../../common/prisma/prisma.service.js";
import { ContractsService } from "../contracts/contracts.service.js";
import { TicketQuoteResponse } from "./dto/pricing.dto.js";

@Injectable()
export class PricingService {
  constructor(private readonly contracts: ContractsService, private readonly prisma: PrismaService) {}

  async ticket(quantity = 1): Promise<TicketQuoteResponse> {
    return {
      quantity,
      blobbieAmount: await this.contracts.quoteTickets(quantity),
      chainId: this.contracts.chainId(),
      contractAddress: this.contracts.dailyDrawAddress()
    };
  }

  async blobbieUsd() {
    const latest = await this.prisma.client.priceSnapshot.findFirst({ orderBy: { observedAt: "desc" } });
    return latest || { priceE18: null, source: "unavailable" };
  }
}
