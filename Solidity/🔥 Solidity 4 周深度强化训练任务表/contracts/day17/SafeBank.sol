// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;
/**
 * 安全银行合约（无漏洞示例）
 */
contract SafeBank {
    address public owner;

    constructor() {
        owner = msg.sender;
    }

    function transferAll(address payable _to) public {
        // 修复：只允许直接调用者是 owner
        require(msg.sender == owner, "Not owner");
        (bool sent, ) = _to.call{value: address(this).balance}("");
        require(sent, "Transfer failed");
    }

    function deposit() public payable {}
}
