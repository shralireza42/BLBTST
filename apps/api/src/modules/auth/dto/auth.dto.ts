import { IsEthereumAddress, IsString, Length } from "class-validator";

export class NonceRequestDto {
  @IsEthereumAddress()
  walletAddress!: string;
}

export class VerifySignatureDto {
  @IsEthereumAddress()
  walletAddress!: string;

  @IsString()
  @Length(1, 4096)
  signature!: string;
}

export type NonceResponse = {
  walletAddress: string;
  nonce: string;
  message: string;
  expiresAt: string;
};

export type AuthVerifyResponse = {
  walletAddress: string;
  token: string;
  role: "admin" | "user";
};
