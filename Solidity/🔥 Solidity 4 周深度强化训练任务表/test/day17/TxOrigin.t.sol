// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../../contracts/day17/SafeBank.sol";
import "../../contracts/day17/TxOriginAttack.sol";
import "../../contracts/day17/TxOriginBank.sol";
import "forge-std/Test.sol";


contract TxOriginTest is Test {

    TxOriginBank vulnBank;
    TxOriginAttack attacker;
    SafeBank safeBank;

    address alice = address(0x1); // owner
    address eve = address(0x2);   // attacker

    function setUp() public {
        vm.deal(alice, 5 ether);
        vm.deal(eve, 1 ether);

        vm.startPrank(alice);
        vulnBank = new TxOriginBank();

        safeBank = new SafeBank();
        vm.stopPrank();

        // 银行充值
        vm.prank(alice);
        vulnBank.deposit{value: 5 ether}();

        console.log("alice is:", address(alice));
        address currentOwner = vulnBank.owner(); // 直接调用 getter
        console.log("TxOriginBank owner is:", currentOwner);
        console.log("TxOriginBank bank is:", address(vulnBank));
        console.log("TxOriginBank Balance", address(vulnBank).balance);
    }

    /*
     * forge test --match-test testTxOriginAttack -vvvv
     */
    function testTxOriginAttack() public {
        console.log("---------------- testTxOriginAttack ----------------");
        // Eve 部署攻击合约
        vm.prank(eve);
        attacker = new TxOriginAttack(address(vulnBank));

        console.log("testTxOriginAttack TxOriginBank bank is:", address(vulnBank));
        console.log("testTxOriginAttack TxOriginAttack bank is:", address(attacker));

        address currentOwner = vulnBank.owner(); // 直接调用 getter
        console.log("TxOriginBank owner is:", currentOwner);

        // 诱导 Alice 发起调用
        vm.prank(alice, alice);
        console.log("tx.origin is:", tx.origin);
        attacker.attack();

        console.log("testTxOriginAttack TxOriginBank Balance", address(vulnBank).balance);
        console.log("testTxOriginAttack TxOriginAttack TxOriginAttack bank is:", address(attacker).balance);

        assertEq(address(vulnBank).balance, 0);

    }

    function testSafeBankNoAttack() public {
        // Eve 部署攻击合约针对 SafeBank（会失败）
        vm.prank(eve);
        TxOriginAttack badAttack = new TxOriginAttack(address(safeBank));

        // Alice 调用也不会通过 msg.sender 检查
        vm.expectRevert();
        vm.prank(alice);
        badAttack.attack();
    }
}