// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IVRFCoordinatorV2Plus} from "../interfaces/IVRFCoordinatorV2Plus.sol";

interface IRawVrfConsumer {
    function rawFulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) external;
}

contract MockVRFCoordinatorV2Plus is IVRFCoordinatorV2Plus {
    uint256 public nextRequestId = 1;

    event RandomWordsRequested(uint256 indexed requestId);

    function requestRandomWords(RandomWordsRequest calldata) external returns (uint256 requestId) {
        requestId = nextRequestId++;
        emit RandomWordsRequested(requestId);
    }

    function fulfill(address consumer, uint256 requestId, uint256[] calldata randomWords) external {
        IRawVrfConsumer(consumer).rawFulfillRandomWords(requestId, randomWords);
    }
}
