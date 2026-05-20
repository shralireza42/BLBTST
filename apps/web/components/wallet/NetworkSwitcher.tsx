"use client";
import { useSwitchChain } from "wagmi";
import { Button } from "../ui/Button";
import { Badge } from "../ui/Badge";
import { targetChain, targetChainId } from "../../lib/wagmi/chains";
import { useIsCorrectNetwork, useWalletNetwork } from "../../lib/hooks/useWallet";

export function NetworkSwitcher() {
  const { switchChain, isPending } = useSwitchChain();
  const { chainId } = useWalletNetwork();
  const correct = useIsCorrectNetwork();
  if (correct) return <Badge tone="green">BNB Chain</Badge>;
  return <div className="rounded-2xl border-2 border-[#020202] bg-[#bc352a] p-3 text-white"><p className="text-sm">Wrong network: {chainId ?? "unknown"}. Please switch to {targetChain.name}.</p><Button className="mt-2" onClick={() => switchChain({ chainId: targetChainId })} disabled={isPending}>Switch to BNB Chain</Button></div>;
}
