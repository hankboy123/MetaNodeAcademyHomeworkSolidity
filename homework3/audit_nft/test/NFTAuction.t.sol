// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {NFTAuction} from "../src/NFTAuction.sol";
import {MyNFT} from "../src/MyNFT.sol";
import {MockAggregatorV3} from "./MockAggregatorV3.t.sol";
import {MockERC20} from "./MockERC20.t.sol";
import {MockNFT} from "./MockNFT.t.sol";
import "chainlink-evm/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

contract NFTAuctionTest is Test {
    NFTAuction public auction;
    MockNFT public nft;
    MockERC20 public usdc;
    MockERC20 public dai;
    MockAggregatorV3 public ethPriceFeed;
    MockAggregatorV3 public usdcPriceFeed;
    MockAggregatorV3 public daiPriceFeed;
    
    address owner = address(0x1);
    address seller = address(0x2);
    address bidder1 = address(0x3);
    address bidder2 = address(0x4);
    
    uint256 constant TOKEN_ID_1 = 1;
    uint256 constant TOKEN_ID_2 = 2;
    uint256 constant START_TIME = 1000;
    uint256 constant END_TIME = 2000;
    uint256 constant MIN_BID_USD = 1000 * 1e18; // 1000 USD (18 decimals)
 

    function setUp() public {
        vm.startPrank(owner);
        
        // 部署价格预言机
        ethPriceFeed = new MockAggregatorV3(2000 * 1e8); // $2000/ETH
        usdcPriceFeed = new MockAggregatorV3(1 * 1e18);   // $1/USDC
        daiPriceFeed = new MockAggregatorV3(1 * 1e18);    // $1/DAI
        
        // 部署拍卖合约
        auction = new NFTAuction(address(ethPriceFeed));
        
        // 部署NFT和ERC20代币
        nft = new MockNFT();
        usdc = new MockERC20("USD Coin", "USDC");
        dai = new MockERC20("DAI Stablecoin", "DAI");
        
        // 设置其他代币的价格预言机
        auction.setPriceFeed(address(usdc), address(usdcPriceFeed));
        auction.setPriceFeed(address(dai), address(daiPriceFeed));
        
        // 铸造NFT给卖家
        vm.stopPrank();
        vm.startPrank(seller);
        nft.mint(seller, TOKEN_ID_1);
        nft.mint(seller, TOKEN_ID_2);
        nft.setApprovalForAll(address(auction), true);
        vm.stopPrank();
        
        // 给竞拍者代币
        vm.prank(address(usdc));
        usdc.mint(bidder1, 10000 * 1e18);
        usdc.mint(bidder2, 10000 * 1e18);
        
        vm.prank(address(dai));
        dai.mint(bidder1, 10000 * 1e18);
        dai.mint(bidder2, 10000 * 1e18);
        
        // 给竞拍者ETH
        vm.deal(bidder1, 100 ether);
        vm.deal(bidder2, 100 ether);
    }

    function test_Constructor() public {
        // 验证ETH价格预言机设置正确
        NFTAuction newAuction = new NFTAuction(address(ethPriceFeed));
        AggregatorV3Interface actualPriceFeed = newAuction.getPriceFeed(address(0));
        assertEq(address(actualPriceFeed), address(ethPriceFeed));

        // 验证默认小数位数
        assertEq(auction.DEFAULT_DECIMALS(), 18);
    }

    function test_SetPriceFeed() public {
        address newToken = address(0x999);
        MockAggregatorV3 newPriceFeed = new MockAggregatorV3(1 * 1e8);
    
        vm.prank(owner);
        auction.setPriceFeed(newToken, address(newPriceFeed));
    
        // 验证代币已添加到支持列表
        address[] memory supportedTokens = auction.getAllSupportedTokens();
        bool found = false;
        for (uint i = 0; i < supportedTokens.length; i++) {
            if (supportedTokens[i] == newToken) {
               found = true;
              break;
            }
        }
        assertTrue(found, "Token should be in supported list");
    
        // 测试重复添加
        uint256 initialLength = supportedTokens.length;
        vm.prank(owner);
        auction.setPriceFeed(newToken, address(newPriceFeed));
        supportedTokens = auction.getAllSupportedTokens();
        assertEq(supportedTokens.length, initialLength, "Should not duplicate tokens");
    }

    function test_Revert_SetPriceFeed_NotOwner() public {
        vm.prank(bidder1);
        vm.expectRevert();
        auction.setPriceFeed(address(0x999), address(ethPriceFeed));
    }

    function test_ListAuctionItem() public {
        vm.startPrank(seller);
    
        auction.listAuctionItem(
            address(nft),
            TOKEN_ID_1,
            START_TIME,
            END_TIME,
            NFTAuction.AuctionStatus.PENDING,
            MIN_BID_USD
        );
    
        vm.stopPrank();
    
        // 验证NFT已上架（通过后续操作验证）
    }

    function test_Revert_ListAuctionItem_NotOwner() public {
        vm.prank(bidder1);
        vm.expectRevert();
        auction.listAuctionItem(
            address(nft),
            TOKEN_ID_1,
            START_TIME,
            END_TIME,
            NFTAuction.AuctionStatus.PENDING,
            MIN_BID_USD
        );
    }
    function test_Revert_ListAuctionItem_NotApproved() public {
        // 创建未授权的NFT
        MockNFT newNFT = new MockNFT();
        newNFT.mint(seller, 999);
    
        vm.startPrank(seller);
        vm.expectRevert("NFT not approved");
        auction.listAuctionItem(
         address(newNFT),
         999,
         START_TIME,
         END_TIME,
          NFTAuction.AuctionStatus.PENDING,
          MIN_BID_USD
        );
        vm.stopPrank();
    }


    function test_FullAuctionFlow_ETH() public {
        // 1. 上架NFT
        vm.startPrank(seller);
        auction.listAuctionItem(
            address(nft),
            TOKEN_ID_1,
            block.timestamp,
            block.timestamp + 1 days,
            NFTAuction.AuctionStatus.PENDING,
            MIN_BID_USD
        );
    
        // 2. 开始拍卖
        auction.startAuction(address(nft), TOKEN_ID_1);
        vm.stopPrank();
    
        // 3. 竞拍者1用ETH支付保证金
        vm.prank(bidder1);
        auction.payWithETH{value: 1 ether}();
    
        // 4. 竞拍者1出价
        uint256 bidAmount1 = 1500 * 1e18; // $1500
        vm.prank(bidder1);
        auction.placeBid(address(nft), TOKEN_ID_1, bidAmount1);
    
        // 5. 竞拍者2用ETH支付保证金
        vm.prank(bidder2);
        auction.payWithETH{value: 2 ether}();
    
        // 6. 竞拍者2出更高价
        uint256 bidAmount2 = 2000 * 1e18; // $2000
        vm.prank(bidder2);
        auction.placeBid(address(nft), TOKEN_ID_1, bidAmount2);
    
        // 7. 结束拍卖
        vm.warp(block.timestamp + 2 days);
        vm.prank(seller);
        auction.endAuction(address(nft), TOKEN_ID_1);
    
        // 8. 验证NFT转移
        assertEq(nft.ownerOf(TOKEN_ID_1), bidder2, "NFT should be transferred to highest bidder");
    
        // 9. 卖家提取资金
        uint256 sellerBalanceBefore = seller.balance;
        vm.prank(seller);
        auction.withdrawFunds(address(nft), TOKEN_ID_1);
    
        // 验证卖家收到资金
        assertGt(seller.balance, sellerBalanceBefore, "Seller should receive funds");
    }

    function test_FullAuctionFlow_ERC20() public {
        // 1. 上架NFT
        vm.startPrank(seller);
        auction.listAuctionItem(
            address(nft),
            TOKEN_ID_2,
            block.timestamp,
            block.timestamp + 1 days,
            NFTAuction.AuctionStatus.PENDING,
           MIN_BID_USD
        );
        auction.startAuction(address(nft), TOKEN_ID_2);
        vm.stopPrank();
    
        // 2. 竞拍者1用USDC支付保证金
        vm.startPrank(bidder1);
        usdc.approve(address(auction), 2000 * 1e18);
        auction.payWithERC20(address(usdc), 2000 * 1e18);
    
        // 3. 竞拍者1出价
        auction.placeBid(address(nft), TOKEN_ID_2, 1500 * 1e18);
        vm.stopPrank();
    
        // 4. 结束拍卖并验证
        vm.warp(block.timestamp + 2 days);
        vm.prank(seller);
        auction.endAuction(address(nft), TOKEN_ID_2);
    
        assertEq(nft.ownerOf(TOKEN_ID_2), bidder1, "NFT should be transferred to bidder1");
    }

    function test_Revert_PlaceBid_BelowMin() public {
        vm.startPrank(seller);
        auction.listAuctionItem(
            address(nft),
            TOKEN_ID_1,
            block.timestamp,
            block.timestamp + 1 days,
            NFTAuction.AuctionStatus.PENDING,
            MIN_BID_USD
        );
        auction.startAuction(address(nft), TOKEN_ID_1);
        vm.stopPrank();
    
        vm.prank(bidder1);
        vm.expectRevert("Bid amount must be greater than minBidUSD");
        auction.placeBid(address(nft), TOKEN_ID_1, MIN_BID_USD - 1);
    }

    function test_Revert_PlaceBid_LowerThanHighest() public {
        vm.startPrank(seller);
        auction.listAuctionItem(
           address(nft),
           TOKEN_ID_1,
            block.timestamp,
            block.timestamp + 1 days,
            NFTAuction.AuctionStatus.PENDING,
            MIN_BID_USD
        );
        auction.startAuction(address(nft), TOKEN_ID_1);
        vm.stopPrank();
    
        // 第一次出价
        vm.prank(bidder1);
        auction.payWithETH{value: 1 ether}();
        auction.placeBid(address(nft), TOKEN_ID_1, 2000 * 1e18);
    
        // 第二次出价更低
        vm.prank(bidder2);
        auction.payWithETH{value: 1 ether}();
        vm.expectRevert("Bid too low");
        auction.placeBid(address(nft), TOKEN_ID_1, 1500 * 1e18);
    }

    function test_Revert_EndAuction_InsufficientPayment() public {
        vm.startPrank(seller);
        auction.listAuctionItem(
            address(nft),
            TOKEN_ID_1,
            block.timestamp,
            block.timestamp + 1 days,
            NFTAuction.AuctionStatus.PENDING,
            MIN_BID_USD
        );
        auction.startAuction(address(nft), TOKEN_ID_1);
        vm.stopPrank();
    
        // 出价但支付不足
        vm.prank(bidder1);
        auction.payWithETH{value: 0.1 ether}(); // 只支付$200 (0.1 ETH * $2000)
        auction.placeBid(address(nft), TOKEN_ID_1, 1000 * 1e18); // 出价$1000
    
        vm.warp(block.timestamp + 2 days);
        vm.prank(seller);
        vm.expectRevert("paid money is not enough");
        auction.endAuction(address(nft), TOKEN_ID_1);
    }

    /**
     * function test_WithdrawExcessFunds() public {
        // 设置场景：竞拍者支付了过多资金
        vm.startPrank(seller);
        auction.listAuctionItem(
            address(nft),
            TOKEN_ID_1,
            block.timestamp,
            block.timestamp + 1 days,
            NFTAuction.AuctionStatus.PENDING,
            MIN_BID_USD
        );
        auction.startAuction(address(nft), TOKEN_ID_1);
        vm.stopPrank();
    
        // 竞拍者支付超额ETH
        vm.prank(bidder1);
        auction.payWithETH{value: 2 ether}(); // $4000 worth
    
        // 出价较低
        auction.placeBid(address(nft), TOKEN_ID_1, 1000 * 1e18); // 出价$1000
    
        // 结束拍卖
        vm.warp(block.timestamp + 2 days);
        vm.prank(seller);
        auction.endAuction(address(nft), TOKEN_ID_1);
    
        // 竞拍者提取多余资金
        uint256 balanceBefore = bidder1.balance;
        vm.prank(bidder1);
        // 注意：当前withdrawFunds函数只能由卖家调用，可能需要修改
        // auction.withdrawExcessFunds(); // 假设有这样的函数
    }
     * 
     * 
    */
    

    function test_ConvertETHtoUSD() public {
        // 设置ETH价格为$2000
        ethPriceFeed.setPrice(2000 * 1e8);
    
        uint256 ethAmount = 1 ether;
        uint256 expectedUSD = 2000 * 1e18; // 1 ETH = $2000 (18 decimals)
    
        uint256 result = auction.convertETHtoUSD(address(0), ethAmount);
        assertEq(result, expectedUSD, "ETH to USD conversion incorrect");
    }

    function test_ConvertERC20toUSD() public {
        // 设置USDC价格为$1.00
        usdcPriceFeed.setPrice(1 * 1e8);
    
        uint256 usdcAmount = 1000 * 1e6; // 1000 USDC (6 decimals)
        uint256 expectedUSD = 1000 * 1e18; // $1000 (18 decimals)
    
        uint256 result = auction.convertERC20toUSD(address(usdc), usdcAmount);
        assertEq(result, expectedUSD, "USDC to USD conversion incorrect");
    }

    function test_GetTokenPrice() public {
        uint256 expectedPrice = 1 * 1e8; // $1.00
        uint256 price = auction.getTokenPrice(address(usdc));
        assertEq(price, expectedPrice, "Token price incorrect");
    
        // 测试ETH价格
        expectedPrice = 2000 * 1e8; // $2000
        price = auction.getTokenPrice(address(0));
        assertEq(price, expectedPrice, "ETH price incorrect");
    }   


    function test_Events() public {
        vm.startPrank(seller);
    
        // 测试 AuctionCreated 事件
        vm.expectEmit(true, true, true, true);
        /*
        emit AuctionCreated(
            auction.getAuctionId(address(nft), TOKEN_ID_1),
            seller,
            address(0),
            MIN_BID_USD,
            block.timestamp,
            block.timestamp + 1 days
        );
    
        auction.listAuctionItem(
            address(nft),
            TOKEN_ID_1,
            block.timestamp,
            block.timestamp + 1 days,
            NFTAuction.AuctionStatus.PENDING,
            MIN_BID_USD
        );*/
    
        vm.stopPrank();
    }   

    function test_Fuzz_Auction(
        uint256 minBidUSD,
        uint256 bidAmount1,
        uint256 bidAmount2
    ) public {
        // 限制输入范围
        minBidUSD = bound(minBidUSD, 100 * 1e18, 10000 * 1e18);
        bidAmount1 = bound(bidAmount1, minBidUSD, minBidUSD * 10);
        bidAmount2 = bound(bidAmount2, bidAmount1 + 1, minBidUSD * 20);
    
        vm.assume(bidAmount2 > bidAmount1);
    
        // 执行测试逻辑
        vm.startPrank(seller);
        auction.listAuctionItem(
            address(nft),
            TOKEN_ID_1,
            block.timestamp,
            block.timestamp + 1 days,
            NFTAuction.AuctionStatus.PENDING,
            minBidUSD
        );
        auction.startAuction(address(nft), TOKEN_ID_1);
        vm.stopPrank();
    
        // 竞拍者1
        vm.prank(bidder1);
        auction.payWithETH{value: 10 ether}();
        auction.placeBid(address(nft), TOKEN_ID_1, bidAmount1);
    
        // 竞拍者2
        vm.prank(bidder2);
        auction.payWithETH{value: 10 ether}();
        auction.placeBid(address(nft), TOKEN_ID_1, bidAmount2);
    
        // 验证最高出价者是bidder2
        // 注意：需要添加getter函数来验证
    }

    function test_Stress_MultipleAuctions() public {
        uint256 numAuctions = 10;
    
        for (uint256 i = 0; i < numAuctions; i++) {
            vm.startPrank(seller);
            nft.mint(seller, 1000 + i);
            nft.approve(address(auction), 1000 + i);
        
            auction.listAuctionItem(
                address(nft),
                1000 + i,
                block.timestamp,
                block.timestamp + 1 days,
                NFTAuction.AuctionStatus.PENDING,
                MIN_BID_USD * (i + 1)
            );
            auction.startAuction(address(nft), 1000 + i);
            vm.stopPrank();
        
            // 竞拍
            vm.prank(bidder1);
            auction.payWithETH{value: 1 ether}();
            auction.placeBid(address(nft), 1000 + i, MIN_BID_USD * (i + 1) + 100 * 1e18);
        }
    
        // 验证所有拍卖都正确创建
        // 注意：需要添加相应的验证逻辑
    }
}
    