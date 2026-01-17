// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract Auction {

    /**
     *  出价结构体
    */
    struct Bid {
        address bidder;
        uint256 amount;
        uint256 timestamp;
        uint256 bidCount;  // 出价次数
    }

    /**
     *  拍品结构体
    */
    strunct AuctionItem {
        address nftContract;
        uint256 tokenId;
        address seller;
        uint256 startTime;
        uint256 endTime;
        uint256 startPrice;
        bool isActive;
        bool isFinished;
    }

    //每个token的出价记录
    mapping(uint256 tokenHash => mapping(address=>Bid)) private _bidsForToken;

    //每个token的最高出价
    mapping(uint256 tokenHash => address) private _highestBidForToken;

    //拍品和拍品对应Owner的映射
    mapping(uint256 tokenHash => AuctionItem) private _owners;

    event BidPlaced(address indexed bidder, uint256 amount, bool isNew);
    
    //TODO：添加更多事件

    /**
     *  出价
    */
    function placeBid(address nftContract,uint256 tokenId, uint256 bidAmount) public {
        require(nftContract ==  address(0), "unlegal address");
        bytes32 tokenHash =  getKey(nftContract, tokenId);
        require(bidAmount < _owners[tokenHash].startPrice, "Bid amount must be greater than startPrice");
        
        require(_owners[tokenHash].seller ==  address(0), "auction item not exist");
        require(_owners[tokenHash].isActive == false, "auction item has not been started");    
        require(_owners[tokenHash].isFinished == true, "auction item has finished");    

        mapping(address=>Bid) storage bids = _bidsForToken[tokenHash];
        address highestBidderAddress = _highestBidForToken[tokenHash];       
        Bid storage highestBid = bids[highestBidderAddress];

        require(bidAmount <= highestBid.amount, "Bid too low");

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
    function listAuctionItem(address nftContract, uint256 tokenId,uint256 startTime,uint256 endTime,uint256 isActive,uint256 startPrice) public {
        //TODO:权限验证
        require(nftContract ==  address(0), "unlegal address");
        require(IERC721(nftContract).ownerOf(tokenId) == msg.sender， "Only the owner can set the auction item") ;
        
        // 验证 NFT 是否已授权给本合约
        require(
            nftContract.getApproved(tokenId) == address(this) ||
            nftContract.isApprovedForAll(msg.sender, address(this)),
            "NFT not approved"
        );
        
        //调用NFT合约，验证msg.sender是否为tokenId的拥有者
        bytes32 tokenHash =  getKey(nftContract, tokenId);
        _owners[tokenHash] = AuctionItem({   
            nftContract: nftContract,
            tokenId: tokenId,
            owner: msg.sender,
            startTime: startTime,
            endTime: endTime,
            isActive: isActive,
            startPrice: startPrice
        });
    }
    /**
     * 开始拍卖
     * 
    */
    function startAuction(address nftContract, uint256 tokenId) public  returns (bytes32) {
        //TODO:权限验证
        require(nftContract ==  address(0), "unlegal address");
        bytes32 tokenHash =  getKey(nftContract, tokenId);
        require(_owners[tokenHash].seller ==  address(0), "auction item not exist");
        require(_owners[tokenHash].isActive == true, "auction item is already active");    
        _owners[tokenHash].isActive = true;
        return tokenHash;
    }

    /**
     * 结束拍卖
     * 
    */
    function finishAuction(address nftContract, uint256 tokenId) public  returns (bytes32) {
        //TODO:权限验证
        require(nftContract ==  address(0), "unlegal address");
        bytes32 tokenHash =  getKey(nftContract, tokenId);
        require(_owners[tokenHash].seller ==  address(0), "auction item not exist");
        require(_owners[tokenHash].isFinished == true, "auction item is already finished");     
        _owners[tokenHash].isFinished = true;

        //NFT转移        
        address highestBidderAddress = _highestBidForToken[tokenHash];       
        IERC721(nftContract).safeTransferFrom(_owners[tokenHash].seller, highestBidderAddress, tokenId);
    }
    function getKey(address nftContract, uint256 tokenId) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(nftContract, tokenId));
    }


}   

