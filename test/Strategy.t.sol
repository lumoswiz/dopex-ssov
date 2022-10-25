// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

// Interfaces
import {ISsovV3} from "../src/interfaces/ISsovV3.sol";
import {IERC20} from "../src/interfaces/IERC20.sol";
import {ISim} from "../src/interfaces/ISim.sol";

// Contracts
import {Simulate} from "../src/simulate/Simulate.sol";
import {Strategy} from "../src/strategy/Strategy.sol";

contract StrategyTest is Test {
    address internal ssov;
    uint256 internal epoch;

    function setUp() public {
        /*=== USER INPUT REQUIRED ===*/

        ssov = 0x10FD85ec522C245a63239b9FC64434F58520bd1f; // weekly dpx calls V3

        /* === END USER INPUT ===*/
    }

    /// -----------------------------------------------------------------------
    /// Helper functions
    /// -----------------------------------------------------------------------

    /// @notice Creates and selects a new arbitrum mainnet fork.
    function setupFork() public returns (uint256 id) {
        id = vm.createSelectFork(vm.rpcUrl("arbitrum"));
        assertEq(vm.activeFork(), id);
    }

    /// @notice Creates and selects a new arbitrum mainnet fork at a specified block.
    function setupForkBlockSpecified(uint256 blk) public returns (uint256 id) {
        id = vm.createSelectFork(vm.rpcUrl("arbitrum"), blk);
        assertEq(vm.activeFork(), id);
    }
}
