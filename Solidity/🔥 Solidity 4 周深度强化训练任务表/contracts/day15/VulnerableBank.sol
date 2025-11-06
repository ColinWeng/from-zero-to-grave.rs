// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

/*
 * 存在漏洞的合约
 */
contract VulnerableBank {

    mapping(address => uint256) public balances;

    function deposit() external payable {
        balances[msg.sender] += msg.value;
    }

    function getBalance() external view returns (uint256) {
        return balances[msg.sender];
    }

    /*
     * 先向 msg.sender 发起转账。
     * 再 balances[msg.sender] 进行扣减
     */
    function withdraw(uint256 amount) external {
        require(balances[msg.sender] >= amount, "Insufficient balance");
        // msg.sender 是一个运行时环境变量，它代表**“当前函数调用的直接调用方”**。
        // 在重入攻击的例子中，msg.sender 是攻击合约地址，而不是发起人的账户地址
        // ❌ 漏洞：先转账，后更新状态
        (bool sent, ) = msg.sender.call{value: amount}("");
        require(sent, "Transfer failed");

        // 如果出现负数，旧版本 Solidity（<0.8.0）中，这种下溢不会报错
        // 在 Solidity 0.8.0+ 版本中，这种情况会触发 panic 错误并 revert 整个调用。
        // 0 - 1 ether 会直接抛出 Panic(uint256) 异常（error code 0x11），自动回滚交易
//        balances[msg.sender] -= amount;

        // 在 unchecked 块里扣余额 → 就不会因为下溢而 revert
        unchecked {
            balances[msg.sender] -= amount;
        }
    }
}
