# BLOBBIE free-tier hosting guide

This guide prepares the project for free or hobby-tier hosting. I cannot deploy to a provider without your account access, but these templates let you deploy from your own accounts.

## Suggested free/hobby stack

- Web: Vercel free tier (`apps/web`)
- API: Render free web service or Railway/Fly equivalent (`apps/api` Dockerfile)
- Realtime: Render free web service (`apps/realtime` Dockerfile)
- Worker: Render worker, Railway worker, or local machine while testing (`apps/worker` Dockerfile)
- PostgreSQL: Neon or Supabase free tier
- Redis: Upstash free tier
- Chain: BSC testnet first

## Step 1: create managed data services

1. Create a Neon/Supabase Postgres database.
2. Copy its pooled connection string into `DATABASE_URL`.
3. Create an Upstash Redis database.
4. Copy its TLS URL into `REDIS_URL`.

Use `.env.testnet.example` as the source for safe testnet values.

## Step 2: deploy backend API

Use `render.yaml` or create a Docker web service manually:

- Docker context: repository root
- Dockerfile: `apps/api/Dockerfile`
- Health check: `/health`
- Env file: copy from `apps/api/.env.testnet.example`

Required API env values:

```bash
DATABASE_URL=
REDIS_URL=
JWT_SECRET=
AUTH_SESSION_SECRET=
ADMIN_API_KEY=
BSC_RPC_URL=https://data-seed-prebsc-1-s1.binance.org:8545/
BSC_CHAIN_ID=97
DAILY_DRAW_CONTRACT_ADDRESS=
JACKPOT_VAULT_CONTRACT_ADDRESS=
PRICE_ADAPTER_CONTRACT_ADDRESS=
BLOBBIE_TOKEN_ADDRESS=
EXPLORER_BASE_URL=https://testnet.bscscan.com
```

## Step 3: run migrations

From your local machine or provider shell:

```bash
pnpm install
pnpm db:migrate
```

Do not run migrations from random untrusted machines.

## Step 4: deploy worker

Use a worker/background service if your free host supports it:

- Docker context: repository root
- Dockerfile: `apps/worker/Dockerfile`
- Env file: copy from `apps/worker/.env.testnet.example`

Start with:

```bash
WORKER_DRY_RUN=true
```

Only disable dry-run after testnet contracts, roles, approvals, and event sync are verified.

## Step 5: deploy realtime service

Use a Docker web service:

- Docker context: repository root
- Dockerfile: `apps/realtime/Dockerfile`
- Health check: `/health`

## Step 6: deploy frontend to Vercel

In Vercel:

- Import repo
- Root directory: `apps/web`
- Framework: Next.js
- It can use `apps/web/vercel.json`

Env values:

```bash
NEXT_PUBLIC_API_BASE_URL=https://YOUR-API-HOST
NEXT_PUBLIC_REOWN_PROJECT_ID=
NEXT_PUBLIC_CHAIN_ID=97
NEXT_PUBLIC_ENABLE_TESTNET=true
NEXT_PUBLIC_BSC_RPC_URL=https://data-seed-prebsc-1-s1.binance.org:8545/
NEXT_PUBLIC_BLOBBIE_TOKEN_ADDRESS=
NEXT_PUBLIC_DAILY_DRAW_CONTRACT_ADDRESS=
NEXT_PUBLIC_JACKPOT_VAULT_CONTRACT_ADDRESS=
NEXT_PUBLIC_PRICE_ADAPTER_CONTRACT_ADDRESS=
NEXT_PUBLIC_EXPLORER_BASE_URL=https://testnet.bscscan.com
```

## Important limits

- Free services may sleep and delay workers.
- Do not use free tiers for mainnet value-bearing automation without monitoring and uptime guarantees.
- Keep `DEPLOYER_PRIVATE_KEY` local only; never put it in Vercel/Render env.
- Use testnet until all flows are verified.
