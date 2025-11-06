// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../../contracts/day15/Attacker.sol";
import "../../contracts/day15/SecureBank.sol";
import "../../contracts/day15/VulnerableBank.sol";
import "forge-std/Test.sol";


contract ReentrancyTest is Test {

    VulnerableBank public vulnerableBank;
    SecureBank public secureBank;
    Attacker public attacker;
    address public user;
    address public attackerAddr;

    function setUp() public {
        user = address(0xAAA);
        attackerAddr = address(0xBBB);

        // 部署合约
        vulnerableBank = new VulnerableBank();
        secureBank = new SecureBank();

        vm.deal(user, 10 ether);
        vm.deal(attackerAddr, 3 ether);

        // 用户存入 10 ether
        vm.prank(user);
        vulnerableBank.deposit{value: 10 ether}();

        // 部署攻击合约
        vm.prank(attackerAddr);
        attacker = new Attacker(address(vulnerableBank));

        // 攻击者存入资金
        vm.prank(attackerAddr);
        attacker.attackDeposit{value: 3 ether}();
    }

    /**
     * forge test --match-test testAttackSucceeds -vvvv
     */
    function testAttackSucceeds() public {
        // bank 上的余额
        uint256 beforeBalance = address(vulnerableBank).balance;
        // 攻击人合约余额
        uint256 beforeAttackerAddrBalance = attackerAddr.balance;
        // 攻击合约余额
        uint256 beforeAttackerBalance = address(attacker).balance;

        vm.prank(attackerAddr);
        attacker.attackWithdraw();

        // bank 上的余额
        uint256 afterBalance = address(vulnerableBank).balance;
        // 攻击人合约余额
        uint256 afterAttackerAddrBalance = attackerAddr.balance;
        // 攻击合约余额
        uint256 afterAttackerBalance = address(attacker).balance;

        emit log_named_uint("Attacker addr before", beforeAttackerAddrBalance);
        emit log_named_uint("Attacker addr after", afterAttackerAddrBalance);

        emit log_named_uint("Bank before", beforeBalance);
        emit log_named_uint("Bank after", afterBalance);

        emit log_named_uint("Attacker contract before", beforeAttackerBalance);
        emit log_named_uint("Attacker contract after", afterAttackerBalance);


        assertEq(afterBalance, 0, "Bank drained");
    }

    /**
     *  forge test --match-test testSecureBankResistsAttack -vvvv
     */
    function testSecureBankResistsAttack() public {
        vm.deal(user, 10 ether);
        vm.deal(attackerAddr, 1 ether);

        vm.prank(user);
        secureBank.deposit{value: 5 ether}();

        vm.prank(attackerAddr);
        Attacker attackerSecure = new Attacker(address(secureBank));

        vm.prank(attackerAddr);
        attackerSecure.attackDeposit{value: 1 ether}();

        vm.prank(attackerAddr);
        vm.expectRevert(); // nonReentrant 会阻止重入
        attackerSecure.attackWithdraw();
    }

}