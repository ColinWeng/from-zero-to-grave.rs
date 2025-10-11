// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./MyToken.sol";
import "forge-std/Test.sol";

contract MyTokenTest is Test {

    MyToken token;
    address owner;
    address addr1;
    address addr2;

    function setUp() public {
        // address(this) 表示当前测试合约的地址。
        owner = address(this);
        addr1 = vm.addr(1);
        addr2 = vm.addr(2);

        // 部署 ERC-20 合约
        token = new MyToken(1000); // initialSupply = 1000
    }

    function testInitialSupplyAssignedToOwner() public {
        assertEq(token.balanceOf(owner), token.totalSupply());
    }

    function testTransferEmitsEventAndBalancesUpdate() public {
        uint256 amountWholeCoins = 50;
        uint256 amountWei = amountWholeCoins * (10 ** token.decimals());

        // 参数 emitter，指定事件是由哪个合约地址发出的
        vm.expectEmit(true, true, false, true, address(token));
        emit MyToken.Transfer(owner, addr1, amountWei);
        bool success = token.transfer(addr1, amountWei);
        assertTrue(success);

        assertEq(token.balanceOf(addr1), amountWei);
        assertEq(token.balanceOf(owner), token.totalSupply() - amountWei);
    }

    /*
     * owner----授权100------------------> addr1
     * addr1----将owner授权的100--->转账--> addr2
     */
    function testApproveAndTransferFrom() public {
        // 授权 addr1
        vm.expectEmit(true, true, false, true);
        emit MyToken.Approval(owner, addr1, 100);
        // 调用 授权
        assertTrue(token.approve(addr1, 100));
        // 查询 授权
        assertEq(token.allowance(owner, addr1), 100);

        // 用 addr1 调用 transferFrom
        vm.prank(addr1);
        vm.expectEmit(true, true, false, true);
        emit MyToken.Transfer(owner, addr2, 60);

        assertTrue(token.transferFrom(owner, addr2, 60));
        assertEq(token.balanceOf(addr2), 60);
        assertEq(token.allowance(owner, addr1), 40);
    }

    function testTransferShouldFailIfBalanceNotEnough() public {
        vm.prank(addr1);
        vm.expectRevert(bytes("ERC20: transfer amount exceeds balance"));
        token.transfer(addr2, 10);
    }

    function testTransferFromShouldFailIfAllowanceNotEnough() public {
        assertTrue(token.approve(addr1, 10));
        vm.prank(addr1);
        vm.expectRevert(bytes("ERC20: amount exceeds allowance"));
        token.transferFrom(owner, addr2, 20);
    }
}