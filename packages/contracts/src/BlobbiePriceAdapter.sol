// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import { IBlobbiePriceAdapter } from "./interfaces/IBlobbiePriceAdapter.sol";

interface IAggregatorV3Like {
    function decimals() external view returns (uint8);

    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);
}

contract BlobbiePriceAdapter is AccessControl, Pausable, IBlobbiePriceAdapter {
    bytes32 public constant CONFIG_ROLE = keccak256("CONFIG_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    uint256 public constant ONE_USD_E18 = 1e18;

    IERC20Metadata public immutable blobbyToken;
    uint256 public immutable blobbyTokenUnit;

    IAggregatorV3Like public blobbieUsdFeed;
    uint256 public maxPriceAge;
    uint256 public manualFallbackPriceE18;
    uint256 public manualPriceUpdatedAt;
    bool public manualFallbackEnabled;

    enum PriceReadStatus {
        Ok,
        InvalidFeed,
        InvalidPrice,
        StalePrice
    }

    constructor(
        address admin,
        address blobbyToken_,
        address blobbieUsdFeed_,
        uint256 maxPriceAge_,
        uint256 initialManualFallbackPriceE18
    ) {
        if (admin == address(0) || blobbyToken_ == address(0) || blobbieUsdFeed_ == address(0)) {
            revert InvalidFeed();
        }

        blobbyToken = IERC20Metadata(blobbyToken_);
        blobbyTokenUnit = 10 ** IERC20Metadata(blobbyToken_).decimals();
        blobbieUsdFeed = IAggregatorV3Like(blobbieUsdFeed_);
        maxPriceAge = maxPriceAge_;
        manualFallbackPriceE18 = initialManualFallbackPriceE18;
        manualPriceUpdatedAt = initialManualFallbackPriceE18 == 0 ? 0 : block.timestamp;
        manualFallbackEnabled = false;

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(CONFIG_ROLE, admin);
        _grantRole(PAUSER_ROLE, admin);

        emit PriceFeedUpdated(blobbieUsdFeed_);
        emit MaxPriceAgeUpdated(maxPriceAge_);
        if (initialManualFallbackPriceE18 != 0) {
            emit ManualFallbackPriceUpdated(initialManualFallbackPriceE18, block.timestamp);
        }
    }

    function setPriceFeed(address blobbieUsdFeed_) external onlyRole(CONFIG_ROLE) {
        if (blobbieUsdFeed_ == address(0)) revert InvalidFeed();
        blobbieUsdFeed = IAggregatorV3Like(blobbieUsdFeed_);
        emit PriceFeedUpdated(blobbieUsdFeed_);
    }

    function setManualFallbackPrice(uint256 blobbieUsdPriceE18_) external onlyRole(CONFIG_ROLE) {
        if (blobbieUsdPriceE18_ == 0) revert InvalidPrice();
        manualFallbackPriceE18 = blobbieUsdPriceE18_;
        manualPriceUpdatedAt = block.timestamp;
        emit ManualFallbackPriceUpdated(blobbieUsdPriceE18_, block.timestamp);
    }

    function enableManualFallback(bool enabled) external onlyRole(CONFIG_ROLE) {
        if (enabled && manualFallbackPriceE18 == 0) revert InvalidPrice();
        manualFallbackEnabled = enabled;
        emit ManualFallbackUpdated(enabled);
    }

    function setMaxPriceAge(uint256 maxPriceAge_) external onlyRole(CONFIG_ROLE) {
        maxPriceAge = maxPriceAge_;
        emit MaxPriceAgeUpdated(maxPriceAge_);
    }

    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function getBlobbieAmountForUsd(uint256 usdAmountE18) public view whenNotPaused returns (uint256 blobbieAmount) {
        if (usdAmountE18 == 0) revert InvalidAmount();
        uint256 priceE18 = getBlobbieUsdPriceE18();
        return (usdAmountE18 * blobbyTokenUnit) / priceE18;
    }

    function getTicketPriceInBlobbie() external view returns (uint256 blobbieAmount) {
        return getBlobbieAmountForUsd(ONE_USD_E18);
    }

    function getBlobbieUsdPriceE18() public view whenNotPaused returns (uint256 priceE18) {
        (PriceReadStatus status, uint256 oraclePrice,) = _tryReadOraclePrice();
        if (status == PriceReadStatus.Ok) {
            return oraclePrice;
        }
        if (manualFallbackEnabled) {
            if (manualFallbackPriceE18 == 0) revert InvalidPrice();
            return manualFallbackPriceE18;
        }
        _revertForStatus(status);
    }

    function latestQuote(uint256 usdAmountE18) external view returns (PriceQuote memory quote) {
        uint256 amount = getBlobbieAmountForUsd(usdAmountE18);
        (PriceReadStatus status, uint256 oraclePrice, uint256 oracleUpdatedAt) = _tryReadOraclePrice();
        bool usingManualFallback = status != PriceReadStatus.Ok;
        uint256 price = usingManualFallback ? manualFallbackPriceE18 : oraclePrice;
        uint256 updatedAt = usingManualFallback ? manualPriceUpdatedAt : oracleUpdatedAt;
        return PriceQuote({
            usdAmountE18: usdAmountE18,
            blobbieAmount: amount,
            blobbieUsdPriceE18: price,
            updatedAt: usingManualFallback ? manualPriceUpdatedAt : updatedAt,
            manualFallback: usingManualFallback
        });
    }

    function quoteTokenAmountForUsd(uint256 usdAmount8) external view returns (uint256 tokenAmount) {
        return getBlobbieAmountForUsd(usdAmount8 * 1e10);
    }

    function tokenUsdPrice8() external view returns (uint256 price8, uint256 updatedAt) {
        (PriceReadStatus status, uint256 oraclePrice, uint256 oracleUpdatedAt) = _tryReadOraclePrice();
        if (status == PriceReadStatus.Ok) {
            return (oraclePrice / 1e10, oracleUpdatedAt);
        }
        if (manualFallbackEnabled) {
            return (manualFallbackPriceE18 / 1e10, manualPriceUpdatedAt);
        }
        _revertForStatus(status);
    }

    function _tryReadOraclePrice() internal view returns (PriceReadStatus status, uint256 priceE18, uint256 updatedAt) {
        if (address(blobbieUsdFeed) == address(0)) return (PriceReadStatus.InvalidFeed, 0, 0);
        (, int256 answer,, uint256 feedUpdatedAt,) = blobbieUsdFeed.latestRoundData();
        if (answer <= 0 || feedUpdatedAt == 0) return (PriceReadStatus.InvalidPrice, 0, feedUpdatedAt);
        if (maxPriceAge != 0 && block.timestamp - feedUpdatedAt > maxPriceAge) {
            return (PriceReadStatus.StalePrice, 0, feedUpdatedAt);
        }

        uint8 feedDecimals = blobbieUsdFeed.decimals();
        uint256 normalized = uint256(answer);
        // Casting is safe because negative or zero oracle answers are rejected above.
        if (feedDecimals > 18) {
            normalized = normalized / (10 ** (feedDecimals - 18));
        } else if (feedDecimals < 18) {
            normalized = normalized * (10 ** (18 - feedDecimals));
        }
        if (normalized == 0) return (PriceReadStatus.InvalidPrice, 0, feedUpdatedAt);
        return (PriceReadStatus.Ok, normalized, feedUpdatedAt);
    }

    function _revertForStatus(PriceReadStatus status) internal pure {
        if (status == PriceReadStatus.InvalidFeed) revert InvalidFeed();
        if (status == PriceReadStatus.InvalidPrice) revert InvalidPrice();
        if (status == PriceReadStatus.StalePrice) revert StalePrice();
        revert PriceUnavailable();
    }
}
