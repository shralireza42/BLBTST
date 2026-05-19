// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IVRFConsumerLike {
    function rawFulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) external;
}

contract MockVRFCoordinator {
    struct RandomWordsRequest {
        bytes32 keyHash;
        uint256 subId;
        uint16 requestConfirmations;
        uint32 callbackGasLimit;
        uint32 numWords;
        bytes extraArgs;
    }

    uint256 public nextRequestId = 1;
    mapping(uint256 requestId => address requester) public requesters;

    event RandomWordsRequested(uint256 indexed requestId, address indexed requester, uint32 numWords);
    event RandomWordsFulfilled(uint256 indexed requestId, address indexed consumer);

    function requestRandomWords(RandomWordsRequest calldata request) external returns (uint256 requestId) {
        requestId = nextRequestId++;
        requesters[requestId] = msg.sender;
        emit RandomWordsRequested(requestId, msg.sender, request.numWords);
    }

    function fulfill(address consumer, uint256 requestId, uint256[] calldata randomWords) external {
        IVRFConsumerLike(consumer).rawFulfillRandomWords(requestId, randomWords);
        emit RandomWordsFulfilled(requestId, consumer);
    }
}
