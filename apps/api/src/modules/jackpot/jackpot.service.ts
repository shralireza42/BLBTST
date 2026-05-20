import { Injectable, NotFoundException } from "@nestjs/common";
import { PaginationDto } from "../../common/dto/pagination.dto.js";
import { serializeForJson } from "../../common/utils/serialize.js";
import { JackpotRepository } from "./jackpot.repository.js";

@Injectable()
export class JackpotService {
  constructor(private readonly repo: JackpotRepository) {}
  async current() { return serializeForJson(await this.repo.current()); }
  async list(pagination: PaginationDto) { return serializeForJson(await this.repo.list(pagination)); }
  async find(cycleId: string) { const cycle=await this.repo.find(BigInt(cycleId)); if(!cycle) throw new NotFoundException("Jackpot cycle not found"); return serializeForJson(cycle); }
  async audit(cycleId: string) { return serializeForJson(await this.repo.audit(BigInt(cycleId))); }
}
