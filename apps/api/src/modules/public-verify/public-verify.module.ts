import { Module } from "@nestjs/common";
import { PublicVerifyController } from "./public-verify.controller.js";
import { PublicVerifyService } from "./public-verify.service.js";

@Module({ controllers: [PublicVerifyController], providers: [PublicVerifyService] })
export class PublicVerifyModule {}
