// script/Deploy.s.sol
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {NFTAuction} from "../src/NFTAuction.sol";

contract NFTAuctionDeploy is Script {
    function run() external returns (NFTAuction) {
        // 1. 设置部署者私钥（从环境变量获取）
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        // 2. 开始广播交易
        vm.startBroadcast(deployerPrivateKey);
        
        // 3. 部署合约
        NFTAuction auction = new NFTAuction();
        
        // 4. 停止广播
        vm.stopBroadcast();
        
        // 5. 返回部署的合约（可选）
        return auction;
    }
}