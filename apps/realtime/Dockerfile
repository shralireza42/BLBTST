FROM node:22-alpine AS base
WORKDIR /app
RUN corepack enable

FROM base AS deps
COPY package.json pnpm-workspace.yaml pnpm-lock.yaml .npmrc ./
COPY apps/realtime/package.json apps/realtime/package.json
RUN pnpm install --filter @blobby/realtime --frozen-lockfile

FROM deps AS build
COPY tsconfig.base.json ./
COPY apps/realtime apps/realtime
RUN pnpm --filter @blobby/realtime build

FROM node:22-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production
RUN corepack enable
COPY --from=build /app/package.json /app/pnpm-workspace.yaml ./
COPY --from=build /app/node_modules ./node_modules
COPY --from=build /app/apps/realtime ./apps/realtime
EXPOSE 3002
CMD ["pnpm", "--filter", "@blobby/realtime", "start"]
