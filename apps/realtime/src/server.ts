import "dotenv/config";
import http from "node:http";
import pino from "pino";
import { z } from "zod";

const env = z.object({ PORT: z.coerce.number().default(3002), LOG_LEVEL: z.string().default("info") }).parse(process.env);
const logger = pino({ level: env.LOG_LEVEL });

const server = http.createServer((req, res) => {
  if (req.url === "/health") {
    res.writeHead(200, { "content-type": "application/json" });
    res.end(JSON.stringify({ ok: true, service: "blobby-realtime" }));
    return;
  }
  if (req.url === "/events") {
    res.writeHead(200, {
      "content-type": "text/event-stream",
      "cache-control": "no-cache",
      connection: "keep-alive"
    });
    res.write(`event: ready\ndata: ${JSON.stringify({ ok: true })}\n\n`);
    return;
  }
  res.writeHead(404);
  res.end("Not found");
});

server.listen(env.PORT, () => logger.info({ port: env.PORT }, "BLOBBIE realtime service listening"));
