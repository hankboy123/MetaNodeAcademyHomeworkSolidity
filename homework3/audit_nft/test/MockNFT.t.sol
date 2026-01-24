// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "chainlink-evm/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import "openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";

// Mock NFT 合约
contract MockNFT is ERC721 {
    constructor() ERC721("MockNFT", "MNFT") {}
    
    function mint(address to, uint256 tokenId) public {
        _mint(to, tokenId);
    }
}