// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "./MyTokenV1.sol";

/**
 * 升级版，增加 burn 功能
 */
contract MyTokenV2 is MyTokenV1 {
    function burn(address from, uint256 amount) external {
        _burn(from, amount);
    }
}
