# BLOBBIE Daily Draw Monorepo

Production-focused scaffold for BLOBBIE Daily Draw and Jackpot operations on BNB Smart Chain.

## Packages

- `contracts` - Solidity Daily Draw, jackpot reserve, and BLOBBIE/USD oracle contracts.
- `apps/api` - Public and admin API for draw state, audit data, and operations.
- `apps/worker` - Automation worker for expiry/threshold close, operational top-up, and event sync.
- `packages/daily-draw-sdk` - Minimal frontend integration hooks and ABI exports.

## Daily Draw rules implemented

- One eligible ticket costs `1 USD` worth of BLOBBIE at purchase time via `IDailyDrawPriceOracle`.
- The included oracle quotes BLOBBIE from a BLOBBIE/WBNB PancakeSwap-style pair plus Chainlink BNB/USD.
- Rounds close when they reach `300` tickets, or after `24 hours`.
- Expired rounds below `300` tickets require an operational BLOBBIE top-up before close.
- Operational top-ups increase the prize pool but do not mint or record eligible ticket entries.
- Each wallet can receive at most one prize per round. If the jackpot pays in the same round, it is assigned to a wallet distinct from the daily winner.
- A configurable basis-point share of ticket revenue funds the jackpot reserve.
- The jackpot pays when the reserve is at or above the configured trigger amount and the round has at least two unique eligible wallets.
- Ticket ranges, top-ups, close requests, VRF request IDs, and winners are emitted as events for public auditability.
- Admin configuration is protected by contract roles and API `x-admin-key` authentication.
- The worker can open rounds, close threshold rounds, top up expired rounds, close them, and index events into Postgres.

## Local setup

```bash
cp .env.example .env
docker compose up -d
pnpm install
pnpm db:migrate
pnpm dev
```

`docker compose up -d` starts PostgreSQL and Redis by default. App containers are also defined
behind the `app` profile for production-like local smoke testing:

```bash
docker compose --profile app up --build
```

The repository still supports npm workspace commands used by CI/agents, but local development is
configured around pnpm:

```bash
pnpm db:generate
pnpm --filter @blobby/api dev
pnpm --filter @blobby/web dev
pnpm --filter @blobby/worker dev
pnpm --filter @blobby/realtime dev
```

## Deployment

Deploy only from the project owner's local machine:

```bash
cp packages/contracts/.env.example packages/contracts/.env
# Fill placeholders locally. Never commit real keys or secrets.
```

After deployment:

1. Fund the Chainlink VRF subscription and add `DailyDraw` as a consumer.
2. Grant `OPERATOR_ROLE` / `TOP_UP_ROLE` to the worker wallet if it differs from the deployer.
3. Approve the Daily Draw contract to spend operational top-up BLOBBIE from the worker/top-up wallet.
4. Set API and worker `.env` values with deployed addresses and secrets.

### Foundry deployment commands

Run all commands from `packages/contracts`.

Build and test:

```bash
forge build
forge test
```

Dry-run deployment against BSC testnet RPC without broadcasting:

```bash
source .env
forge script script/DeployBlobbieDraw.s.sol:DeployBlobbieDraw \
  --rpc-url "$BSC_TESTNET_RPC_URL" \
  -vvvv
```

Broadcast to BSC testnet:

```bash
source .env
forge script script/DeployBlobbieDraw.s.sol:DeployBlobbieDraw \
  --rpc-url "$BSC_TESTNET_RPC_URL" \
  --broadcast \
  -vvvv
```

Verify contracts on BscScan after testnet deployment:

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

Add the deployed `DailyDraw` address as a Chainlink VRF consumer in the Chainlink VRF dashboard
for `CHAINLINK_VRF_SUBSCRIPTION_ID` before expecting randomness fulfillment.

Run post-deploy config verification:

```bash
source .env
forge script script/VerifyConfig.s.sol:VerifyConfig \
  --rpc-url "$BSC_TESTNET_RPC_URL" \
  -vvvv
```

Broadcast to BSC mainnet only after testnet deployment, BscScan verification, VRF consumer setup,
and post-deploy verification succeed:

```bash
source .env
forge script script/DeployBlobbieDraw.s.sol:DeployBlobbieDraw \
  --rpc-url "$BSC_RPC_URL" \
  --broadcast \
  -vvvv

forge script script/VerifyConfig.s.sol:VerifyConfig \
  --rpc-url "$BSC_RPC_URL" \
  -vvvv
```

## Worker automation

The worker uses BullMQ with Redis for repeatable automation jobs. Configure `apps/worker/.env`
from `apps/worker/.env.example`, including:

- `REDIS_URL`
- `BSC_RPC_URL`
- `DAILY_DRAW_ADDRESS`
- `JACKPOT_VAULT_ADDRESS`
- `CONTRACT_SYNC_START_BLOCK`
- `CONTRACT_CONFIRMATION_DEPTH`
- `WORKER_DRY_RUN`
- `WORKER_PRIVATE_KEY` only when dry-run is disabled

Run locally:

```bash
npm run dev -w apps/worker
```

Jobs registered by the worker:

- `round-timeout-monitor`
- `round-close-worker`
- `settlement-monitor`
- `vrf-monitor`
- `jackpot-threshold-monitor`
- `oracle-health-monitor`
- `price-snapshot-worker`
- `audit-export-worker`

Keep `WORKER_DRY_RUN=true` until deployed contract addresses, roles, token approvals, and Redis
connectivity are verified. Worker health is exposed through `GET /health/indexer`.

## Security

Never commit secrets. Copy `.env.example` files to `.env` locally and provide RPC URLs, private keys,
BscScan keys, admin secrets, and deployed addresses through environment variables only.

Deployments are intentionally script-based and should be run only from the project owner's local machine.