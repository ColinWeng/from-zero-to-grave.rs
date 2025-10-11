import keccak256 from 'keccak256';
import { MerkleTree } from 'merkletreejs';

// 假设白名单名单
const whitelistAddresses = [
    "0x1111111111111111111111111111111111111111",
    "0x2222222222222222222222222222222222222222",
    "0x3333333333333333333333333333333333333333"
];

// 1. 生成叶子节点（地址小写并去除 0x 前缀哈希）
const leafNodes = whitelistAddresses.map(addr => keccak256(addr.toLowerCase()));
// 2. 构造 Merkle 树（排序 true 保证一致性）
const merkleTree = new MerkleTree(leafNodes, keccak256, { sortPairs: true });

// 3. 根节点（部署时要放链上）
const root = merkleTree.getHexRoot();
console.log("Merkle Root:", root);

// 4. 模拟生成某个地址的 proof
const claimingAddress = "0x2222222222222222222222222222222222222222";
const proof = merkleTree.getHexProof(keccak256(claimingAddress.toLowerCase()));
console.log("Proof for", claimingAddress, ":", proof);