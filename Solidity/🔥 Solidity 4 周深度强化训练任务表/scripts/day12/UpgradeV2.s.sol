// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../../contracts/day12/MyTokenV2.sol";

import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "forge-std/Script.sol";

contract UpgradeV2Script is Script {
    // 在这里替换成部署出来的 ProxyAdmin 地址和 Proxy 地址
    address constant PROXY_ADMIN = 012;
    address constant PROXY = 0121;

    function run() external {
        vm.startBroadcast();

        // 1. 部署 V2 逻辑合约
        MyTokenV2 v2 = new MyTokenV2();
        console.log("MyTokenV2 logic deployed at:", address(v2));

        // 2. 通过 ProxyAdmin 升级
        ProxyAdmin proxyAdmin = ProxyAdmin(PROXY_ADMIN);
        proxyAdmin.upgrade(PROXY, address(v2));

        console.log("Proxy upgraded to V2");

        vm.stopBroadcast();
    }
}