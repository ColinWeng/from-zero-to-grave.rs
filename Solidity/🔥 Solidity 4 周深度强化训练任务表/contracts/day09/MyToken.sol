// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * 基于 OpenZeppelin 的 ERC20 实现，增加 mint 方法和 maxSupply 限制。
 */
contract MyToken is ERC20, Ownable {

    uint256 public immutable maxSupply; // 最大供应量（单位：最小单位）

    // 构造函数，继承 ERC20 和 Ownable，传入初始化参数
    constructor(
        string memory name_,
        string memory symbol_,
        uint256 maxSupply_
    ) ERC20(name_, symbol_) Ownable(msg.sender){
        require(maxSupply_ > 0, "Max supply must be > 0");
        maxSupply = maxSupply_;
    }

    // 铸造新代币（只有合约所有者可以调用）
    function mint(address to, uint256 amount) external onlyOwner{
        require(totalSupply() + amount <= maxSupply, "Mint exceeds max supply");
        _mint(to, amount);
    }

}
