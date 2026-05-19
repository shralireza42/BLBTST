// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {IAggregatorV3} from "./interfaces/IAggregatorV3.sol";
import {IDailyDrawPriceOracle} from "./interfaces/IDailyDrawPriceOracle.sol";
import {IUniswapV2Pair} from "./interfaces/IUniswapV2Pair.sol";

/// @notice Quotes BLOBBIE/USD from a BLOBBIE-WBNB PancakeSwap-style pair and Chainlink BNB/USD.
contract BlobbyUsdOracle is AccessControl, IDailyDrawPriceOracle {
    bytes32 public constant ORACLE_ADMIN_ROLE = keccak256("ORACLE_ADMIN_ROLE");

    uint256 public constant USD_DECIMALS = 8;
    uint256 public constant BPS_DENOMINATOR = 10_000;

    IERC20Metadata public immutable blobby;
    address public immutable wrappedNative;
    IUniswapV2Pair public pair;
    IAggregatorV3 public nativeUsdFeed;

    uint256 public maxFeedStaleness;
    uint256 public minNativeReserve;
    uint256 public premiumBps;

    event PairUpdated(address indexed pair);
    event NativeUsdFeedUpdated(address indexed feed);
    event OracleSafetyUpdated(uint256 maxFeedStaleness, uint256 minNativeReserve, uint256 premiumBps);

    error InvalidAddress();
    error InvalidPair();
    error InvalidFeedAnswer();
    error StaleFeed();
    error InsufficientLiquidity();
    error PremiumTooHigh();

    constructor(
        address admin,
        address blobbyToken,
        address wrappedNativeToken,
        address pancakePair,
        address nativeUsdFeedAddress,
        uint256 initialMaxFeedStaleness,
        uint256 initialMinNativeReserve,
        uint256 initialPremiumBps
    ) {
        if (
            admin == address(0) || blobbyToken == address(0) || wrappedNativeToken == address(0)
                || pancakePair == address(0) || nativeUsdFeedAddress == address(0)
        ) {
            revert InvalidAddress();
        }
        if (initialPremiumBps > 2_000) {
            revert PremiumTooHigh();
        }

        blobby = IERC20Metadata(blobbyToken);
        wrappedNative = wrappedNativeToken;
        pair = IUniswapV2Pair(pancakePair);
        nativeUsdFeed = IAggregatorV3(nativeUsdFeedAddress);
        maxFeedStaleness = initialMaxFeedStaleness;
        minNativeReserve = initialMinNativeReserve;
        premiumBps = initialPremiumBps;

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ORACLE_ADMIN_ROLE, admin);

        _validatePair();
    }

    function setPair(address newPair) external onlyRole(ORACLE_ADMIN_ROLE) {
        if (newPair == address(0)) {
            revert InvalidAddress();
        }
        pair = IUniswapV2Pair(newPair);
        _validatePair();
        emit PairUpdated(newPair);
    }

    function setNativeUsdFeed(address newFeed) external onlyRole(ORACLE_ADMIN_ROLE) {
        if (newFeed == address(0)) {
            revert InvalidAddress();
        }
        nativeUsdFeed = IAggregatorV3(newFeed);
        emit NativeUsdFeedUpdated(newFeed);
    }

    function setSafetyConfig(uint256 newMaxFeedStaleness, uint256 newMinNativeReserve, uint256 newPremiumBps)
        external
        onlyRole(ORACLE_ADMIN_ROLE)
    {
        if (newPremiumBps > 2_000) {
            revert PremiumTooHigh();
        }
        maxFeedStaleness = newMaxFeedStaleness;
        minNativeReserve = newMinNativeReserve;
        premiumBps = newPremiumBps;
        emit OracleSafetyUpdated(newMaxFeedStaleness, newMinNativeReserve, newPremiumBps);
    }

    function blobbiesForUsd(uint256 usdAmount8) external view returns (uint256) {
        if (usdAmount8 == 0) {
            return 0;
        }

        (uint256 tokenReserve, uint256 nativeReserve) = _reserves();
        if (nativeReserve < minNativeReserve) {
            revert InsufficientLiquidity();
        }

        (, int256 answer,, uint256 updatedAt,) = nativeUsdFeed.latestRoundData();
        if (answer <= 0) {
            revert InvalidFeedAnswer();
        }
        if (maxFeedStaleness != 0 && block.timestamp - updatedAt > maxFeedStaleness) {
            revert StaleFeed();
        }

        uint256 feedScale = 10 ** nativeUsdFeed.decimals();
        uint256 baseAmount = (usdAmount8 * tokenReserve * 1e18 * feedScale)
            / ((10 ** USD_DECIMALS) * nativeReserve * uint256(answer));

        return (baseAmount * (BPS_DENOMINATOR + premiumBps)) / BPS_DENOMINATOR;
    }

    function reserves() external view returns (uint256 tokenReserve, uint256 nativeReserve) {
        return _reserves();
    }

    function _reserves() internal view returns (uint256 tokenReserve, uint256 nativeReserve) {
        (uint112 reserve0, uint112 reserve1,) = pair.getReserves();
        if (pair.token0() == address(blobby) && pair.token1() == wrappedNative) {
            return (uint256(reserve0), uint256(reserve1));
        }
        if (pair.token1() == address(blobby) && pair.token0() == wrappedNative) {
            return (uint256(reserve1), uint256(reserve0));
        }
        revert InvalidPair();
    }

    function _validatePair() internal view {
        bool valid = (pair.token0() == address(blobby) && pair.token1() == wrappedNative)
            || (pair.token1() == address(blobby) && pair.token0() == wrappedNative);
        if (!valid) {
            revert InvalidPair();
        }
    }
}
