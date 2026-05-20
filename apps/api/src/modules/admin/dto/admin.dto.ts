import {
  IsBoolean,
  IsEthereumAddress,
  IsIn,
  IsInt,
  IsObject,
  IsOptional,
  IsString,
  Matches,
  Max,
  Min
} from "class-validator";
import { PaginationDto } from "../../../common/dto/pagination.dto.js";

const uintString = /^\d+$/;

export class DrawConfigDto {
  @IsOptional() @IsInt() @Min(1) ticketThreshold?: number;
  @IsOptional() @IsInt() @Min(1) roundDuration?: number;
  @IsOptional() @Matches(uintString) ticketUsdPriceE18?: string;
  @IsOptional() @IsInt() @Min(0) @Max(10_000) jackpotContributionBps?: number;
  @IsOptional() @IsEthereumAddress() treasury?: string;
  @IsOptional() @IsString() reason?: string;
}

export class JackpotConfigDto {
  @IsOptional() @Matches(uintString) thresholdUsdE18?: string;
  @IsOptional() @IsInt() @Min(0) @Max(10_000) contributionBps?: number;
  @IsOptional() @IsEthereumAddress() treasury?: string;
  @IsOptional() @IsString() reason?: string;
}

export class PrizeConfigDto {
  @IsString() name!: string;
  @IsIn([
    "FIRST",
    "SECOND_TO_TENTH",
    "ELEVENTH_TO_ONE_FIFTIETH",
    "FREE_ENTRY_RESERVE",
    "JACKPOT_ALLOCATION",
    "BURN_TREASURY",
    "UNUSED_REDISTRIBUTION"
  ])
  tier!: string;
  @IsInt() @Min(0) slotStart!: number;
  @IsInt() @Min(0) slotEnd!: number;
  @Matches(uintString) usdValueE18!: string;
  @IsOptional() @IsBoolean() isActive?: boolean;
  @IsOptional() @IsString() reason?: string;
}

export class AdminPauseDto {
  @IsOptional() @IsString() reason?: string;
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

export class AdminLogsQueryDto extends PaginationDto {
  @IsOptional() @IsString() action?: string;
}
