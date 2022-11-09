// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {Strings} from "openzeppelin-contracts/utils/Strings.sol";
import "../src/simulate/Key.sol";

// Interfaces
import {ISim} from "../src/interfaces/ISim.sol";
import {ISsovV3} from "../src/interfaces/ISsovV3.sol";
import {IERC20} from "../src/interfaces/IERC20.sol";
import {IVolatilityOracle} from "../src/interfaces/IVolatilityOracle.sol";

// Contracts
import {SimulateV2} from "../src/simulate/SimulateV2.sol";

// Structs
import "../src/structs/Structs.sol";

contract StrategyTest is Test {
    using Strings for uint256;
    using Key for Inputs;

    SimulateV2 sim;

    address public ssov;

    Inputs[] public inputs;

    function setUp() public {
        /*=== USER INPUT REQUIRED ===*/

        ssov = 0x10FD85ec522C245a63239b9FC64434F58520bd1f; // weekly dpx calls V3
        deploySimulate();
        setupFork();

        allocateInputs();

        /* === END USER INPUT ===*/
    }

    /// -----------------------------------------------------------------------
    /// Test: Run Strategies
    /// -----------------------------------------------------------------------

    function test_runStrategies() public {
        writeHeaders();

        for (uint256 i; i < inputs.length; ++i) {
            if (inputs[i].txType == 0) {
                // DEPOSIT
                bytes32 key = inputs[i].compute();
                sim.deposit(inputs[i]);
                Outputs memory output = sim.getWrite(key);
                sim.withdraw(output);
                output = sim.getWrite(key);

                string memory outputString = outputToString(output);

                vm.writeLine("./analysis/output.csv", outputString);
            }

            if (inputs[i].txType == 1) {
                // PURCHASE
                bytes32 key = inputs[i].compute();
                sim.purchase(inputs[i]);
                Outputs memory output = sim.getBuy(key);
                sim.settle(output);
                output = sim.getBuy(key);

                string memory outputString = outputToString(output);

                vm.writeLine("./analysis/output.csv", outputString);
            }
        }
    }

    /// -----------------------------------------------------------------------
    /// Test: SimulateV2
    /// -----------------------------------------------------------------------

    function test_depositThenWithdraw() public {
        Inputs memory input = inputs[0];

        bytes32 key = input.compute();

        sim.deposit(input);

        Outputs memory output = sim.getWrite(key);

        sim.withdraw(output);

        output = sim.getWrite(key);
    }

    function test_purchaseThenSettle() public {
        Inputs memory input = inputs[1];
        bytes32 key = input.compute();

        sim.purchase(input);

        Outputs memory output = sim.getBuy(key);

        sim.settle(output);

        output = sim.getBuy(key);

        emit log_named_uint(
            "checkpointIndex",
            output.writerDetails.checkpointIndex
        );
        emit log_named_uint(
            "collateralTokenWithdrawAmount",
            output.writerDetails.collateralTokenWithdrawAmount
        );
        emit log_named_uint(
            "rewardTokenWithdrawAmounts",
            output.writerDetails.rewardTokenWithdrawAmounts.length
        );

        emit log_named_uint("premium", output.buyerDetails.premium);
        emit log_named_uint("purchaseFee", output.buyerDetails.purchaseFee);
        emit log_named_uint("netPnl", output.buyerDetails.netPnl);
    }

    /// -----------------------------------------------------------------------
    /// Test: Outputs to CSV
    /// -----------------------------------------------------------------------

    function test_outputToStringDeposit() public {
        // deposit -> withdraw sequence
        Inputs memory input = inputs[0];
        bytes32 key = input.compute();
        sim.deposit(input);
        Outputs memory output = sim.getWrite(key);
        sim.withdraw(output);
        output = sim.getWrite(key);

        // outputToString
        string memory outputString = outputToString(output);

        emit log_string(outputString);
    }

    function test_outputToStringPurchase() public {
        // purchase -> settle
        Inputs memory input = inputs[1];
        bytes32 key = input.compute();
        sim.purchase(input);
        Outputs memory output = sim.getBuy(key);
        sim.settle(output);
        output = sim.getBuy(key);

        // outputToString
        string memory outputString = outputToString(output);

        emit log_string(outputString);
    }

    function test_outputToCsvDeposit() public {
        // deposit -> withdraw sequence
        Inputs memory input = inputs[0];
        bytes32 key = input.compute();
        sim.deposit(input);
        Outputs memory output = sim.getWrite(key);
        sim.withdraw(output);
        output = sim.getWrite(key);

        // outputToString
        string memory outputString = outputToString(output);

        writeHeaders();

        vm.writeLine("./analysis/output.csv", outputString);
    }

    function test_outputToCsvPurchase() public {
        // purchase -> settle
        Inputs memory input = inputs[1];
        bytes32 key = input.compute();
        sim.purchase(input);
        Outputs memory output = sim.getBuy(key);
        sim.settle(output);
        output = sim.getBuy(key);

        // outputToString
        string memory outputString = outputToString(output);

        writeHeaders();

        vm.writeLine("./analysis/output.csv", outputString);
    }

    /// -----------------------------------------------------------------------
    /// Test: Inputs (Python)
    /// -----------------------------------------------------------------------

    function test_allocateInputs() public {
        assertEq(inputs.length, getInputLength(), "something went wrong");

        Inputs memory input = inputs[1];

        emit log_named_uint("amount", input.amount);
        emit log_named_uint("strike", input.strike);
    }

    function test_getInputs() public {
        (uint256 e, uint256 b, uint256 s, uint256 a, uint256 t) = getInputs(2);
        uint256 l = getInputLength();

        emit log_uint(e);
        emit log_uint(b);
        emit log_uint(s);
        emit log_uint(a);
        emit log_uint(t);

        emit log_named_uint("length inputs", l);
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
    /// Helper Functions: Deploy Contracts (Persistent Storage)
    /// -----------------------------------------------------------------------

    function deploySimulate() public {
        sim = new SimulateV2(ISsovV3(ssov));
        vm.makePersistent(address(sim));
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
    /// Helper Functions: Outputs -> CSV
    /// -----------------------------------------------------------------------

    function writeHeaders() public {
        string memory path = "./analysis/output.csv";

        string
            memory headers = "epoch,blockNumber,strikeIndex,strike,amount,txType,premium,purchaseFee,netPnl,collateralTokenWithdrawAmount,rewardTokenWithdrawAmounts_DPX,rewardTokenWithdrawAmounts_JONES";

        vm.writeLine(path, headers);
    }

    function outputToString(Outputs memory output)
        public
        returns (string memory outputs)
    {
        outputs = string(
            abi.encodePacked(
                vm.toString(output.inputs.epoch),
                ",",
                vm.toString(output.inputs.blockNumber),
                ",",
                vm.toString(output.inputs.strikeIndex),
                ",",
                vm.toString(output.inputs.strike),
                ",",
                vm.toString(output.inputs.amount),
                ",",
                vm.toString(output.inputs.txType),
                ",",
                vm.toString(output.buyerDetails.premium),
                ",",
                vm.toString(output.buyerDetails.purchaseFee),
                ",",
                vm.toString(output.buyerDetails.netPnl),
                ",",
                vm.toString(output.writerDetails.collateralTokenWithdrawAmount),
                ",",
                vm.toString(output.writerDetails.rewardTokenWithdrawAmounts[0]),
                ",",
                vm.toString(output.writerDetails.rewardTokenWithdrawAmounts[1])
            )
        );
    }

    /// -----------------------------------------------------------------------
    /// Helper Functions: Inputs
    /// -----------------------------------------------------------------------

    function getInputs(uint256 _idx)
        public
        returns (
            uint256 _epoch,
            uint256 _blockNumber,
            uint256 _strikeIndex,
            uint256 _amount,
            uint256 _txType
        )
    {
        string[] memory inputString = new string[](5);
        inputString[0] = "python3";
        inputString[1] = "analysis/inputs.py";
        inputString[2] = "inputs";
        inputString[3] = "--index";
        inputString[4] = _idx.toString();
        bytes memory res = vm.ffi(inputString);
        (_epoch, _blockNumber, _strikeIndex, _amount, _txType) = abi.decode(
            res,
            (uint256, uint256, uint256, uint256, uint256)
        );
        _amount = _amount * 10**10;
    }

    function getInputLength() public returns (uint256 l) {
        string[] memory inputString = new string[](3);
        inputString[0] = "python3";
        inputString[1] = "analysis/inputs.py";
        inputString[2] = "length";
        bytes memory res = vm.ffi(inputString);
        l = abi.decode(res, (uint256));
    }

    function allocateInputs() public {
        // Get length of inputs
        uint256 inputsLength = getInputLength();

        for (uint256 i; i < inputsLength; ++i) {
            (
                uint256 _epoch,
                uint256 _blockNumber,
                uint256 _strikeIndex,
                uint256 _amount,
                uint256 _txType
            ) = getInputs(i);

            // forked environment initiated in `setUp`. This function has to be called after `setupFork`.
            uint256 strike = ISsovV3(ssov).getEpochData(_epoch).strikes[
                _strikeIndex
            ];

            inputs.push(
                Inputs({
                    epoch: _epoch,
                    blockNumber: _blockNumber,
                    strikeIndex: _strikeIndex,
                    strike: strike,
                    amount: _amount,
                    txType: _txType
                })
            );
        }
    }
}
