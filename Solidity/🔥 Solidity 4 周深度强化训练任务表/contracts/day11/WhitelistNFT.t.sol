// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./WhitelistNFT.sol";
import "forge-std/Test.sol";

contract WhitelistNFTTest is Test {

    WhitelistNFT public nft;

    function setUp() public {
        // 这里替换成 Node 脚本生成的 root
        bytes32 root = 0xcbf843e9efe7be41ca4d3a03347d27e7bb96d83ae75b3b36983ad907d2109c65; // 用实际的 merkleRoot 替换
        nft = new WhitelistNFT(root);
    }

    function testMintWithProof() public {
        address user = 0x2222222222222222222222222222222222222222;
        // 这里替换成 Node 脚本生成的 proof
        bytes32[] memory proof = new bytes32[](2);
        proof[0] = 0xe2c07404b8c1df4c46226425cac68c28d27a766bbddce62309f36724839b22c0;
        proof[1] = 0x37d95e0aa71e34defa88b4c43498bc8b90207e31ad0ef4aa6f5bea78bd25a1ab;

        nft.safeMint(user, "https://example.com/token/1.json", proof);

        assertEq(nft.ownerOf(0), user);
        assertTrue(nft.minted(user));
    }

    function testFailMintWithoutProof() public {
        address attacker = address(0x999);
        bytes32[] memory fakeProof = new bytes32[](0);
        vm.expectRevert(bytes("Not in whitelist"));
        nft.safeMint(attacker, "https://example.com/token/2.json", fakeProof);
    }
}