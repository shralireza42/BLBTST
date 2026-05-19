import { Injectable, NotFoundException } from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import { PrismaService } from "../../common/prisma/prisma.service.js";
import { serializeForJson } from "../../common/utils/serialize.js";

@Injectable()
export class PublicVerifyService {
  constructor(private readonly prisma: PrismaService, private readonly config: ConfigService) {}

  async round(roundId: string) {
    const id = BigInt(roundId);
    const round = await this.prisma.client.drawRound.findUnique({ where: { id } });
    if (!round) throw new NotFoundException("Round not found");

    const [entries, winners, settlements, topUps, events, priceSnapshots] = await Promise.all([
      this.prisma.client.drawEntry.findMany({ where: { roundId: id }, orderBy: [{ startInclusive: "asc" }, { createdAt: "asc" }] }),
      this.prisma.client.drawWinner.findMany({ where: { roundId: id }, orderBy: [{ slot: "asc" }, { createdAt: "asc" }] }),
      this.prisma.client.drawSettlement.findMany({ where: { roundId: id }, orderBy: { createdAt: "asc" } }),
      this.prisma.client.drawTopUp.findMany({ where: { roundId: id }, orderBy: [{ blockNumber: "asc" }, { logIndex: "asc" }] }),
      this.eventsForRound(id),
      this.prisma.client.priceSnapshot.findMany({ where: { drawRoundId: id }, orderBy: { observedAt: "asc" } })
    ]);

    const closeTrigger = inferCloseTrigger(round, events);
    const vrfRequested = events.find((event) => event.eventName === "RandomnessRequested");
    const vrfFulfilled = events.find((event) => event.eventName === "RandomnessFulfilled");

    const response = {
      kind: "daily-draw-round-audit",
      round: {
        id: round.id,
        status: round.status,
        openTime: round.openedAt,
        closeTime: round.closedAt,
        finalizedAt: round.finalizedAt,
        closeTrigger,
        ticketCount: round.totalEntryCount || round.eligibleTicketCount,
        uniqueWalletCount: round.uniqueWalletCount,
        eligibleTicketCount: round.eligibleTicketCount,
        operationalTopUpAmount: round.operationalTopUp,
        reviewStatus: round.reviewStatus,
        reviewReason: round.reviewReason
      },
      prizePoolComposition: {
        grossTicketRevenue: round.grossTicketRevenue,
        operationalTopUp: round.operationalTopUp,
        prizePoolRemaining: round.prizePool,
        dailyPrizePaid: round.dailyPrizePaid,
        jackpotContribution: round.jackpotContribution,
        jackpotAllocation: round.jackpotContribution,
        freeEntryReserveAllocation: round.freeEntryReserve,
        burnTreasuryAllocation: round.burnTreasuryReserve,
        topUps
      },
      vrf: {
        requestId: round.vrfRequestId,
        randomness: round.randomness,
        requestEvent: vrfRequested ? eventSummary(vrfRequested, this.explorerBase()) : null,
        fulfillmentEvent: vrfFulfilled ? eventSummary(vrfFulfilled, this.explorerBase()) : null,
        fulfillmentTransaction: round.settlementTxHash || vrfFulfilled?.txHash || null,
        proofData: {
          source: "Chainlink VRF event projection",
          requestPayload: vrfRequested?.payload ?? null,
          fulfillmentPayload: vrfFulfilled?.payload ?? null
        }
      },
      winnerDerivation: {
        explanation:
          "Eligible paid ticket ranges are ordered by purchase event. The VRF randomness is mixed with each prize slot index; the resulting ticket index maps to an eligible ticket range. Wallets already selected in the same round are skipped, so a wallet can win at most once. If no unused eligible wallet remains, the slot is unawarded.",
        eligibleEntries: entries.filter((entry) => entry.status === "ELIGIBLE" && entry.eligibleQuantity > 0).map((entry) => ({
          walletAddress: entry.walletAddress,
          quantity: entry.quantity,
          eligibleQuantity: entry.eligibleQuantity,
          startInclusive: entry.startInclusive,
          endExclusive: entry.endExclusive,
          txHash: entry.txHash,
          explorerUrl: this.txUrl(entry.txHash)
        }))
      },
      winners: winners.map((winner) => ({
        slot: winner.slot,
        tier: winner.tier,
        walletAddress: winner.walletAddress || winner.winner,
        amount: winner.amount,
        usdValueE18: winner.usdValueE18,
        paid: winner.paid,
        txHash: winner.txHash,
        explorerUrl: this.txUrl(winner.txHash)
      })),
      allocations: {
        jackpotAllocation: round.jackpotContribution,
        freeEntryReserveAllocation: round.freeEntryReserve,
        burnTreasuryAllocation: round.burnTreasuryReserve
      },
      settlements,
      priceSnapshots,
      explorerLinks: this.roundExplorerLinks(round, events),
      downloads: {
        json: `/verify/export/round/${round.id}.json`,
        csv: `/verify/export/round/${round.id}.csv`
      },
      rawEvents: events.map((event) => eventSummary(event, this.explorerBase()))
    };

    return serializeForJson(response);
  }

