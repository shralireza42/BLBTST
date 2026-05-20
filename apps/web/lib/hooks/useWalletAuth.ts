"use client";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { useSignMessage } from "wagmi";

const API_BASE = process.env.NEXT_PUBLIC_API_BASE_URL || "http://localhost:3001";
const AUTH_MESSAGE_PREFIX = "Sign this message to authenticate with BLOBBIE. This does not cost gas.";

export function useWalletLogin() {
  const { signMessageAsync } = useSignMessage();
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async (walletAddress: string) => {
      const nonceRes = await fetch(`${API_BASE}/auth/nonce`, { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ walletAddress }) });
      if (!nonceRes.ok) throw new Error(await nonceRes.text());
      const nonce = await nonceRes.json() as { message: string };
      const message = nonce.message.includes(AUTH_MESSAGE_PREFIX) ? nonce.message : `${AUTH_MESSAGE_PREFIX}\n\n${nonce.message}`;
      const signature = await signMessageAsync({ message });
      const verifyRes = await fetch(`${API_BASE}/auth/verify`, { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ walletAddress, signature }) });
      if (!verifyRes.ok) throw new Error(await verifyRes.text());
      const session = await verifyRes.json() as { token: string; walletAddress: string; role: string };
      window.localStorage.setItem("blobby-session", session.token);
      await qc.invalidateQueries({ queryKey: ["profile"] });
      return session;
    }
  });
}
