export const priceAdapterAbi = [
  { type: "function", name: "getBlobbieUsdPriceE18", stateMutability: "view", inputs: [], outputs: [{ type: "uint256" }] },
  { type: "function", name: "getTicketPriceInBlobbie", stateMutability: "view", inputs: [], outputs: [{ type: "uint256" }] }
] as const;
