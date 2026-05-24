# BLOBBIE Monorepo Deployment Guide

BLOBBIE is a Web3 gaming, Daily Draw, and Jackpot platform for BNB Smart Chain. This repository contains smart contracts, backend APIs, workers, realtime services, database schema, and the responsive web frontend.

> **Mainnet deployment is owner-only. Private keys must stay on the owner's local machine. Never paste private keys, RPC secrets, BscScan keys, admin secrets, or wallet seed phrases into source code, tickets, chat, CI logs, or screenshots.**

---

## 1. Project overview

BLOBBIE includes:

- Daily Draw: users buy BLOBBIE tickets where `1 ticket = 1 USD worth of BLOBBIE`.
- Jackpot: jackpot reserve funded from draw allocations and paid to one winner per cycle.
- Public auditability: event indexing, verification APIs, JSON/CSV exports, and explorer links.
- Worker automation: round timeout checks, close/settlement monitors, event indexing, oracle health, and audit exports.
- Admin backend: configuration, fraud controls, worker/oracle health, and action logs.
- Frontend: Next.js App Router app matching the BLOBBIE brand style.

---

## 2. Architecture overview

```txt
apps/web        Next.js frontend, wallet connection, Daily Draw/Jackpot UI
apps/api        NestJS API, admin APIs, public verification APIs
apps/worker     BullMQ workers, contract event indexer, automation jobs
apps/realtime   Realtime/SSE service placeholder for live updates
packages/contracts Foundry contracts: DailyDraw, JackpotVault, PriceAdapter, TreasuryRouter
packages/database Prisma 7 generated client wrapper
packages/daily-draw-sdk Minimal frontend integration SDK
contracts       Earlier Hardhat contract package retained for compatibility
```

Runtime dependencies:

```txt
PostgreSQL  Stores users, wallets, rounds, entries, winners, events, admin logs
Redis       BullMQ queues and worker coordination
BNB Chain   BLOBBIE token, DailyDraw, JackpotVault, PriceAdapter, TreasuryRouter
Chainlink   VRF randomness for winner selection
BscScan     Contract verification and explorer links
```

---

## 3. Prerequisites

Install these before local development or deployment.

### Node.js

Recommended: Node.js 22+.

```bash
node --version
```

### pnpm

This repo supports npm for CI/agent workflows, but local development is documented with pnpm.

```bash
corepack enable
corepack prepare pnpm@10.0.0 --activate
pnpm --version
```

### Docker

Required for local PostgreSQL and Redis.

```bash
docker --version
docker compose version
```

### Foundry

Required for smart contract tests and deployments.

```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
forge --version
```

### PostgreSQL

For local development, Docker Compose starts PostgreSQL automatically. For production, use a managed PostgreSQL instance or a hardened self-hosted deployment.

### Redis

For local development, Docker Compose starts Redis automatically. For production, use a managed Redis instance or a hardened self-hosted deployment.

---

## 4. Local setup

```bash
git clone <repo-url>
cd <repo>
cp .env.example .env
```

Start local infrastructure:

```bash
docker compose up -d
```

Install dependencies:

```bash
pnpm install
```

Generate Prisma client:

```bash
pnpm db:generate
```

Run migrations:

```bash
pnpm db:migrate
```

Start apps:

```bash
pnpm dev
```

The default local services are:

- Web: `http://localhost:3000`
- API: `http://localhost:3001`
- Realtime: `http://localhost:3002`
- PostgreSQL: `localhost:5432`
- Redis: `localhost:6379`

For free-tier hosting preparation, see `docs/free-hosting.md` and `.env.testnet.example`.

---

## 5. Environment variables

Copy examples and fill placeholders locally:

```bash
cp .env.example .env
cp apps/api/.env.example apps/api/.env
cp apps/worker/.env.example apps/worker/.env
cp apps/realtime/.env.example apps/realtime/.env
cp apps/web/.env.example apps/web/.env.local
cp packages/contracts/.env.example packages/contracts/.env
```

Required placeholders include:

