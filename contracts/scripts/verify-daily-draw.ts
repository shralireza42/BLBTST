import assert from "node:assert/strict";
import { network } from "hardhat";

const KEY_HASH = "0x1111111111111111111111111111111111111111111111111111111111111111";

async function deployFixture(ethers: Awaited<ReturnType<typeof network.connect>>["ethers"]) {
  const [admin, alice, bob, topUpWallet] = await ethers.getSigners();

  const token: any = await ethers.deployContract("MockBlobby");
  const oracle: any = await ethers.deployContract("MockDailyDrawPriceOracle", [ethers.parseEther("1")]);
  const vrf: any = await ethers.deployContract("MockVRFCoordinatorV2Plus");

  const draw: any = await ethers.deployContract("DailyDraw", [
    admin.address,
    await token.getAddress(),
    await oracle.getAddress(),
    {
      coordinator: await vrf.getAddress(),
      keyHash: KEY_HASH,
      subscriptionId: 1,
      requestConfirmations: 3,
      callbackGasLimit: 500_000,
      extraArgs: "0x"
    },
    3,
    24 * 60 * 60,
    1_000,
    ethers.parseEther("0.2")
  ]);

  for (const account of [alice, bob, topUpWallet]) {
    await token.mint(account.address, ethers.parseEther("1000"));
    await token.connect(account).approve(await draw.getAddress(), ethers.MaxUint256);
  }

  await token.mint(admin.address, ethers.parseEther("1000"));
  await token.approve(await draw.getAddress(), ethers.MaxUint256);
  await draw.grantRole(await draw.TOP_UP_ROLE(), topUpWallet.address);
  await draw.openRound();

  return { alice, bob, topUpWallet, token, oracle, vrf, draw };
}

async function verifyDynamicTicketPricing(ethers: Awaited<ReturnType<typeof network.connect>>["ethers"]) {
  const { alice, bob, token, oracle, draw } = await deployFixture(ethers);

  await draw.connect(alice).buyTickets(1, ethers.parseEther("1"));
  await oracle.setBlobbiesPerUsd8(ethers.parseEther("2"));
  await draw.connect(bob).buyTickets(1, ethers.parseEther("2"));

  assert.equal(await token.balanceOf(await draw.getAddress()), ethers.parseEther("3"));
  const round = await draw.rounds(1);
  assert.equal(round.eligibleTicketCount, 2n);
  assert.equal(round.grossTicketRevenue, ethers.parseEther("3"));
}

async function verifyExpiryTopUp(
  ethers: Awaited<ReturnType<typeof network.connect>>["ethers"],
  networkHelpers: Awaited<ReturnType<typeof network.connect>>["networkHelpers"]
) {
  const { alice, topUpWallet, draw, vrf } = await deployFixture(ethers);

  await draw.connect(alice).buyTickets(1, ethers.parseEther("1"));
  await networkHelpers.time.increase(24 * 60 * 60 + 1);

  assert.equal(await draw.requiredOperationalTopUp(1), ethers.parseEther("2"));
  await draw.connect(topUpWallet).topUpAndClose(1, ethers.parseEther("2"));

  const roundAfterClose = await draw.rounds(1);
  assert.equal(roundAfterClose.eligibleTicketCount, 1n);
  assert.equal(roundAfterClose.uniqueWalletCount, 1n);
  assert.equal(await draw.ticketRangeCount(1), 1n);

  await vrf.fulfill(await draw.getAddress(), roundAfterClose.vrfRequestId, [123, 456]);

  const fulfilledRound = await draw.rounds(1);
  assert.equal(fulfilledRound.dailyWinner, alice.address);
  assert.equal(fulfilledRound.jackpotWinner, ethers.ZeroAddress);
}

async function verifyDistinctJackpotWinner(ethers: Awaited<ReturnType<typeof network.connect>>["ethers"]) {
  const { alice, bob, draw, vrf } = await deployFixture(ethers);

  await draw.connect(alice).buyTickets(2, ethers.parseEther("2"));
  await draw.connect(bob).buyTickets(1, ethers.parseEther("1"));
  await draw.closeRound(1);

  const roundAfterClose = await draw.rounds(1);
  assert.equal(roundAfterClose.eligibleTicketCount, 3n);
  assert.equal(roundAfterClose.jackpotEligible, true);

  await vrf.fulfill(await draw.getAddress(), roundAfterClose.vrfRequestId, [0, 2]);

  const fulfilledRound = await draw.rounds(1);
  assert.equal(fulfilledRound.dailyWinner, alice.address);
  assert.equal(fulfilledRound.jackpotWinner, bob.address);
  assert.notEqual(fulfilledRound.dailyWinner, fulfilledRound.jackpotWinner);
  assert.equal(await draw.jackpotReserve(), 0n);
}

async function main() {
  const { ethers, networkHelpers } = await network.connect();

  await verifyDynamicTicketPricing(ethers);
  await verifyExpiryTopUp(ethers, networkHelpers);
  await verifyDistinctJackpotWinner(ethers);

  console.log("DailyDraw verification passed");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
