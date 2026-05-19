// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract BlobbieTreasuryRouter is AccessControl, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    bytes32 public constant ROUTER_ADMIN_ROLE = keccak256("ROUTER_ADMIN_ROLE");
    bytes32 public constant DRAW_ROLE = keccak256("DRAW_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    struct SplitConfig {
        address prizePool;
        address jackpotVault;
        address treasury;
        uint16 jackpotBps;
        uint16 treasuryBps;
    }

    IERC20 public immutable blobbyToken;
    SplitConfig public splitConfig;

    event SplitConfigUpdated(SplitConfig config);
    event RevenueRouted(
        uint256 indexed roundId, uint256 grossAmount, uint256 prizeAmount, uint256 jackpotAmount, uint256 treasuryAmount
    );

    error InvalidConfig();
    error InvalidAmount();

    constructor(address admin, address blobbyToken_, SplitConfig memory initialConfig) {
        if (admin == address(0) || blobbyToken_ == address(0)) revert InvalidConfig();
        blobbyToken = IERC20(blobbyToken_);
        _setSplitConfig(initialConfig);

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ROUTER_ADMIN_ROLE, admin);
        _grantRole(DRAW_ROLE, admin);
        _grantRole(PAUSER_ROLE, admin);
    }

    function setSplitConfig(SplitConfig calldata newConfig) external onlyRole(ROUTER_ADMIN_ROLE) {
        _setSplitConfig(newConfig);
    }

    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function routeRevenue(uint256 roundId, uint256 grossAmount)
        external
        onlyRole(DRAW_ROLE)
        nonReentrant
        whenNotPaused
        returns (uint256 prizeAmount, uint256 jackpotAmount, uint256 treasuryAmount)
    {
        if (grossAmount == 0) revert InvalidAmount();
        jackpotAmount = (grossAmount * splitConfig.jackpotBps) / 10_000;
        treasuryAmount = (grossAmount * splitConfig.treasuryBps) / 10_000;
        prizeAmount = grossAmount - jackpotAmount - treasuryAmount;
        emit RevenueRouted(roundId, grossAmount, prizeAmount, jackpotAmount, treasuryAmount);
    }

    function _setSplitConfig(SplitConfig memory newConfig) internal {
        if (
            newConfig.prizePool == address(0) || newConfig.jackpotVault == address(0)
                || newConfig.treasury == address(0)
                || uint256(newConfig.jackpotBps) + uint256(newConfig.treasuryBps) > 10_000
        ) {
            revert InvalidConfig();
        }
        splitConfig = newConfig;
        emit SplitConfigUpdated(newConfig);
    }
}
