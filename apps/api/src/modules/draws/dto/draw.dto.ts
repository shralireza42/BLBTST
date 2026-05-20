import { IsEthereumAddress, IsInt, IsString, Min } from "class-validator";

export class DrawQuoteDto {
  @IsInt()
  @Min(1)
  quantity!: number;
}

export class PreparePurchaseDto extends DrawQuoteDto {
  @IsEthereumAddress()
  walletAddress!: string;

  @IsString()
  maxBlobbieCost!: string;
}
