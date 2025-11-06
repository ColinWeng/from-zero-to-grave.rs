// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./ReentrancyAttackPull.sol";
import {Test} from "forge-std/Test.sol";

contract ReentrancyTestPull is Test {

    PullPaymentBank public bank;
    ReentrancyAttackPull public attacker;

    address deployer = makeAddr("deployer");
    address user1 = makeAddr("user1");

    function setUp() public {
        vm.startPrank(deployer);
        bank = new PullPaymentBank();
        vm.stopPrank();

        // 给 user1 和攻击合约一些启动资金
        vm.deal(user1, 10 ether);

        // 部署攻击合约
        vm.startPrank(user1);
        attacker = new ReentrancyAttackPull(address(bank));
        vm.stopPrank();
    }

    function testReentrancyFails() public {
        emit log_named_uint("Bank balance before", address(bank).balance);
        emit log_named_uint("Attacker balance before", address(attacker).balance);

        // user1 发动攻击
        vm.startPrank(user1);
        attacker.attack{value: 1 ether}();
        vm.stopPrank();

        emit log_named_uint("Bank balance after", address(bank).balance);
        emit log_named_uint("Attacker balance after", address(attacker).balance);

        // 验证银行还剩钱（攻击未造成损失）
        assertEq(address(bank).balance, 0, "Bank should remain empty after user's withdrawal");
        // 验证攻击者只拿回了自己的钱（没偷额外资金）
        assertEq(address(attacker).balance, 1 ether, "Attacker should only get its own deposit back");
    }
}
