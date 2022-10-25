// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {Strings} from "openzeppelin-contracts/utils/Strings.sol";

// Interfaces
import {ISim} from "../src/interfaces/ISim.sol";

import {ISsovV3} from "../src/interfaces/ISsovV3.sol";
import {IERC20} from "../src/interfaces/IERC20.sol";
import {IVolatilityOracle} from "../src/interfaces/IVolatilityOracle.sol";

// Contracts
import {Simulate} from "../src/simulate/Simulate.sol";
import {Strategy} from "../src/strategy/Strategy.sol";

contract StrategyTest is Test {
    using Strings for uint256;

    address internal ssov;
    uint256 internal epoch;

    function setUp() public {
        /*=== USER INPUT REQUIRED ===*/

        ssov = 0x10FD85ec522C245a63239b9FC64434F58520bd1f; // weekly dpx calls V3

        /* === END USER INPUT ===*/
    }

    /// -----------------------------------------------------------------------
    /// Helper Functions: Fork
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

    /// -----------------------------------------------------------------------
    /// Helper Functions: SSOV State Variables
    /// -----------------------------------------------------------------------

    function getStateVariables()
        public
        view
        returns (uint256 volatility, uint256 price)
    {
        volatility = ISsovV3(ssov).getVolatility(0);
        price = ISsovV3(ssov).getUnderlyingPrice();
    }

    function getStrike(uint256 _epoch, uint256 strikeIndex)
        public
        view
        returns (uint256 strike)
    {
        return ISsovV3(ssov).getEpochData(_epoch).strikes[strikeIndex];
    }

    /// -----------------------------------------------------------------------
    /// Helper Functions: Inputs
    /// -----------------------------------------------------------------------

    struct Actions {
        uint256 epoch;
        uint256 blockNumber;
        uint256 strikeIndex;
        uint256 amount;
        bool txType; // 0 -> deposit, 1 -> purchase
    }

    function getInputs(uint256 _idx)
        public
        returns (
            uint256 _epoch,
            uint256 _blockNumber,
            uint256 _strikeIndex,
            uint256 _amount,
            bool _txType
        )
    {
        string[] memory inputs = new string[](5);
        inputs[0] = "python3";
        inputs[1] = inputs[1] = "analysis/inputs.py";
        inputs[2] = "epoch";
        inputs[3] = "--index";
        inputs[4] = _idx.toString();
        bytes memory res = vm.ffi(inputs);
        (_epoch, _blockNumber, _strikeIndex, _amount, _txType) = abi.decode(
            res,
            (uint256, uint256, uint256, uint256, bool)
        );
    }

    function test_getInputs() public {
        (uint256 e, uint256 b, uint256 s, uint256 a, bool t) = getInputs(0);

        emit log_uint(e);
        emit log_uint(b);
        emit log_uint(s);
        emit log_uint(a);
        assertEq(t, false);
    }
}
