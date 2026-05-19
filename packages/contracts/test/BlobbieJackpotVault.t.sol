// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { BlobbieJackpotVault } from "../src/BlobbieJackpotVault.sol";
import { IBlobbieJackpotVault } from "../src/interfaces/IBlobbieJackpotVault.sol";
import { MockBlobbieToken } from "../src/mocks/MockBlobbieToken.sol";

contract BlobbieJackpotVaultTest {
    function testInitialConfig() external {
        MockBlobbieToken token = new MockBlobbieToken();
        BlobbieJackpotVault vault = new BlobbieJackpotVault(
            address(this),
            address(token),
            IBlobbieJackpotVault.JackpotConfig({
                triggerAmount: 100 ether, contributionBps: 1_000, treasury: address(this)
            })
        );

        IBlobbieJackpotVault.JackpotConfig memory config = vault.config();
        require(config.triggerAmount == 100 ether, "unexpected trigger");
        require(config.contributionBps == 1_000, "unexpected bps");
    }
}
