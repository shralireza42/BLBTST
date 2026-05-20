import { Body, Controller, Post } from "@nestjs/common";
import { AuthService } from "./auth.service.js";
import { NonceRequestDto, NonceResponse, AuthVerifyResponse, VerifySignatureDto } from "./dto/auth.dto.js";

@Controller("auth")
export class AuthController {
  constructor(private readonly auth: AuthService) {}

  @Post("nonce")
  nonce(@Body() dto: NonceRequestDto): Promise<NonceResponse> {
    return this.auth.createNonce(dto.walletAddress);
  }

  @Post("verify")
  verify(@Body() dto: VerifySignatureDto): Promise<AuthVerifyResponse> {
    return this.auth.verify(dto.walletAddress, dto.signature);
  }
}
