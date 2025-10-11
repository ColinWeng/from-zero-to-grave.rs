// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * - **学习点**：
      - ERC-721 基本方法（`safeMint`、`tokenURI`）
   - **任务**：
      - 实现`MyNFT.sol`，mint 时设置自定义 URI
 */
contract MyNFT is ERC721URIStorage, Ownable {

    uint256 private _nextTokenId;

    constructor(string memory name_, string memory symbol_)
    ERC721(name_, symbol_)
    Ownable(msg.sender) // 传入 deployer 作为初始 owner
    {}

    // 铸造 NFT 并设置 URI
    function safeMint(address to, string memory uri) external onlyOwner {
        uint256 tokenId = _nextTokenId;
        _nextTokenId++;

        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);
    }

    // 批量铸造 NFTs，并为每个设置独立 URI
    function batchSafeMint(address[] calldata recipients, string[] calldata uris) external onlyOwner {
        require(recipients.length == uris.length, "MyNFT: recipients and uris length mismatch");

        for (uint256 i = 0; i < recipients.length; i++) {
            uint256 tokenId = _nextTokenId;
            _nextTokenId++;

            _safeMint(recipients[i], tokenId);
            _setTokenURI(tokenId, uris[i]);
        }
    }

    // 获取下一个可用 tokenId
    function nextTokenId() external view returns (uint256) {
        return _nextTokenId;
    }
}
