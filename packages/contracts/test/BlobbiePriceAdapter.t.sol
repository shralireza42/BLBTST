// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { BlobbiePriceAdapter } from "../src/BlobbiePriceAdapter.sol";
import { MockBlobbieToken } from "../src/mocks/MockBlobbieToken.sol";
import { MockPriceFeed } from "../src/mocks/MockPriceFeed.sol";

contract BlobbiePriceAdapterTest {
    function testQuoteTokenAmountForUsd() external {
        MockBlobbieToken token = new MockBlobbieToken();
        MockPriceFeed feed = new MockPriceFeed(8, 2e8);
        BlobbiePriceAdapter adapter = new BlobbiePriceAdapter(address(this), address(token), address(feed), 1 hours, 0);

        require(adapter.quoteTokenAmountForUsd(1e8) == 0.5 ether, "unexpected quote");
    }
}
