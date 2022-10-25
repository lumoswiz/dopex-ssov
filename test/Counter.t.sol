// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

contract CounterTest is Test {
    Counter public counter;

    function setUp() public {
        counter = new Counter();
        counter.setNumber(10);
    }

    function test_writeLine() public {
        string memory path = "output.json";

        string memory s1 = "collateralTokenWithdrawn:";
        string memory s2 = vm.toString(counter.number());

        string memory line1 = string.concat(s1, s2);

        vm.writeLine(path, line1);
    }

    function test_Number() public {
        assertEq(counter.number(), 10);
    }
}
