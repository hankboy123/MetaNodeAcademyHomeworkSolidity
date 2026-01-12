pragm solidity ^0.8.0;


contract BeggingContract {
    struct TimeRestriction {
        uint256 startTime;
        uint256 endTime;
        bool  isTimeRestricted;  // 是否启用时间限制
    }

    struct Donor {
        address donorAddress;
        uint256 amount;
        bool exists;  // 明确的存在标志
    }
    uint256 private _locked = 1;
    
    modifier nonReentrant() {
        require(_locked == 1, "ReentrancyGuard: reentrant call");
        _locked = 2;
        _;
        _locked = 1;
    }

    TimeRestriction public timeRestriction;
    mapping(address => Donor) public balances;
    address[] public donors;

    uint256 public totalBalance;
    uint256 public withdrawnAmount;
    address public owner;
    constructor(){
        owner = msg.sender;
        timeRestriction = TimeRestriction({
            startTime: 0,
            endTime: 0,
            isTimeRestricted: false
        });
        
    }

    modifier onlyOwner(){
         require(msg.sender == owner, "Only owner can withdraw");
        _;
    }

    event Donation (address indexed donor, uint256 amount, uint256 totalBalance);
    event Withdrawn(address indexed withdrawer, uint256 amount, uint256 totalBalance);

    function enableTimeRestriction(uint256 startTime, uint256 endTime) public onlyOwner {
        require(startTime < endTime, "Start time must be before end time");
        timeRestriction = TimeRestriction({
            startTime: startTime,
            endTime: endTime,
            isTimeRestricted: true
        });
    }

    function donate() public payable nonReentrant returns(uint256){
        require(msg.value > 0, "Must send some ether to beg");
        // 检查时间限制
        if (timeRestriction.isTimeRestricted) {
            require(block.timestamp >= timeRestriction.startTime, "Donation period has not started");
            require(block.timestamp <= timeRestriction.endTime, "Donation period has ended");
        }
        Donor storage donor = balances[msg.sender];
        if (!donor.exists) {
            // 新捐赠者
            donor.exists = true;
            donor.donorAddress = msg.sender;
            donor.totalAmount = msg.value;
        } else {
            // 现有捐赠者更新
            donor.totalAmount += msg.value;
            donors.push(msg.sender);
        }
        totalBalance += msg.value;        
        emit Donation (msg.sender, msg.value, balances[msg.sender].amount);
        return balances[msg.sender].amount;
    }

    function withdraw(uint256 amount) public onlyOwner nonReentrant returns(uint256){
        require(amount <= totalBalance, "Insufficient balance to withdraw");
        totalBalance -= amount;
        withdrawnAmount += amount;
        payable(msg.sender).transfer(amount);
        emit Withdrawn(msg.sender, amount, totalBalance);
        return totalBalance;
    }

    function getBalance() public view returns(uint256){
        return balances[msg.sender];
    }

    function getTop(uint n) public view returns(address[] memory){
        require(n>0, "Insufficient number");
        address[] memory topN=new address[](n);
        uint256[] memory topNBalances=new uint256[](n);
        for(uint256 i=0; i<n; i++){
            topNBalances[i] = 0;
            topN[i] = address(0);
        }

        // This is not gas efficient, but works for demonstration purposes
        for(uint256 i=0; i<donors.length; i++){ // Assume max 1000 donors for simplicity
            address donorAddress = donors[i];
            Donor storage donor = balances[donorAddress];


            for(uint256 j=0; j<n; j++){
                

                if(donor.amount > topNBalances[j]){
                    // Shift lower ranks down
                    for(uint256 k=n-1; k>j; k--){
                        topNBalances[k] = topNBalances[k-1];
                        topN[k] = topN[k-1];
                    }
                    topNBalances[j] = donor.amount;
                    topN[j] = donorAddress;
                    break;
                }
            }
        }
        return topN;    

    }

}