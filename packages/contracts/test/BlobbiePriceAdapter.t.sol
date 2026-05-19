// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { BlobbiePriceAdapter } from "../src/BlobbiePriceAdapter.sol";
import { IBlobbiePriceAdapter } from "../src/interfaces/IBlobbiePriceAdapter.sol";
import { MockBlobbieToken } from "../src/mocks/MockBlobbieToken.sol";
import { MockPriceFeed } from "../src/mocks/MockPriceFeed.sol";

interface Vm {
    function expectEmit(bool checkTopic1, bool checkTopic2, bool checkTopic3, bool checkData) external;
    function expectRevert() external;
    function expectRevert(bytes4 selector) external;
    function warp(uint256 newTimestamp) external;
}

contract BlobbiePriceAdapterTest {
    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    event ManualFallbackPriceUpdated(uint256 blobbieUsdPriceE18, uint256 updatedAt);
    event ManualFallbackUpdated(bool enabled);
    event MaxPriceAgeUpdated(uint256 maxPriceAge);

    function testCalculatesOneUsdTicketPriceCorrectly() external {
        (, BlobbiePriceAdapter adapter,) = _deployAdapter(18, 2e18, 1 hours, 0);

        require(adapter.getTicketPriceInBlobbie() == 0.5 ether, "unexpected ticket price");
        require(adapter.getBlobbieAmountForUsd(5e18) == 2.5 ether, "unexpected usd quote");
        require(adapter.getBlobbieUsdPriceE18() == 2e18, "unexpected normalized price");
    }

    function testHandlesOracleDecimalsCorrectly() external {
        (, BlobbiePriceAdapter adapter,) = _deployAdapter(6, 2_500_000, 1 hours, 0);

        require(adapter.getBlobbieUsdPriceE18() == 2.5e18, "unexpected normalized decimal price");
        require(adapter.getTicketPriceInBlobbie() == 0.4 ether, "unexpected decimal quote");
    }

    function testRejectsStaleOraclePrice() external {
        vm.warp(10 days);
        (MockPriceFeed feed, BlobbiePriceAdapter adapter,) = _deployAdapter(18, 1e18, 1 hours, 0);
        feed.setAnswerWithUpdatedAt(1e18, block.timestamp - 2 hours);

        vm.expectRevert(IBlobbiePriceAdapter.StalePrice.selector);
        adapter.getBlobbieUsdPriceE18();
    }

    function testRejectsZeroAndNegativePrice() external {
        (MockPriceFeed feed, BlobbiePriceAdapter adapter,) = _deployAdapter(18, 1e18, 1 hours, 0);

        feed.setAnswer(0);
        vm.expectRevert(IBlobbiePriceAdapter.InvalidPrice.selector);
        adapter.getBlobbieUsdPriceE18();

        feed.setAnswer(-1);
        vm.expectRevert(IBlobbiePriceAdapter.InvalidPrice.selector);
        adapter.getBlobbieUsdPriceE18();
    }

    function testFallbackDisabledByDefault() external {
        vm.warp(10 days);
        (MockPriceFeed feed, BlobbiePriceAdapter adapter,) = _deployAdapter(18, 1e18, 1 hours, 3e18);
        feed.setAnswerWithUpdatedAt(1e18, block.timestamp - 2 hours);

        require(!adapter.manualFallbackEnabled(), "fallback enabled by default");
        vm.expectRevert(IBlobbiePriceAdapter.StalePrice.selector);
        adapter.getBlobbieUsdPriceE18();
    }

    function testFallbackEmitsEvents() external {
        vm.warp(10 days);
        (MockPriceFeed feed, BlobbiePriceAdapter adapter,) = _deployAdapter(18, 1e18, 1 hours, 0);

        vm.expectEmit(false, false, false, true);
        emit ManualFallbackPriceUpdated(3e18, block.timestamp);
        adapter.setManualFallbackPrice(3e18);

        vm.expectEmit(false, false, false, true);
        emit ManualFallbackUpdated(true);
        adapter.enableManualFallback(true);

        feed.setAnswerWithUpdatedAt(1e18, block.timestamp - 2 hours);
        require(adapter.getBlobbieUsdPriceE18() == 3e18, "fallback price not active");
    }

    function testOnlyConfigRoleCanUpdateConfig() external {
        (, BlobbiePriceAdapter adapter,) = _deployAdapter(18, 1e18, 1 hours, 0);
        UnauthorizedCaller caller = new UnauthorizedCaller();

        require(!caller.trySetMaxPriceAge(adapter, 2 hours), "unauthorized config update");

        adapter.grantRole(adapter.CONFIG_ROLE(), address(caller));
        require(caller.trySetMaxPriceAge(adapter, 2 hours), "authorized config update failed");
        require(adapter.maxPriceAge() == 2 hours, "max age not updated");
    }

    function testSetMaxPriceAgeEmitsEvent() external {
        (, BlobbiePriceAdapter adapter,) = _deployAdapter(18, 1e18, 1 hours, 0);

        vm.expectEmit(false, false, false, true);
        emit MaxPriceAgeUpdated(2 hours);
        adapter.setMaxPriceAge(2 hours);
    }

    function testPausedAdapterRejectsPricingReads() external {
        (, BlobbiePriceAdapter adapter,) = _deployAdapter(18, 1e18, 1 hours, 0);
        adapter.pause();

        vm.expectRevert();
        adapter.getTicketPriceInBlobbie();
    }

    function testFuzzUsdQuoteScalesLinearly(uint96 usdAmount, uint96 price) external {
        uint256 boundedUsd = 1 + (uint256(usdAmount) % 1_000_000e18);
        uint256 boundedPrice = 1e12 + (uint256(price) % 1_000e18);
        (, BlobbiePriceAdapter adapter,) = _deployAdapter(18, int256(boundedPrice), 1 hours, 0);

        uint256 expected = (boundedUsd * 1 ether) / boundedPrice;
        require(adapter.getBlobbieAmountForUsd(boundedUsd) == expected, "quote mismatch");
    }

    function testFuzzOracleDecimalNormalization(uint8 decimals, uint96 answer) external {
        uint8 boundedDecimals = decimals % 19;
        uint256 boundedAnswer = 1 + (uint256(answer) % 1_000_000e18);
        (, BlobbiePriceAdapter adapter,) = _deployAdapter(boundedDecimals, int256(boundedAnswer), 1 hours, 0);

        uint256 expected = boundedDecimals > 18
            ? boundedAnswer / (10 ** (boundedDecimals - 18))
            : boundedAnswer * (10 ** (18 - boundedDecimals));
        require(adapter.getBlobbieUsdPriceE18() == expected, "normalized price mismatch");
    }

    function _deployAdapter(uint8 feedDecimals, int256 answer, uint256 maxPriceAge, uint256 manualFallbackPriceE18)
        internal
        returns (MockPriceFeed feed, BlobbiePriceAdapter adapter, MockBlobbieToken token)
    {
        token = new MockBlobbieToken();
        feed = new MockPriceFeed(feedDecimals, answer);
        adapter =
            new BlobbiePriceAdapter(address(this), address(token), address(feed), maxPriceAge, manualFallbackPriceE18);
    }
}

contract UnauthorizedCaller {
    function trySetMaxPriceAge(BlobbiePriceAdapter adapter, uint256 maxPriceAge) external returns (bool success) {
        (success,) = address(adapter).call(abi.encodeCall(BlobbiePriceAdapter.setMaxPriceAge, (maxPriceAge)));
    }
}
