// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { BlobbieDailyDraw } from "../src/BlobbieDailyDraw.sol";
import { BlobbieJackpotVault } from "../src/BlobbieJackpotVault.sol";
import { BlobbiePriceAdapter } from "../src/BlobbiePriceAdapter.sol";
import { BlobbieTreasuryRouter } from "../src/BlobbieTreasuryRouter.sol";
import { IBlobbieDailyDraw } from "../src/interfaces/IBlobbieDailyDraw.sol";
import { IBlobbieJackpotVault } from "../src/interfaces/IBlobbieJackpotVault.sol";

contract DeployBlobbieDraw {
    struct DeployParams {
        address admin;
        address blobbyToken;
        address priceFeed;
        address vrfCoordinator;
        bytes32 vrfKeyHash;
        uint256 vrfSubscriptionId;
        address treasury;
    }

    struct DeployedContracts {
        address priceAdapter;
        address jackpotVault;
        address treasuryRouter;
        address dailyDraw;
    }

    function run(DeployParams calldata params) external returns (DeployedContracts memory deployed) {
        BlobbiePriceAdapter priceAdapter =
            new BlobbiePriceAdapter(params.admin, params.blobbyToken, params.priceFeed, 1 hours, 0);

        BlobbieJackpotVault jackpotVault = new BlobbieJackpotVault(
            params.admin,
            params.blobbyToken,
            IBlobbieJackpotVault.JackpotConfig({ triggerAmount: 0, contributionBps: 1_000, treasury: params.treasury })
        );

        BlobbieTreasuryRouter treasuryRouter = new BlobbieTreasuryRouter(
            params.admin,
            params.blobbyToken,
            BlobbieTreasuryRouter.SplitConfig({
                prizePool: params.admin,
                jackpotVault: address(jackpotVault),
                treasury: params.treasury,
                jackpotBps: 1_000,
                treasuryBps: 0
            })
        );

        BlobbieDailyDraw dailyDraw = new BlobbieDailyDraw(
            params.admin,
            params.blobbyToken,
            address(priceAdapter),
            address(jackpotVault),
            IBlobbieDailyDraw.DrawConfig({
                ticketThreshold: 300, roundDuration: 24 hours, ticketUsdPrice8: 1e8, jackpotContributionBps: 1_000
            }),
            IBlobbieDailyDraw.VrfConfig({
                coordinator: params.vrfCoordinator,
                keyHash: params.vrfKeyHash,
                subscriptionId: params.vrfSubscriptionId,
                requestConfirmations: 3,
                callbackGasLimit: 500_000,
                extraArgs: bytes("")
            })
        );

        deployed = DeployedContracts({
            priceAdapter: address(priceAdapter),
            jackpotVault: address(jackpotVault),
            treasuryRouter: address(treasuryRouter),
            dailyDraw: address(dailyDraw)
        });
    }
}
