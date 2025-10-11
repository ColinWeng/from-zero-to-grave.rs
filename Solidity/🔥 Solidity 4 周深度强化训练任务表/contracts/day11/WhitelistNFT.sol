// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

/*
    D11 任务是要实现 基于 Merkle Tree 的链上白名单 Mint。
    分三步完成：
        Node.js 端用 merkletreejs 生成 Merkle Root + Proof
        Solidity 合约端存储 merkleRoot 并在 mint 时验证 proof
        Foundry 测试：模拟 Node 计算 proof，然后调用合约验证 mint 流程
 */
contract WhitelistNFT is ERC721URIStorage, Ownable {

    bytes32 public merkleRoot;
    uint256 private _nextTokenId;
    mapping(address => bool) public minted; // 防止重复 mint

    constructor(bytes32 root_) ERC721("WhitelistNFT", "WNFT") Ownable(msg.sender){
        merkleRoot = root_;
    }

    function safeMint(address to, string memory uri, bytes32[] calldata proof) external {
        require(!minted[to], "Already minted");

        // 1. 计算 leaf
        bytes32 leaf = keccak256(abi.encodePacked(to));

        // 2. 验证 proof
        require(MerkleProof.verify(proof, merkleRoot, leaf), "Not in whitelist");

        // 3. 铸造
        uint256 tokenId = _nextTokenId++;
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);
        minted[to] = true;
    }
}