```bash
DATABASE_URL=
REDIS_URL=
JWT_SECRET=
BSC_RPC_URL=
BSC_TESTNET_RPC_URL=
BSC_CHAIN_ID=56
BLOBBIE_TOKEN_ADDRESS=
BLOBBIE_USD_FEED_ADDRESS=
DAILY_DRAW_CONTRACT_ADDRESS=
JACKPOT_VAULT_CONTRACT_ADDRESS=
PRICE_ADAPTER_CONTRACT_ADDRESS=
TREASURY_ROUTER_CONTRACT_ADDRESS=
TREASURY_WALLET=
OPERATIONAL_WALLET=
BURN_WALLET=
CHAINLINK_VRF_COORDINATOR=
CHAINLINK_VRF_SUBSCRIPTION_ID=
CHAINLINK_VRF_KEY_HASH=
BSCSCAN_API_KEY=
DEPLOYER_PRIVATE_KEY=
```

Frontend public variables:

```bash
NEXT_PUBLIC_API_BASE_URL=
NEXT_PUBLIC_REOWN_PROJECT_ID=
NEXT_PUBLIC_CHAIN_ID=56
NEXT_PUBLIC_BLOBBIE_TOKEN_ADDRESS=
NEXT_PUBLIC_DAILY_DRAW_CONTRACT_ADDRESS=
NEXT_PUBLIC_JACKPOT_VAULT_CONTRACT_ADDRESS=
NEXT_PUBLIC_PRICE_ADAPTER_CONTRACT_ADDRESS=
NEXT_PUBLIC_EXPLORER_BASE_URL=https://bscscan.com
```

Security rules:

- `.env` files are local only.
- Never commit real secrets.
- Never use production private keys in cloud agents or CI unless a secure secret manager and approval process are in place.
- Mainnet deploy keys must stay on the owner's local machine.

---

## 6. Database setup

Local Docker PostgreSQL uses:

```bash
DATABASE_URL=postgresql://blobby:blobby@localhost:5432/blobby
```

Docker service-to-service URL uses:

```bash
DATABASE_URL=postgresql://blobby:blobby@postgres:5432/blobby
```

Start database:

```bash
docker compose up -d postgres
```

Check health:

```bash
docker compose ps postgres
```

---

## 7. Prisma migration

Generate Prisma client:

```bash
pnpm db:generate
```

Apply migrations:

```bash
pnpm db:migrate
```

Direct workspace commands:

```bash
pnpm --filter @blobby/api prisma:generate
pnpm --filter @blobby/api prisma:migrate
```

Migration files live in:

```txt
apps/api/prisma/migrations
```

---

## 8. Backend run

Development:

```bash
pnpm --filter @blobby/api dev
```

Build:

```bash
pnpm --filter @blobby/api build
```

Start built app:

```bash
pnpm --filter @blobby/api start
```

API health:

```bash
curl http://localhost:3001/health
curl http://localhost:3001/health/indexer
```

---

## 9. Worker run

The worker uses BullMQ and Redis.

Development:

```bash
pnpm --filter @blobby/worker dev
```

Build:

```bash
pnpm --filter @blobby/worker build
```

Start:

```bash
pnpm --filter @blobby/worker start
```

Important worker env:

```bash
REDIS_URL=
WORKER_DRY_RUN=true
WORKER_PRIVATE_KEY=
CONTRACT_SYNC_START_BLOCK=
CONTRACT_CONFIRMATION_DEPTH=12
```

Keep `WORKER_DRY_RUN=true` until deployed addresses, contract roles, top-up approvals, Redis connectivity, and event cursors are verified.

---

## 10. Realtime run

Development:

```bash
pnpm --filter @blobby/realtime dev
```

Build:

```bash
pnpm --filter @blobby/realtime build
```

Start:

```bash
pnpm --filter @blobby/realtime start
```

Health:

```bash
curl http://localhost:3002/health
```

SSE placeholder:

```bash
curl http://localhost:3002/events
```

---

## 11. Frontend run

Development:

```bash
pnpm --filter @blobby/web dev
```

Build:

