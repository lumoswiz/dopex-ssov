// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../structs/Structs.sol";

library OutputId {
    function compute(Outputs memory output) internal pure returns (bytes32 id) {
        return keccak256(abi.encode(output.inputs));
    }
}
