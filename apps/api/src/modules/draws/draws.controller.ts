import { Body, Controller, Get, Param, Post, Query } from "@nestjs/common";
import { PaginationDto } from "../../common/dto/pagination.dto.js";
import { DrawQuoteDto, PreparePurchaseDto } from "./dto/draw.dto.js";
import { DrawsService } from "./draws.service.js";

@Controller("draw")
export class DrawsController {
  constructor(private readonly draws: DrawsService) {}

  @Get("current") current() { return this.draws.current(); }
  @Get("rounds") rounds(@Query() pagination: PaginationDto) { return this.draws.list(pagination); }
  @Get("rounds/:roundId") round(@Param("roundId") roundId: string) { return this.draws.find(roundId); }
  @Get("rounds/:roundId/audit") audit(@Param("roundId") roundId: string) { return this.draws.audit(roundId); }
  @Get("rounds/:roundId/winners") winners(@Param("roundId") roundId: string) { return this.draws.winners(roundId); }
  @Post("quote") quote(@Body() dto: DrawQuoteDto) { return this.draws.quote(dto); }
  @Post("prepare-purchase") prepare(@Body() dto: PreparePurchaseDto) { return this.draws.preparePurchase(dto); }
  @Get("my/:walletAddress") my(@Param("walletAddress") walletAddress: string) { return this.draws.my(walletAddress); }
}
