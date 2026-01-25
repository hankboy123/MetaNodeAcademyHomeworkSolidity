// script/DeployUUPSProxy.s.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/NFTAuction.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployNFTAuction is Script {
    address constant SEPOLIA_ETH_USD_PRICE_FEED = 0x694AA1769357215DE4FAC081bf1f309aDC325306;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        
        // 1. 部署逻辑合约
        NFTAuction implementation = new NFTAuction();
        console.log("Implementation deployed at:", address(implementation));
        
        // 2. 部署代理合约
        bytes memory initData = abi.encodeWithSelector(
            NFTAuction.initialize.selector,
            SEPOLIA_ETH_USD_PRICE_FEED
        );
        
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(implementation),
            initData
        );
        
        console.log("Proxy deployed at:", address(proxy));
        
        // 3. 包装代理合约
        NFTAuction auction = NFTAuction(address(proxy));
        console.log("Current owner:", auction.owner());
        
        vm.stopBroadcast();
    }
}