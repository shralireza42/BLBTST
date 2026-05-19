// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { IBlobbieJackpotVault } from "./interfaces/IBlobbieJackpotVault.sol";

contract BlobbieJackpotVault is AccessControl, Pausable, ReentrancyGuard, IBlobbieJackpotVault {
    using SafeERC20 for IERC20;

    bytes32 public constant VAULT_ADMIN_ROLE = keccak256("VAULT_ADMIN_ROLE");
    bytes32 public constant DRAW_ROLE = keccak256("DRAW_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    IERC20 public immutable blobbyToken;
    JackpotConfig private _config;
    uint256 private _reserve;
    mapping(uint256 roundId => uint256 amount) public reservedByRound;

    constructor(address admin, address blobbyToken_, JackpotConfig memory initialConfig) {
        if (admin == address(0) || blobbyToken_ == address(0)) revert InvalidConfig();

        blobbyToken = IERC20(blobbyToken_);
        _setConfig(initialConfig);

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(VAULT_ADMIN_ROLE, admin);
        _grantRole(DRAW_ROLE, admin);
        _grantRole(PAUSER_ROLE, admin);
    }

    function setConfig(JackpotConfig calldata newConfig) external onlyRole(VAULT_ADMIN_ROLE) {
        _setConfig(newConfig);
    }

    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function reserve() external view returns (uint256) {
        return _reserve;
    }

    function config() external view returns (JackpotConfig memory) {
        return _config;
    }

    function fund(uint256 roundId, uint256 amount) external nonReentrant whenNotPaused {
        if (amount == 0) revert InvalidConfig();
        blobbyToken.safeTransferFrom(msg.sender, address(this), amount);
        _reserve += amount;
        emit JackpotFunded(roundId, msg.sender, amount);
    }

    function reserveForRound(uint256 roundId, uint256 amount) external onlyRole(DRAW_ROLE) whenNotPaused {
        if (amount > _reserve) revert InsufficientReserve();
        reservedByRound[roundId] += amount;
        emit JackpotReserved(roundId, amount);
    }

    function payJackpot(uint256 roundId, address winner, uint256 amount)
        external
        onlyRole(DRAW_ROLE)
        nonReentrant
        whenNotPaused
    {
        if (winner == address(0)) revert InvalidRecipient();
        if (amount > _reserve) revert InsufficientReserve();
        _reserve -= amount;
        blobbyToken.safeTransfer(winner, amount);
        emit JackpotPaid(roundId, winner, amount);
    }

    function _setConfig(JackpotConfig memory newConfig) internal {
        if (newConfig.contributionBps > 10_000 || newConfig.treasury == address(0)) revert InvalidConfig();
        _config = newConfig;
        emit JackpotConfigUpdated(newConfig.triggerAmount, newConfig.contributionBps, newConfig.treasury);
    }
}
