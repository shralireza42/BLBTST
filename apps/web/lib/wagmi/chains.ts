import { bsc, bscTestnet } from "wagmi/chains";

export const mainnetChain = bsc;
export const testnetChain = bscTestnet;
export const developmentTestnetEnabled = process.env.NEXT_PUBLIC_ENABLE_TESTNET === "true" || process.env.NODE_ENV === "development";
export const supportedChains = developmentTestnetEnabled ? [mainnetChain, testnetChain] as const : [mainnetChain] as const;
export const targetChainId = Number(process.env.NEXT_PUBLIC_CHAIN_ID || mainnetChain.id);
export const targetChain = supportedChains.find((chain) => chain.id === targetChainId) || mainnetChain;
export const isSupportedChainId = (chainId?: number) => Boolean(chainId && supportedChains.some((chain) => chain.id === chainId));
