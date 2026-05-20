// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { console2 } from "forge-std/console2.sol";

import { BlobbieDailyDraw } from "../src/BlobbieDailyDraw.sol";
import { BlobbieJackpotVault } from "../src/BlobbieJackpotVault.sol";
import { BlobbiePriceAdapter } from "../src/BlobbiePriceAdapter.sol";
import { BlobbieTreasuryRouter } from "../src/BlobbieTreasuryRouter.sol";
import { IBlobbieJackpotVault } from "../src/interfaces/IBlobbieJackpotVault.sol";

interface VmVerify {
    function envAddress(string calldata name) external view returns (address);
    function envOr(string calldata name, address defaultValue) external view returns (address);
}

contract VerifyConfig {
    VmVerify private constant vm = VmVerify(address(uint160(uint256(keccak256("hevm cheat code")))));

    function run() external view returns (bool ok) {
        address dailyDrawAddress = vm.envAddress("DAILY_DRAW_CONTRACT_ADDRESS");
        address priceAdapterAddress = vm.envAddress("PRICE_ADAPTER_CONTRACT_ADDRESS");
        address jackpotVaultAddress = vm.envAddress("JACKPOT_VAULT_CONTRACT_ADDRESS");
        address treasuryRouterAddress = vm.envAddress("TREASURY_ROUTER_CONTRACT_ADDRESS");
        address operationalWallet = vm.envOr("OPERATIONAL_WALLET", address(0));

        _verifyCore(dailyDrawAddress, priceAdapterAddress, jackpotVaultAddress, treasuryRouterAddress);
        _verifyRoles(dailyDrawAddress, jackpotVaultAddress, treasuryRouterAddress, operationalWallet);
        return true;
    }

    function _verifyCore(
        address dailyDrawAddress,
        address priceAdapterAddress,
        address jackpotVaultAddress,
        address treasuryRouterAddress
    ) internal view {
        BlobbieDailyDraw dailyDraw = BlobbieDailyDraw(dailyDrawAddress);
        BlobbiePriceAdapter priceAdapter = BlobbiePriceAdapter(priceAdapterAddress);
        BlobbieJackpotVault jackpotVault = BlobbieJackpotVault(jackpotVaultAddress);

        (uint32 ticketThreshold, uint64 roundDuration, uint256 ticketUsdPriceE18,, address treasury) =
            dailyDraw.drawConfig();
        IBlobbieJackpotVault.JackpotConfig memory jackpotConfig = jackpotVault.config();
        uint256 priceE18 = priceAdapter.getBlobbieUsdPriceE18();

        console2.log("DailyDraw", dailyDrawAddress);
        console2.log("PriceAdapter", priceAdapterAddress);
        console2.log("JackpotVault", jackpotVaultAddress);
        console2.log("TreasuryRouter", treasuryRouterAddress);
        console2.log("CurrentRoundId", dailyDraw.currentRoundId());
        console2.log("JackpotReserve", jackpotVault.reserve());
        console2.log("BlobbieUsdPriceE18", priceE18);
        console2.log("JackpotThresholdUsdE18", jackpotConfig.thresholdUsdE18);
        console2.log("TicketThreshold", ticketThreshold);
        console2.log("RoundDuration", roundDuration);
        console2.log("TicketUsdPriceE18", ticketUsdPriceE18);
        console2.log("Treasury", treasury);

        require(dailyDrawAddress != address(0), "DAILY_DRAW_ZERO");
        require(priceAdapterAddress != address(0), "PRICE_ADAPTER_ZERO");
        require(jackpotVaultAddress != address(0), "JACKPOT_VAULT_ZERO");
        require(treasuryRouterAddress != address(0), "TREASURY_ROUTER_ZERO");
        require(dailyDraw.currentRoundId() != 0, "NO_ROUND_STARTED");
        require(priceE18 != 0, "PRICE_ZERO");
        require(jackpotConfig.thresholdUsdE18 != 0, "JACKPOT_THRESHOLD_ZERO");
        require(ticketThreshold == 300, "UNEXPECTED_TICKET_THRESHOLD");
        require(roundDuration == 24 hours, "UNEXPECTED_ROUND_DURATION");
        require(ticketUsdPriceE18 == 1e18, "UNEXPECTED_TICKET_PRICE");
        require(treasury != address(0), "TREASURY_ZERO");
    }

    function _verifyRoles(
        address dailyDrawAddress,
        address jackpotVaultAddress,
        address treasuryRouterAddress,
        address operationalWallet
    ) internal view {
        BlobbieDailyDraw dailyDraw = BlobbieDailyDraw(dailyDrawAddress);
        BlobbieJackpotVault jackpotVault = BlobbieJackpotVault(jackpotVaultAddress);
        BlobbieTreasuryRouter treasuryRouter = BlobbieTreasuryRouter(treasuryRouterAddress);

        bool dailyDrawHasVaultRole = jackpotVault.hasRole(jackpotVault.DRAW_ROLE(), dailyDrawAddress);
        bool dailyDrawHasRouterRole = treasuryRouter.hasRole(treasuryRouter.DRAW_ROLE(), dailyDrawAddress);
        bool operationalHasOperatorRole =
            operationalWallet == address(0) ? true : dailyDraw.hasRole(dailyDraw.OPERATOR_ROLE(), operationalWallet);
        bool operationalHasTopUpRole =
            operationalWallet == address(0) ? true : dailyDraw.hasRole(dailyDraw.TOP_UP_ROLE(), operationalWallet);

        console2.log("DailyDrawHasVaultRole", dailyDrawHasVaultRole);
        console2.log("DailyDrawHasRouterRole", dailyDrawHasRouterRole);
        console2.log("OperationalHasOperatorRole", operationalHasOperatorRole);
        console2.log("OperationalHasTopUpRole", operationalHasTopUpRole);

        require(dailyDrawHasVaultRole, "DAILY_DRAW_MISSING_VAULT_ROLE");
        require(dailyDrawHasRouterRole, "DAILY_DRAW_MISSING_ROUTER_ROLE");
        require(operationalHasOperatorRole, "OPERATIONAL_MISSING_OPERATOR_ROLE");
        require(operationalHasTopUpRole, "OPERATIONAL_MISSING_TOP_UP_ROLE");
    }
}
