// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/**
 * 可升级ERC20版本1
 */
contract MyTokenV1 is Initializable, ERC20Upgradeable {

    /*
        不能在构造函数里初始化，因为逻辑合约是通过 Proxy delegatecall 调用，构造函数只会在逻辑合约部署时执行一次（不会初始化 Proxy 的数据）。
        必须用 initialize() 来设置初始值，只允许执行一次（initializer 修饰器）。
     */

    function initialize(string memory name_, string memory symbol_) public initializer {
        __ERC20_init(name_, symbol_);
        _mint(msg.sender, 1000 * 10 ** decimals());
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
