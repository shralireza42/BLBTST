// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { BlobbieDailyDraw } from "../src/BlobbieDailyDraw.sol";
import { BlobbieJackpotVault } from "../src/BlobbieJackpotVault.sol";
import { BlobbiePriceAdapter } from "../src/BlobbiePriceAdapter.sol";
import { IBlobbieDailyDraw } from "../src/interfaces/IBlobbieDailyDraw.sol";
import { IBlobbieJackpotVault } from "../src/interfaces/IBlobbieJackpotVault.sol";
import { MockBlobbieToken } from "../src/mocks/MockBlobbieToken.sol";
import { MockPriceFeed } from "../src/mocks/MockPriceFeed.sol";
import { MockVRFCoordinator } from "../src/mocks/MockVRFCoordinator.sol";

interface Vm {
    function expectRevert() external;
    function expectRevert(bytes4 selector) external;
    function warp(uint256 newTimestamp) external;
}

contract BlobbieDailyDrawTest {
    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));
    address private constant TREASURY = address(0x7777);

    function test300thTicketClosesRound() external {
        (BlobbieDailyDraw draw,,, MockBlobbieToken token,,) = _deploy();
        Buyer alice = _fundBuyer(token, 300 ether);

        alice.buy(draw, token, 300, 300 ether);

        IBlobbieDailyDraw.Round memory round = draw.getRound(1);
        require(round.status == IBlobbieDailyDraw.RoundStatus.CLOSED, "round not closed");
        require(round.eligibleTicketCount == 300, "ticket count mismatch");
    }

    function test24hTimeoutClosesRound() external {
        (BlobbieDailyDraw draw,,, MockBlobbieToken token,,) = _deploy();
        Buyer alice = _fundBuyer(token, 1 ether);
        alice.buy(draw, token, 1, 1 ether);

        vm.warp(block.timestamp + 24 hours + 1);
        draw.closeRoundByTimeout(1);

        IBlobbieDailyDraw.Round memory round = draw.getRound(1);
        require(round.status == IBlobbieDailyDraw.RoundStatus.CLOSED, "round not closed by timeout");
    }

    function testTopUpRequiredIfFewerThan300Tickets() external {
        (BlobbieDailyDraw draw,,, MockBlobbieToken token,,) = _deploy();
        Buyer alice = _fundBuyer(token, 1 ether);
        alice.buy(draw, token, 1, 1 ether);

        vm.warp(block.timestamp + 24 hours + 1);
        draw.closeRoundByTimeout(1);

        require(draw.requiredOperationalTopUp(1) == 299 ether, "unexpected topup requirement");
    }

    function testTopUpDoesNotCreateEligibleTickets() external {
        (BlobbieDailyDraw draw,,, MockBlobbieToken token,,) = _deploy();
        Buyer alice = _fundBuyer(token, 1 ether);
        alice.buy(draw, token, 1, 1 ether);
        vm.warp(block.timestamp + 24 hours + 1);
        draw.closeRoundByTimeout(1);

        token.mint(address(this), 299 ether);
        token.approve(address(draw), 299 ether);
        draw.provideOperationalTopUp(1, 299 ether);

        IBlobbieDailyDraw.Round memory round = draw.getRound(1);
        require(round.eligibleTicketCount == 1, "topup created tickets");
        require(draw.participantCount(1) == 1, "topup created participant");
        require(draw.ticketRangeCount(1) == 1, "topup created range");
        require(round.prizePool == 300 ether, "topup not in prize pool");
    }

    function testOnlyRealPaidTicketsCanWin() external {
        (BlobbieDailyDraw draw,,, MockBlobbieToken token, MockVRFCoordinator vrf,) = _deploy();
        Buyer alice = _fundBuyer(token, 1 ether);
        alice.buy(draw, token, 1, 1 ether);
        vm.warp(block.timestamp + 24 hours + 1);
        draw.closeRoundByTimeout(1);
        _topUp(draw, token, 299 ether);
        _requestFulfillSettle(draw, vrf, 1, 0);

        require(draw.winnerAtSlot(1, 0) == address(alice), "paid buyer did not win");
        require(draw.winnerAtSlot(1, 1) == address(0), "topup created a winner");
    }

    function testNoWalletWinsTwice() external {
        (BlobbieDailyDraw draw,,, MockBlobbieToken token, MockVRFCoordinator vrf,) = _deploy();
        Buyer alice = _fundBuyer(token, 150 ether);
        Buyer bob = _fundBuyer(token, 150 ether);
        alice.buy(draw, token, 150, 150 ether);
        bob.buy(draw, token, 150, 150 ether);

        _requestFulfillSettle(draw, vrf, 1, 0);

        address first = draw.winnerAtSlot(1, 0);
        address second = draw.winnerAtSlot(1, 1);
        require(first != address(0) && second != address(0), "expected two winners");
        require(first != second, "duplicate winner");
    }

    function testInsufficientUniqueWalletsLeavesUnfilledSlots() external {
        (BlobbieDailyDraw draw,,, MockBlobbieToken token, MockVRFCoordinator vrf,) = _deploy();
        Buyer alice = _fundBuyer(token, 300 ether);
        alice.buy(draw, token, 300, 300 ether);

        _requestFulfillSettle(draw, vrf, 1, 0);

        IBlobbieDailyDraw.Round memory round = draw.getRound(1);
        require(round.winnersPaid == 1, "unexpected winners paid");
        require(draw.winnerAtSlot(1, 1) == address(0), "slot should be unfilled");
    }

    function testUnusedAllocationRedistributes70_30() external {
        (BlobbieDailyDraw draw, BlobbieJackpotVault vault,, MockBlobbieToken token, MockVRFCoordinator vrf,) = _deploy();
        Buyer alice = _fundBuyer(token, 300 ether);
        alice.buy(draw, token, 300, 300 ether);

        _requestFulfillSettle(draw, vrf, 1, 0);

        IBlobbieDailyDraw.Round memory round = draw.getRound(1);
        require(round.jackpotAllocated == 128.2 ether, "unexpected jackpot allocation");
        require(round.burnTreasuryAllocated == 59.8 ether, "unexpected burn allocation");
        require(vault.reserve() == 128.2 ether, "vault reserve mismatch");
        require(token.balanceOf(TREASURY) == 59.8 ether, "treasury balance mismatch");
    }

    function testJackpotAllocationSentCorrectly() external {
        (BlobbieDailyDraw draw, BlobbieJackpotVault vault,, MockBlobbieToken token, MockVRFCoordinator vrf,) = _deploy();
        Buyer alice = _fundBuyer(token, 150 ether);
        Buyer bob = _fundBuyer(token, 150 ether);
        alice.buy(draw, token, 150, 150 ether);
        bob.buy(draw, token, 150, 150 ether);

        _requestFulfillSettle(draw, vrf, 1, 0);

        require(vault.reserve() == draw.getRound(1).jackpotAllocated, "jackpot not sent");
    }

    function testPriceDriftProtected() external {
        (BlobbieDailyDraw draw,,, MockBlobbieToken token,, MockPriceFeed feed) = _deploy();
        Buyer alice = _fundBuyer(token, 2 ether);
        feed.setAnswer(0.5e18);

        vm.expectRevert(IBlobbieDailyDraw.InvalidPayment.selector);
        alice.buy(draw, token, 1, 1 ether);
    }

    function testDuplicateSettlementPrevented() external {
        (BlobbieDailyDraw draw,,, MockBlobbieToken token, MockVRFCoordinator vrf,) = _deploy();
        Buyer alice = _fundBuyer(token, 300 ether);
        alice.buy(draw, token, 300, 300 ether);
        _requestFulfillSettle(draw, vrf, 1, 0);

        vm.expectRevert(IBlobbieDailyDraw.DuplicateSettlement.selector);
        draw.settleRound(1);
    }

    function testPausedContractBlocksPurchases() external {
        (BlobbieDailyDraw draw,,, MockBlobbieToken token,,) = _deploy();
        Buyer alice = _fundBuyer(token, 1 ether);
        draw.pause();

        vm.expectRevert();
        alice.buy(draw, token, 1, 1 ether);
    }

    function _deploy()
        internal
        returns (
            BlobbieDailyDraw draw,
            BlobbieJackpotVault vault,
            BlobbiePriceAdapter adapter,
            MockBlobbieToken token,
            MockVRFCoordinator vrf,
            MockPriceFeed feed
        )
    {
        token = new MockBlobbieToken();
        feed = new MockPriceFeed(18, 1e18);
        vrf = new MockVRFCoordinator();
        adapter = new BlobbiePriceAdapter(address(this), address(token), address(feed), 0, 0);
        vault = new BlobbieJackpotVault(
            address(this),
            address(token),
            IBlobbieJackpotVault.JackpotConfig({
                thresholdUsdE18: 100_000e18, contributionBps: 1_000, priceAdapter: address(adapter), treasury: TREASURY
            })
        );
        draw = new BlobbieDailyDraw(
            address(this),
            address(token),
            address(adapter),
            address(vault),
            IBlobbieDailyDraw.DrawConfig({
                ticketThreshold: 300,
                roundDuration: 24 hours,
                ticketUsdPriceE18: 1e18,
                jackpotContributionBps: 1_000,
                treasury: TREASURY
            }),
            IBlobbieDailyDraw.VrfConfig({
                coordinator: address(vrf),
                keyHash: bytes32(uint256(1)),
                subscriptionId: 1,
                requestConfirmations: 3,
                callbackGasLimit: 500_000,
                extraArgs: bytes("")
            })
        );
        vault.grantRole(vault.DRAW_ROLE(), address(draw));
    }

    function _fundBuyer(MockBlobbieToken token, uint256 amount) internal returns (Buyer buyer) {
        buyer = new Buyer();
        token.mint(address(buyer), amount);
    }

    function _topUp(BlobbieDailyDraw draw, MockBlobbieToken token, uint256 amount) internal {
        token.mint(address(this), amount);
        token.approve(address(draw), amount);
        draw.provideOperationalTopUp(1, amount);
    }

    function _requestFulfillSettle(BlobbieDailyDraw draw, MockVRFCoordinator vrf, uint256 roundId, uint256 randomness)
        internal
    {
        uint256 requestId = draw.requestRandomness(roundId);
        uint256[] memory words = new uint256[](1);
        words[0] = randomness;
        vrf.fulfill(address(draw), requestId, words);
        draw.settleRound(roundId);
    }
}

contract Buyer {
    function buy(BlobbieDailyDraw draw, MockBlobbieToken token, uint256 quantity, uint256 maxCost) external {
        token.approve(address(draw), maxCost);
        draw.buyTickets(quantity, maxCost);
    }
}
