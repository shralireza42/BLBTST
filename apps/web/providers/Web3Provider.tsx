"use client";

import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { ReactNode, useEffect, useState } from "react";
import { WagmiProvider } from "wagmi";
import { ensureAppKit, wagmiConfig } from "../lib/wagmi/config";

export function Web3Provider({ children }: { children: ReactNode }) {
  const [queryClient] = useState(() => new QueryClient({ defaultOptions: { queries: { staleTime: 20_000, retry: 1 } } }));
  useEffect(() => ensureAppKit(), []);
  return <WagmiProvider config={wagmiConfig as any}><QueryClientProvider client={queryClient}>{children}</QueryClientProvider></WagmiProvider>;
}
