"use client";
import { useAccount } from "wagmi";
import { Card } from "../ui/Card";
import { NetworkSwitcher } from "./NetworkSwitcher";
import { useBlobbieBalance } from "../../lib/hooks/useContracts";
import { formatToken, shortAddress } from "../../lib/utils";

export function WalletStatus() {
  const { address, isConnected } = useAccount();
  const balance = useBlobbieBalance();
  return <Card><h3 className="display-text text-2xl">Wallet Status</h3>{isConnected ? <><p className="mt-2">{shortAddress(address)}</p><p>BLOBBIE balance: {typeof balance.data === "bigint" ? formatToken(balance.data.toString()) : "--"}</p><div className="mt-3"><NetworkSwitcher /></div></> : <p className="mt-2">Connect wallet to view profile, tickets, and rewards.</p>}</Card>;
}
