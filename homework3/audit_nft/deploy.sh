# 加载环境变量
source .env

# 部署并验证
forge script script/DeployNFTAuction.s.sol:DeployNFTAuction \
    --rpc-url $SEPOLIA_RPC_URL \
    --private-key $PRIVATE_KEY \
    --broadcast \
    --verify \
    -vvvv