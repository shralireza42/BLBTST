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
}
