// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../../lib/infernet-sdk/src/consumer/Callback.sol";
import "../../../lib/infernet-sdk/lib/solady/src/auth/Ownable.sol";
import "../interfaces/IWorldID.sol";
import "./ByteHasher.sol"; // Make sure this path is correct

contract SimpleWorldIDInfernetIntegration is CallbackConsumer, Ownable {
    using ByteHasher for bytes;

    IWorldID public worldId;
    uint256 internal immutable externalNullifier;
    uint256 public groupId = 1; // Assuming groupId is 1, adjust as necessary
    mapping(uint256 => bool) public nullifierHashes;

    event InfernetResponseRequested(uint256 indexed requestId, string input);
    event InfernetResponseReceived(uint256 indexed requestId, string output);

    constructor(IWorldID _worldId, string memory _appId, string memory _actionId, address coordinator)
        CallbackConsumer(coordinator) 
    {
        worldId = _worldId;
        externalNullifier = abi.encodePacked(_appId).hashToField() ^ abi.encodePacked(_actionId).hashToField();
    }

    function verifyAndRequestCompute(
        address signal, 
        uint256 root, 
        uint256 nullifierHash, 
        uint256[8] calldata proof, 
        string calldata input
    ) external {
        if (nullifierHashes[nullifierHash]) revert("Nullifier already used");

        worldId.verifyProof(
            root,
            groupId,
            abi.encodePacked(signal).hashToField(),
            nullifierHash,
            externalNullifier,
            proof
        );

        nullifierHashes[nullifierHash] = true;

        uint256 requestId = _generate(input);
        emit InfernetResponseRequested(requestId, input);
    }

    function _generate(string memory input) private returns (uint256 requestId) {
        bytes memory inputData = abi.encode(input);
        // Simulating a requestId for this example. In a real scenario, this might be generated or returned by the compute request.
        requestId = uint256(keccak256(abi.encodePacked(input, block.timestamp)));

        // Assuming 'ritual-haiku-minter' is the task identifier for your Infernet compute task.
        // Adjust `gasLimit` and `payment` as needed based on the task's requirements and your budget.
        _requestCompute(
            "mistralai/Mistral-7B-v0.1", // This is your specific task identifier within Infernet
            inputData, // The input data for the compute task
            150 gwei,  // Example gas price, adjust based on current network conditions
            4_000_000, // Example gas limit for the computation
            1         // Redundancy, adjust based on how many duplicate computations you want for reliability
        );

        return requestId;
    }

    // Override the callback function to handle the compute response from Infernet
    function _receiveCompute(
        uint32 subscriptionId,
        uint32 interval,
        uint16 redundancy,
        address node,
        bytes calldata input,
        bytes calldata output,
        bytes calldata proof
    ) internal override {
        // Process the Infernet response here. For simplicity, we're directly converting the output to a string.
        emit InfernetResponseReceived(subscriptionId, string(output));
    }
}

