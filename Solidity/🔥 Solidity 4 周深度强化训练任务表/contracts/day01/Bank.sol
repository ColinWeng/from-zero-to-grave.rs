// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

/*
 * 写一个 `Bank.sol` 合约：
    - 存款（`deposit()`）
    - 查询余额（`getBalance()`）
    - 提款（`withdraw(uint amount)`）
 */
contract Bank {

    // 存储用户的余额
    mapping(address => uint256) private balances;

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);

    // 存款（`deposit()`）
    // 要让用户调用，并能支付，所以需要 external 和 payable
    // 全局变量 `msg.value` 表示 本次调用发送的 Wei 数量
    function deposit() external payable {
        require(msg.value > 0, "deposit value must > 0");
        balances[msg.sender] += msg.value;
        // 发送存款事件
        emit Deposit(msg.sender, msg.value);
    }

    // 查询余额（`getBalance()`）
    // 查询自己的余额，不会进行修改，所以需要 external 和 view
    // 全局变量 `msg.sender` 表示 当前调用者地址
    function getBalance() external view returns (uint256) {
        return balances[msg.sender];
    }

    // 提款（`withdraw(uint amount)`）
    function withdraw(uint amount) external {
        require(amount > 0, "withdraw amount value must > 0");
        require(balances[msg.sender] >= amount, "Insufficient balance");
        // 先减，防止重复
        balances[msg.sender] -= amount;
        // 发起转账
        (bool sent,) = payable(msg.sender).call{value: amount}("");
        // 校验转账结果
        require(sent, "call failed");
        //  发送转账事件
        emit Withdraw(msg.sender, amount);
    }
}