```bash
pnpm --filter @blobby/web build
```

Start:

```bash
pnpm --filter @blobby/web start
```

Assets expected in `apps/web/public`:

```txt
LOGO.png
blobbie1.png
```

If assets are missing, place the real BLOBBIE files there before production deployment.

---

## 12. Smart contract tests

Run from `packages/contracts`:

```bash
forge fmt
forge build
forge test
forge test -vvv
```

The test suite includes unit, integration, fuzz, and invariant-style tests.

---

## 13. Local mock deployment

The contracts are intended for BSC testnet/mainnet deployment with real env variables. For local dry-runs, use Foundry script simulation without broadcasting:

```bash
cd packages/contracts
cp .env.example .env
# Fill local placeholder values.
source .env
forge script script/DeployBlobbieDraw.s.sol:DeployBlobbieDraw \
  --rpc-url "$BSC_TESTNET_RPC_URL" \
  -vvvv
```

This simulates deployment and prints addresses without sending transactions.

---

## 14. BSC testnet deployment

> Testnet deployment should happen before any mainnet action.

From `packages/contracts`:

```bash
source .env
forge build
forge test
forge script script/DeployBlobbieDraw.s.sol:DeployBlobbieDraw \
  --rpc-url "$BSC_TESTNET_RPC_URL" \
  --broadcast \
  -vvvv
```

After deployment, copy printed addresses into:

```bash
PRICE_ADAPTER_CONTRACT_ADDRESS=
JACKPOT_VAULT_CONTRACT_ADDRESS=
TREASURY_ROUTER_CONTRACT_ADDRESS=
DAILY_DRAW_CONTRACT_ADDRESS=
```

Then update API, worker, and frontend env files with the deployed testnet addresses.

---

## 15. BSCScan verification

Testnet chain ID is `97`; mainnet chain ID is `56`.

Example testnet verification commands:

```bash
forge verify-contract "$PRICE_ADAPTER_CONTRACT_ADDRESS" src/BlobbiePriceAdapter.sol:BlobbiePriceAdapter \
  --chain-id 97 \
  --etherscan-api-key "$BSCSCAN_API_KEY"

forge verify-contract "$JACKPOT_VAULT_CONTRACT_ADDRESS" src/BlobbieJackpotVault.sol:BlobbieJackpotVault \
  --chain-id 97 \
  --etherscan-api-key "$BSCSCAN_API_KEY"

forge verify-contract "$TREASURY_ROUTER_CONTRACT_ADDRESS" src/BlobbieTreasuryRouter.sol:BlobbieTreasuryRouter \
  --chain-id 97 \
  --etherscan-api-key "$BSCSCAN_API_KEY"

forge verify-contract "$DAILY_DRAW_CONTRACT_ADDRESS" src/BlobbieDailyDraw.sol:BlobbieDailyDraw \
  --chain-id 97 \
  --etherscan-api-key "$BSCSCAN_API_KEY"
```

For mainnet, use `--chain-id 56`.

Constructor arguments may need to be supplied depending on BscScan/Foundry verification behavior. Generate them from deployment logs if needed.

---

## 16. Chainlink VRF setup

### Create subscription

1. Open the Chainlink VRF dashboard.
2. Select BNB Smart Chain testnet or mainnet.
3. Create a VRF subscription.
4. Save the subscription ID in:

```bash
CHAINLINK_VRF_SUBSCRIPTION_ID=
```

### Fund subscription

Fund the subscription with the required LINK/native token amount for the selected network.

### Deploy consumer contract

Deploy `BlobbieDailyDraw` with:

```bash
CHAINLINK_VRF_COORDINATOR=
CHAINLINK_VRF_SUBSCRIPTION_ID=
CHAINLINK_VRF_KEY_HASH=
```

### Add deployed DailyDraw as consumer

After deployment:

1. Open the VRF subscription.
2. Add `DAILY_DRAW_CONTRACT_ADDRESS` as a consumer.
3. Confirm the transaction.
4. Wait for confirmation before testing randomness fulfillment.

---

## 17. BSC mainnet deployment

