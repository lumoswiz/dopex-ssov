// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../structs/Structs.sol";

library Key {
    function compute(Inputs memory input) internal pure returns (bytes32 id) {
        return keccak256(abi.encode(input));
    }
}
