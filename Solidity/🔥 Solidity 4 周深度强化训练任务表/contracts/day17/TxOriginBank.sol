// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

/**
 * 漏洞示例合约: 使用 tx.origin 判断权限的银行合约（有漏洞）
 */
contract TxOriginBank {
    address public owner;

    constructor() {
        owner = msg.sender; // 部署者是银行拥有者
    }

    // 使用 tx.origin 判断权限（有漏洞）
    /*
        💥 漏洞原因：
            如果 tx.origin == owner，即交易最初的发起者是 owner，就允许执行转账。
            但如果 owner 调用了一个恶意合约，而该合约再调用此函数，tx.origin 仍然是 owner，验证会被绕过。
     */
    function transferAll(address payable _to) public {
        require(tx.origin == owner, "Not owner"); // ⚠️ 漏洞点
        (bool sent, ) = _to.call{value: address(this).balance}("");
        require(sent, "Transfer failed");
    }

    // 存款函数，方便演示
    function deposit() public payable {}
}
