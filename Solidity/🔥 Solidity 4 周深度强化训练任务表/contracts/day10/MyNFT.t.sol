// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./MyNFT.sol";
import "forge-std/Test.sol";

contract MyNFTTest is Test {
    MyNFT public nft;
    address public alice;
    address public owner;

    function setUp() public {
        owner = address(this);
        alice = address(0x1);
        nft = new MyNFT("MyNFT", "MNFT");
    }

    function testSafeMintAndTokenURI() public {
        string memory uri = "https://nft.example/metadata/1.json";

        nft.safeMint(alice, uri);

        assertEq(nft.ownerOf(0), alice);
        assertEq(nft.tokenURI(0), uri);
        assertEq(nft.nextTokenId(), 1);
    }

    function testRevertIfNonOwnerMint() public {
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice)
        );
        nft.safeMint(alice, "https://nft.example/metadata/2.json");
    }
}