> **Mainnet deployment requires explicit owner action. Do not run mainnet deployment from a cloud agent. Keep `DEPLOYER_PRIVATE_KEY` local on the owner's machine only.**

Mainnet deployment is allowed only after:

- Testnet deployment succeeded.
- BscScan verification succeeded on testnet.
- Chainlink VRF consumer setup succeeded on testnet.
- Post-deploy verification succeeded on testnet.
- Backend/worker/frontend were tested against testnet addresses.
- Owner has reviewed env values and addresses.

Mainnet commands from `packages/contracts`:

```bash
source .env
forge script script/DeployBlobbieDraw.s.sol:DeployBlobbieDraw \
  --rpc-url "$BSC_RPC_URL" \
  --broadcast \
  -vvvv
```

Post-deploy verification:

```bash
forge script script/VerifyConfig.s.sol:VerifyConfig \
  --rpc-url "$BSC_RPC_URL" \
  -vvvv
```

Then verify on BscScan with `--chain-id 56` and add DailyDraw as VRF consumer on the mainnet subscription.

---

## 18. Backend production config

Set production API env:

```bash
NODE_ENV=production
DATABASE_URL=
REDIS_URL=
JWT_SECRET=
AUTH_SESSION_SECRET=
ADMIN_API_KEY=
ADMIN_WALLETS=
BSC_RPC_URL=
BSC_CHAIN_ID=56
DAILY_DRAW_CONTRACT_ADDRESS=
JACKPOT_VAULT_CONTRACT_ADDRESS=
PRICE_ADAPTER_CONTRACT_ADDRESS=
BLOBBIE_TOKEN_ADDRESS=
EXPLORER_BASE_URL=https://bscscan.com
```

Production recommendations:

- Use managed PostgreSQL with backups.
- Use managed Redis with persistence/monitoring.
- Enforce HTTPS.
- Restrict admin API access with network rules where possible.
- Rotate `ADMIN_API_KEY` and session secrets periodically.
- Do not expose admin secrets to the frontend.

---

## 19. Worker production config

Set worker env:

```bash
NODE_ENV=production
DATABASE_URL=
REDIS_URL=
BSC_RPC_URL=
BSC_CHAIN_ID=56
DAILY_DRAW_CONTRACT_ADDRESS=
JACKPOT_VAULT_CONTRACT_ADDRESS=
PRICE_ADAPTER_CONTRACT_ADDRESS=
WORKER_DRY_RUN=false
WORKER_PRIVATE_KEY=
CONTRACT_SYNC_START_BLOCK=
CONTRACT_CONFIRMATION_DEPTH=12
MAX_TOP_UP_WEI=
```

Worker wallet requirements:

- Must have required on-chain roles.
- Must have gas funds.
- Must have BLOBBIE allowance for operational top-ups if top-up automation is enabled.
- Private key must be stored in a secure secret manager, not source code.

---

## 20. Event indexer start block config

Use the block where the contracts were deployed:

```bash
CONTRACT_SYNC_START_BLOCK=<deployment-block>
CONTRACT_CONFIRMATION_DEPTH=12
EVENT_SYNC_CHUNK_SIZE=2000
```

If you start too early, sync may take longer. If you start too late, the database will miss events.

For re-sync in development:

1. Stop worker.
2. Clear relevant `ContractSyncCursor` rows.
3. Set `CONTRACT_SYNC_START_BLOCK` to the deployment block.
4. Restart worker.

---

## 21. Admin first setup

1. Set `ADMIN_API_KEY` in API env.
2. Set `ADMIN_WALLETS` to comma-separated admin wallet addresses.
3. Start API.
4. Connect wallet in frontend.
5. Sign the auth message.
6. Use admin UI or API with `x-admin-key` for protected routes.
7. Confirm `AdminActionLog` records admin actions.
8. Configure draw/prize/jackpot settings.
9. Confirm fraud exclusion and clear-wallet workflows.

Do not put admin API keys in public frontend env variables.

---

## 22. Health checks

API:

```bash
curl https://api.example.com/health
curl https://api.example.com/health/indexer
```

