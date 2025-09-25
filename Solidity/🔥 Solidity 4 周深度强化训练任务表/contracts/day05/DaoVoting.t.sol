// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./DaoVoting.sol";
import {Test} from "forge-std/Test.sol";

contract DaoVotingTest is Test {

    DaoVoting dao;
    address alice;
    address bob;
    address carol;

    function setUp() public {
        dao = new DaoVoting();
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        carol = makeAddr("carol");
    }

    function testCreateProposal() public {
        dao.createProposal("Hello DAO");

        (
            string memory description,
            uint256 voteCount,
            uint256 startTime,
            uint256 endTime,
            bool closed
        ) = dao.getProposal(0);

        assertEq(description, "Hello DAO");
        assertEq(voteCount, 0);
        assertFalse(closed);
        assertTrue(startTime < endTime);
    }

    function testVoteAndCount() public {
        dao.createProposal("Vote Test");

        vm.startPrank(alice);
        dao.vote(0);

        vm.startPrank(bob);
        dao.vote(0);

        vm.startPrank(carol);
        dao.vote(0);

        (, uint256 voteCount,,,) = dao.getProposal(0);

        assertEq(voteCount, 3);
    }

    function testCannotDoubleVote() public {
        dao.createProposal("No Double Voting");

        vm.startPrank(alice);
        dao.vote(0);

        vm.expectRevert(bytes("Already voted"));
        dao.vote(0);
    }

    function testCannotVoteAfterEndTime() public {
        dao.createProposal("Time Limit Test");

        (, , , uint256 endTime, ) = dao.getProposal(0);
        // Sets `block.timestamp`. 跳时间：超过结束时间
        vm.warp(endTime + 1);

        vm.expectRevert(bytes("Voting ended"));
        vm.prank(alice);
        dao.vote(0);
    }

    function testCloseProposal() public {
        dao.createProposal("Close Test");

        (, , , uint256 endTime, ) = dao.getProposal(0);
        vm.warp(endTime + 1);

        vm.expectEmit(true, false, false, true);
        emit DaoVoting.ProposalClosed(0, 0);
        dao.closeProposal(0);

        (, , , , bool closed) = dao.getProposal(0);
        assertTrue(closed);
    }
}