import { IsInt, Min } from "class-validator";

export class TicketQuoteDto {
  @IsInt()
  @Min(1)
  quantity!: number;
}

export type TicketQuoteResponse = {
  quantity: number;
  blobbieAmount: string;
  chainId: number;
  contractAddress: string;
};
