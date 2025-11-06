// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {Test} from "forge-std/Test.sol";
import {Bank} from "./Bank.sol";

contract BankTest is Test {

    Bank public bank;
    address owner;
    address user1;
    address user2;

    function setUp() public {
        owner = makeAddr("owner");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        vm.deal(owner, 100 ether);
        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);

        vm.startPrank(owner);
        bank = new Bank();
        vm.stopPrank();
    }

    function testBalancesMatchContractBalance() public {
        // 以 user1 身份调用 deposit
        vm.prank(user1);
        bank.deposit{value: 5 ether}();

        vm.prank(user1);
        uint256 user1Balance = bank.getBalance();

        // 以 user2 身份调用 deposit
        vm.prank(user2);
        bank.deposit{value: 3 ether}();

        vm.prank(user2);
        uint256 user2Balance = bank.getBalance();

        // 获取逻辑余额总和
        uint256 totalLogicBalance = user1Balance + user2Balance;
        // 获取真实链上余额
        uint256 contractBalance = address(bank).balance;

        assertEq(totalLogicBalance, contractBalance, "The total logical balance should be equal to the real balance of the contract");
    }

    function testCloseBankTransfersAllToOwner() public {
        // 用户1存 5 ETH
        vm.prank(user1);
        bank.deposit{value: 5 ether}();

        uint256 ownerBefore = owner.balance;

        // 🎯 声明我们期望捕获的事件
        vm.expectEmit(true, false, false, true);
        emit Bank.BankClosed(owner, 5 ether); // 注意这里要加 Bank. 前缀调用事件签名

        // owner 关闭银行
        vm.startPrank(owner);
        bank.closeBank();
        vm.stopPrank();

        // 验证合约余额为 0
        assertEq(address(bank).balance, 0, "The contract balance should be 0");

        // 验证 owner 收到资金
        assertEq(owner.balance, ownerBefore + 5 ether, "owner All funds should be received");
    }


}
