// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./Receiver.sol";
import "./Sender.sol";
import {Test} from "forge-std/Test.sol";

contract D4_CallTest is Test {

    Receiver public receiver;
    Sender public sender;
    address user;

    function setUp() public {
        receiver = new Receiver();
        sender = new Sender();
        user = makeAddr("user");
        vm.deal(user, 100 ether);
    }

    // 测试调用 foo
    function testCallFooWithETH() public {
        vm.prank(user);
        vm.expectEmit(true, true, false, true);
        emit Receiver.Received(address(sender), 1 ether, "Hello from Sender");

        sender.callFoo{value: 1 ether}(payable(address(receiver)), "Hello from Sender");
    }

    // 测试直接发送 ETH
    function testSendETH() public {
        vm.prank(user);
        vm.expectEmit(true, true, false, true);
        emit Receiver.Received(address(sender), 0.5 ether, "Receive was called");

        sender.sendETH{value: 0.5 ether}(payable(address(receiver)));
    }

}

