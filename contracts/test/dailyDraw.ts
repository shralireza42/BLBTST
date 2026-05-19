import { expect } from "chai";
import { ethers } from "hardhat";
import { time } from "@nomicfoundation/hardhat-network-helpers";

const KEY_HASH = "0x1111111111111111111111111111111111111111111111111111111111111111";

describe("DailyDraw", function () {
  async function deployFixture() {
    const [admin, alice, bob, topUpWallet] = await ethers.getSigners();

    const token = await ethers.deployContract("MockBlobby");
    const oracle = await ethers.deployContract("MockDailyDrawPriceOracle", [ethers.parseEther("1")]);
    const vrf = await ethers.deployContract("MockVRFCoordinatorV2Plus");

    const draw = await ethers.deployContract("DailyDraw", [
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

    await draw.openRound();

    return { admin, alice, bob, topUpWallet, token, oracle, vrf, draw };
  }

  it("quotes each ticket as one USD worth of BLOBBIE at purchase time", async function () {
    const { alice, bob, token, oracle, draw } = await deployFixture();

    await draw.connect(alice).buyTickets(1, ethers.parseEther("1"));
    await oracle.setBlobbiesPerUsd8(ethers.parseEther("2"));
    await draw.connect(bob).buyTickets(1, ethers.parseEther("2"));

    expect(await token.balanceOf(await draw.getAddress())).to.equal(ethers.parseEther("3"));
    const round = await draw.rounds(1);
    expect(round.eligibleTicketCount).to.equal(2);
    expect(round.grossTicketRevenue).to.equal(ethers.parseEther("3"));
  });

  it("requires expiry top-up without creating eligible entries", async function () {
    const { alice, topUpWallet, draw, vrf } = await deployFixture();

    await draw.connect(alice).buyTickets(1, ethers.parseEther("1"));
    await time.increase(24 * 60 * 60 + 1);

    expect(await draw.requiredOperationalTopUp(1)).to.equal(ethers.parseEther("2"));
    await draw.connect(topUpWallet).topUpAndClose(1, ethers.parseEther("2"));

    const roundAfterClose = await draw.rounds(1);
    expect(roundAfterClose.eligibleTicketCount).to.equal(1);
    expect(roundAfterClose.uniqueWalletCount).to.equal(1);
    expect(await draw.ticketRangeCount(1)).to.equal(1);

    await vrf.fulfill(await draw.getAddress(), roundAfterClose.vrfRequestId, [123, 456]);

    const fulfilledRound = await draw.rounds(1);
    expect(fulfilledRound.dailyWinner).to.equal(alice.address);
    expect(fulfilledRound.jackpotWinner).to.equal(ethers.ZeroAddress);
  });

  it("closes at the ticket threshold and pays jackpot to a distinct wallet", async function () {
    const { alice, bob, draw, vrf } = await deployFixture();

    await draw.connect(alice).buyTickets(2, ethers.parseEther("2"));
    await draw.connect(bob).buyTickets(1, ethers.parseEther("1"));
    await draw.closeRound(1);

    const roundAfterClose = await draw.rounds(1);
    expect(roundAfterClose.eligibleTicketCount).to.equal(3);
    expect(roundAfterClose.jackpotEligible).to.equal(true);

    await vrf.fulfill(await draw.getAddress(), roundAfterClose.vrfRequestId, [0, 2]);

    const fulfilledRound = await draw.rounds(1);
    expect(fulfilledRound.dailyWinner).to.equal(alice.address);
    expect(fulfilledRound.jackpotWinner).to.equal(bob.address);
    expect(fulfilledRound.dailyWinner).to.not.equal(fulfilledRound.jackpotWinner);
    expect(await draw.jackpotReserve()).to.equal(0);
  });
});
