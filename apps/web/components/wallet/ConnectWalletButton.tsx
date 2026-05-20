"use client";
import { useAppKit } from "@reown/appkit/react";
import { useEffect, useState } from "react";
import { useAccount, useConnect, useDisconnect } from "wagmi";
import { Button } from "../ui/Button";
import { useWalletDisplayName } from "../../lib/hooks/useWallet";
import { ensureAppKit } from "../../lib/wagmi/config";

const reownEnabled = Boolean(process.env.NEXT_PUBLIC_REOWN_PROJECT_ID || process.env.NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID);

export function ConnectWalletButton() {
  const [mounted, setMounted] = useState(false);
  useEffect(() => setMounted(true), []);
  if (reownEnabled && mounted) return <ReownWalletButton />;
  return <WagmiWalletButton />;
}

function ReownWalletButton() {
  ensureAppKit();
  const appKit = useAppKit();
  const { address, isConnected, isConnecting } = useAccount();
  const displayName = useWalletDisplayName();
  return <Button variant="primary" onClick={() => appKit.open({ view: isConnected ? "Account" : "Connect" })}>{isConnecting ? "Connecting..." : isConnected && address ? displayName : "Connect Wallet"}</Button>;
}

function WagmiWalletButton() {
  const { address, isConnected } = useAccount();
  const { connectors, connect, isPending } = useConnect();
  const { disconnect } = useDisconnect();
  const displayName = useWalletDisplayName();
  if (isConnected && address) return <Button variant="primary" onClick={() => disconnect()}>{displayName}</Button>;
  return <Button variant="primary" onClick={() => connectors[0] && connect({ connector: connectors[0] })} disabled={isPending}>{isPending ? "Connecting..." : "Connect Wallet"}</Button>;
}
