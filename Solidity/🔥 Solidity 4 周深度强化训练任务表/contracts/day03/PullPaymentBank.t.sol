// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {Test} from "forge-std/Test.sol";
import {PullPaymentBank} from "./PullPaymentBank.sol";

contract PullPaymentBankTest is Test {
    PullPaymentBank public bank;
    address user1;
    address user2;

    function setUp() public {
        bank = new PullPaymentBank();
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);
    }


    function testMultipleAccountsIndependentBalances() public {
        // user1 存 5 ETH
        vm.prank(user1);
        bank.deposit{value: 5 ether}();

        // user2 存 3 ETH
        vm.prank(user2);
        bank.deposit{value: 3 ether}();

        // 检查各自余额
        vm.prank(user1);
        assertEq(bank.getBalance(), 5 ether);

        vm.prank(user2);
        assertEq(bank.getBalance(), 3 ether);

        // user1 提现
        vm.prank(user1);
        bank.withdraw();
        assertEq(user1.balance, 100 ether); // 提回来了

        // user2 不受影响
        vm.prank(user2);
        assertEq(bank.getBalance(), 3 ether);
    }

}
