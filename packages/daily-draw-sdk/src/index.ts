import { BrowserProvider, Contract, JsonRpcSigner, Provider } from "ethers";

export const dailyDrawAbi = [
  "function currentRoundId() view returns (uint256)",
  "function ticketThreshold() view returns (uint32)",
  "function jackpotReserve() view returns (uint256)",
  "function quoteTickets(uint32 quantity) view returns (uint256)",
  "function requiredOperationalTopUp(uint256 roundId) view returns (uint256)",
  "function rounds(uint256 roundId) view returns (uint256 id,uint64 openedAt,uint64 expiresAt,uint64 closedAt,uint32 eligibleTicketCount,uint32 uniqueWalletCount,uint256 grossTicketRevenue,uint256 prizePool,uint256 jackpotContribution,uint256 operationalTopUp,uint256 dailyPrizePaid,uint256 jackpotPaid,address dailyWinner,address jackpotWinner,uint256 vrfRequestId,bool jackpotEligible,uint8 status)",
  "function buyTickets(uint32 quantity,uint256 maxPayment)",
  "event TicketsPurchased(uint256 indexed roundId,address indexed buyer,uint32 quantity,uint32 startInclusive,uint32 endExclusive,uint256 blobbyPaid,uint256 jackpotContribution)",
  "event RoundCloseRequested(uint256 indexed roundId,uint256 indexed requestId,bool jackpotEligible)",
  "event RoundFulfilled(uint256 indexed roundId,address indexed dailyWinner,uint256 dailyPrizePaid,address indexed jackpotWinner,uint256 jackpotPaid)"
] as const;

export const erc20ApprovalAbi = [
  "function allowance(address owner,address spender) view returns (uint256)",
  "function approve(address spender,uint256 amount) returns (bool)"
] as const;

export type DailyDrawConfig = {
  dailyDrawAddress: string;
  blobbyTokenAddress: string;
};

export function getDailyDrawContract(address: string, runner: Provider | JsonRpcSigner) {
  return new Contract(address, dailyDrawAbi, runner);
}

export function getBlobbyApprovalContract(address: string, runner: Provider | JsonRpcSigner) {
  return new Contract(address, erc20ApprovalAbi, runner);
}

export async function getBrowserSigner(ethereum: unknown) {
  const provider = new BrowserProvider(ethereum);
  return provider.getSigner();
}

export async function getTicketQuote(config: DailyDrawConfig, provider: Provider, quantity: number) {
  const contract = getDailyDrawContract(config.dailyDrawAddress, provider);
  return BigInt(await contract.quoteTickets(quantity));
}

export async function buyDailyDrawTickets(
  config: DailyDrawConfig,
  signer: JsonRpcSigner,
  quantity: number,
  maxPaymentWei: bigint
) {
  const contract = getDailyDrawContract(config.dailyDrawAddress, signer);
  return contract.buyTickets(quantity, maxPaymentWei);
}

export async function ensureBlobbyAllowance(
  config: DailyDrawConfig,
  signer: JsonRpcSigner,
  owner: string,
  requiredAllowanceWei: bigint
) {
  const token = getBlobbyApprovalContract(config.blobbyTokenAddress, signer);
  const currentAllowance = BigInt(await token.allowance(owner, config.dailyDrawAddress));
  if (currentAllowance >= requiredAllowanceWei) {
    return null;
  }
  return token.approve(config.dailyDrawAddress, requiredAllowanceWei);
}
