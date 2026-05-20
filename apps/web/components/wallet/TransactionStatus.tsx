import { Badge } from "../ui/Badge";

export type TransactionPhase = "idle" | "waiting_for_wallet" | "submitted" | "pending_confirmation" | "success" | "failed" | "rejected" | "wrong_network" | "insufficient_balance" | "insufficient_allowance";
const labels: Record<TransactionPhase, string> = {
  idle: "Ready",
  waiting_for_wallet: "Waiting for wallet confirmation",
  submitted: "Transaction submitted",
  pending_confirmation: "Pending confirmation",
  success: "Success",
  failed: "Failed",
  rejected: "Rejected by user",
  wrong_network: "Wrong network",
  insufficient_balance: "Insufficient balance",
  insufficient_allowance: "Approval required"
};
export function TransactionStatus({ phase, error }: { phase: TransactionPhase; error?: string }) { const tone = phase === "success" ? "green" : phase === "failed" || phase === "rejected" || phase === "wrong_network" ? "red" : "cream"; return <div className="grid gap-2"><Badge tone={tone}>{labels[phase]}</Badge>{error&&<p className="text-sm text-[#bc352a]">{error}</p>}</div>; }
