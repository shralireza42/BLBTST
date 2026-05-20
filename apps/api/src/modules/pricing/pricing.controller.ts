import { Body, Controller, Get, Post } from "@nestjs/common";
import { TicketQuoteDto } from "./dto/pricing.dto.js";
import { PricingService } from "./pricing.service.js";

@Controller("pricing")
export class PricingController {
  constructor(private readonly pricing: PricingService) {}

  @Get("ticket")
  ticket() {
    return this.pricing.ticket(1);
  }

  @Post("ticket")
  ticketForQuantity(@Body() dto: TicketQuoteDto) {
    return this.pricing.ticket(dto.quantity);
  }

  @Get("blobbie-usd")
  blobbieUsd() {
    return this.pricing.blobbieUsd();
  }
}
