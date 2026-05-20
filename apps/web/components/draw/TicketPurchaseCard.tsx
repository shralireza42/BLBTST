"use client";

import { useMemo, useState } from "react";
import { useAccount } from "wagmi";
import { useQueryClient } from "@tanstack/react-query";
import { Button } from "../ui/Button";
import { Card } from "../ui/Card";
import { Input } from "../ui/Input";
import { Badge } from "../ui/Badge";
import { NetworkSwitcher } from "../wallet/NetworkSwitcher";
import { TransactionPhase, TransactionStatus } from "../wallet/TransactionStatus";
import { useTicketQuote } from "../../lib/hooks/useBlobbyApi";
import { useApproveBlobbie, useBlobbieAllowance, useBlobbieBalance, useBuyTickets } from "../../lib/hooks/useContracts";
import { useIsCorrectNetwork } from "../../lib/hooks/useWallet";
import { formatToken } from "../../lib/utils";

export function TicketPurchaseCard() {
  const [qty, setQty] = useState(1);
  const [error, setError] = useState<string>();
  const { address } = useAccount();
  const queryClient = useQueryClient();
  const correctNetwork = useIsCorrectNetwork();
  const quote = useTicketQuote(qty);
  const balance = useBlobbieBalance();
  const allowance = useBlobbieAllowance();
  const approve = useApproveBlobbie();
  const buy = useBuyTickets();

  const quotedCost = useMemo(() => {
    const raw = (quote.data as { blobbieAmount?: string } | undefined)?.blobbieAmount;
    try { return raw ? BigInt(raw) : 0n; } catch { return 0n; }
  }, [quote.data]);
  const hasBalance = typeof balance.data === "bigint" && balance.data >= quotedCost;
  const hasAllowance = typeof allowance.data === "bigint" && allowance.data >= quotedCost;

  const phase: TransactionPhase = !address
    ? "idle"
    : !correctNetwork
      ? "wrong_network"
      : quotedCost > 0n && !hasBalance
        ? "insufficient_balance"
        : quotedCost > 0n && !hasAllowance
          ? approve.isPending || approve.receipt.isLoading
            ? "pending_confirmation"
            : "insufficient_allowance"
          : buy.isPending
            ? "waiting_for_wallet"
            : buy.receipt.isLoading
              ? "pending_confirmation"
              : buy.receipt.isSuccess
                ? "success"
                : buy.error
                  ? "failed"
                  : "idle";

  async function handleApprove() {
    setError(undefined);
    try { approve.approve(quotedCost); }
    catch (err) { setError(err instanceof Error ? err.message : "Approval failed"); }
  }

  async function handleBuy() {
    setError(undefined);
    try {
      const refreshed = await queryClient.fetchQuery({ queryKey: ["draw", "quote", qty], queryFn: async () => quote.refetch().then((r) => r.data) });
      const maxCost = BigInt((refreshed as { blobbieAmount?: string } | undefined)?.blobbieAmount || quotedCost.toString());
      buy.buy(qty, maxCost);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Purchase failed");
    }
  }

  return <Card>
    <h2 className="display-text text-3xl">Buy Tickets</h2>
    <p className="mt-2">1 ticket = 1 USD worth of BLOBBIE. Quote refreshes before purchase for slippage protection.</p>
    <div className="mt-4 grid gap-3">
      <Input type="number" min={1} max={300} value={qty} onChange={(e) => setQty(Math.max(1, Math.min(300, Number(e.target.value) || 1)))} />
      <div className="rounded-2xl bg-white p-4 border-2 border-[#020202]"><p className="text-sm">Estimated cost</p><p className="display-text text-2xl">{formatToken(quotedCost.toString())} BLOBBIE</p></div>
      <div className="grid gap-2 text-sm"><p>Balance: {typeof balance.data === "bigint" ? formatToken(balance.data.toString()) : "--"}</p><p>Allowance: {typeof allowance.data === "bigint" ? formatToken(allowance.data.toString()) : "--"}</p></div>
      <Badge>{quote.isFetching ? "Refreshing price" : "Price ready"}</Badge>
      {address && !correctNetwork && <NetworkSwitcher />}
      <TransactionStatus phase={phase} error={error || buy.error?.message || approve.error?.message} />
      {!address && <Button disabled>Connect wallet to buy</Button>}
      {address && correctNetwork && quotedCost > 0n && !hasAllowance && <Button onClick={handleApprove} disabled={!hasBalance || approve.isPending || approve.receipt.isLoading}>Approve BLOBBIE</Button>}
      {address && correctNetwork && hasAllowance && <Button variant="secondary" onClick={handleBuy} disabled={!hasBalance || buy.isPending || buy.receipt.isLoading}>Buy Tickets</Button>}
      <p className="text-xs opacity-70">Transactions require explicit wallet confirmation. The frontend never performs settlement or claims by itself.</p>
    </div>
  </Card>;
}
