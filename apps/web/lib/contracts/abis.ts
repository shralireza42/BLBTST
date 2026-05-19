export const dailyDrawAbi = [
  { type: "function", name: "buyTickets", stateMutability: "nonpayable", inputs: [{ name: "quantity", type: "uint256" }, { name: "maxBlobbieCost", type: "uint256" }], outputs: [{ type: "uint256" }] },
  { type: "function", name: "quoteTickets", stateMutability: "view", inputs: [{ name: "quantity", type: "uint256" }], outputs: [{ type: "uint256" }] }
] as const;
export const erc20Abi = [
  { type: "function", name: "approve", stateMutability: "nonpayable", inputs: [{ name: "spender", type: "address" }, { name: "amount", type: "uint256" }], outputs: [{ type: "bool" }] },
  { type: "function", name: "allowance", stateMutability: "view", inputs: [{ name: "owner", type: "address" }, { name: "spender", type: "address" }], outputs: [{ type: "uint256" }] }
] as const;
