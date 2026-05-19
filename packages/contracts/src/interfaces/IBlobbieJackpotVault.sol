// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IBlobbieJackpotVault {
    struct JackpotConfig {
        uint256 triggerAmount;
        uint16 contributionBps;
        address treasury;
    }

    event JackpotConfigUpdated(uint256 triggerAmount, uint16 contributionBps, address indexed treasury);
    event JackpotFunded(uint256 indexed roundId, address indexed payer, uint256 amount);
    event JackpotReserved(uint256 indexed roundId, uint256 amount);
    event JackpotPaid(uint256 indexed roundId, address indexed winner, uint256 amount);

    error InvalidConfig();
    error InvalidRecipient();
    error InsufficientReserve();
    error UnsupportedToken();

    function reserve() external view returns (uint256);

    function config() external view returns (JackpotConfig memory);

    function fund(uint256 roundId, uint256 amount) external;

    function reserveForRound(uint256 roundId, uint256 amount) external;

    function payJackpot(uint256 roundId, address winner, uint256 amount) external;
}
