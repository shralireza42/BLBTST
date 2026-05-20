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

contract IntegrationDailyDrawJackpotTest {
    address private constant TREASURY = address(0x7777);

    function testPackageWiringSkeleton() external {
        MockBlobbieToken token = new MockBlobbieToken();
        MockPriceFeed feed = new MockPriceFeed(8, 1e8);
        MockVRFCoordinator vrf = new MockVRFCoordinator();
        BlobbiePriceAdapter adapter = new BlobbiePriceAdapter(address(this), address(token), address(feed), 1 hours, 0);
        BlobbieJackpotVault vault = new BlobbieJackpotVault(
            address(this),
            address(token),
            IBlobbieJackpotVault.JackpotConfig({
                thresholdUsdE18: 100_000e18,
                contributionBps: 1_000,
                priceAdapter: address(adapter),
                treasury: address(this)
            })
        );
        BlobbieDailyDraw draw = new BlobbieDailyDraw(
            address(this),
            address(token),
            address(adapter),
            address(vault),
            IBlobbieDailyDraw.DrawConfig({
                ticketThreshold: 300,
                roundDuration: 24 hours,
                ticketUsdPriceE18: 1e18,
                jackpotContributionBps: 1_000,
                treasury: address(this)
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

        require(address(draw.priceAdapter()) == address(adapter), "adapter mismatch");
        require(address(draw.jackpotVault()) == address(vault), "vault mismatch");
    }

    function testIntegrationDrawAllocatesThenJackpotPaysCycle() external {
        MockBlobbieToken token = new MockBlobbieToken();
        MockPriceFeed feed = new MockPriceFeed(18, 1e18);
        MockVRFCoordinator vrf = new MockVRFCoordinator();
        BlobbiePriceAdapter adapter = new BlobbiePriceAdapter(address(this), address(token), address(feed), 0, 0);
        BlobbieJackpotVault vault = new BlobbieJackpotVault(
            address(this),
            address(token),
            IBlobbieJackpotVault.JackpotConfig({
                thresholdUsdE18: 100e18, contributionBps: 1_000, priceAdapter: address(adapter), treasury: TREASURY
            })
        );
        BlobbieDailyDraw draw = new BlobbieDailyDraw(
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

        IntegrationBuyer alice = _fundBuyer(token, 300 ether);
        alice.buy(draw, token, 300, 300 ether);
        uint256 requestId = draw.requestRandomness(1);
        uint256[] memory words = new uint256[](1);
        words[0] = 0;
        vrf.fulfill(address(draw), requestId, words);
        draw.settleRound(1);

        require(vault.reserve() >= vault.jackpotThresholdInBlobbie(), "jackpot threshold not met");
        uint256 cycleId = vault.requestJackpotRandomness(1, 123);
        (address winner, uint256 amount) = vault.settleJackpotWinner(cycleId, 0);

        require(winner == address(alice), "unexpected jackpot winner");
        require(amount > 0, "no jackpot paid");
        require(vault.reserve() == 0, "vault did not reset");
        require(token.balanceOf(address(vault)) == 0, "vault retained funds");
    }

    function _fundBuyer(MockBlobbieToken token, uint256 amount) internal returns (IntegrationBuyer buyer) {
        buyer = new IntegrationBuyer();
        token.mint(address(buyer), amount);
    }
}

contract IntegrationBuyer {
    function buy(BlobbieDailyDraw draw, MockBlobbieToken token, uint256 quantity, uint256 maxCost) external {
        token.approve(address(draw), maxCost);
        draw.buyTickets(quantity, maxCost);
    }
}
