"use client";
import { useAccount, useChainId } from "wagmi";
import { isSupportedChainId, targetChain, targetChainId } from "../wagmi/chains";
import { shortAddress } from "../utils";
import { useProfile } from "./useBlobbyApi";

export function useWalletAccount() { return useAccount(); }
export function useWalletNetwork() { const chainId = useChainId(); return { chainId, targetChain, targetChainId, isSupported: isSupportedChainId(chainId) }; }
export function useIsCorrectNetwork() { const { chainId } = useWalletNetwork(); return chainId === targetChainId; }
export function useShortAddress(address?: string) { return shortAddress(address); }
export function useWalletDisplayName() { const { address } = useAccount(); const profile = useProfile(); const username = (profile.data as { nickname?: string } | undefined)?.nickname; return username || shortAddress(address); }