  async jackpot(cycleId: string) {
    const id = BigInt(cycleId);
    const cycle = await this.prisma.client.jackpotCycle.findUnique({ where: { id } });
    if (!cycle) throw new NotFoundException("Jackpot cycle not found");

    const [entries, contributions, winner, events] = await Promise.all([
      this.prisma.client.jackpotEntry.findMany({ where: { cycleId: id }, orderBy: [{ startInclusive: "asc" }, { createdAt: "asc" }] }),
      this.prisma.client.jackpotContribution.findMany({ where: { cycleId: id }, orderBy: [{ blockNumber: "asc" }, { logIndex: "asc" }] }),
      this.prisma.client.jackpotWinner.findUnique({ where: { cycleId: id } }),
      this.eventsForJackpotCycle(id)
    ]);

    const requestEvent = events.find((event) => event.eventName === "JackpotRandomnessRequested");
    const paidEvent = events.find((event) => event.eventName === "JackpotPaid");
    const triggerContribution = contributions[0];

    const response = {
      kind: "jackpot-cycle-audit",
      cycle: {
        id: cycle.id,
        status: cycle.status,
        reserveBalance: cycle.reserveBalance,
        thresholdUsdE18: cycle.thresholdUsdE18,
        thresholdBlobbie: cycle.thresholdBlobbie,
        eligibleEntries: cycle.eligibleTicketCount,
        cycleStart: cycle.startedAt,
        thresholdMetAt: cycle.thresholdMetAt,
        endedAt: cycle.endedAt,
        triggerRound: triggerContribution?.drawRoundId ?? null
      },
      vrf: {
        requestId: cycle.vrfRequestId,
        randomness: cycle.randomness,
        requestEvent: requestEvent ? eventSummary(requestEvent, this.explorerBase()) : null,
        proofData: requestEvent?.payload ?? null
      },
      entries: entries.map((entry) => ({
        walletAddress: entry.walletAddress,
        ticketCount: entry.ticketCount,
        startInclusive: entry.startInclusive,
        endExclusive: entry.endExclusive,
        source: entry.source,
        eligible: entry.eligible,
        exclusionReason: entry.exclusionReason,
        txHash: entry.txHash,
        explorerUrl: this.txUrl(entry.txHash)
      })),
      contributions: contributions.map((contribution) => ({
        drawRoundId: contribution.drawRoundId,
        amount: contribution.amount,
        source: contribution.source,
        txHash: contribution.txHash,
        explorerUrl: this.txUrl(contribution.txHash)
      })),
      winner: winner
        ? {
            walletAddress: winner.walletAddress,
            amount: winner.amount,
            paidAt: winner.paidAt,
            payoutTx: winner.txHash,
            explorerUrl: this.txUrl(winner.txHash)
          }
        : null,
      payoutTx: winner?.txHash || paidEvent?.txHash || cycle.settlementTxHash || null,
      explorerLinks: this.jackpotExplorerLinks(cycle, events),
      downloads: { json: `/verify/jackpot/${cycle.id}` },
      rawEvents: events.map((event) => eventSummary(event, this.explorerBase()))
    };

    return serializeForJson(response);
  }

