-- CreateSchema
CREATE SCHEMA IF NOT EXISTS "public";

-- CreateEnum
CREATE TYPE "UserStatus" AS ENUM ('ACTIVE', 'SUSPENDED', 'BANNED', 'DELETED');

-- CreateEnum
CREATE TYPE "WalletStatus" AS ENUM ('ACTIVE', 'BANNED', 'FRAUD_REJECTED', 'REVIEW_REQUIRED');

-- CreateEnum
CREATE TYPE "ReviewStatus" AS ENUM ('NONE', 'PENDING', 'APPROVED', 'REJECTED', 'ESCALATED');

-- CreateEnum
CREATE TYPE "DrawRoundStatus" AS ENUM ('OPEN', 'CLOSED', 'VRF_REQUESTED', 'DRAWING', 'SETTLING', 'FINALIZED', 'PAUSED', 'FAILED_NEEDS_ADMIN_REVIEW', 'CALCULATING', 'FULFILLED', 'CANCELLED');

-- CreateEnum
CREATE TYPE "DrawEntrySource" AS ENUM ('PAID', 'REFERRAL', 'PROMOTIONAL', 'TASK_REWARD', 'OPERATIONAL_TOP_UP', 'ADMIN_ADJUSTMENT');

-- CreateEnum
CREATE TYPE "DrawEntryStatus" AS ENUM ('ELIGIBLE', 'EXCLUDED', 'FRAUD_REJECTED', 'CANCELLED');

-- CreateEnum
CREATE TYPE "DrawPrizeTier" AS ENUM ('FIRST', 'SECOND_TO_TENTH', 'ELEVENTH_TO_ONE_FIFTIETH', 'FREE_ENTRY_RESERVE', 'JACKPOT_ALLOCATION', 'BURN_TREASURY', 'UNUSED_REDISTRIBUTION');

-- CreateEnum
CREATE TYPE "DrawSettlementStatus" AS ENUM ('PENDING', 'VRF_REQUESTED', 'RANDOMNESS_RECEIVED', 'SETTLING', 'FINALIZED', 'FAILED', 'ADMIN_REVIEW');

-- CreateEnum
CREATE TYPE "JackpotCycleStatus" AS ENUM ('OPEN', 'THRESHOLD_MET', 'VRF_REQUESTED', 'SETTLING', 'PAID', 'CANCELLED', 'FAILED_NEEDS_ADMIN_REVIEW');

-- CreateEnum
CREATE TYPE "RewardLedgerType" AS ENUM ('DRAW_PRIZE', 'JACKPOT_PRIZE', 'REFERRAL_REWARD', 'TASK_REWARD', 'FREE_ENTRY_RESERVE', 'BURN_TREASURY_RESERVE', 'ADJUSTMENT');

-- CreateEnum
CREATE TYPE "RewardLedgerStatus" AS ENUM ('PENDING', 'POSTED', 'REVERSED', 'FAILED');

-- CreateEnum
CREATE TYPE "ReferralBindingStatus" AS ENUM ('ACTIVE', 'REVOKED', 'FRAUD_REJECTED');

-- CreateEnum
CREATE TYPE "ReferralRewardStatus" AS ENUM ('PENDING', 'APPROVED', 'PAID', 'REJECTED');

-- CreateEnum
CREATE TYPE "TaskStatus" AS ENUM ('DRAFT', 'ACTIVE', 'PAUSED', 'ENDED', 'ARCHIVED');

-- CreateEnum
CREATE TYPE "TaskClaimStatus" AS ENUM ('PENDING', 'APPROVED', 'REJECTED', 'PAID', 'EXPIRED');

-- CreateEnum
CREATE TYPE "FraudSignalType" AS ENUM ('WALLET_CLUSTER', 'DUPLICATE_ACCOUNT', 'BOT_ACTIVITY', 'SUSPICIOUS_REFERRAL', 'CHARGEBACK', 'ADMIN_FLAG', 'OTHER');

-- CreateEnum
CREATE TYPE "FraudCaseStatus" AS ENUM ('OPEN', 'INVESTIGATING', 'CLEARED', 'CONFIRMED', 'CLOSED');

-- CreateEnum
CREATE TYPE "ContractEventStatus" AS ENUM ('PENDING', 'PROCESSED', 'FAILED', 'IGNORED');

-- CreateEnum
CREATE TYPE "AdminActionStatus" AS ENUM ('SUCCESS', 'FAILED', 'PENDING');

-- CreateEnum
CREATE TYPE "SupportTicketStatus" AS ENUM ('OPEN', 'PENDING_USER', 'PENDING_ADMIN', 'RESOLVED', 'CLOSED');

-- CreateEnum
CREATE TYPE "SupportPriority" AS ENUM ('LOW', 'NORMAL', 'HIGH', 'URGENT');

-- CreateEnum
CREATE TYPE "BugReportStatus" AS ENUM ('NEW', 'TRIAGED', 'IN_PROGRESS', 'FIXED', 'WONT_FIX', 'DUPLICATE');

