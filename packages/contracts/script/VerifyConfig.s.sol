// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { BlobbieDailyDraw } from "../src/BlobbieDailyDraw.sol";
import { BlobbieJackpotVault } from "../src/BlobbieJackpotVault.sol";
import { BlobbiePriceAdapter } from "../src/BlobbiePriceAdapter.sol";

contract VerifyConfig {
    struct ConfigSnapshot {
        address dailyDraw;
        address priceAdapter;
        address jackpotVault;
        uint256 currentRoundId;
        uint256 jackpotReserve;
        uint256 tokenUsdPrice8;
        uint256 tokenUsdPriceUpdatedAt;
    }

    function run(address dailyDraw_, address priceAdapter_, address jackpotVault_)
        external
        view
        returns (ConfigSnapshot memory snapshot)
    {
        BlobbieDailyDraw dailyDraw = BlobbieDailyDraw(dailyDraw_);
        BlobbiePriceAdapter priceAdapter = BlobbiePriceAdapter(priceAdapter_);
        BlobbieJackpotVault jackpotVault = BlobbieJackpotVault(jackpotVault_);
        (uint256 price8, uint256 updatedAt) = priceAdapter.tokenUsdPrice8();

        snapshot = ConfigSnapshot({
            dailyDraw: dailyDraw_,
            priceAdapter: priceAdapter_,
            jackpotVault: jackpotVault_,
            currentRoundId: dailyDraw.currentRoundId(),
            jackpotReserve: jackpotVault.reserve(),
            tokenUsdPrice8: price8,
            tokenUsdPriceUpdatedAt: updatedAt
        });
    }
}