Admin:

```bash
GET /admin/system/health
GET /admin/contracts/sync-status
GET /admin/worker/health
GET /admin/oracle/health
```

Realtime:

```bash
curl https://realtime.example.com/health
```

Worker health is written to `SystemConfig` and job logs are written to `AdminActionLog`.

---

## 23. Go-live checklist

- [ ] Contracts deployed on testnet.
- [ ] Testnet contracts verified on BscScan.
- [ ] DailyDraw added as Chainlink VRF consumer on testnet.
- [ ] Testnet draw purchase flow works.
- [ ] Testnet VRF fulfillment works.
- [ ] Event indexer catches up from deployment block.
- [ ] Public verification endpoints show expected data.
- [ ] Admin health pages show OK status.
- [ ] Fraud exclusion tested.
- [ ] Worker dry-run reviewed.
- [ ] Worker production wallet funded and role-checked.
- [ ] Mainnet env reviewed by owner.
- [ ] Mainnet private key remains local/secure.
- [ ] Mainnet deployment explicitly approved by owner.
- [ ] Mainnet contracts verified.
- [ ] Mainnet VRF consumer added.
- [ ] Monitoring and alerting enabled.

---

## 24. Emergency procedures

If draw purchases must stop:

1. Pause `BlobbieDailyDraw` on-chain using authorized pauser.
2. Set `draw.paused` feature flag in admin backend.
3. Stop worker transaction automation or set `WORKER_DRY_RUN=true`.
4. Keep event indexer running if safe.
5. Post a public status update.

If oracle data is unhealthy:

1. Pause draw purchases if pricing cannot be trusted.
2. Review `OracleHealthCheck` records.
3. Use manual fallback only if approved by multisig/owner policy.
4. Emit and record every config change.

If VRF fulfillment is delayed:

1. Confirm subscription is funded.
2. Confirm DailyDraw is an approved consumer.
3. Check coordinator/network status.
4. Do not settle winners manually outside contract rules.

If fraud is detected:

1. Exclude wallet in admin fraud panel.
2. Record reason.
3. Verify exclusion propagates to draw/jackpot eligibility.
4. Keep audit logs.

---

## 25. Security checklist

- [ ] No secrets committed.
- [ ] Mainnet deploy key never leaves owner-controlled machine/secret manager.
- [ ] Admin actions are logged.
- [ ] Admin API key is not exposed to frontend.
- [ ] Worker private key has minimal required roles.
- [ ] On-chain roles reviewed after deployment.
- [ ] VRF subscription owner reviewed.
- [ ] Price feed address reviewed.
- [ ] Manual fallback disabled by default.
- [ ] Emergency recovery cannot withdraw tracked reserves.
- [ ] Event indexer uses confirmation depth.
- [ ] Database has backups.
- [ ] Redis is access-controlled.
- [ ] TLS enabled for public services.
- [ ] Frontend public env contains only public values.

---

## 26. Known limitations

- Smart contracts and backend require a professional audit before mainnet value is at risk.
- Current realtime service is an SSE-ready placeholder, not a full chat/game realtime backend.
- Game pages are Phaser integration-ready shells, not final paid game logic.
- Event indexing is confirmation-depth based but not a full deep reorg rollback engine.
- BscScan verification may require constructor arguments depending on explorer behavior.
- Worker automation should remain dry-run until roles, allowances, balances, and monitoring are verified.
- Frontend dev mock fallback is isolated and intended only for local development.

---

## 27. Audit recommendation

Before mainnet launch with real funds:

1. Complete an internal security review.
2. Run full Foundry tests and add any missing edge-case tests.
3. Run static analysis tools such as Slither.
4. Perform a testnet public beta.
5. Hire an independent smart contract auditor.
6. Audit backend admin and worker operational security.
7. Audit deployment procedure and key management.
8. Do not proceed to mainnet until critical/high findings are fixed and retested.

Mainnet launch should be treated as a formal release controlled by the project owner. Private keys, admin keys, and deployment approvals must remain under owner control.
