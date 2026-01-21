// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract NFTAuction {
    // Chainlink 价格预言机

    enum AuctionStatus { PENDING, ACTIVE, ENDED, CANCELLED }
    
    enum FundType { ETH, USD, ERC20 }

    /**
     *  买家支付的金额结构体（暂时没用）
    */
    struct PaidMoney{
        address fundAddress;
        uint256 amount;  
        FundType fundType;
        bool isExist;
    }

    /**
     *  出价结构体
    */
    struct Bid {
        address bidder;
        uint256 amountUSD;  // 美金
        uint256 timestamp;
        uint256 bidCount;  // 出价次数
    }

    /**
     *  拍品结构体
    */
    struct AuctionItem {
        address nftContract;
        uint256 tokenId;
        address seller;
        uint256 startTime;
        uint256 endTime;
        uint256 minBidUSD;  // 美金
        AuctionStatus status;    // 拍卖状态
    }

    mapping(uint256 => AggregatorV3Interface) private _priceFeeds;

    //每个拍卖的出价记录
    mapping(uint256  => mapping(address=>Bid)) private _bidsForToken;

    //每个拍卖的最高出价
    mapping(uint256  => address) private _highestBidForToken;

    
    //最高出价者支付的金额
    mapping(address => mapping(uint256 => PaidMoney)) private _paidAmounts;
    mapping(address => uint256[]) private _paidFundTypes;

    //拍品和拍品对应Owner的映射
    mapping(uint256 auctionId => AuctionItem) private _owners;

    // 支持的代币列表
    address[] public supportedTokens;

    event BidPlaced(address indexed bidder, uint256 amount, bool isNew);

    event AuctionCreated(
        bytes32 indexed auctionId,
        address indexed creator,
        address acceptedToken,
        uint256 minBidUSD,
        uint256 startTime,
        uint256 endTime
    );
    
    event NewBid(
        bytes32 indexed auctionId,
        uint256 indexed bidId,
        address indexed bidder,
        address token,
        uint256 tokenAmount,
        uint256 usdValue,
        uint256 timestamp
    );
    
    event BidUpdated(
        bytes32 indexed auctionId,
        uint256 indexed bidId,
        uint256 newUsdValue
    );
    
    event AuctionEnded(
        bytes32 indexed auctionId,
        address indexed winner,
        uint256 winningBidId,
        uint256 winningAmountUSD
    );
    
    event PriceFeedUpdated(
        address indexed token,
        address priceFeed
    );

    // ============ 构造函数 ============
    constructor() {
        // 初始化 ETH/USD 价格预言机（Sepolia 测试网）
         uint256 fundTypeId = getFundTypeId(FundType.ETH,address(0));
        _setPriceFeed(fundTypeId, address(0x694AA1769357215DE4FAC081bf1f309aDC325306));
    }

    /**
     * @dev 设置代币价格预言机
     * @param token 代币地址（address(0) 表示 ETH）
     * @param priceFeed Chainlink 预言机地址
     */
    function setPriceFeed(address token, address priceFeed)  {
         uint256 fundTypeId = getFundTypeId(FundType.ETH,fundAddress);
        _setPriceFeed(fundTypeId, priceFeed);
    }
    
    function _setPriceFeed(uint256 fundTypeId, address priceFeed) internal {
        _priceFeeds[fundTypeId] = AggregatorV3Interface(priceFeed);
        if (fundAddress != address(0)) {
            // 添加到支持的代币列表（如果未存在）
            bool exists = false;
            for (uint i = 0; i < supportedTokens.length; i++) {
                if (supportedTokens[i] == token) {
                    exists = true;
                    break;
                }
            }
            if (!exists) {
                supportedTokens.push(token);
            }
        }
        
        emit PriceFeedUpdated(token, priceFeed);
    }

    /**
     * 支付竞价
    */
    function payWithETH() public payable {
        require(msg.value >0, "Payment amount mismatch");
        /**
         * 
        require(nftContract !=  address(0), "unlegal address");
        bytes32 auctionId =  getAuctionId(nftContract, tokenId);
        require(_owners[auctionId].status == AuctionStatus.END, "auction item has not been finished");     
        mapping(address=>Bid) storage bids = _bidsForToken[auctionId];
        address highestBidderAddress = _highestBidForToken[auctionId];     
        require(highestBidderAddress == msg.sender, "lower bidder do not have to pay ");
        */
       
        uint256 fundTypeId = getFundTypeId(FundType.ETH, address(0));
    

        mapping(uint256 => PaidMoney) storage paidMoneyMap = _paidAmounts[msg.sender];
        PaidMoney storage paidMoney = paidMoneyMap[fundTypeId];
        if(paidMoney.isExist == false){
            //新增
            paidMoney.fundAddress = msg.address;
            paidMoney.fundType = FundType.ETH;
             _paidFundTypes[msg.address].push(fundTypeId);
            paidMoney.amount =amount;
            paidMoney.isExist=true;
        }else{
            //修改
            paidMoney.amount += amount;
        }

    }

    /**
     * 支付竞价
    */
    function payWithERC20(address ERC20Address, uint256 amount) public payable {
        require(ERC20Address !=  address(0), "unlegal address");
        require(amount >0, "Payment amount mismatch");
         /**
        require(nftContract !=  address(0), "unlegal address");
        bytes32 auctionId =  getAuctionId(nftContract, tokenId);
        require(_owners[auctionId].status == AuctionStatus.END, "auction item has not been finished");     
        mapping(address=>Bid) storage bids = _bidsForToken[auctionId];
        address highestBidderAddress = _highestBidForToken[auctionId];     
        require(highestBidderAddress == msg.sender, "lower bidder do not have to pay ");
        Bid storage highestBid = bids[highestBidderAddress];  
        */
        uint256 fundTypeId = getFundTypeId(FundType.ERC20, ERC20Address);

        IERC20 token = IERC20(ERC20Address);
        token.transferFrom(msg.sender, address(this), amount);   
        
        mapping(uint256 => PaidMoney) storage paidMoneyMap = _paidAmounts[msg.sender];
        PaidMoney storage paidMoney = paidMoneyMap[fundTypeId];
        if(paidMoney.fundAddress ==address(0)){
            paidMoney.fundAddress = ERC20Address;
            paidMoney.fundType = FundType.ERC20;
             _paidFundTypes[ERC20Address].push(fundTypeId);
            //新增
            paidMoney.amount =amount;
        }else{
            //修改
            paidMoney.amount += amount;
        }
    }
    
    

    function existsPaidFundType(address bidder, FundType fundType) internal view returns (bool) {
        
        uint256[] storage fundTypes = _paidFundTypes[bidder];
        for (uint i = 0; i < fundTypes.length; i++) {
            if (fundTypes[i] == uint256(fundType)) {
                return true;
            }
        }
        return false;
    }

    function existsInSupportedTokens(address token) internal view returns (bool) {
        for (uint i = 0; i < supportedTokens.length; i++) {
            if (supportedTokens[i] == token) {
                return true;
            }
        }
        return false;
    }

    /**
     *  出价
    */
    function placeBid(address nftContract,uint256 tokenId, uint256 bidAmount) public {
        require(nftContract !=  address(0), "unlegal address");
        bytes32 auctionId =  getAuctionId(nftContract, tokenId);
        require(bidAmount >= _owners[auctionId].minBidUSD, "Bid amount must be greater than minBidUSD");
        
        require(_owners[auctionId].seller !=  address(0), "auction item not exist");
        require(_owners[auctionId].isActive == true, "auction item has not been started");    
        require(_owners[auctionId].status != AuctionStatus.ENDED, "auction item has finished");    

        mapping(address=>Bid) storage bids = _bidsForToken[auctionId];
        address highestBidderAddress = _highestBidForToken[auctionId];       
        Bid storage highestBid = bids[highestBidderAddress];

        require(bidAmount > highestBid.amount, "Bid too low");

        // 可以添加基于实时价格的复杂逻辑
        int256 currentPrice = getLatestPrice();
        emit PriceUpdated(currentPrice);

        Bid storage existingBid = bids[msg.sender];
        if (existingBid.bidder == address(0)) {
            // 第一次出价
            bids[msg.sender] = Bid({
                bidder: msg.sender,
                amount: bidAmount,
                timestamp: block.timestamp,
                bidCount: 1
            });
            emit BidPlaced(msg.sender, bidAmount, true);
        } else {
            // 更新出价
            existingBid.amount = bidAmount;
            existingBid.timestamp = block.timestamp;
            existingBid.bidCount += 1;
            emit BidPlaced(msg.sender, bidAmount, false);
        }

        _highestBidForToken[tokenId]=msg.sender;
    }

    /**
     *  上架拍品
    */
    function listAuctionItem(address nftContract, uint256 tokenId,uint256 startTime,uint256 endTime,AuctionStatus status,uint256 minBidUSD) public {
        //TODO:权限验证
        require(nftContract !=  address(0), "unlegal address");
        require(IERC721(nftContract).ownerOf(tokenId), "Only the owner can set the auction item") ;
        
        // 验证 NFT 是否已授权给本合约
        require(
            nftContract.getApproved(tokenId) == address(this) ||
            nftContract.isApprovedForAll(msg.sender, address(this)),
            "NFT not approved"
        );
        
        //调用NFT合约，验证msg.sender是否为tokenId的拥有者
        bytes32 auctionId =  getAuctionId(nftContract, tokenId);
        _owners[auctionId] = AuctionItem({   
            nftContract: nftContract,
            tokenId: tokenId,
            owner: msg.sender,
            startTime: startTime,
            endTime: endTime,
            status: status,
            minBidUSD: minBidUSD
        });
    }
    /**
     * 开始拍卖
     * 
    */
    function startAuction(address nftContract, uint256 tokenId) public  returns (bytes32) {
        //TODO:权限验证
        require(nftContract !=  address(0), "unlegal address");
        bytes32 auctionId =  getAuctionId(nftContract, tokenId);
        require(_owners[auctionId].seller !=  address(0), "auction item not exist");
        require(_owners[auctionId].status != AuctionStatus.ACTIVE, "auction item has finished");    
        _owners[auctionId].status = AuctionStatus.ACTIVE;
        return auctionId;
    }

    /**
     * 结束拍卖
     * 
    */
    function endAuction(address nftContract, uint256 tokenId) public  returns (bytes32) {
        //TODO:权限验证
        
        require(nftContract !=  address(0), "unlegal address");
        require(_owners[auctionId].seller !=  address(0), "auction item not exist");
        require(_owners[auctionId].status != AuctionStatus.END, "auction item is already finished");     
        bytes32 auctionId =  getAuctionId(nftContract, tokenId);
        mapping(address=>Bid) storage bids = _bidsForToken[auctionId];
        address highestBidderAddress = _highestBidForToken[auctionId];       
        Bid storage highestBid = bids[highestBidderAddress];


        for(uint i=0;i<_paidFundTypes[highestBidderAddress].length;i++){
            uint256 fundTypeId = _paidFundTypes[highestBidderAddress][i];
            if(fundTypeId == address(0)){
                //ETH
                uint256 ethAmount = _paidAmounts[highestBidderAddress][fundTypeId].amount;
                paidAmount += convertETHtoUSD(fundTypeId,ethAmount);
            }else{
                //ERC20
                uint256 erc20Amount = _paidAmounts[highestBidderAddress][fundTypeId].amount;
                paidAmount += convertERC20toUSD(fundTypeId,erc20Amount);
            }
        }

        require(paidAmount >= highestBid.amount, "paid money is not enough");
        _owners[auctionId].status = AuctionStatus.END;        

        //NFT转移        
        address highestBidderAddress = _highestBidForToken[auctionId];
        //TODO: 资金结算
                       
        IERC721(nftContract).safeTransferFrom(_owners[auctionId].seller, highestBidderAddress, tokenId);
    }

    /**
     * 提现资金(最高出价的人提取多余现金，卖家提取竞标的现金)
    */
    function withdrawFunds(address nftContract, uint256 tokenId) public {
        require(nftContract !=  address(0), "unlegal address");
        bytes32 auctionId =  getAuctionId(nftContract, tokenId);
        require(_owners[auctionId].seller !=  address(0), "unlegal address");   
        address highestBidderAddress = _highestBidForToken[auctionId];      
        mapping(address=>Bid) storage bids = _bidsForToken[auctionId];     
        Bid storage highestBid = bids[highestBidderAddress];
        uint256 amount = _paidAmounts[highestBidderAddress].amount; 
        require(_owners[auctionId].seller ==  msg.sender, "not seller");   
        require(amount >= highestBid.amount, "No funds to withdraw");



        for(uint i=0;i<_paidFundTypes.length;i++){
            uint256 fundTypeId = _paidFundTypes[i];
            if(fundTypeId == address(0)){
                
                //ETH            
                uint256 ethAmount = _paidAmounts[highestBid.bidder][fundTypeId].amount;
                _paidAmounts[highestBid.bidder][fundTypeId].amount= 0;
                payable(msg.sender).transfer(ethAmount); 
            }else{
                //ERC20
                uint256 erc20Amount = _paidAmounts[highestBidderAddress][fundTypeId].amount;
                _paidAmounts[highestBid.bidder][fundTypeId].amount= 0;                
                IERC20 token = IERC20(paidMoney.fundAddress);
                token.transferFrom(address(this), msg.sender, erc20Amount);  
            }
        }
     

    }

    /**
     *  获取最新ETH/USD价格
     */
    function getLatestPrice(uint256 fundTypeId) public view returns (int256) {
        (, int256 price, , , ) = _priceFeeds[fundTypeId].latestRoundData();
        return price;
    }

    /**
     *  将ETH转换为USD
     */
    function convertETHtoUSD(uint256 fundTypeId,uint256 ethAmount) public view returns (uint256) {
        int256 price = getLatestPrice(fundAddress);
        require(price > 0, "Invalid price");
        return (ethAmount * uint256(price)) / 1e8;
    }
    function convertERC20toUSD(uint256 fundTypeId,uint256 erc20Amount) public view returns (uint256) {
         // 验证代币地址
        require(token != address(0), "Invalid token address");
        require(tokenAmount > 0, "Token amount must be > 0");
        
        // 获取价格
        uint256 price = getTokenPrice(token);
        
        // 获取代币小数位
        uint8 tokenDecimals = getTokenDecimals(token);
        
        // 计算USD价值
        // 公式：usdValue = tokenAmount * price / 10^tokenDecimals
        // price已经有8位小数，所以结果也有8位小数
        usdValue = (tokenAmount * price) / (10 ** uint256(tokenDecimals));
        
        return usdValue;
    }
    
    /**
     *  将USD转换为ETH
     */
    function convertUSDtoETH(uint256 usdAmount) public view returns (uint256) {
        int256 price = getLatestPrice();
        require(price > 0, "Invalid price");
        return (usdAmount * 1e8) / uint256(price);
    }

    /**
     * @dev 获取代币价格（带验证）
     * @param token 代币地址
     * @return price 价格（带8位小数）
     */
    function getTokenPrice(address token) public view returns (uint256 price) {
        // 检查价格预言机是否设置
        AggregatorV3Interface priceFeed = priceFeeds[token];
        require(address(priceFeed) != address(0), "Price feed not set");
        
        // 获取最新价格数据
        (, int256 answer, , uint256 updatedAt, ) = priceFeed.latestRoundData();
        
        // 验证价格有效性
        require(answer > 0, "Invalid price");
        require(block.timestamp - updatedAt <= 1 hours, "Stale price");
        
        return uint256(answer);
    }
    
    /**
     * @dev 获取代币小数位
     * @param token 代币地址
     * @return decimals 小数位
     */
    function getTokenDecimals(address token) public view returns (uint8) {
        try IERC20Metadata(token).decimals() returns (uint8 decimals) {
            return decimals;
        } catch {
            // 如果无法获取，返回默认值
            return DEFAULT_DECIMALS;
        }
    }

    /**
     * @dev 获取代币价格和元数据
     
    function getTokenPriceInfo(address token) 
        external 
        view 
        returns (
            uint256 price,
            uint8 tokenDecimals,
            uint8 priceFeedDecimals,
            string memory tokenSymbol,
            bool isPriceFeedSet
        ) 
    {
        tokenDecimals = getTokenDecimals(token);
        priceFeedDecimals = CHAINLINK_DECIMALS;
        isPriceFeedSet = address(priceFeeds[token]) != address(0);
        
        try IERC20Metadata(token).symbol() returns (string memory symbol) {
            tokenSymbol = symbol;
        } catch {
            tokenSymbol = "UNKNOWN";
        }
        
        if (isPriceFeedSet) {
            price = getTokenPrice(token);
        } else {
            price = 0;
        }
        
        return (price, tokenDecimals, priceFeedDecimals, tokenSymbol, isPriceFeedSet);
    }*/

    function getAuctionId(address nftContract, uint256 tokenId) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(nftContract, tokenId));
    }

    
    function getFundTypeId(FundType fundType, address addressERC) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(fundType, addressERC));
    }



}   

