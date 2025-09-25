// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {Test} from "forge-std/Test.sol";
import {Bank} from "./Bank.sol";

contract BankTest is Test {

    Bank bank;

    address user1;
    address user2;

    function setUp() public {
        // 给测试地址生成
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        // 部署合约
        bank = new Bank();

        // 给 user1 & user2 初始 ETH 余额
        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);
    }

    // 测试存款
    function testDeposit() public {
        uint256 depositAmount = 1 ether;

        // 以 user1 身份调用 deposit
        vm.prank(user1);
        bank.deposit{value: depositAmount}();

        uint256 balance = bank.getBalance();
        // 注意：调用 getBalance() 时，默认 msg.sender 是本合约（Test），而不是 user1
        // 所以我们用 vm.prank 来指定 msg.sender
        vm.prank(user1);
        uint256 userBalance = bank.getBalance();

        assertEq(userBalance, depositAmount);
    }

    // 测试提款成功
    function testWithdraw() public {
        uint256 depositAmount = 1 ether;

        // user1 存款
        vm.prank(user1);
        bank.deposit{value: depositAmount}();

        // user1 提款
        vm.startPrank(user1);
        bank.withdraw(depositAmount);
        vm.stopPrank();

        // 验证余额应为 0
        vm.prank(user1);
        uint256 finalBalance = bank.getBalance();
        assertEq(finalBalance, 0);
    }

    // 测试提款失败（余额不足）
    function testWithdrawRevertWhenInsufficientBalance() public {
        vm.prank(user1);
        vm.expectRevert(bytes("Insufficient balance"));
        bank.withdraw(1 ether);
    }

    // 测试事件 — 存款
    function testDepositEvent() public {
        vm.expectEmit(true, true, true, true);
        emit Bank.Deposit(user1, 1 ether);

        vm.prank(user1);
        bank.deposit{value: 1 ether}();
    }

    // 测试事件 — 提款
    function testWithdrawEvent() public {
        vm.prank(user1);
        bank.deposit{value: 1 ether}();

        vm.expectEmit(true, true, true, true);
        emit Bank.Withdraw(user1, 1 ether);

        vm.prank(user1);
        bank.withdraw(1 ether);
    }
}
