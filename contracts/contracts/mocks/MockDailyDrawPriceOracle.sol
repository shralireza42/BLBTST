// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IDailyDrawPriceOracle} from "../interfaces/IDailyDrawPriceOracle.sol";

contract MockDailyDrawPriceOracle is IDailyDrawPriceOracle {
    uint256 public blobbiesPerUsd8;

    constructor(uint256 initialBlobbiesPerUsd8) {
        blobbiesPerUsd8 = initialBlobbiesPerUsd8;
    }

    function setBlobbiesPerUsd8(uint256 newBlobbiesPerUsd8) external {
        blobbiesPerUsd8 = newBlobbiesPerUsd8;
    }

    function blobbiesForUsd(uint256 usdAmount8) external view returns (uint256) {
        return (usdAmount8 * blobbiesPerUsd8) / 1e8;
    }
}
