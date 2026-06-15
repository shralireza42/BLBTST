# AGENTS.md

## Cursor Cloud specific instructions

This monorepo (`blobby-monorepo`) is a Web3 Daily Draw / Jackpot platform for BNB Smart Chain. General setup/run/test commands live in `README.md` (sections 4, 8–13). The notes below are the non-obvious things to know when developing in the Cursor Cloud environment. The update script already runs `pnpm install` and `pnpm db:generate` on startup.

### Services overview

| Service | Path | Dev command | Port |
|---|---|---|---|
| Web (Next.js frontend) | `apps/web` | `pnpm --filter @blobby/web dev` | 3000 |
| API (NestJS) | `apps/api` | see NestJS caveat below | 3001 |
| Realtime (SSE stub) | `apps/realtime` | `pnpm --filter @blobby/realtime dev` | 3002 |
| Worker (BullMQ) | `apps/worker` | `pnpm --filter @blobby/worker dev` | n/a |
| Contracts (Foundry) | `packages/contracts` | `forge build` / `forge test` | n/a |

Required infra for end-to-end dev: **PostgreSQL** (5432) and **Redis** (6379). Realtime, `packages/daily-draw-sdk`, and the legacy Hardhat `contracts/` package are optional.

### Infra: Postgres + Redis (not Docker)

Docker is not available here, so Postgres 16 and Redis 7 are installed via `apt`. Start them (idempotent) before running api/worker:

```bash
sudo pg_ctlcluster 16 main start            # PostgreSQL
sudo redis-server --daemonize yes --appendonly yes --dir /var/lib/redis-blobby   # Redis
```

The DB role/database expected by the connection string `postgresql://blobby:blobby@localhost:5432/blobby` is created once with:

```bash
sudo -u postgres psql -c "CREATE ROLE blobby LOGIN PASSWORD 'blobby';"
sudo -u postgres psql -c "CREATE DATABASE blobby OWNER blobby;"
```

Do NOT start Redis with `--appendonly yes` from the repo root; it writes an `appendonlydir/` into the working tree. Always pass `--dir /var/lib/redis-blobby` (or another path outside the repo).

### Env files

`.env*` files are gitignored. Each service loads `.env` (or `.env.local` for web) from its own directory, so per-app env files are required: `apps/api/.env`, `apps/worker/.env`, `apps/realtime/.env`, `apps/web/.env.local` (plus a root `.env`). Use `localhost` (not the Docker hostnames `postgres`/`redis` from the root `.env.example`) for `DATABASE_URL` and `REDIS_URL`. Base values on `.env.example` / each `*/.env.example`; generate real `JWT_SECRET`, `AUTH_SESSION_SECRET`, and `ADMIN_API_KEY` values. Keep `WORKER_DRY_RUN=true` locally.

### Env must be in the process environment (not just the .env file)

`packages/database/src/client.ts` reads `process.env.DATABASE_URL` **at import time**, before NestJS `ConfigModule` / `dotenv/config` runs. So api and worker crash with `DATABASE_URL is required` if you only rely on the `.env` file. Export the env into the shell before launching, e.g.:

```bash
cd apps/api && set -a; source .env; set +a; <run command>
```

Prisma migrations: run `pnpm db:migrate` (`prisma migrate deploy`) once after the DB is up. `pnpm db:generate` regenerates the gitignored client into `packages/database/src/generated/prisma` and is already in the startup script.

### NestJS API dev caveat (important)

The documented dev script `tsx watch src/server.ts` does **not** work for the NestJS API: tsx/esbuild does not emit `emitDecoratorMetadata`, so NestJS dependency injection passes `undefined` for type-injected providers (e.g. `ConfigService`), and the app crashes (first visible failure is in `ContractsService`). Run the API via the TypeScript compiler instead. Hot-reload dev that works:

```bash
cd apps/api && set -a; source .env; set +a
./node_modules/.bin/tsc -p tsconfig.json --watch --preserveWatchOutput &
node --watch dist/server.js
```

Or a one-shot run: `pnpm --filter @blobby/api build && (cd apps/api && set -a; source .env; set +a; node dist/server.js)`. `worker`, `realtime`, and `web` dev scripts work fine as-is (no NestJS DI). Verify the API with `curl http://localhost:3001/health` → `{"ok":true}`.

### Worker behavior

On startup the worker registers all 8 BullMQ queues (visible via `GET http://localhost:3001/health/indexer`) and then runs an immediate bootstrap `syncContracts`. With placeholder zero contract addresses and the public BSC RPC, that bootstrap call (and the scheduled `eth_getLogs` jobs) fail/rate-limit and log `worker crashed` / `worker.<queue>.failed`. This is expected without deployed contract addresses + a reliable RPC; the process stays alive and keeps processing scheduled jobs. Real on-chain functionality needs deployed testnet/mainnet addresses and a private RPC.

### Foundry contracts

Foundry (`forge`) is a system toolchain (install via `foundryup`), not a JS dependency, so it is not in the update script. The remappings in `packages/contracts/remappings.txt` expect `@openzeppelin/contracts` at the **root** `node_modules`, but pnpm's isolated layout does not hoist it there. Create a symlink so `forge build`/`forge test` resolve it:

```bash
ln -sfn "$(readlink -f contracts/node_modules/@openzeppelin/contracts)" node_modules/@openzeppelin/contracts
```

Then `cd packages/contracts && forge test` (42 tests). `forge-std` is already hoisted at root.

### Known pre-existing typecheck failures (not env issues)

`pnpm typecheck` fails in two workspaces due to repo code/config, unrelated to environment setup: the legacy `@blobby/contracts` (Hardhat) package lacks `@types/node`, and `apps/web` has a TS2883 type-portability error in `lib/hooks/useContracts.ts`. The backend workspaces (`api`, `worker`, `realtime`, `database`, `daily-draw-sdk`) typecheck and build cleanly, and `apps/web` still runs fine under `next dev`.
