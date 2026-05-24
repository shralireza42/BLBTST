"use client";
import { useAccount, useReadContract, useWaitForTransactionReceipt, useWriteContract } from "wagmi";
import { addresses } from "../contracts/addresses";
import { dailyDrawAbi, erc20Abi, jackpotVaultAbi, priceAdapterAbi } from "../contracts/abis";

const asAddress = (value: string) => value as `0x${string}`;

export function useBlobbieBalance() {
  const { address } = useAccount();
  return useReadContract({ address: asAddress(addresses.blobbyToken), abi: erc20Abi, functionName: "balanceOf", args: address ? [address] : undefined, query: { enabled: Boolean(address) } });
}

export function useBlobbieAllowance() {
  const { address } = useAccount();
  return useReadContract({ address: asAddress(addresses.blobbyToken), abi: erc20Abi, functionName: "allowance", args: address ? [address, asAddress(addresses.dailyDraw)] : undefined, query: { enabled: Boolean(address) } });
}

export function useApproveBlobbie() {
  const write = useWriteContract();
  const receipt = useWaitForTransactionReceipt({ hash: write.data });
  return {
    data: write.data,
    error: write.error,
    isPending: write.isPending,
    receipt,
    approve: (amount: bigint) =>
      write.writeContract({
        address: asAddress(addresses.blobbyToken),
        abi: erc20Abi,
        functionName: "approve",
        args: [asAddress(addresses.dailyDraw), amount]
      })
  };
}

export function useBuyTickets() {
  const write = useWriteContract();
  const receipt = useWaitForTransactionReceipt({ hash: write.data });
  return {
    data: write.data,
    error: write.error,
    isPending: write.isPending,
    receipt,
    buy: (quantity: number, maxBlobbieCost: bigint) =>
      write.writeContract({
        address: asAddress(addresses.dailyDraw),
        abi: dailyDrawAbi,
        functionName: "buyTickets",
        args: [BigInt(quantity), maxBlobbieCost]
      })
  };
}

export function useCurrentDrawContractState() {
  const roundId = useReadContract({ address: asAddress(addresses.dailyDraw), abi: dailyDrawAbi, functionName: "currentRoundId" });
  const round = useReadContract({ address: asAddress(addresses.dailyDraw), abi: dailyDrawAbi, functionName: "getRound", args: roundId.data ? [roundId.data] : undefined, query: { enabled: Boolean(roundId.data) } });
  return { roundId, round };
}

export function useMyTickets() {
  return { data: [], isLoading: false };
}

export function useJackpotReserve() {
  return useReadContract({ address: asAddress(addresses.jackpotVault), abi: jackpotVaultAbi, functionName: "reserve" });
}

export function useJackpotCycle() {
  const cycleId = useReadContract({ address: asAddress(addresses.jackpotVault), abi: jackpotVaultAbi, functionName: "currentCycleId" });
  const cycle = useReadContract({ address: asAddress(addresses.jackpotVault), abi: jackpotVaultAbi, functionName: "getCycle", args: cycleId.data ? [cycleId.data] : undefined, query: { enabled: Boolean(cycleId.data) } });
  return { cycleId, cycle };
}

export function useJackpotThreshold() {
  return useReadContract({ address: asAddress(addresses.jackpotVault), abi: jackpotVaultAbi, functionName: "jackpotThresholdInBlobbie" });
}

export function useBlobbieUsdPrice() {
  return useReadContract({ address: asAddress(addresses.priceAdapter), abi: priceAdapterAbi, functionName: "getBlobbieUsdPriceE18" });
}