  async roundCsv(roundId: string) {
    const data = (await this.round(roundId)) as {
      round: Record<string, unknown>;
      winnerDerivation: { eligibleEntries: Array<Record<string, unknown>> };
      winners: Array<Record<string, unknown>>;
      rawEvents: Array<Record<string, unknown>>;
    };
    const lines = ["section,walletAddress,quantity,startInclusive,endExclusive,slot,tier,amount,txHash,explorerUrl"];
    for (const entry of data.winnerDerivation.eligibleEntries) {
      lines.push([
        "entry",
        entry.walletAddress,
        entry.quantity,
        entry.startInclusive,
        entry.endExclusive,
        "",
        "",
        "",
        entry.txHash,
        entry.explorerUrl
      ].map(csv).join(","));
    }
    for (const winner of data.winners) {
      lines.push([
        "winner",
        winner.walletAddress,
        "",
        "",
        "",
        winner.slot,
        winner.tier,
        winner.amount,
        winner.txHash,
        winner.explorerUrl
      ].map(csv).join(","));
    }
    for (const event of data.rawEvents) {
      lines.push(["event", "", "", "", "", "", event.eventName, "", event.txHash, event.explorerUrl].map(csv).join(","));
    }
    return lines.join("\n");
  }

  private async eventsForRound(roundId: bigint) {
    return this.prisma.client.contractEvent.findMany({
      where: { payload: { path: ["roundId"], equals: roundId.toString() } },
      orderBy: [{ blockNumber: "asc" }, { logIndex: "asc" }]
    });
  }

  private async eventsForJackpotCycle(cycleId: bigint) {
    return this.prisma.client.contractEvent.findMany({
      where: { payload: { path: ["cycleId"], equals: cycleId.toString() } },
      orderBy: [{ blockNumber: "asc" }, { logIndex: "asc" }]
    });
  }

  private roundExplorerLinks(round: { txHash: string | null; closeTxHash: string | null; settlementTxHash: string | null; contractAddress: string | null }, events: Array<{ txHash: string; eventName: string }>) {
    return {
      contract: this.addressUrl(round.contractAddress),
      openTx: this.txUrl(round.txHash),
      closeTx: this.txUrl(round.closeTxHash),
      settlementTx: this.txUrl(round.settlementTxHash),
      eventTransactions: events.map((event) => ({ eventName: event.eventName, txHash: event.txHash, explorerUrl: this.txUrl(event.txHash) }))
    };
  }

  private jackpotExplorerLinks(cycle: { txHash: string | null; settlementTxHash: string | null; contractAddress: string | null }, events: Array<{ txHash: string; eventName: string }>) {
    return {
      contract: this.addressUrl(cycle.contractAddress),
      startTx: this.txUrl(cycle.txHash),
      payoutTx: this.txUrl(cycle.settlementTxHash),
      eventTransactions: events.map((event) => ({ eventName: event.eventName, txHash: event.txHash, explorerUrl: this.txUrl(event.txHash) }))
    };
  }

  private explorerBase() {
    return (this.config.get<string>("EXPLORER_BASE_URL") || "https://bscscan.com").replace(/\/$/, "");
  }

  private txUrl(txHash: string | null | undefined) {
    return txHash ? `${this.explorerBase()}/tx/${txHash}` : null;
  }

  private addressUrl(address: string | null | undefined) {
    return address ? `${this.explorerBase()}/address/${address}` : null;
  }
}

function inferCloseTrigger(round: { eligibleTicketCount: number; closedAt: Date | null; expiresAt: Date }, events: Array<{ eventName: string }>) {
  if (!round.closedAt) return null;
  if (round.eligibleTicketCount >= 300) return "TICKET_THRESHOLD";
  if (events.some((event) => event.eventName === "OperationalTopUpRequired" || event.eventName === "OperationalTopUpReceived")) return "TIMEOUT_WITH_TOP_UP";
  if (round.closedAt >= round.expiresAt) return "TIMEOUT";
  return "ADMIN_OR_UNKNOWN";
}

function eventSummary(event: { eventName: string; txHash: string; logIndex: number; blockNumber: bigint; payload: unknown }, explorerBase: string) {
  return {
    eventName: event.eventName,
    txHash: event.txHash,
    logIndex: event.logIndex,
    blockNumber: event.blockNumber,
    payload: event.payload,
    explorerUrl: `${explorerBase}/tx/${event.txHash}`
  };
}

function csv(value: unknown) {
  return `"${String(value ?? "").replaceAll('"', '""')}"`;
}
