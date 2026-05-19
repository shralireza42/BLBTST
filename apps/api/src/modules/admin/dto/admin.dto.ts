import { IsBoolean, IsEthereumAddress, IsInt, IsObject, IsOptional, IsString, Min } from "class-validator";

export class DrawConfigDto {
  @IsOptional() @IsInt() @Min(1) ticketThreshold?: number;
  @IsOptional() @IsInt() @Min(1) roundDuration?: number;
  @IsOptional() @IsString() ticketUsdPriceE18?: string;
}
export class JackpotConfigDto {
  @IsOptional() @IsString() thresholdUsdE18?: string;
  @IsOptional() @IsInt() @Min(0) contributionBps?: number;
}
export class WalletFraudDto {
  @IsEthereumAddress() walletAddress!: string;
  @IsOptional() @IsString() reason?: string;
}
export class FeatureFlagDto {
  @IsString() key!: string;
  @IsBoolean() enabled!: boolean;
  @IsOptional() @IsObject() rules?: Record<string, unknown>;
}
