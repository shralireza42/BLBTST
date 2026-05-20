export const devMock = {
  currentDraw: { chain: { id: "1", status: 0, expiresAt: new Date(Date.now()+7_200_000).toISOString(), eligibleTicketCount: 184, uniqueWalletCount: 92, prizePool: "184000000000000000000" }, indexed: null },
  rounds: { data: Array.from({length:6},(_,i)=>({ id: String(20-i), status: i?"FINALIZED":"OPEN", eligibleTicketCount: 300-i*17, uniqueWalletCount: 122-i*8, prizePool: "300000000000000000000" })), total: 6, page: 1, limit: 25 },
  jackpot: { cycle: { id: "7", status: "OPEN", reserveBalance: "42000000000000000000000", thresholdUsdE18: "100000000000000000000000", eligibleEntries: 12840, cycleStart: new Date(Date.now()-86400000).toISOString() } },
  tasks: [{ id:"daily-x", title:"Post a BLOBBIE meme", status:"API Verified", reward:"25 BLOBBIE" },{ id:"join", title:"Join Telegram", status:"Auto Verified", reward:"10 BLOBBIE" },{ id:"proof", title:"Submit fan art", status:"Proof Required", reward:"100 BLOBBIE" }]
};
