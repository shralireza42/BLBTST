import { createAppKit } from "@reown/appkit/react";
import { WagmiAdapter } from "@reown/appkit-adapter-wagmi";
import { cookieStorage, createConfig, createStorage, http } from "wagmi";
import { injected, walletConnect } from "wagmi/connectors";
import { mainnetChain, supportedChains, testnetChain } from "./chains";

const projectId = process.env.NEXT_PUBLIC_REOWN_PROJECT_ID || process.env.NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID || "";
const transports = {
  [mainnetChain.id]: http(process.env.NEXT_PUBLIC_BSC_RPC_URL),
  [testnetChain.id]: http(process.env.NEXT_PUBLIC_BSC_TESTNET_RPC_URL)
};

const connectors = projectId ? [injected(), walletConnect({ projectId })] : [injected()];

const wagmiAdapter = projectId
  ? new WagmiAdapter({
      networks: [...supportedChains] as any,
      projectId,
      ssr: true,
      storage: createStorage({ storage: cookieStorage }),
      transports,
      connectors
    } as any)
  : null;

export const wagmiConfig = wagmiAdapter?.wagmiConfig ?? createConfig({
  chains: supportedChains,
  connectors,
  transports,
  ssr: true,
  storage: createStorage({ storage: cookieStorage })
});

let appKitInitialized = false;
export function ensureAppKit() {
  if (!projectId || !wagmiAdapter || appKitInitialized || typeof window === "undefined") return;
  createAppKit({
    adapters: [wagmiAdapter],
    networks: [...supportedChains] as any,
    projectId,
    metadata: {
      name: "BLOBBIE",
      description: "BLOBBIE Daily Draw and Jackpot",
      url: window.location.origin,
      icons: [`${window.location.origin}/LOGO.png`]
    },
    features: { analytics: false }
  } as any);
  appKitInitialized = true;
}
