import { devMock } from "../mock/data";
const API_BASE = process.env.NEXT_PUBLIC_API_BASE_URL || "http://localhost:3001";
async function request<T>(path: string, init?: RequestInit, fallback?: T): Promise<T> {
  try { const res = await fetch(`${API_BASE}${path}`, { ...init, headers: { "content-type": "application/json", ...(init?.headers||{}) }, cache: "no-store" }); if(!res.ok) throw new Error(await res.text()); return await res.json() as T; }
  catch (e) { if (process.env.NODE_ENV !== "production" && fallback !== undefined) return fallback; throw e; }
}
export const api = {
  currentDraw: () => request("/draw/current", undefined, devMock.currentDraw),
  roundHistory: () => request("/draw/rounds", undefined, devMock.rounds),
  ticketQuote: (quantity:number) => request("/draw/quote", { method:"POST", body: JSON.stringify({ quantity }) }, { quantity, blobbieAmount: `${quantity}000000000000000000` }),
  preparePurchase: (walletAddress:string, quantity:number, maxBlobbieCost:string) => request("/draw/prepare-purchase", { method:"POST", body: JSON.stringify({ walletAddress, quantity, maxBlobbieCost }) }),
  myDrawStatus: (wallet:string) => request(`/draw/my/${wallet}`, undefined, []),
  roundAudit: (id:string) => request(`/verify/round/${id}`),
  currentJackpot: () => request("/jackpot/current", undefined, devMock.jackpot),
  jackpotHistory: () => request("/jackpot/cycles", undefined, { data: [] }),
  jackpotAudit: (id:string) => request(`/verify/jackpot/${id}`),
  tasks: () => Promise.resolve(devMock.tasks),
  claimTask: (id:string) => Promise.resolve({ ok:true, id }),
  referralStats: () => Promise.resolve({ code:"BLOBBIE42", active:12, converted:7, earned:"1,250 BLOBBIE", pending:"300 BLOBBIE", history: [] }),
  profile: () => Promise.resolve({ nickname:"Blobbie enjoyer", avatar:"/blobbie1.png" }),
  rewardsLedger: () => Promise.resolve([]),
  adminDrawHealth: () => request("/admin/draws/health", { headers: adminHeaders() }),
  adminJackpotHealth: () => request("/admin/jackpot", { headers: adminHeaders() }),
  contractSyncStatus: () => request("/admin/contracts/sync-status", { headers: adminHeaders() }),
  adminActionLogs: () => request("/admin/action-logs", { headers: adminHeaders() }),
  adminHealth: (path:string) => request(`/admin/${path}`, { headers: adminHeaders() })
};
function adminHeaders(): Record<string, string> {
  const key = typeof window !== "undefined" ? window.localStorage.getItem("blobby-admin-key") : undefined;
  return key ? { "x-admin-key": key } : {};
}
