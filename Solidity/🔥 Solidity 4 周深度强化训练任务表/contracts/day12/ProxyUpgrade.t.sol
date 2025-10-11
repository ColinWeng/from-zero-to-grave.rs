// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./MyTokenV1.sol";
import "./MyTokenV2.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "forge-std/Test.sol";


contract ProxyUpgradeTest is Test {
    address owner = address(this);

    TransparentUpgradeableProxy proxy;
    ProxyAdmin proxyAdmin;

    // ERC1967 admin 槽常量（固定值）
    bytes32 constant ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

    function setUp() public {
        // 部署逻辑合约 V1
        MyTokenV1 v1 = new MyTokenV1();

        // 初始化数据
        bytes memory initData = abi.encodeWithSignature(
            "initialize(string,string)",
            "MyToken",
            "MTK"
        );

        // 部署透明代理（OZ v5 会自动 new ProxyAdmin）
        proxy = new TransparentUpgradeableProxy(
            address(v1),
            owner, // initialOwner
            initData
        );

        // ✅ 用 Foundry vm.load 读取真实的 admin 地址
        address adminAddr = address(uint160(uint256(
            vm.load(address(proxy), ADMIN_SLOT)
        )));
        proxyAdmin = ProxyAdmin(adminAddr);
    }

    function testUpgrade() public {
        // 通过代理调用 V1 的方法
        MyTokenV1 tokenV1 = MyTokenV1(address(proxy));
        assertEq(tokenV1.name(), "MyToken");

        tokenV1.mint(owner, 100);
        assertEq(
            tokenV1.balanceOf(owner),
            1000 * 10 ** tokenV1.decimals() + 100
        );

        // 部署逻辑合约 V2
        MyTokenV2 v2 = new MyTokenV2();

        // ✅ 使用真实 ProxyAdmin 升级
        proxyAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(address(proxy)),
            address(v2),
            ""
        );

        // 升级完成后用 V2 接口交互
        MyTokenV2 tokenV2 = MyTokenV2(address(proxy));

        tokenV2.burn(owner, 100);
        assertEq(
            tokenV2.balanceOf(owner),
            1000 * 10 ** tokenV2.decimals()
        );
    }
}