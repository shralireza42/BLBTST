import { env } from "./config/env.js";
import { createApp } from "./app.js";
import { logger } from "./logger.js";

const app = createApp();

app.listen(env.PORT, () => {
  logger.info({ port: env.PORT }, "BLOBBIE API listening");
});
