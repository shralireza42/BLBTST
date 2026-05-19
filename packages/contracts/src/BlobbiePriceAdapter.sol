// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";

import { IBlobbiePriceAdapter } from "./interfaces/IBlobbiePriceAdapter.sol";

interface IAggregatorV3Like {
    function decimals() external view returns (uint8);

    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);
}

contract BlobbiePriceAdapter is AccessControl, Pausable, IBlobbiePriceAdapter {
    bytes32 public constant PRICE_ADMIN_ROLE = keccak256("PRICE_ADMIN_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    address public immutable blobbyToken;
    IAggregatorV3Like public tokenUsdFeed;
    uint256 public maxStaleness;
    uint256 public manualTokenUsdPrice8;
    uint256 public manualPriceUpdatedAt;
    bool public manualPricingEnabled;

    constructor(
        address admin,
        address blobbyToken_,
        address tokenUsdFeed_,
        uint256 maxStaleness_,
        uint256 initialManualTokenUsdPrice8
    ) {
        if (admin == address(0) || blobbyToken_ == address(0)) revert InvalidFeed();

        blobbyToken = blobbyToken_;
        tokenUsdFeed = IAggregatorV3Like(tokenUsdFeed_);
        maxStaleness = maxStaleness_;
        manualTokenUsdPrice8 = initialManualTokenUsdPrice8;
        manualPriceUpdatedAt = block.timestamp;
        manualPricingEnabled = tokenUsdFeed_ == address(0);

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(PRICE_ADMIN_ROLE, admin);
        _grantRole(PAUSER_ROLE, admin);
    }

    function setPriceFeed(address tokenUsdFeed_, uint256 maxStaleness_) external onlyRole(PRICE_ADMIN_ROLE) {
        tokenUsdFeed = IAggregatorV3Like(tokenUsdFeed_);
        maxStaleness = maxStaleness_;
        manualPricingEnabled = tokenUsdFeed_ == address(0);
        emit PriceFeedsUpdated(tokenUsdFeed_, maxStaleness_);
    }

    function setManualPrice(uint256 tokenUsdPrice8_) external onlyRole(PRICE_ADMIN_ROLE) {
        if (tokenUsdPrice8_ == 0) revert InvalidPrice();
        manualTokenUsdPrice8 = tokenUsdPrice8_;
        manualPriceUpdatedAt = block.timestamp;
        manualPricingEnabled = true;
        emit ManualPriceUpdated(tokenUsdPrice8_, block.timestamp);
    }

    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function quoteTokenAmountForUsd(uint256 usdAmount8) external view returns (uint256 tokenAmount) {
        if (usdAmount8 == 0) revert InvalidAmount();
        (uint256 price8,) = tokenUsdPrice8();
        return (usdAmount8 * 1e18) / price8;
    }

    function latestQuote(uint256 usdAmount8) external view returns (PriceQuote memory quote) {
        uint256 amount = this.quoteTokenAmountForUsd(usdAmount8);
        (uint256 price8, uint256 updatedAt) = tokenUsdPrice8();
        return PriceQuote({ usdAmount8: usdAmount8, tokenAmount: amount, tokenUsdPrice8: price8, updatedAt: updatedAt });
    }

    function tokenUsdPrice8() public view returns (uint256 price8, uint256 updatedAt) {
        if (manualPricingEnabled) {
            if (manualTokenUsdPrice8 == 0) revert InvalidPrice();
            return (manualTokenUsdPrice8, manualPriceUpdatedAt);
        }

        if (address(tokenUsdFeed) == address(0)) revert InvalidFeed();
        (, int256 answer,, uint256 feedUpdatedAt,) = tokenUsdFeed.latestRoundData();
        if (answer <= 0) revert InvalidPrice();
        if (maxStaleness != 0 && block.timestamp - feedUpdatedAt > maxStaleness) revert StalePrice();

        uint8 feedDecimals = tokenUsdFeed.decimals();
        uint256 normalized = uint256(answer);
        if (feedDecimals > 8) {
            normalized = normalized / (10 ** (feedDecimals - 8));
        } else if (feedDecimals < 8) {
            normalized = normalized * (10 ** (8 - feedDecimals));
        }
        return (normalized, feedUpdatedAt);
    }
}
