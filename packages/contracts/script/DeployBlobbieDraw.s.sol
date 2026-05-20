// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { console2 } from "forge-std/console2.sol";

import { BlobbieDailyDraw } from "../src/BlobbieDailyDraw.sol";
import { BlobbieJackpotVault } from "../src/BlobbieJackpotVault.sol";
import { BlobbiePriceAdapter } from "../src/BlobbiePriceAdapter.sol";
import { BlobbieTreasuryRouter } from "../src/BlobbieTreasuryRouter.sol";
import { IBlobbieDailyDraw } from "../src/interfaces/IBlobbieDailyDraw.sol";
import { IBlobbieJackpotVault } from "../src/interfaces/IBlobbieJackpotVault.sol";

interface VmDeploy {
    function envUint(string calldata name) external view returns (uint256);
    function envAddress(string calldata name) external view returns (address);
    function envBytes32(string calldata name) external view returns (bytes32);
    function envOr(string calldata name, address defaultValue) external view returns (address);
    function envOr(string calldata name, uint256 defaultValue) external view returns (uint256);
    function envOr(string calldata name, bytes calldata defaultValue) external view returns (bytes memory);
    function addr(uint256 privateKey) external returns (address);
    function startBroadcast(uint256 privateKey) external;
    function stopBroadcast() external;
}

contract DeployBlobbieDraw {
    VmDeploy private constant vm = VmDeploy(address(uint160(uint256(keccak256("hevm cheat code")))));

    struct DeployParams {
        address admin;
        address blobbyToken;
        address blobbieUsdFeed;
        address vrfCoordinator;
        bytes32 vrfKeyHash;
        uint256 vrfSubscriptionId;
        address treasury;
        address operationalWallet;
        uint256 maxPriceAge;
        uint256 jackpotThresholdUsdE18;
        uint16 jackpotContributionBps;
        uint32 ticketThreshold;
        uint64 roundDuration;
        uint256 ticketUsdPriceE18;
        uint16 vrfRequestConfirmations;
        uint32 vrfCallbackGasLimit;
        bytes vrfExtraArgs;
    }

    struct DeployedContracts {
        address priceAdapter;
        address jackpotVault;
        address treasuryRouter;
        address dailyDraw;
    }

    function run() external returns (DeployedContracts memory deployed) {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        DeployParams memory params = _readParams(deployer);

        console2.log("BLOBBIE deployer", deployer);
        console2.log("BLOBBIE admin", params.admin);
        console2.log("BSC chain id", block.chainid);

        vm.startBroadcast(deployerPrivateKey);
        deployed = _deploy(params);
        vm.stopBroadcast();

        console2.log("BlobbiePriceAdapter", deployed.priceAdapter);
        console2.log("BlobbieJackpotVault", deployed.jackpotVault);
        console2.log("BlobbieTreasuryRouter", deployed.treasuryRouter);
        console2.log("BlobbieDailyDraw", deployed.dailyDraw);
    }

    function _deploy(DeployParams memory params) internal returns (DeployedContracts memory deployed) {
        BlobbiePriceAdapter priceAdapter =
            new BlobbiePriceAdapter(params.admin, params.blobbyToken, params.blobbieUsdFeed, params.maxPriceAge, 0);

        BlobbieJackpotVault jackpotVault = new BlobbieJackpotVault(
            params.admin,
            params.blobbyToken,
            IBlobbieJackpotVault.JackpotConfig({
                thresholdUsdE18: params.jackpotThresholdUsdE18,
                contributionBps: params.jackpotContributionBps,
                priceAdapter: address(priceAdapter),
                treasury: params.treasury
            })
        );

        BlobbieTreasuryRouter treasuryRouter = new BlobbieTreasuryRouter(
            params.admin,
            params.blobbyToken,
            BlobbieTreasuryRouter.SplitConfig({
                prizePool: params.admin,
                jackpotVault: address(jackpotVault),
                treasury: params.treasury,
                jackpotBps: params.jackpotContributionBps,
                treasuryBps: 0
            })
        );

        BlobbieDailyDraw dailyDraw = new BlobbieDailyDraw(
            params.admin,
            params.blobbyToken,
            address(priceAdapter),
            address(jackpotVault),
            IBlobbieDailyDraw.DrawConfig({
                ticketThreshold: params.ticketThreshold,
                roundDuration: params.roundDuration,
                ticketUsdPriceE18: params.ticketUsdPriceE18,
                jackpotContributionBps: params.jackpotContributionBps,
                treasury: params.treasury
            }),
            IBlobbieDailyDraw.VrfConfig({
                coordinator: params.vrfCoordinator,
                keyHash: params.vrfKeyHash,
                subscriptionId: params.vrfSubscriptionId,
                requestConfirmations: params.vrfRequestConfirmations,
                callbackGasLimit: params.vrfCallbackGasLimit,
                extraArgs: params.vrfExtraArgs
            })
        );

        jackpotVault.grantRole(jackpotVault.DRAW_ROLE(), address(dailyDraw));
        treasuryRouter.grantRole(treasuryRouter.DRAW_ROLE(), address(dailyDraw));

        if (params.operationalWallet != address(0)) {
            dailyDraw.grantRole(dailyDraw.OPERATOR_ROLE(), params.operationalWallet);
            dailyDraw.grantRole(dailyDraw.TOP_UP_ROLE(), params.operationalWallet);
        }

        deployed = DeployedContracts({
            priceAdapter: address(priceAdapter),
            jackpotVault: address(jackpotVault),
            treasuryRouter: address(treasuryRouter),
            dailyDraw: address(dailyDraw)
        });
    }

    function _readParams(address deployer) internal view returns (DeployParams memory params) {
        params.admin = vm.envOr("ADMIN_ADDRESS", deployer);
        params.blobbyToken = vm.envAddress("BLOBBIE_TOKEN_ADDRESS");
        params.blobbieUsdFeed = vm.envAddress("BLOBBIE_USD_FEED_ADDRESS");
        params.vrfCoordinator = vm.envAddress("CHAINLINK_VRF_COORDINATOR");
        params.vrfKeyHash = vm.envBytes32("CHAINLINK_VRF_KEY_HASH");
        params.vrfSubscriptionId = vm.envUint("CHAINLINK_VRF_SUBSCRIPTION_ID");
        params.treasury = vm.envAddress("TREASURY_WALLET");
        params.operationalWallet = vm.envOr("OPERATIONAL_WALLET", address(0));
        params.maxPriceAge = vm.envOr("MAX_PRICE_AGE", uint256(1 hours));
        params.jackpotThresholdUsdE18 = vm.envOr("JACKPOT_THRESHOLD_USD_E18", uint256(100_000e18));
        params.jackpotContributionBps = uint16(vm.envOr("JACKPOT_CONTRIBUTION_BPS", uint256(1_000)));
        params.ticketThreshold = uint32(vm.envOr("DRAW_TICKET_THRESHOLD", uint256(300)));
        params.roundDuration = uint64(vm.envOr("DRAW_ROUND_DURATION", uint256(24 hours)));
        params.ticketUsdPriceE18 = vm.envOr("DRAW_TICKET_USD_PRICE_E18", uint256(1e18));
        params.vrfRequestConfirmations = uint16(vm.envOr("CHAINLINK_VRF_REQUEST_CONFIRMATIONS", uint256(3)));
        params.vrfCallbackGasLimit = uint32(vm.envOr("CHAINLINK_VRF_CALLBACK_GAS_LIMIT", uint256(500_000)));
        params.vrfExtraArgs = vm.envOr("CHAINLINK_VRF_EXTRA_ARGS", bytes(""));
    }
}
