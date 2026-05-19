import { Injectable } from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import { Contract, JsonRpcProvider } from "ethers";

const dailyDrawAbi = [
  "function quoteTickets(uint256 quantity) view returns (uint256)",
  "function currentRoundId() view returns (uint256)",
  "function requiredOperationalTopUp(uint256 roundId) view returns (uint256)"
] as const;

@Injectable()
export class ContractsService {
  private readonly provider: JsonRpcProvider;

  constructor(private readonly config: ConfigService) {
    this.provider = new JsonRpcProvider(this.config.get<string>("BSC_RPC_URL"), Number(this.config.get("BSC_CHAIN_ID") || 56));
  }

  dailyDrawAddress() {
    return this.config.get<string>("DAILY_DRAW_ADDRESS") || "0x0000000000000000000000000000000000000000";
  }

  chainId() {
    return Number(this.config.get("BSC_CHAIN_ID") || 56);
  }

  async quoteTickets(quantity: number): Promise<string> {
    const address = this.dailyDrawAddress();
    const contract = new Contract(address, dailyDrawAbi, this.provider);
    return (await contract.quoteTickets(BigInt(quantity))).toString();
  }

  syncStatus() {
    return { chainId: this.chainId(), dailyDrawAddress: this.dailyDrawAddress() };
  }
}
