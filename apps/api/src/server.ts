import "reflect-metadata";
import helmet from "helmet";
import { NestFactory } from "@nestjs/core";
import { ConfigService } from "@nestjs/config";
import { ValidationPipe } from "@nestjs/common";
import { AppModule } from "./app.module.js";

async function bootstrap() {
  const app = await NestFactory.create(AppModule, { bufferLogs: true });
  const config = app.get(ConfigService);
  app.use(helmet());
  app.enableCors({ origin: config.get<string>("CORS_ORIGIN") === "*" ? true : config.get<string>("CORS_ORIGIN") || true });
  app.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true, forbidNonWhitelisted: true }));
  const port = Number(config.get("PORT") || 3001);
  await app.listen(port);
}

bootstrap().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
