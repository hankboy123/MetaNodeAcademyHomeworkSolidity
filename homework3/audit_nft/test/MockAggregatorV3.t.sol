// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import "chainlink-evm/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

// Mock Chainlink Aggregator 接口（简化版）
// Mock Chainlink 预言机
contract MockAggregatorV3 is AggregatorV3Interface {
    uint8 public decimals = 8;
    int256 private price;
    
    constructor(int256 _price) {
        price = _price;
    }
    
    function latestRoundData() external view returns (
        uint80 roundId,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
    ) {
        return (0, price, block.timestamp, block.timestamp, 0);
    }
    
    function setPrice(int256 _price) public {
        price = _price;
    }
    
    // 其他接口函数（为简洁省略）
    function description() external pure returns (string memory) { return "Mock"; }
    function version() external pure returns (uint256) { return 1; }
    function getRoundData(uint80) external pure returns (uint80, int256, uint256, uint256, uint80) {
        revert("Not implemented");
    }
}
