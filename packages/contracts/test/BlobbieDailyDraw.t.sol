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

contract BlobbieDailyDrawTest {
    function testOpenRoundSkeleton() external {
        (BlobbieDailyDraw draw,,,) = _deploy();
        uint256 roundId = draw.openRound();
        IBlobbieDailyDraw.Round memory round = draw.getRound(roundId);
        require(round.status == IBlobbieDailyDraw.RoundStatus.Open, "round not open");
    }

    function _deploy()
        internal
        returns (BlobbieDailyDraw draw, BlobbiePriceAdapter adapter, BlobbieJackpotVault vault, MockBlobbieToken token)
    {
        token = new MockBlobbieToken();
        MockPriceFeed feed = new MockPriceFeed(8, 1e8);
        MockVRFCoordinator vrf = new MockVRFCoordinator();
        adapter = new BlobbiePriceAdapter(address(this), address(token), address(feed), 1 hours, 0);
        vault = new BlobbieJackpotVault(
            address(this),
            address(token),
            IBlobbieJackpotVault.JackpotConfig({
                triggerAmount: 100 ether, contributionBps: 1_000, treasury: address(this)
            })
        );
        draw = new BlobbieDailyDraw(
            address(this),
            address(token),
            address(adapter),
            address(vault),
            IBlobbieDailyDraw.DrawConfig({
                ticketThreshold: 300, roundDuration: 24 hours, ticketUsdPrice8: 1e8, jackpotContributionBps: 1_000
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
    }
}
