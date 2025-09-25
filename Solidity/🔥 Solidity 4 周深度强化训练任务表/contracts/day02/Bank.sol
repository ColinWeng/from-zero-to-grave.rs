// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

// 引入 OpenZeppelin Ownable
// 如果有  '"@openzeppelin/contracts/access/Ownable.sol"' cannot be resolved 的提示 ，
// 执行 npm install @openzeppelin/contracts
import "@openzeppelin/contracts/access/Ownable.sol";

/*
    在`Bank.sol`中增加只有`owner`能调用的`closeBank()`函数
 */
// 继承 抽象合约 Ownable
contract Bank is Ownable {

    mapping(address => uint256) private balances;

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    // 新增关闭事件
    event BankClosed(address indexed owner, uint256 remainingBalance);

    /*
     * 在 Solidity 中，合约的构造函数执行顺序是：
        父合约的构造函数 会在子合约的构造函数体执行 之前 调用。
        执行顺序按照继承关系，从最顶层的父合约向下。
        如果父合约有构造函数参数，可以在子合约构造函数的签名后一对括号里传入（像你写的 Ownable(msg.sender)）。
     */
    constructor() Ownable(msg.sender){
        // 默认 owner 是部署者
    }

    function deposit() external payable {
        require(msg.value > 0, "deposit value must > 0");
        balances[msg.sender] += msg.value;
        emit Deposit(msg.sender, msg.value);
    }

    function getBalance() external view returns (uint256) {
        return balances[msg.sender];
    }

    function withdraw(uint amount) external {
        require(amount > 0, "withdraw amount value must > 0");
        require(balances[msg.sender] >= amount, "Insufficient balance");
        balances[msg.sender] -= amount;
        (bool sent,) = payable(msg.sender).call{value: amount}("");
        require(sent, "call failed");
        emit Withdraw(msg.sender, amount);
    }

    // 只有 owner 可以关闭银行
    function closeBank() external onlyOwner {
        // mapping(address => uint256) private balances 记录用户余额，
        // address(this).balance 直接读取 EVM 合约上的 balance，
        // 当前合约地址的余额
        uint256 remaining = address(this).balance;
        // 转账所有资金给 owner
        if (remaining > 0) {
            (bool sent,) = payable(owner()).call{value: remaining}("");
            require(sent, "Transfer failed");
        }
        emit BankClosed(owner(), remaining);
    }
}
