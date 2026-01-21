// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// 导入 OpenZeppelin 的 ERC721 实现
import "openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import "openzeppelin-contracts/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "openzeppelin-contracts/contracts/utils/Counters.sol";

contract MyNFT is ERC721, ERC721URIStorage, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdCounter;

    // 可配置的铸造价格
    uint256 public mintPrice = 0.01 ether;
    
    // 每个地址的铸造限制
    uint256 public maxMintPerAddress = 10;
    
    // 总供应量限制
    uint256 public maxSupply = 10000;
    
    // 记录每个地址铸造的数量
    mapping(address => uint256) private _mintedCount;
    
    // 基础 URI
    string private _baseTokenURI;

    // 事件声明
    event Minted(address indexed to, uint256 indexed tokenId, string tokenURI);
    event BatchMinted(address indexed to, uint256[] tokenIds);
    event PriceUpdated(uint256 newPrice);
    event BaseURIUpdated(string newBaseURI);

    constructor(
        string memory name,
        string memory symbol,
        string memory baseURI
    ) ERC721(name, symbol) {
        _baseTokenURI = baseURI;
        // 将合约部署者设置为所有者
        _transferOwnership(msg.sender);
    }

    // 安全铸造函数（公开铸造）
    function safeMint(address to, string memory uri) public payable {
        require(_tokenIdCounter.current() < maxSupply, "Max supply reached");
        require(msg.value >= mintPrice, "Insufficient payment");
        require(_mintedCount[to] < maxMintPerAddress, "Exceeds mint limit");
        
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _mintedCount[to]++;
        
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);
        
        emit Minted(to, tokenId, uri);
    }

    // 批量铸造（仅所有者）
    function batchMint(address to, string[] memory uris) public onlyOwner {
        require(_tokenIdCounter.current() + uris.length <= maxSupply, "Exceeds max supply");
        
        uint256[] memory tokenIds = new uint256[](uris.length);
        
        for (uint256 i = 0; i < uris.length; i++) {
            uint256 tokenId = _tokenIdCounter.current();
            _tokenIdCounter.increment();
            
            _safeMint(to, tokenId);
            _setTokenURI(tokenId, uris[i]);
            
            tokenIds[i] = tokenId;
        }
        
        emit BatchMinted(to, tokenIds);
    }

    // 铸造给指定地址（仅所有者，免费）
    function mintToAddress(address to, string memory uri) public onlyOwner {
        require(_tokenIdCounter.current() < maxSupply, "Max supply reached");
        
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);
        
        emit Minted(to, tokenId, uri);
    }

    // 更新铸造价格（仅所有者）
    function setMintPrice(uint256 newPrice) public onlyOwner {
        mintPrice = newPrice;
        emit PriceUpdated(newPrice);
    }

    // 更新基础URI（仅所有者）
    function setBaseURI(string memory newBaseURI) public onlyOwner {
        _baseTokenURI = newBaseURI;
        emit BaseURIUpdated(newBaseURI);
    }

    // 设置单个token的URI
    function setTokenURI(uint256 tokenId, string memory _tokenURI) public {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "Caller is not owner nor approved");
        _setTokenURI(tokenId, _tokenURI);
    }

    // 更新每个地址的铸造限制
    function setMaxMintPerAddress(uint256 newLimit) public onlyOwner {
        maxMintPerAddress = newLimit;
    }

    // 更新总供应量
    function setMaxSupply(uint256 newMaxSupply) public onlyOwner {
        require(newMaxSupply >= _tokenIdCounter.current(), "New supply must be >= current minted");
        maxSupply = newMaxSupply;
    }

    // 提取合约余额（仅所有者）
    function withdraw() public onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No balance to withdraw");
        
        (bool success, ) = payable(owner()).call{value: balance}("");
        require(success, "Withdrawal failed");
    }

    // 获取已铸造的总量
    function totalSupply() public view returns (uint256) {
        return _tokenIdCounter.current();
    }

    // 获取地址已铸造的数量
    function mintedCount(address account) public view returns (uint256) {
        return _mintedCount[account];
    }

    // 检查token是否存在
    function exists(uint256 tokenId) public view returns (bool) {
        return _exists(tokenId);
    }

    // 获取合约中所有token的持有者
    function getAllOwners() public view returns (address[] memory) {
        uint256 total = _tokenIdCounter.current();
        address[] memory owners = new address[](total);
        
        for (uint256 i = 0; i < total; i++) {
            owners[i] = ownerOf(i);
        }
        
        return owners;
    }

    // 重写基础URI函数
    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }

    // 重写必需的函数（ERC721URIStorage）
    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    // 重写必需的函数（ERC721URIStorage）
    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    // 支持接口检测
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}