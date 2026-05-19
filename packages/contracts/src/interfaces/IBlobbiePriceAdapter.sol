// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IBlobbiePriceAdapter {
    struct PriceQuote {
        uint256 usdAmount8;
        uint256 tokenAmount;
        uint256 tokenUsdPrice8;
        uint256 updatedAt;
    }

    event PriceFeedsUpdated(address indexed tokenUsdFeed, uint256 maxStaleness);
    event ManualPriceUpdated(uint256 tokenUsdPrice8, uint256 updatedAt);

    error InvalidPrice();
    error InvalidFeed();
    error StalePrice();
    error InvalidAmount();

    function quoteTokenAmountForUsd(uint256 usdAmount8) external view returns (uint256 tokenAmount);

    function latestQuote(uint256 usdAmount8) external view returns (PriceQuote memory quote);

    function tokenUsdPrice8() external view returns (uint256 price8, uint256 updatedAt);
}
