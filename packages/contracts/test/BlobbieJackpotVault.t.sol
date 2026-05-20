// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { BlobbieJackpotVault } from "../src/BlobbieJackpotVault.sol";
import { BlobbiePriceAdapter } from "../src/BlobbiePriceAdapter.sol";
import { IBlobbieJackpotVault } from "../src/interfaces/IBlobbieJackpotVault.sol";
import { MockBlobbieToken } from "../src/mocks/MockBlobbieToken.sol";
import { MockPriceFeed } from "../src/mocks/MockPriceFeed.sol";

interface Vm {
    function expectRevert() external;
    function expectRevert(bytes4 selector) external;
}

contract BlobbieJackpotVaultTest {
    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    address private constant ALICE = address(0xA11CE);
    address private constant BOB = address(0xB0B);
    uint256 private constant THRESHOLD = 100_000 ether;

    function testInitialConfigUsesDefaultThreshold() external {
        (BlobbieJackpotVault vault,,) = _deploy();

        IBlobbieJackpotVault.JackpotConfig memory config = vault.config();
        require(config.thresholdUsdE18 == 100_000e18, "unexpected default trigger");
        require(config.contributionBps == 1_000, "unexpected bps");
        require(vault.currentCycleId() == 1, "cycle not started");
    }

    function testContributionIncreasesReserve() external {
        (BlobbieJackpotVault vault,, MockBlobbieToken token) = _deploy();

        token.mint(address(this), 1_000 ether);
        token.approve(address(vault), 1_000 ether);
        vault.contributeFromDraw(1_000 ether);

        require(vault.reserve() == 1_000 ether, "total reserve not increased");
        IBlobbieJackpotVault.JackpotCycle memory cycle = vault.getCycle(vault.currentCycleId());
        require(cycle.reserveBalance == 1_000 ether, "cycle reserve not increased");
        require(cycle.totalContributed == 1_000 ether, "contribution not tracked");
    }

    function testEligiblePaidTicketsCreateEntries() external {
        (BlobbieJackpotVault vault,,) = _deploy();

        vault.recordEligibleTickets(ALICE, 3);
        IBlobbieJackpotVault.JackpotCycle memory cycle = vault.getCycle(vault.currentCycleId());
        require(cycle.eligibleTicketCount == 3, "tickets not tracked");
        require(vault.eligibleTicketsByUser(vault.currentCycleId(), ALICE) == 3, "user tickets not tracked");
        require(vault.entryRangeCount(vault.currentCycleId()) == 1, "entry range not tracked");
    }

    function testFreeReferralTaskAndTopUpTicketsDoNotCreateEntries() external {
        (BlobbieJackpotVault vault,,) = _deploy();

        vault.recordExcludedTickets(ALICE, 1, IBlobbieJackpotVault.TicketExclusion.Referral);
        vault.recordExcludedTickets(ALICE, 1, IBlobbieJackpotVault.TicketExclusion.Promotional);
        vault.recordExcludedTickets(ALICE, 1, IBlobbieJackpotVault.TicketExclusion.TaskReward);
        vault.recordExcludedTickets(ALICE, 1, IBlobbieJackpotVault.TicketExclusion.OperationalTopUp);

        IBlobbieJackpotVault.JackpotCycle memory cycle = vault.getCycle(vault.currentCycleId());
        require(cycle.eligibleTicketCount == 0, "excluded tickets created entries");
        require(vault.entryRangeCount(vault.currentCycleId()) == 0, "excluded range tracked");
    }

    function testThresholdCheckWorks() external {
        (BlobbieJackpotVault vault,, MockBlobbieToken token) = _deploy();

        token.mint(address(this), THRESHOLD);
        token.approve(address(vault), THRESHOLD);
        vault.contributeFromDraw(THRESHOLD - 1);
        require(!vault.isThresholdMet(), "threshold met too early");

        vault.contributeFromDraw(1);
        require(vault.isThresholdMet(), "threshold not met");
        require(vault.jackpotThresholdInBlobbie() == THRESHOLD, "unexpected threshold in blobbie");
    }

    function testJackpotPaysFullCycleBalanceAndResets() external {
        (BlobbieJackpotVault vault,, MockBlobbieToken token) = _deploy();

        token.mint(address(this), THRESHOLD + 7 ether);
        token.approve(address(vault), THRESHOLD + 7 ether);
        vault.contributeFromDraw(THRESHOLD + 7 ether);
        vault.recordEligibleTickets(ALICE, 2);
        uint256 cycleId = vault.requestJackpotRandomness(1, 99);

        (address winner, uint256 amount) = vault.settleJackpotWinner(cycleId, 0);

        require(winner == ALICE, "unexpected winner");
        require(amount == THRESHOLD + 7 ether, "did not pay full balance");
        require(token.balanceOf(ALICE) == THRESHOLD + 7 ether, "winner not paid");
        require(vault.reserve() == 0, "reserve not reset");
        require(vault.currentCycleId() == cycleId + 1, "cycle not reset");

        IBlobbieJackpotVault.JackpotCycle memory settledCycle = vault.getCycle(cycleId);
        require(settledCycle.settled, "cycle not settled");
        require(settledCycle.reserveBalance == 0, "cycle reserve not cleared");
        require(settledCycle.winner == ALICE, "winner not stored");
    }

    function testBannedOrFraudRejectedWalletCannotWin() external {
        (BlobbieJackpotVault vault,, MockBlobbieToken token) = _deploy();

        token.mint(address(this), THRESHOLD);
        token.approve(address(vault), THRESHOLD);
        vault.contributeFromDraw(THRESHOLD);
        vault.recordEligibleTickets(ALICE, 1);
        vault.recordEligibleTickets(BOB, 1);
        vault.setWalletStatus(ALICE, true, false);
        uint256 cycleId = vault.requestJackpotRandomness(1, 100);

        (address winner,) = vault.settleJackpotWinner(cycleId, 0);
        require(winner == BOB, "banned wallet won");

        token.mint(address(this), THRESHOLD);
        token.approve(address(vault), THRESHOLD);
        vault.contributeFromDraw(THRESHOLD);
        vault.setWalletStatus(ALICE, false, false);
        vault.recordEligibleTickets(ALICE, 1);
        vault.recordEligibleTickets(BOB, 1);
        vault.setWalletStatus(BOB, false, true);
        cycleId = vault.requestJackpotRandomness(2, 101);

        (winner,) = vault.settleJackpotWinner(cycleId, 1);
        require(winner == ALICE, "fraud rejected wallet won");
    }

    function testDuplicateSettlementPrevented() external {
        (BlobbieJackpotVault vault,, MockBlobbieToken token) = _deploy();

        token.mint(address(this), THRESHOLD);
        token.approve(address(vault), THRESHOLD);
        vault.contributeFromDraw(THRESHOLD);
        vault.recordEligibleTickets(ALICE, 1);
        uint256 cycleId = vault.requestJackpotRandomness(1, 99);
        vault.settleJackpotWinner(cycleId, 0);

        vm.expectRevert(IBlobbieJackpotVault.SettlementAlreadyCompleted.selector);
        vault.settleJackpotWinner(cycleId, 0);
    }

    function testPausedVaultRejectsSensitiveActions() external {
        (BlobbieJackpotVault vault,, MockBlobbieToken token) = _deploy();
        token.mint(address(this), 1 ether);
        token.approve(address(vault), 1 ether);
        vault.pause();

        vm.expectRevert();
        vault.contributeFromDraw(1 ether);

        vm.expectRevert();
        vault.recordEligibleTickets(ALICE, 1);
    }

    function testFuzzContributionReserveAccounting(uint96 firstAmount, uint96 secondAmount) external {
        (BlobbieJackpotVault vault,, MockBlobbieToken token) = _deploy();
        uint256 first = 1 + (uint256(firstAmount) % 1_000_000 ether);
        uint256 second = 1 + (uint256(secondAmount) % 1_000_000 ether);
        token.mint(address(this), first + second);
        token.approve(address(vault), first + second);

        vault.contributeFromDraw(first);
        vault.contributeFromDraw(second);

        IBlobbieJackpotVault.JackpotCycle memory cycle = vault.getCycle(vault.currentCycleId());
        require(vault.reserve() == first + second, "reserve mismatch");
        require(cycle.reserveBalance == first + second, "cycle reserve mismatch");
        require(token.balanceOf(address(vault)) == vault.reserve(), "vault silently lost funds");
    }

    function testFuzzExcludedTicketsNeverIncreaseEligibility(uint96 referral, uint96 promo, uint96 task, uint96 topUp)
        external
    {
        (BlobbieJackpotVault vault,,) = _deploy();
        uint256 a = 1 + (uint256(referral) % 10_000);
        uint256 b = 1 + (uint256(promo) % 10_000);
        uint256 c = 1 + (uint256(task) % 10_000);
        uint256 d = 1 + (uint256(topUp) % 10_000);

        vault.recordExcludedTickets(ALICE, a, IBlobbieJackpotVault.TicketExclusion.Referral);
        vault.recordExcludedTickets(ALICE, b, IBlobbieJackpotVault.TicketExclusion.Promotional);
        vault.recordExcludedTickets(ALICE, c, IBlobbieJackpotVault.TicketExclusion.TaskReward);
        vault.recordExcludedTickets(ALICE, d, IBlobbieJackpotVault.TicketExclusion.OperationalTopUp);

        IBlobbieJackpotVault.JackpotCycle memory cycle = vault.getCycle(vault.currentCycleId());
        require(cycle.eligibleTicketCount == 0, "excluded tickets counted");
        require(vault.entryRangeCount(vault.currentCycleId()) == 0, "excluded entries created");
    }

    function testInvariantJackpotCannotPayTwiceSameCycle() external {
        (BlobbieJackpotVault vault,, MockBlobbieToken token) = _deploy();

        token.mint(address(this), THRESHOLD);
        token.approve(address(vault), THRESHOLD);
        vault.contributeFromDraw(THRESHOLD);
        vault.recordEligibleTickets(ALICE, 1);
        uint256 cycleId = vault.requestJackpotRandomness(1, 99);
        vault.settleJackpotWinner(cycleId, 0);
        uint256 aliceBalance = token.balanceOf(ALICE);

        vm.expectRevert(IBlobbieJackpotVault.SettlementAlreadyCompleted.selector);
        vault.settleJackpotWinner(cycleId, 0);
        require(token.balanceOf(ALICE) == aliceBalance, "second payout occurred");
    }

    function _deploy()
        internal
        returns (BlobbieJackpotVault vault, BlobbiePriceAdapter adapter, MockBlobbieToken token)
    {
        token = new MockBlobbieToken();
        MockPriceFeed feed = new MockPriceFeed(18, 1e18);
        adapter = new BlobbiePriceAdapter(address(this), address(token), address(feed), 1 hours, 0);
        vault = new BlobbieJackpotVault(
            address(this),
            address(token),
            IBlobbieJackpotVault.JackpotConfig({
                thresholdUsdE18: 0, contributionBps: 1_000, priceAdapter: address(adapter), treasury: address(this)
            })
        );
    }
}
