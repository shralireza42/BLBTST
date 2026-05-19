"use client";
import { useAccount, useConnect, useDisconnect } from "wagmi";
import { Button } from "./Button";
import { shortAddress } from "../../lib/utils";
export function WalletButton() { const { address, isConnected }=useAccount(); const { connectors, connect, isPending }=useConnect(); const { disconnect }=useDisconnect(); if(isConnected) return <Button variant="primary" onClick={()=>disconnect()}>{shortAddress(address)}</Button>; return <Button variant="primary" onClick={()=>connect({ connector: connectors[0] })} disabled={isPending}>Connect Wallet</Button>; }
