"use client";
import { useWriteContract } from "wagmi";
import { addresses } from "../contracts/addresses";
import { dailyDrawAbi } from "../contracts/abis";
export function useBuyTickets() { return useWriteContract(); }
export function buyTicketsRequest(quantity: number, maxBlobbieCost: bigint) { return { address: addresses.dailyDraw as `0x${string}`, abi: dailyDrawAbi, functionName: "buyTickets", args: [BigInt(quantity), maxBlobbieCost] as const }; }
