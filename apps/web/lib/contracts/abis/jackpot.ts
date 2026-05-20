export const jackpotVaultAbi = [
  { type: "function", name: "reserve", stateMutability: "view", inputs: [], outputs: [{ type: "uint256" }] },
  { type: "function", name: "currentCycleId", stateMutability: "view", inputs: [], outputs: [{ type: "uint256" }] },
  { type: "function", name: "jackpotThresholdInBlobbie", stateMutability: "view", inputs: [], outputs: [{ type: "uint256" }] },
  { type: "function", name: "getCycle", stateMutability: "view", inputs: [{ name: "cycleId", type: "uint256" }], outputs: [{ type: "tuple", components: [ { name:"id", type:"uint256" }, { name:"startedAt", type:"uint256" }, { name:"endedAt", type:"uint256" }, { name:"reserveBalance", type:"uint256" }, { name:"totalContributed", type:"uint256" }, { name:"eligibleTicketCount", type:"uint256" }, { name:"randomnessRequestId", type:"uint256" }, { name:"winner", type:"address" }, { name:"paidAmount", type:"uint256" }, { name:"randomnessRequested", type:"bool" }, { name:"settled", type:"bool" } ] }] }
] as const;
