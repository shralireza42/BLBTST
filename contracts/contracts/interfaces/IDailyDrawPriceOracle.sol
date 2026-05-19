// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IDailyDrawPriceOracle {
    /// @notice Returns the BLOBBIE token amount for a USD amount with 8 decimals.
    function blobbiesForUsd(uint256 usdAmount8) external view returns (uint256);
}
