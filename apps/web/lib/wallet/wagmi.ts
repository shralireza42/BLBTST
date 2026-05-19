import { createConfig, http } from "wagmi";
import { bsc, bscTestnet } from "wagmi/chains";
import { injected, walletConnect } from "wagmi/connectors";
const projectId = process.env.NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID;
export const wagmiConfig = createConfig({
  chains: [bsc, bscTestnet],
  connectors: projectId ? [injected(), walletConnect({ projectId })] : [injected()],
  transports: { [bsc.id]: http(process.env.NEXT_PUBLIC_BSC_RPC_URL), [bscTestnet.id]: http() },
  ssr: true
});
