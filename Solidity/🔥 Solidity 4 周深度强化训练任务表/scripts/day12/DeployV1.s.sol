// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../../contracts/day12/MyTokenV1.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "forge-std/Script.sol";

contract DeployV1Script is Script {

    function run() external {
        vm.startBroadcast();

        // 1. 部署 ProxyAdmin
        ProxyAdmin proxyAdmin = new ProxyAdmin();
        console.log("ProxyAdmin deployed at:", address(proxyAdmin));

        // 2. 部署逻辑合约（V1）
        MyTokenV1 v1 = new MyTokenV1();
        console.log("MyTokenV1 logic deployed at:", address(v1));

        // 3. 初始化数据
        bytes memory initData = abi.encodeWithSignature(
            "initialize(string,string)",
            "MyToken",
            "MTK"
        );

        // 4. 部署 Transparent Proxy，指向 V1
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(v1),
            address(proxyAdmin),
            initData
        );

        console.log("Proxy deployed at:", address(proxy));

        vm.stopBroadcast();
    }
}