// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./MyToken.sol";
import "forge-std/Test.sol";

contract MyTokenTest is Test{

    MyToken token;
    address owner;
    address alice;
    uint256 constant MAX_SUPPLY = 1000 ether;

    function setUp() public {
        owner = address(this); // 测试合约本身作为 owner
        alice = address(0x1);
        token = new MyToken("MyToken", "MTK", MAX_SUPPLY);
    }

    function testOwnerCanMint() public {
        token.mint(alice, 500 ether);
        assertEq(token.totalSupply(), 500 ether);
        assertEq(token.balanceOf(alice), 500 ether);
    }

    function testRevertIfNonOwnerMint() public {
        vm.prank(alice); // 设置调用者为 alice

        // 期望错误 Ownable.OwnableUnauthorizedAccount
        // 错误选择器 (selector)：在 Solidity 里，每个错误类型（error）都有一个唯一的 4 字节选择器。
        vm.expectRevert(
            abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice)
        );
        token.mint(alice, 10 ether);
    }

    function testRevertIfExceedsMaxSupply() public {
        token.mint(alice, 1000 ether);
        vm.expectRevert(bytes("Mint exceeds max supply"));
        token.mint(alice, 1 ether);
    }
}