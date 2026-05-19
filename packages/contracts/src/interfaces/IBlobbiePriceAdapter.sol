// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IBlobbiePriceAdapter {
    struct PriceQuote {
        uint256 usdAmountE18;
        uint256 blobbieAmount;
        uint256 blobbieUsdPriceE18;
        uint256 updatedAt;
        bool manualFallback;
    }

    event PriceFeedUpdated(address indexed blobbieUsdFeed);
    event MaxPriceAgeUpdated(uint256 maxPriceAge);
    event ManualFallbackPriceUpdated(uint256 blobbieUsdPriceE18, uint256 updatedAt);
    event ManualFallbackUpdated(bool enabled);

    error InvalidPrice();
    error InvalidFeed();
    error StalePrice();
    error InvalidAmount();
    error PriceUnavailable();

    function getBlobbieAmountForUsd(uint256 usdAmountE18) external view returns (uint256 blobbieAmount);

    function getTicketPriceInBlobbie() external view returns (uint256 blobbieAmount);

    function getBlobbieUsdPriceE18() external view returns (uint256 priceE18);

    function latestQuote(uint256 usdAmountE18) external view returns (PriceQuote memory quote);
}
