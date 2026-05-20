// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { IBlobbieJackpotVault } from "./interfaces/IBlobbieJackpotVault.sol";
import { IBlobbiePriceAdapter } from "./interfaces/IBlobbiePriceAdapter.sol";

contract BlobbieJackpotVault is AccessControl, Pausable, ReentrancyGuard, IBlobbieJackpotVault {
    using SafeERC20 for IERC20;

    bytes32 public constant VAULT_ADMIN_ROLE = keccak256("VAULT_ADMIN_ROLE");
    bytes32 public constant DRAW_ROLE = keccak256("DRAW_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    IERC20 public immutable blobbyToken;
    uint256 public constant DEFAULT_THRESHOLD_USD_E18 = 100_000e18;

    JackpotConfig private _config;
    uint256 private _totalReserve;
    uint256 public currentCycleId;

    struct EntryRange {
        address user;
        uint256 startInclusive;
        uint256 endExclusive;
    }

    mapping(uint256 cycleId => JackpotCycle cycle) private _cycles;
    mapping(uint256 cycleId => EntryRange[] ranges) private _entryRanges;
    mapping(uint256 cycleId => mapping(address user => uint256 ticketCount)) public eligibleTicketsByUser;
    mapping(uint256 cycleId => bool emitted) public thresholdReachedEmitted;
    mapping(address user => bool banned) public bannedWallet;
    mapping(address user => bool fraudRejected) public fraudRejectedWallet;

    constructor(address admin, address blobbyToken_, JackpotConfig memory initialConfig) {
        if (admin == address(0) || blobbyToken_ == address(0)) revert InvalidConfig();

        blobbyToken = IERC20(blobbyToken_);

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(VAULT_ADMIN_ROLE, admin);
        _grantRole(DRAW_ROLE, admin);
        _grantRole(PAUSER_ROLE, admin);

        _setConfig(_normalizeConfig(initialConfig));
        _startNextCycle();
    }

    function setConfig(JackpotConfig calldata newConfig) external onlyRole(VAULT_ADMIN_ROLE) {
        _setConfig(_normalizeConfig(newConfig));
    }

    function setThresholdUsdE18(uint256 thresholdUsdE18) external onlyRole(VAULT_ADMIN_ROLE) {
        if (thresholdUsdE18 == 0) revert InvalidConfig();
        _config.thresholdUsdE18 = thresholdUsdE18;
        emit JackpotConfigUpdated(_config.thresholdUsdE18, _config.contributionBps, _config.priceAdapter);
    }

    function setWalletStatus(address user, bool banned, bool fraudRejected) external onlyRole(VAULT_ADMIN_ROLE) {
        if (user == address(0)) revert InvalidRecipient();
        bannedWallet[user] = banned;
        fraudRejectedWallet[user] = fraudRejected;
        emit JackpotWalletStatusUpdated(user, banned, fraudRejected);
    }

    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function reserve() external view returns (uint256) {
        return _totalReserve;
    }

    function config() external view returns (JackpotConfig memory) {
        return _config;
    }

    function getCycle(uint256 cycleId) external view returns (JackpotCycle memory) {
        return _cycles[cycleId];
    }

    function entryRangeCount(uint256 cycleId) external view returns (uint256) {
        return _entryRanges[cycleId].length;
    }

    function getEntryRange(uint256 cycleId, uint256 index)
        external
        view
        returns (address user, uint256 startInclusive, uint256 endExclusive)
    {
        EntryRange storage range = _entryRanges[cycleId][index];
        return (range.user, range.startInclusive, range.endExclusive);
    }

    function contributeFromDraw(uint256 amount) external onlyRole(DRAW_ROLE) nonReentrant whenNotPaused {
        if (amount == 0) revert InvalidAmount();
        blobbyToken.safeTransferFrom(msg.sender, address(this), amount);
        JackpotCycle storage cycle = _cycles[currentCycleId];
        cycle.reserveBalance += amount;
        cycle.totalContributed += amount;
        _totalReserve += amount;
        emit JackpotContributionReceived(currentCycleId, msg.sender, amount);
        _emitThresholdReachedIfNeeded(cycle);
    }

    function recordEligibleTickets(address user, uint256 ticketCount) external onlyRole(DRAW_ROLE) whenNotPaused {
        if (user == address(0)) revert InvalidRecipient();
        if (ticketCount == 0) revert InvalidAmount();
        if (bannedWallet[user] || fraudRejectedWallet[user]) revert WalletExcluded();

        JackpotCycle storage cycle = _cycles[currentCycleId];
        uint256 start = cycle.eligibleTicketCount;
        uint256 end = start + ticketCount;
        cycle.eligibleTicketCount = end;
        eligibleTicketsByUser[currentCycleId][user] += ticketCount;
        _entryRanges[currentCycleId].push(EntryRange({ user: user, startInclusive: start, endExclusive: end }));
        emit JackpotEligibleTicketsRecorded(currentCycleId, user, ticketCount, start, end);
    }

    function recordExcludedTickets(address user, uint256 ticketCount, TicketExclusion exclusion)
        external
        onlyRole(DRAW_ROLE)
        whenNotPaused
    {
        if (user == address(0)) revert InvalidRecipient();
        if (ticketCount == 0) revert InvalidAmount();
        if (exclusion == TicketExclusion.None) revert InvalidConfig();
        emit JackpotTicketsExcluded(currentCycleId, user, ticketCount, exclusion);
    }

    function isThresholdMet() external view returns (bool) {
        return _cycles[currentCycleId].reserveBalance >= jackpotThresholdInBlobbie();
    }

    function jackpotThresholdInBlobbie() public view returns (uint256) {
        return IBlobbiePriceAdapter(_config.priceAdapter).getBlobbieAmountForUsd(_config.thresholdUsdE18);
    }

    function requestJackpotRandomness(uint256 roundId, uint256 requestId)
        external
        onlyRole(DRAW_ROLE)
        whenNotPaused
        returns (uint256 cycleId)
    {
        cycleId = currentCycleId;
        JackpotCycle storage cycle = _cycles[cycleId];
        if (cycle.settled) revert SettlementAlreadyCompleted();
        if (cycle.randomnessRequested) revert SettlementAlreadyRequested();
        if (cycle.eligibleTicketCount == 0) revert NoEligibleEntries();
        if (cycle.reserveBalance < jackpotThresholdInBlobbie()) revert ThresholdNotMet();

        _emitThresholdReachedIfNeeded(cycle);
        cycle.randomnessRequested = true;
        cycle.randomnessRequestId = requestId;
        emit JackpotRandomnessRequested(cycleId, roundId, requestId);
    }

    function settleJackpotWinner(uint256 cycleId, uint256 randomness)
        external
        onlyRole(DRAW_ROLE)
        nonReentrant
        whenNotPaused
        returns (address winner, uint256 amount)
    {
        JackpotCycle storage cycle = _cycles[cycleId];
        if (!cycle.randomnessRequested) revert SettlementNotRequested();
        if (cycle.settled) revert SettlementAlreadyCompleted();
        if (cycle.reserveBalance == 0) revert InsufficientReserve();

        winner = _selectEligibleWinner(cycleId, randomness);
        amount = cycle.reserveBalance;
        emit JackpotWinnerSelected(cycleId, winner, amount);
        cycle.reserveBalance = 0;
        cycle.winner = winner;
        cycle.paidAmount = amount;
        cycle.endedAt = block.timestamp;
        cycle.settled = true;
        _totalReserve -= amount;

        blobbyToken.safeTransfer(winner, amount);
        emit JackpotPaid(cycleId, winner, amount);
        uint256 nextCycleId = _startNextCycle();
        emit JackpotCycleReset(cycleId, nextCycleId);
    }

    function emergencyRecoverUnsupportedToken(address token, address recipient, uint256 amount, string calldata reason)
        external
        onlyRole(VAULT_ADMIN_ROLE)
        nonReentrant
        whenPaused
    {
        if (token == address(blobbyToken)) revert UnsupportedToken();
        if (recipient == address(0)) revert InvalidRecipient();
        if (amount == 0) revert InvalidAmount();
        IERC20(token).safeTransfer(recipient, amount);
        emit EmergencyRecovery(token, recipient, amount, reason);
    }

    function emergencyRecoverExcessBlobbie(address recipient, uint256 amount, string calldata reason)
        external
        onlyRole(VAULT_ADMIN_ROLE)
        nonReentrant
        whenPaused
    {
        if (recipient == address(0)) revert InvalidRecipient();
        if (amount == 0) revert InvalidAmount();
        uint256 balance = blobbyToken.balanceOf(address(this));
        if (balance < _totalReserve || amount > balance - _totalReserve) revert ReserveAccountingMismatch();
        blobbyToken.safeTransfer(recipient, amount);
        emit EmergencyRecovery(address(blobbyToken), recipient, amount, reason);
    }

    function _setConfig(JackpotConfig memory newConfig) internal {
        if (
            newConfig.contributionBps > 10_000 || newConfig.priceAdapter == address(0)
                || newConfig.treasury == address(0)
        ) {
            revert InvalidConfig();
        }
        _config = newConfig;
        emit JackpotConfigUpdated(newConfig.thresholdUsdE18, newConfig.contributionBps, newConfig.priceAdapter);
    }

    function _normalizeConfig(JackpotConfig memory rawConfig) internal pure returns (JackpotConfig memory) {
        if (rawConfig.thresholdUsdE18 == 0) {
            rawConfig.thresholdUsdE18 = DEFAULT_THRESHOLD_USD_E18;
        }
        return rawConfig;
    }

    function _startNextCycle() internal returns (uint256 cycleId) {
        currentCycleId += 1;
        cycleId = currentCycleId;
        _cycles[cycleId] = JackpotCycle({
            id: cycleId,
            startedAt: block.timestamp,
            endedAt: 0,
            reserveBalance: 0,
            totalContributed: 0,
            eligibleTicketCount: 0,
            randomnessRequestId: 0,
            winner: address(0),
            paidAmount: 0,
            randomnessRequested: false,
            settled: false
        });
        emit JackpotCycleStarted(cycleId, block.timestamp);
    }

    function _emitThresholdReachedIfNeeded(JackpotCycle storage cycle) internal {
        uint256 thresholdAmount = jackpotThresholdInBlobbie();
        if (!thresholdReachedEmitted[cycle.id] && cycle.reserveBalance >= thresholdAmount) {
            thresholdReachedEmitted[cycle.id] = true;
            emit JackpotThresholdReached(cycle.id, cycle.reserveBalance, thresholdAmount);
        }
    }

    function _selectEligibleWinner(uint256 cycleId, uint256 randomness) internal view returns (address) {
        JackpotCycle storage cycle = _cycles[cycleId];
        if (cycle.eligibleTicketCount == 0) revert NoEligibleEntries();

        uint256 ticketIndex = randomness % cycle.eligibleTicketCount;
        EntryRange[] storage ranges = _entryRanges[cycleId];
        uint256 startRangeIndex = _rangeIndexForTicket(ranges, ticketIndex);

        for (uint256 offset = 0; offset < ranges.length; offset++) {
            EntryRange storage range = ranges[(startRangeIndex + offset) % ranges.length];
            if (!bannedWallet[range.user] && !fraudRejectedWallet[range.user]) {
                return range.user;
            }
        }
        revert NoEligibleWinner();
    }

    function _rangeIndexForTicket(EntryRange[] storage ranges, uint256 ticketIndex) internal view returns (uint256) {
        for (uint256 i = 0; i < ranges.length; i++) {
            if (ticketIndex >= ranges[i].startInclusive && ticketIndex < ranges[i].endExclusive) {
                return i;
            }
        }
        revert NoEligibleEntries();
    }
}
