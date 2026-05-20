import { Controller, Get, Param, Query } from "@nestjs/common";
import { PaginationDto } from "../../common/dto/pagination.dto.js";
import { JackpotService } from "./jackpot.service.js";

@Controller("jackpot")
export class JackpotController {
  constructor(private readonly jackpot: JackpotService) {}
  @Get("current") current() { return this.jackpot.current(); }
  @Get("cycles") cycles(@Query() pagination: PaginationDto) { return this.jackpot.list(pagination); }
  @Get("cycles/:cycleId") cycle(@Param("cycleId") cycleId: string) { return this.jackpot.find(cycleId); }
  @Get("cycles/:cycleId/audit") audit(@Param("cycleId") cycleId: string) { return this.jackpot.audit(cycleId); }
}
