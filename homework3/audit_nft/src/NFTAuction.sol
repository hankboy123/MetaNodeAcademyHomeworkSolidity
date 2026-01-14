// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract NFTAuction is ERC721{
    uint256 public highestBid;

    constructor() ERC721("MyNFT", "MNFT") {}

    function placeBid(uint256 bidAmount) public {
        require(bidAmount > highestBid, "Bid too low");
        highestBid = bidAmount;
    }
}