import { Controller, Get, Header, Param } from "@nestjs/common";
import { PublicVerifyService } from "./public-verify.service.js";

@Controller("verify")
export class PublicVerifyController {
  constructor(private readonly verify: PublicVerifyService) {}
  @Get("round/:roundId") round(@Param("roundId") roundId: string) { return this.verify.round(roundId); }
  @Get("jackpot/:cycleId") jackpot(@Param("cycleId") cycleId: string) { return this.verify.jackpot(cycleId); }
  @Get("export/round/:roundId.json") exportRoundJson(@Param("roundId") roundId: string) { return this.verify.round(roundId); }
  @Get("export/round/:roundId.csv")
  @Header("content-type", "text/csv")
  exportRoundCsv(@Param("roundId") roundId: string) { return this.verify.roundCsv(roundId); }
}
