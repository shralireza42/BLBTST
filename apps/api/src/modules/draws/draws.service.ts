import { Injectable, NotFoundException } from "@nestjs/common";
import { serializeForJson } from "../../common/utils/serialize.js";
import { PaginationDto } from "../../common/dto/pagination.dto.js";
import { ContractsService } from "../contracts/contracts.service.js";
import { DrawQuoteDto, PreparePurchaseDto } from "./dto/draw.dto.js";
import { DrawsRepository } from "./draws.repository.js";

@Injectable()
export class DrawsService {
  constructor(private readonly repo: DrawsRepository, private readonly contracts: ContractsService) {}

  async current() { return serializeForJson(await this.repo.current()); }
  async list(pagination: PaginationDto) { return serializeForJson(await this.repo.list(pagination)); }

  async find(roundId: string) {
    const round = await this.repo.find(BigInt(roundId));
    if (!round) throw new NotFoundException("Draw round not found");
    return serializeForJson(round);
  }

  async audit(roundId: string) { return serializeForJson(await this.repo.audit(BigInt(roundId))); }
  async winners(roundId: string) { return serializeForJson(await this.repo.winners(BigInt(roundId))); }
  async my(walletAddress: string) { return serializeForJson(await this.repo.my(walletAddress)); }

  async quote(dto: DrawQuoteDto) {
    return { quantity: dto.quantity, blobbieAmount: await this.contracts.quoteTickets(dto.quantity), chainId: this.contracts.chainId(), contractAddress: this.contracts.dailyDrawAddress() };
  }

  async preparePurchase(dto: PreparePurchaseDto) {
    const quote = await this.quote(dto);
    return { ...quote, walletAddress: dto.walletAddress.toLowerCase(), maxBlobbieCost: dto.maxBlobbieCost, method: "buyTickets", args: [String(dto.quantity), dto.maxBlobbieCost] };
  }
}