-- CreateTable
CREATE TABLE "User" (
    "id" TEXT NOT NULL,
    "email" TEXT,
    "username" TEXT,
    "status" "UserStatus" NOT NULL DEFAULT 'ACTIVE',
    "reviewStatus" "ReviewStatus" NOT NULL DEFAULT 'NONE',
    "fraudExcluded" BOOLEAN NOT NULL DEFAULT false,
    "bannedAt" TIMESTAMP(3),
    "fraudRejectedAt" TIMESTAMP(3),
    "lastLoginAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "deletedAt" TIMESTAMP(3),

    CONSTRAINT "User_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Wallet" (
    "id" TEXT NOT NULL,
    "userId" TEXT,
    "address" TEXT NOT NULL,
    "chainId" INTEGER NOT NULL DEFAULT 56,
    "status" "WalletStatus" NOT NULL DEFAULT 'ACTIVE',
    "isPrimary" BOOLEAN NOT NULL DEFAULT false,
    "fraudExcluded" BOOLEAN NOT NULL DEFAULT false,
    "bannedAt" TIMESTAMP(3),
    "fraudRejectedAt" TIMESTAMP(3),
    "firstSeenAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "lastSeenAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "deletedAt" TIMESTAMP(3),

    CONSTRAINT "Wallet_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Profile" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "displayName" TEXT,
    "avatarUrl" TEXT,
    "bio" TEXT,
    "country" TEXT,
    "locale" TEXT,
    "timezone" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Profile_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "DrawRound" (
    "id" BIGINT NOT NULL,
    "chainId" INTEGER NOT NULL DEFAULT 56,
    "contractAddress" TEXT,
    "status" "DrawRoundStatus" NOT NULL DEFAULT 'OPEN',
    "openedAt" TIMESTAMP(3) NOT NULL,
    "expiresAt" TIMESTAMP(3) NOT NULL,
    "closedAt" TIMESTAMP(3),
    "finalizedAt" TIMESTAMP(3),
    "eligibleTicketCount" INTEGER NOT NULL DEFAULT 0,
    "totalEntryCount" INTEGER NOT NULL DEFAULT 0,
    "uniqueWalletCount" INTEGER NOT NULL DEFAULT 0,
    "grossTicketRevenue" DECIMAL(78,0) NOT NULL DEFAULT 0,
    "prizePool" DECIMAL(78,0) NOT NULL DEFAULT 0,
    "jackpotContribution" DECIMAL(78,0) NOT NULL DEFAULT 0,
    "operationalTopUp" DECIMAL(78,0) NOT NULL DEFAULT 0,
    "topUpRequired" DECIMAL(78,0) NOT NULL DEFAULT 0,
    "dailyPrizePaid" DECIMAL(78,0) NOT NULL DEFAULT 0,
    "jackpotPaid" DECIMAL(78,0) NOT NULL DEFAULT 0,
    "freeEntryReserve" DECIMAL(78,0) NOT NULL DEFAULT 0,
    "burnTreasuryReserve" DECIMAL(78,0) NOT NULL DEFAULT 0,
    "dailyWinner" TEXT,
    "jackpotWinner" TEXT,
    "vrfRequestId" DECIMAL(78,0),
    "randomness" DECIMAL(78,0),
    "jackpotEligible" BOOLEAN NOT NULL DEFAULT false,
    "reviewStatus" "ReviewStatus" NOT NULL DEFAULT 'NONE',
    "reviewReason" TEXT,
    "txHash" TEXT,
    "closeTxHash" TEXT,
    "settlementTxHash" TEXT,
    "blockNumber" BIGINT,
    "closeBlockNumber" BIGINT,
    "settlementBlockNumber" BIGINT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "DrawRound_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "DrawEntry" (
    "id" TEXT NOT NULL,
    "roundId" BIGINT NOT NULL,
    "walletId" TEXT,
    "userId" TEXT,
    "walletAddress" TEXT NOT NULL,
    "chainId" INTEGER NOT NULL DEFAULT 56,
    "contractAddress" TEXT,
    "source" "DrawEntrySource" NOT NULL DEFAULT 'PAID',
    "status" "DrawEntryStatus" NOT NULL DEFAULT 'ELIGIBLE',
    "quantity" INTEGER NOT NULL,
    "eligibleQuantity" INTEGER NOT NULL DEFAULT 0,
    "startInclusive" INTEGER,
    "endExclusive" INTEGER,
    "blobbyPaid" DECIMAL(78,0) NOT NULL DEFAULT 0,
    "usdValueE18" DECIMAL(78,0) NOT NULL DEFAULT 0,
    "jackpotContribution" DECIMAL(78,0) NOT NULL DEFAULT 0,
    "excludedReason" TEXT,
    "fraudExcluded" BOOLEAN NOT NULL DEFAULT false,
    "txHash" TEXT,
    "logIndex" INTEGER,
    "blockNumber" BIGINT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "DrawEntry_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "DrawWinner" (
    "id" TEXT NOT NULL,
    "roundId" BIGINT NOT NULL,
    "walletId" TEXT,
    "walletAddress" TEXT,
    "winner" TEXT,
    "slot" INTEGER,
    "tier" "DrawPrizeTier",
    "prizeType" TEXT NOT NULL DEFAULT 'DAILY',
    "amount" DECIMAL(78,0) NOT NULL,
    "usdValueE18" DECIMAL(78,0) NOT NULL DEFAULT 0,
    "paid" BOOLEAN NOT NULL DEFAULT false,
    "txHash" TEXT,
    "logIndex" INTEGER,
    "blockNumber" BIGINT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "DrawWinner_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "DrawPrizeConfig" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "tier" "DrawPrizeTier" NOT NULL,
    "slotStart" INTEGER NOT NULL,
    "slotEnd" INTEGER NOT NULL,
    "usdValueE18" DECIMAL(78,0) NOT NULL,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "effectiveFrom" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "effectiveTo" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "DrawPrizeConfig_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "DrawSettlement" (
    "id" TEXT NOT NULL,
    "roundId" BIGINT NOT NULL,
    "status" "DrawSettlementStatus" NOT NULL DEFAULT 'PENDING',
    "vrfRequestId" DECIMAL(78,0),
    "randomness" DECIMAL(78,0),
    "winnersPaid" INTEGER NOT NULL DEFAULT 0,
    "totalPrizePaid" DECIMAL(78,0) NOT NULL DEFAULT 0,
    "jackpotAllocated" DECIMAL(78,0) NOT NULL DEFAULT 0,
    "freeEntryReserve" DECIMAL(78,0) NOT NULL DEFAULT 0,
    "burnTreasury" DECIMAL(78,0) NOT NULL DEFAULT 0,
    "failureReason" TEXT,
    "reviewStatus" "ReviewStatus" NOT NULL DEFAULT 'NONE',
    "requestedTxHash" TEXT,
    "fulfilledTxHash" TEXT,
    "settledTxHash" TEXT,
    "blockNumber" BIGINT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "finalizedAt" TIMESTAMP(3),

    CONSTRAINT "DrawSettlement_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "JackpotCycle" (
    "id" BIGINT NOT NULL,
    "chainId" INTEGER NOT NULL DEFAULT 56,
    "contractAddress" TEXT,
    "status" "JackpotCycleStatus" NOT NULL DEFAULT 'OPEN',
    "startedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "thresholdMetAt" TIMESTAMP(3),
    "randomnessRequestedAt" TIMESTAMP(3),
    "endedAt" TIMESTAMP(3),
    "thresholdUsdE18" DECIMAL(78,0) NOT NULL DEFAULT 100000000000000000000000,
    "thresholdBlobbie" DECIMAL(78,0) NOT NULL DEFAULT 0,
    "reserveBalance" DECIMAL(78,0) NOT NULL DEFAULT 0,
    "totalContributed" DECIMAL(78,0) NOT NULL DEFAULT 0,
    "eligibleTicketCount" INTEGER NOT NULL DEFAULT 0,
    "vrfRequestId" DECIMAL(78,0),
    "randomness" DECIMAL(78,0),
    "winnerWalletAddress" TEXT,
    "paidAmount" DECIMAL(78,0) NOT NULL DEFAULT 0,
    "txHash" TEXT,
    "settlementTxHash" TEXT,
    "blockNumber" BIGINT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "JackpotCycle_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "JackpotEntry" (
    "id" TEXT NOT NULL,
    "cycleId" BIGINT NOT NULL,
    "walletId" TEXT,
    "walletAddress" TEXT NOT NULL,
    "drawRoundId" BIGINT,
    "drawEntryId" TEXT,
    "ticketCount" INTEGER NOT NULL,
    "startInclusive" INTEGER,
    "endExclusive" INTEGER,
    "source" "DrawEntrySource" NOT NULL DEFAULT 'PAID',
    "eligible" BOOLEAN NOT NULL DEFAULT true,
    "exclusionReason" TEXT,
    "fraudExcluded" BOOLEAN NOT NULL DEFAULT false,
    "txHash" TEXT,
    "logIndex" INTEGER,
    "blockNumber" BIGINT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "JackpotEntry_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "JackpotContribution" (
    "id" TEXT NOT NULL,
    "cycleId" BIGINT NOT NULL,
    "drawRoundId" BIGINT,
    "amount" DECIMAL(78,0) NOT NULL,
    "source" TEXT NOT NULL,
    "chainId" INTEGER NOT NULL DEFAULT 56,
    "contractAddress" TEXT,
    "txHash" TEXT,
    "logIndex" INTEGER,
    "blockNumber" BIGINT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "JackpotContribution_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "JackpotWinner" (
    "id" TEXT NOT NULL,
    "cycleId" BIGINT NOT NULL,
    "walletId" TEXT,
    "walletAddress" TEXT NOT NULL,
    "amount" DECIMAL(78,0) NOT NULL,
    "txHash" TEXT,
    "logIndex" INTEGER,
    "blockNumber" BIGINT,
    "paidAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "JackpotWinner_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "RewardLedgerEntry" (
    "id" TEXT NOT NULL,
    "userId" TEXT,
    "walletId" TEXT,
    "walletAddress" TEXT,
    "type" "RewardLedgerType" NOT NULL,
    "status" "RewardLedgerStatus" NOT NULL DEFAULT 'PENDING',
    "amount" DECIMAL(78,0) NOT NULL,
    "usdValueE18" DECIMAL(78,0),
    "chainId" INTEGER NOT NULL DEFAULT 56,
    "contractAddress" TEXT,
    "txHash" TEXT,
    "blockNumber" BIGINT,
    "referenceType" TEXT,
    "referenceId" TEXT,
    "metadata" JSONB,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "RewardLedgerEntry_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ReferralCode" (
    "id" TEXT NOT NULL,
    "code" TEXT NOT NULL,
    "userId" TEXT,
    "walletId" TEXT,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "maxUses" INTEGER,
    "useCount" INTEGER NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "expiresAt" TIMESTAMP(3),

    CONSTRAINT "ReferralCode_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ReferralBinding" (
    "id" TEXT NOT NULL,
    "referralCodeId" TEXT NOT NULL,
    "referredUserId" TEXT,
    "referredWalletAddress" TEXT NOT NULL,
    "referrerUserId" TEXT,
    "status" "ReferralBindingStatus" NOT NULL DEFAULT 'ACTIVE',
    "fraudExcluded" BOOLEAN NOT NULL DEFAULT false,
    "boundAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "revokedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "ReferralBinding_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ReferralReward" (
    "id" TEXT NOT NULL,
    "referralCodeId" TEXT,
    "userId" TEXT,
    "walletId" TEXT,
    "walletAddress" TEXT NOT NULL,
    "status" "ReferralRewardStatus" NOT NULL DEFAULT 'PENDING',
    "amount" DECIMAL(78,0) NOT NULL,
    "rewardToken" TEXT,
    "reason" TEXT,
    "txHash" TEXT,
    "blockNumber" BIGINT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "paidAt" TIMESTAMP(3),

    CONSTRAINT "ReferralReward_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Task" (
    "id" TEXT NOT NULL,
    "slug" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "description" TEXT,
    "status" "TaskStatus" NOT NULL DEFAULT 'DRAFT',
    "rewardAmount" DECIMAL(78,0) NOT NULL DEFAULT 0,
    "rewardUsdE18" DECIMAL(78,0),
    "startsAt" TIMESTAMP(3),
    "endsAt" TIMESTAMP(3),
    "maxClaims" INTEGER,
    "claimCount" INTEGER NOT NULL DEFAULT 0,
    "metadata" JSONB,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Task_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "TaskClaim" (
    "id" TEXT NOT NULL,
    "taskId" TEXT NOT NULL,
    "userId" TEXT,
    "walletId" TEXT,
    "walletAddress" TEXT NOT NULL,
    "status" "TaskClaimStatus" NOT NULL DEFAULT 'PENDING',
    "proof" JSONB,
    "rewardAmount" DECIMAL(78,0) NOT NULL DEFAULT 0,
    "fraudExcluded" BOOLEAN NOT NULL DEFAULT false,
    "reviewStatus" "ReviewStatus" NOT NULL DEFAULT 'PENDING',
    "reviewedBy" TEXT,
    "reviewedAt" TIMESTAMP(3),
    "txHash" TEXT,
    "blockNumber" BIGINT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "TaskClaim_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "TaskVerificationLog" (
    "id" TEXT NOT NULL,
    "taskClaimId" TEXT NOT NULL,
    "userId" TEXT,
    "verifier" TEXT NOT NULL,
    "result" "ReviewStatus" NOT NULL,
    "reason" TEXT,
    "payload" JSONB,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "TaskVerificationLog_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "FraudSignal" (
    "id" TEXT NOT NULL,
    "type" "FraudSignalType" NOT NULL,
    "severity" INTEGER NOT NULL DEFAULT 1,
    "userId" TEXT,
    "walletId" TEXT,
    "walletAddress" TEXT,
    "source" TEXT NOT NULL,
    "payload" JSONB,
    "reviewed" BOOLEAN NOT NULL DEFAULT false,
    "reviewedBy" TEXT,
    "reviewedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "FraudSignal_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "FraudCase" (
    "id" TEXT NOT NULL,
    "status" "FraudCaseStatus" NOT NULL DEFAULT 'OPEN',
    "userId" TEXT,
    "walletId" TEXT,
    "walletAddress" TEXT,
    "title" TEXT NOT NULL,
    "description" TEXT,
    "riskScore" INTEGER NOT NULL DEFAULT 0,
    "assignedTo" TEXT,
    "resolution" TEXT,
    "openedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "closedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "FraudCase_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ContractEvent" (
    "id" TEXT NOT NULL,
    "chainId" INTEGER NOT NULL DEFAULT 56,
    "contractAddress" TEXT NOT NULL,
    "eventName" TEXT NOT NULL,
    "txHash" TEXT NOT NULL,
    "logIndex" INTEGER NOT NULL,
    "blockNumber" BIGINT NOT NULL,
    "blockHash" TEXT,
    "payload" JSONB NOT NULL,
    "status" "ContractEventStatus" NOT NULL DEFAULT 'PENDING',
    "processedAt" TIMESTAMP(3),
    "error" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "ContractEvent_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ContractSyncCursor" (
    "id" TEXT NOT NULL,
    "chainId" INTEGER NOT NULL DEFAULT 56,
    "contractAddress" TEXT NOT NULL,
    "cursorName" TEXT NOT NULL,
    "lastBlockNumber" BIGINT NOT NULL DEFAULT 0,
    "lastTxHash" TEXT,
    "lastLogIndex" INTEGER,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ContractSyncCursor_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "AdminActionLog" (
    "id" TEXT NOT NULL,
    "actorUserId" TEXT,
    "actorWallet" TEXT,
    "action" TEXT NOT NULL,
    "status" "AdminActionStatus" NOT NULL DEFAULT 'SUCCESS',
    "targetType" TEXT,
    "targetId" TEXT,
    "ipAddress" TEXT,
    "userAgent" TEXT,
    "payload" JSONB NOT NULL,
    "txHash" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "AdminActionLog_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "FeatureFlag" (
    "key" TEXT NOT NULL,
    "enabled" BOOLEAN NOT NULL DEFAULT false,
    "description" TEXT,
    "rules" JSONB,
    "updatedBy" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "FeatureFlag_pkey" PRIMARY KEY ("key")
);

-- CreateTable
CREATE TABLE "SystemConfig" (
    "key" TEXT NOT NULL,
    "value" JSONB NOT NULL,
    "description" TEXT,
    "isSecret" BOOLEAN NOT NULL DEFAULT false,
    "updatedBy" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "SystemConfig_pkey" PRIMARY KEY ("key")
);

-- CreateTable
CREATE TABLE "PriceSnapshot" (
    "id" TEXT NOT NULL,
    "chainId" INTEGER NOT NULL DEFAULT 56,
    "oracleAddress" TEXT,
    "tokenAddress" TEXT,
    "drawRoundId" BIGINT,
    "priceE18" DECIMAL(78,0) NOT NULL,
    "source" TEXT NOT NULL,
    "blockNumber" BIGINT,
    "txHash" TEXT,
    "observedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "PriceSnapshot_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "OracleHealthCheck" (
    "id" TEXT NOT NULL,
    "chainId" INTEGER NOT NULL DEFAULT 56,
    "oracleAddress" TEXT NOT NULL,
    "status" TEXT NOT NULL,
    "priceE18" DECIMAL(78,0),
    "lastUpdatedAt" TIMESTAMP(3),
    "maxPriceAge" INTEGER,
    "latencyMs" INTEGER,
    "error" TEXT,
    "checkedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "OracleHealthCheck_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "SupportTicket" (
    "id" TEXT NOT NULL,
    "userId" TEXT,
    "walletId" TEXT,
    "walletAddress" TEXT,
    "subject" TEXT NOT NULL,
    "message" TEXT NOT NULL,
    "status" "SupportTicketStatus" NOT NULL DEFAULT 'OPEN',
    "priority" "SupportPriority" NOT NULL DEFAULT 'NORMAL',
    "assignedTo" TEXT,
    "metadata" JSONB,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "resolvedAt" TIMESTAMP(3),

    CONSTRAINT "SupportTicket_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "BugReport" (
    "id" TEXT NOT NULL,
    "userId" TEXT,
    "walletId" TEXT,
    "walletAddress" TEXT,
    "title" TEXT NOT NULL,
    "description" TEXT NOT NULL,
    "status" "BugReportStatus" NOT NULL DEFAULT 'NEW',
    "severity" "SupportPriority" NOT NULL DEFAULT 'NORMAL',
    "environment" JSONB,
    "steps" TEXT,
    "assignedTo" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "resolvedAt" TIMESTAMP(3),

    CONSTRAINT "BugReport_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "TicketPurchase" (
    "id" TEXT NOT NULL,
    "roundId" BIGINT NOT NULL,
    "buyer" TEXT NOT NULL,
    "quantity" INTEGER NOT NULL,
    "startInclusive" INTEGER NOT NULL,
    "endExclusive" INTEGER NOT NULL,
    "blobbyPaid" DECIMAL(78,0) NOT NULL,
    "jackpotContribution" DECIMAL(78,0) NOT NULL,
    "txHash" TEXT NOT NULL,
    "logIndex" INTEGER NOT NULL,
    "blockNumber" BIGINT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "TicketPurchase_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "DrawTopUp" (
    "id" TEXT NOT NULL,
    "roundId" BIGINT NOT NULL,
    "payer" TEXT NOT NULL,
    "amount" DECIMAL(78,0) NOT NULL,
    "txHash" TEXT NOT NULL,
    "logIndex" INTEGER NOT NULL,
    "blockNumber" BIGINT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "DrawTopUp_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ChainEvent" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "txHash" TEXT NOT NULL,
    "logIndex" INTEGER NOT NULL,
    "blockNumber" BIGINT NOT NULL,
    "payload" JSONB NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ChainEvent_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "AppConfig" (
    "key" TEXT NOT NULL,
    "value" JSONB NOT NULL,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "AppConfig_pkey" PRIMARY KEY ("key")
);

-- CreateTable
CREATE TABLE "AdminAuditLog" (
    "id" TEXT NOT NULL,
    "action" TEXT NOT NULL,
    "actor" TEXT NOT NULL,
    "payload" JSONB NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "AdminAuditLog_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "User_email_key" ON "User"("email");

-- CreateIndex
CREATE UNIQUE INDEX "User_username_key" ON "User"("username");

-- CreateIndex
CREATE INDEX "User_status_idx" ON "User"("status");

-- CreateIndex
CREATE INDEX "User_reviewStatus_idx" ON "User"("reviewStatus");

-- CreateIndex
CREATE INDEX "User_fraudExcluded_idx" ON "User"("fraudExcluded");

-- CreateIndex
CREATE INDEX "User_createdAt_idx" ON "User"("createdAt");

-- CreateIndex
CREATE INDEX "Wallet_userId_idx" ON "Wallet"("userId");

-- CreateIndex
CREATE INDEX "Wallet_status_idx" ON "Wallet"("status");

-- CreateIndex
CREATE INDEX "Wallet_fraudExcluded_idx" ON "Wallet"("fraudExcluded");

-- CreateIndex
CREATE INDEX "Wallet_address_idx" ON "Wallet"("address");

-- CreateIndex
CREATE UNIQUE INDEX "Wallet_chainId_address_key" ON "Wallet"("chainId", "address");

-- CreateIndex
CREATE UNIQUE INDEX "Profile_userId_key" ON "Profile"("userId");

-- CreateIndex
CREATE INDEX "DrawRound_status_idx" ON "DrawRound"("status");

-- CreateIndex
CREATE INDEX "DrawRound_openedAt_idx" ON "DrawRound"("openedAt");

-- CreateIndex
CREATE INDEX "DrawRound_expiresAt_idx" ON "DrawRound"("expiresAt");

-- CreateIndex
CREATE INDEX "DrawRound_txHash_idx" ON "DrawRound"("txHash");

-- CreateIndex
CREATE INDEX "DrawRound_blockNumber_idx" ON "DrawRound"("blockNumber");

-- CreateIndex
CREATE UNIQUE INDEX "DrawRound_chainId_contractAddress_id_key" ON "DrawRound"("chainId", "contractAddress", "id");

-- CreateIndex
CREATE INDEX "DrawEntry_roundId_idx" ON "DrawEntry"("roundId");

-- CreateIndex
CREATE INDEX "DrawEntry_walletId_idx" ON "DrawEntry"("walletId");

-- CreateIndex
CREATE INDEX "DrawEntry_walletAddress_idx" ON "DrawEntry"("walletAddress");

-- CreateIndex
CREATE INDEX "DrawEntry_source_idx" ON "DrawEntry"("source");

-- CreateIndex
CREATE INDEX "DrawEntry_status_idx" ON "DrawEntry"("status");

-- CreateIndex
CREATE INDEX "DrawEntry_blockNumber_idx" ON "DrawEntry"("blockNumber");

-- CreateIndex
CREATE UNIQUE INDEX "DrawEntry_chainId_txHash_logIndex_key" ON "DrawEntry"("chainId", "txHash", "logIndex");

-- CreateIndex
CREATE INDEX "DrawWinner_walletId_idx" ON "DrawWinner"("walletId");

-- CreateIndex
CREATE INDEX "DrawWinner_walletAddress_idx" ON "DrawWinner"("walletAddress");

-- CreateIndex
CREATE INDEX "DrawWinner_winner_idx" ON "DrawWinner"("winner");

-- CreateIndex
CREATE INDEX "DrawWinner_tier_idx" ON "DrawWinner"("tier");

-- CreateIndex
CREATE INDEX "DrawWinner_prizeType_idx" ON "DrawWinner"("prizeType");

-- CreateIndex
CREATE INDEX "DrawWinner_blockNumber_idx" ON "DrawWinner"("blockNumber");

-- CreateIndex
CREATE UNIQUE INDEX "DrawWinner_roundId_slot_key" ON "DrawWinner"("roundId", "slot");

-- CreateIndex
CREATE UNIQUE INDEX "DrawWinner_roundId_walletAddress_key" ON "DrawWinner"("roundId", "walletAddress");

-- CreateIndex
CREATE UNIQUE INDEX "DrawWinner_txHash_logIndex_prizeType_key" ON "DrawWinner"("txHash", "logIndex", "prizeType");

-- CreateIndex
CREATE UNIQUE INDEX "DrawWinner_txHash_logIndex_tier_key" ON "DrawWinner"("txHash", "logIndex", "tier");

-- CreateIndex
CREATE INDEX "DrawPrizeConfig_isActive_idx" ON "DrawPrizeConfig"("isActive");

-- CreateIndex
CREATE INDEX "DrawPrizeConfig_tier_idx" ON "DrawPrizeConfig"("tier");

-- CreateIndex
CREATE INDEX "DrawPrizeConfig_effectiveFrom_idx" ON "DrawPrizeConfig"("effectiveFrom");

-- CreateIndex
CREATE INDEX "DrawSettlement_roundId_idx" ON "DrawSettlement"("roundId");

-- CreateIndex
CREATE INDEX "DrawSettlement_status_idx" ON "DrawSettlement"("status");

-- CreateIndex
CREATE INDEX "DrawSettlement_vrfRequestId_idx" ON "DrawSettlement"("vrfRequestId");

-- CreateIndex
CREATE INDEX "DrawSettlement_blockNumber_idx" ON "DrawSettlement"("blockNumber");

-- CreateIndex
CREATE INDEX "JackpotCycle_status_idx" ON "JackpotCycle"("status");

-- CreateIndex
CREATE INDEX "JackpotCycle_startedAt_idx" ON "JackpotCycle"("startedAt");

-- CreateIndex
CREATE INDEX "JackpotCycle_vrfRequestId_idx" ON "JackpotCycle"("vrfRequestId");

-- CreateIndex
CREATE INDEX "JackpotCycle_blockNumber_idx" ON "JackpotCycle"("blockNumber");

-- CreateIndex
CREATE UNIQUE INDEX "JackpotCycle_chainId_contractAddress_id_key" ON "JackpotCycle"("chainId", "contractAddress", "id");

-- CreateIndex
CREATE INDEX "JackpotEntry_cycleId_idx" ON "JackpotEntry"("cycleId");

-- CreateIndex
CREATE INDEX "JackpotEntry_walletId_idx" ON "JackpotEntry"("walletId");

-- CreateIndex
CREATE INDEX "JackpotEntry_walletAddress_idx" ON "JackpotEntry"("walletAddress");

-- CreateIndex
CREATE INDEX "JackpotEntry_source_idx" ON "JackpotEntry"("source");

-- CreateIndex
CREATE INDEX "JackpotEntry_eligible_idx" ON "JackpotEntry"("eligible");

-- CreateIndex
CREATE UNIQUE INDEX "JackpotEntry_txHash_logIndex_key" ON "JackpotEntry"("txHash", "logIndex");

-- CreateIndex
CREATE INDEX "JackpotContribution_cycleId_idx" ON "JackpotContribution"("cycleId");

-- CreateIndex
CREATE INDEX "JackpotContribution_drawRoundId_idx" ON "JackpotContribution"("drawRoundId");

-- CreateIndex
CREATE INDEX "JackpotContribution_blockNumber_idx" ON "JackpotContribution"("blockNumber");

-- CreateIndex
CREATE UNIQUE INDEX "JackpotContribution_chainId_txHash_logIndex_key" ON "JackpotContribution"("chainId", "txHash", "logIndex");

-- CreateIndex
CREATE UNIQUE INDEX "JackpotWinner_cycleId_key" ON "JackpotWinner"("cycleId");

-- CreateIndex
CREATE INDEX "JackpotWinner_walletId_idx" ON "JackpotWinner"("walletId");

-- CreateIndex
CREATE INDEX "JackpotWinner_walletAddress_idx" ON "JackpotWinner"("walletAddress");

-- CreateIndex
CREATE INDEX "JackpotWinner_blockNumber_idx" ON "JackpotWinner"("blockNumber");

-- CreateIndex
CREATE UNIQUE INDEX "JackpotWinner_txHash_logIndex_key" ON "JackpotWinner"("txHash", "logIndex");

-- CreateIndex
CREATE INDEX "RewardLedgerEntry_userId_idx" ON "RewardLedgerEntry"("userId");

-- CreateIndex
CREATE INDEX "RewardLedgerEntry_walletId_idx" ON "RewardLedgerEntry"("walletId");

-- CreateIndex
CREATE INDEX "RewardLedgerEntry_type_idx" ON "RewardLedgerEntry"("type");

-- CreateIndex
CREATE INDEX "RewardLedgerEntry_status_idx" ON "RewardLedgerEntry"("status");

-- CreateIndex
CREATE INDEX "RewardLedgerEntry_referenceType_referenceId_idx" ON "RewardLedgerEntry"("referenceType", "referenceId");

-- CreateIndex
CREATE INDEX "RewardLedgerEntry_txHash_idx" ON "RewardLedgerEntry"("txHash");

-- CreateIndex
CREATE UNIQUE INDEX "ReferralCode_code_key" ON "ReferralCode"("code");

-- CreateIndex
CREATE INDEX "ReferralCode_userId_idx" ON "ReferralCode"("userId");

-- CreateIndex
CREATE INDEX "ReferralCode_walletId_idx" ON "ReferralCode"("walletId");

-- CreateIndex
CREATE INDEX "ReferralCode_isActive_idx" ON "ReferralCode"("isActive");

-- CreateIndex
CREATE INDEX "ReferralBinding_referredUserId_idx" ON "ReferralBinding"("referredUserId");

-- CreateIndex
CREATE INDEX "ReferralBinding_referrerUserId_idx" ON "ReferralBinding"("referrerUserId");

-- CreateIndex
CREATE INDEX "ReferralBinding_status_idx" ON "ReferralBinding"("status");

-- CreateIndex
CREATE UNIQUE INDEX "ReferralBinding_referralCodeId_referredWalletAddress_key" ON "ReferralBinding"("referralCodeId", "referredWalletAddress");

-- CreateIndex
CREATE INDEX "ReferralReward_referralCodeId_idx" ON "ReferralReward"("referralCodeId");

-- CreateIndex
CREATE INDEX "ReferralReward_userId_idx" ON "ReferralReward"("userId");

-- CreateIndex
CREATE INDEX "ReferralReward_walletId_idx" ON "ReferralReward"("walletId");

-- CreateIndex
CREATE INDEX "ReferralReward_status_idx" ON "ReferralReward"("status");

-- CreateIndex
CREATE INDEX "ReferralReward_txHash_idx" ON "ReferralReward"("txHash");

-- CreateIndex
CREATE UNIQUE INDEX "Task_slug_key" ON "Task"("slug");

-- CreateIndex
CREATE INDEX "Task_status_idx" ON "Task"("status");

-- CreateIndex
CREATE INDEX "Task_startsAt_idx" ON "Task"("startsAt");

-- CreateIndex
CREATE INDEX "Task_endsAt_idx" ON "Task"("endsAt");

-- CreateIndex
CREATE INDEX "TaskClaim_userId_idx" ON "TaskClaim"("userId");

-- CreateIndex
CREATE INDEX "TaskClaim_walletId_idx" ON "TaskClaim"("walletId");

-- CreateIndex
CREATE INDEX "TaskClaim_status_idx" ON "TaskClaim"("status");

-- CreateIndex
CREATE INDEX "TaskClaim_reviewStatus_idx" ON "TaskClaim"("reviewStatus");

-- CreateIndex
CREATE UNIQUE INDEX "TaskClaim_taskId_walletAddress_key" ON "TaskClaim"("taskId", "walletAddress");

-- CreateIndex
CREATE INDEX "TaskVerificationLog_taskClaimId_idx" ON "TaskVerificationLog"("taskClaimId");

-- CreateIndex
CREATE INDEX "TaskVerificationLog_userId_idx" ON "TaskVerificationLog"("userId");

-- CreateIndex
CREATE INDEX "TaskVerificationLog_result_idx" ON "TaskVerificationLog"("result");

-- CreateIndex
CREATE INDEX "FraudSignal_type_idx" ON "FraudSignal"("type");

-- CreateIndex
CREATE INDEX "FraudSignal_severity_idx" ON "FraudSignal"("severity");

-- CreateIndex
CREATE INDEX "FraudSignal_userId_idx" ON "FraudSignal"("userId");

-- CreateIndex
CREATE INDEX "FraudSignal_walletId_idx" ON "FraudSignal"("walletId");

-- CreateIndex
CREATE INDEX "FraudSignal_walletAddress_idx" ON "FraudSignal"("walletAddress");

-- CreateIndex
CREATE INDEX "FraudSignal_reviewed_idx" ON "FraudSignal"("reviewed");

-- CreateIndex
CREATE INDEX "FraudCase_status_idx" ON "FraudCase"("status");

-- CreateIndex
CREATE INDEX "FraudCase_userId_idx" ON "FraudCase"("userId");

-- CreateIndex
CREATE INDEX "FraudCase_walletId_idx" ON "FraudCase"("walletId");

-- CreateIndex
CREATE INDEX "FraudCase_walletAddress_idx" ON "FraudCase"("walletAddress");

-- CreateIndex
CREATE INDEX "FraudCase_riskScore_idx" ON "FraudCase"("riskScore");

-- CreateIndex
CREATE INDEX "ContractEvent_chainId_contractAddress_idx" ON "ContractEvent"("chainId", "contractAddress");

-- CreateIndex
CREATE INDEX "ContractEvent_eventName_idx" ON "ContractEvent"("eventName");

-- CreateIndex
CREATE INDEX "ContractEvent_blockNumber_idx" ON "ContractEvent"("blockNumber");

-- CreateIndex
CREATE INDEX "ContractEvent_status_idx" ON "ContractEvent"("status");

-- CreateIndex
CREATE UNIQUE INDEX "ContractEvent_chainId_txHash_logIndex_key" ON "ContractEvent"("chainId", "txHash", "logIndex");

-- CreateIndex
CREATE INDEX "ContractSyncCursor_lastBlockNumber_idx" ON "ContractSyncCursor"("lastBlockNumber");

-- CreateIndex
CREATE UNIQUE INDEX "ContractSyncCursor_chainId_contractAddress_cursorName_key" ON "ContractSyncCursor"("chainId", "contractAddress", "cursorName");

-- CreateIndex
CREATE INDEX "AdminActionLog_actorUserId_idx" ON "AdminActionLog"("actorUserId");

-- CreateIndex
CREATE INDEX "AdminActionLog_actorWallet_idx" ON "AdminActionLog"("actorWallet");

-- CreateIndex
CREATE INDEX "AdminActionLog_action_idx" ON "AdminActionLog"("action");

-- CreateIndex
CREATE INDEX "AdminActionLog_targetType_targetId_idx" ON "AdminActionLog"("targetType", "targetId");

-- CreateIndex
CREATE INDEX "AdminActionLog_createdAt_idx" ON "AdminActionLog"("createdAt");

-- CreateIndex
CREATE INDEX "PriceSnapshot_chainId_oracleAddress_idx" ON "PriceSnapshot"("chainId", "oracleAddress");

-- CreateIndex
CREATE INDEX "PriceSnapshot_tokenAddress_idx" ON "PriceSnapshot"("tokenAddress");

-- CreateIndex
CREATE INDEX "PriceSnapshot_drawRoundId_idx" ON "PriceSnapshot"("drawRoundId");

-- CreateIndex
CREATE INDEX "PriceSnapshot_blockNumber_idx" ON "PriceSnapshot"("blockNumber");

-- CreateIndex
CREATE INDEX "PriceSnapshot_observedAt_idx" ON "PriceSnapshot"("observedAt");

-- CreateIndex
CREATE INDEX "OracleHealthCheck_chainId_oracleAddress_idx" ON "OracleHealthCheck"("chainId", "oracleAddress");

-- CreateIndex
CREATE INDEX "OracleHealthCheck_status_idx" ON "OracleHealthCheck"("status");

-- CreateIndex
CREATE INDEX "OracleHealthCheck_checkedAt_idx" ON "OracleHealthCheck"("checkedAt");

-- CreateIndex
CREATE INDEX "SupportTicket_userId_idx" ON "SupportTicket"("userId");

-- CreateIndex
CREATE INDEX "SupportTicket_walletId_idx" ON "SupportTicket"("walletId");

-- CreateIndex
CREATE INDEX "SupportTicket_status_idx" ON "SupportTicket"("status");

-- CreateIndex
CREATE INDEX "SupportTicket_priority_idx" ON "SupportTicket"("priority");

-- CreateIndex
CREATE INDEX "SupportTicket_createdAt_idx" ON "SupportTicket"("createdAt");

-- CreateIndex
CREATE INDEX "BugReport_userId_idx" ON "BugReport"("userId");

-- CreateIndex
CREATE INDEX "BugReport_walletId_idx" ON "BugReport"("walletId");

-- CreateIndex
CREATE INDEX "BugReport_status_idx" ON "BugReport"("status");

-- CreateIndex
CREATE INDEX "BugReport_severity_idx" ON "BugReport"("severity");

-- CreateIndex
CREATE INDEX "BugReport_createdAt_idx" ON "BugReport"("createdAt");

-- CreateIndex
CREATE INDEX "TicketPurchase_roundId_idx" ON "TicketPurchase"("roundId");

-- CreateIndex
CREATE INDEX "TicketPurchase_buyer_idx" ON "TicketPurchase"("buyer");

-- CreateIndex
CREATE UNIQUE INDEX "TicketPurchase_txHash_logIndex_key" ON "TicketPurchase"("txHash", "logIndex");

-- CreateIndex
CREATE INDEX "DrawTopUp_roundId_idx" ON "DrawTopUp"("roundId");

-- CreateIndex
CREATE UNIQUE INDEX "DrawTopUp_txHash_logIndex_key" ON "DrawTopUp"("txHash", "logIndex");

-- CreateIndex
CREATE INDEX "ChainEvent_name_idx" ON "ChainEvent"("name");

-- CreateIndex
CREATE INDEX "ChainEvent_blockNumber_idx" ON "ChainEvent"("blockNumber");

-- CreateIndex
CREATE UNIQUE INDEX "ChainEvent_txHash_logIndex_key" ON "ChainEvent"("txHash", "logIndex");

-- AddForeignKey
ALTER TABLE "Wallet" ADD CONSTRAINT "Wallet_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Profile" ADD CONSTRAINT "Profile_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "DrawEntry" ADD CONSTRAINT "DrawEntry_roundId_fkey" FOREIGN KEY ("roundId") REFERENCES "DrawRound"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "DrawEntry" ADD CONSTRAINT "DrawEntry_walletId_fkey" FOREIGN KEY ("walletId") REFERENCES "Wallet"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "DrawWinner" ADD CONSTRAINT "DrawWinner_roundId_fkey" FOREIGN KEY ("roundId") REFERENCES "DrawRound"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "DrawWinner" ADD CONSTRAINT "DrawWinner_walletId_fkey" FOREIGN KEY ("walletId") REFERENCES "Wallet"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "DrawSettlement" ADD CONSTRAINT "DrawSettlement_roundId_fkey" FOREIGN KEY ("roundId") REFERENCES "DrawRound"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "JackpotEntry" ADD CONSTRAINT "JackpotEntry_cycleId_fkey" FOREIGN KEY ("cycleId") REFERENCES "JackpotCycle"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "JackpotEntry" ADD CONSTRAINT "JackpotEntry_walletId_fkey" FOREIGN KEY ("walletId") REFERENCES "Wallet"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "JackpotContribution" ADD CONSTRAINT "JackpotContribution_cycleId_fkey" FOREIGN KEY ("cycleId") REFERENCES "JackpotCycle"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "JackpotWinner" ADD CONSTRAINT "JackpotWinner_cycleId_fkey" FOREIGN KEY ("cycleId") REFERENCES "JackpotCycle"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "JackpotWinner" ADD CONSTRAINT "JackpotWinner_walletId_fkey" FOREIGN KEY ("walletId") REFERENCES "Wallet"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "RewardLedgerEntry" ADD CONSTRAINT "RewardLedgerEntry_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "RewardLedgerEntry" ADD CONSTRAINT "RewardLedgerEntry_walletId_fkey" FOREIGN KEY ("walletId") REFERENCES "Wallet"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ReferralCode" ADD CONSTRAINT "ReferralCode_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ReferralCode" ADD CONSTRAINT "ReferralCode_walletId_fkey" FOREIGN KEY ("walletId") REFERENCES "Wallet"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ReferralBinding" ADD CONSTRAINT "ReferralBinding_referralCodeId_fkey" FOREIGN KEY ("referralCodeId") REFERENCES "ReferralCode"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ReferralBinding" ADD CONSTRAINT "ReferralBinding_referredUserId_fkey" FOREIGN KEY ("referredUserId") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ReferralBinding" ADD CONSTRAINT "ReferralBinding_referrerUserId_fkey" FOREIGN KEY ("referrerUserId") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ReferralReward" ADD CONSTRAINT "ReferralReward_referralCodeId_fkey" FOREIGN KEY ("referralCodeId") REFERENCES "ReferralCode"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ReferralReward" ADD CONSTRAINT "ReferralReward_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ReferralReward" ADD CONSTRAINT "ReferralReward_walletId_fkey" FOREIGN KEY ("walletId") REFERENCES "Wallet"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "TaskClaim" ADD CONSTRAINT "TaskClaim_taskId_fkey" FOREIGN KEY ("taskId") REFERENCES "Task"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "TaskClaim" ADD CONSTRAINT "TaskClaim_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "TaskClaim" ADD CONSTRAINT "TaskClaim_walletId_fkey" FOREIGN KEY ("walletId") REFERENCES "Wallet"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "TaskVerificationLog" ADD CONSTRAINT "TaskVerificationLog_taskClaimId_fkey" FOREIGN KEY ("taskClaimId") REFERENCES "TaskClaim"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "TaskVerificationLog" ADD CONSTRAINT "TaskVerificationLog_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "FraudSignal" ADD CONSTRAINT "FraudSignal_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "FraudSignal" ADD CONSTRAINT "FraudSignal_walletId_fkey" FOREIGN KEY ("walletId") REFERENCES "Wallet"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "FraudCase" ADD CONSTRAINT "FraudCase_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "FraudCase" ADD CONSTRAINT "FraudCase_walletId_fkey" FOREIGN KEY ("walletId") REFERENCES "Wallet"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "PriceSnapshot" ADD CONSTRAINT "PriceSnapshot_drawRoundId_fkey" FOREIGN KEY ("drawRoundId") REFERENCES "DrawRound"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "SupportTicket" ADD CONSTRAINT "SupportTicket_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "SupportTicket" ADD CONSTRAINT "SupportTicket_walletId_fkey" FOREIGN KEY ("walletId") REFERENCES "Wallet"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "BugReport" ADD CONSTRAINT "BugReport_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "BugReport" ADD CONSTRAINT "BugReport_walletId_fkey" FOREIGN KEY ("walletId") REFERENCES "Wallet"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "TicketPurchase" ADD CONSTRAINT "TicketPurchase_roundId_fkey" FOREIGN KEY ("roundId") REFERENCES "DrawRound"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "DrawTopUp" ADD CONSTRAINT "DrawTopUp_roundId_fkey" FOREIGN KEY ("roundId") REFERENCES "DrawRound"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

