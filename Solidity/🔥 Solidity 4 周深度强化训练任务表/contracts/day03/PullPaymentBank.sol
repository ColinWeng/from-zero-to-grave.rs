// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/*
- 新建`PullPaymentBank.sol`
- 存款时增加余额记录
- 提现时读取余额 → 转账 → 余额清零
 */
// 使用 openzeppelin 提供的防重入抽象类
contract PullPaymentBank is ReentrancyGuard{

    mapping(address => uint256) private balances;

    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);

    // 存款
    function deposit() external payable {
        require(msg.value > 0, "Deposit must be greater than 0");
        balances[msg.sender] += msg.value;
        emit Deposited(msg.sender, msg.value);
    }

    // 查看余额
    function getBalance() external view returns (uint256) {
        return balances[msg.sender];
    }

    // 提现 — 拉取支付模式
    // 使用 函数修改器（nonReentrant），防重入
    function withdraw() external nonReentrant {
        uint256 amount = balances[msg.sender];
        require(amount > 0, "No balance to withdraw");

        // 先将余额清零
        balances[msg.sender] = 0;

        // 再转账
        (bool sent, ) = payable(msg.sender).call{value: amount}("");
        require(sent, "Transfer failed");

        emit Withdrawn(msg.sender, amount);
    }
}
