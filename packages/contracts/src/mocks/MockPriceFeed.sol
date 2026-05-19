// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract MockPriceFeed {
    uint8 public immutable decimals;
    int256 public answer;
    uint256 public updatedAt;
    uint80 public roundId;

    constructor(uint8 decimals_, int256 initialAnswer) {
        decimals = decimals_;
        setAnswer(initialAnswer);
    }

    function setAnswer(int256 newAnswer) public {
        answer = newAnswer;
        updatedAt = block.timestamp;
        roundId += 1;
    }

    function latestRoundData() external view returns (uint80, int256, uint256, uint256, uint80) {
        return (roundId, answer, updatedAt, updatedAt, roundId);
    }
}
