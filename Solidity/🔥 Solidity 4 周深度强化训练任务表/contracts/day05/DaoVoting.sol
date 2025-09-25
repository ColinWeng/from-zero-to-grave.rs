// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

/*
    - `createProposal(string desc)`创建提案
    - `vote(uint proposalId)`投票
    - `closeProposal(uint proposalId)`关闭 & 计算结果
 */
contract DaoVoting {

    struct Proposal {
        string description;             // 提案描述
        uint256 voteCount;              // 投票数
        uint256 startTime;              // 开始时间
        uint256 endTime;                // 结束时间
        bool closed;                    // 结束标记
        mapping(address => bool) voted; // 投票人
    }

    Proposal[] public proposals;        // 所有提案

    event ProposalCreated(uint256 proposalId, string description, uint256 startTime, uint256 endTime);
    event Voted(uint256 proposalId, address voter);
    event ProposalClosed(uint256 proposalId, uint256 finalVoteCount);

    // 创建提案
    /*
        时间单位：（需要注意润秒）
            1 seconds
            1 minutes
            1 hours
            1 days
            1 weeks
     */
    function createProposal(string calldata desc) external {
        uint256 start = block.timestamp;
        uint256 end = block.timestamp + 3 days;

        // 创建 Proposal 结构体并推入数组（这样描述可能不太合适）
        // 和 Java 不同，不能使用 new 去创建 struct。
        // .push() 是 storage 动态数组的标准初始化方式，
        proposals.push();
        Proposal storage p = proposals[proposals.length - 1];
        p.description = desc;
        p.voteCount = 0;
        p.startTime = start;
        p.endTime = end;
        p.closed = false;

        emit ProposalCreated(proposals.length - 1, desc, start, end);
    }

    // 投票，对一个提案进行投票，投了就是同意
    function vote(uint proposalId) external {
        // 校验议题
        require(proposalId < proposals.length, "Proposal not found");
        // 使用 storage，表示获取 storage 中的引用；memory 的话，会创建一个内存副本
        Proposal storage p = proposals[proposalId];
        // 校验时间
        require(block.timestamp >= p.startTime, "Voting not started");
        require(block.timestamp <= p.endTime, "Voting ended");
        // 校验投票人，p.voted[msg.sender] 不存在，默认值是 false
        require(!p.voted[msg.sender], "Already voted");

        p.voted[msg.sender] = true;
        p.voteCount += 1;

        emit Voted(proposalId, msg.sender);
    }

    // 关闭 & 计算结果，关闭提案并输出最终票数
    function closeProposal(uint proposalId) external {
        require(proposalId < proposals.length, "Proposal not found");
        Proposal storage p = proposals[proposalId];
        require(block.timestamp > p.endTime, "Voting still active");
        require(!p.closed, "Already closed");

        p.closed = true;
        emit ProposalClosed(proposalId, p.voteCount);
    }

    function getProposal(uint proposalId) external view returns (
        string memory description,
        uint256 voteCount,
        uint256 startTime,
        uint256 endTime,
        bool closed
    ){
        require(proposalId < proposals.length, "Proposal not found");
        Proposal storage p = proposals[proposalId];
        return (p.description, p.voteCount, p.startTime, p.endTime, p.closed);
    }
}
