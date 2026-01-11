pragm solidity ^0.8.0;

contract Voting{
    mapping(address => uint256)  votes;
    address[] public candidates;

    event Voted  (address indexed voter, address indexed votee, uint256 totalVotes);
    event VotesReset(address indexed voter);

    constructor(address[] memory _candidates){
        for(uint256 i=0; i<_candidates.length; i++){
            candidates.push(_candidates[i]);
            votes[_candidates[i]] = 0;
        }
    }

    function vote(address votee)public returns(uint256){
        votes[votee] +=1;
        emit Voted(msg.sender, votee, votes[votee]);
        return votes[votee];
    }

    function getVotes() public view return(uint256){
        return votes[msg.sender];
    }
    function resetVotes() public {
        for(uint256 i=0; i<candidates.length; i++){
            votes[candidates[i]] = 0;
        }
        emit VotesReset(msg.sender);
    }

    /**
     * 只针对ASCII字符有效
    */
    function reverse(string memory stringToReverse) public pure returns (string memory){
        bytes memory strBytes = bytes(stringToReverse);
        uint256 len = strBytes.length;
        bytes memory reversed = new bytes(len);
        for(uint256 i=0; i<len; i++){
            reversed[i] = strBytes[len - i - 1];
        }
        return string(reversed);
    }

    /**
     * 罗马数字包含以下七种字符: I， V， X， L，C，D 和 M。
        字符          数值
        I             1
        V             5
        X             10
        L             50
        C             100
        D             500
        M             1000
        例如， 罗马数字 2 写做 II ，即为两个并列的 1 。12 写做 XII ，即为 X + II 。 27 写做  XXVII, 即为 XX + V + II 。

        通常情况下，罗马数字中小的数字在大的数字的右边。但也存在特例，例如 4 不写做 IIII，而是 IV。数字 1 在数字 5 的左边，所表示的数等于大数 5 减小数 1 得到的数值 4 。同样地，数字 9 表示为 IX。这个特殊的规则只适用于以下六种情况：

        I 可以放在 V (5) 和 X (10) 的左边，来表示 4 和 9。
        X 可以放在 L (50) 和 C (100) 的左边，来表示 40 和 90。 
        C 可以放在 D (500) 和 M (1000) 的左边，来表示 400 和 900。
        给定一个罗马数字，将其转换成整数。
     * 
     * 
    */
   
   function romanToInt(string memory s) public pure returns (uint256){
        bytes memory strBytes = bytes(s);
        uint256 total = 0;
        uint256 prevValue = 0;

        for(uint256 i=0; i<strBytes.length; i++){
            uint256 currValue = charToValue(strBytes[i]);
            if(currValue > prevValue && prevValue !=0){
                total += currValue - 2 * prevValue;
            }else{
                total += currValue;
            }
            prevValue = currValue;
        }
        return total;
   }
   function charToValue(bytes1 char) internal pure returns (uint256){
        if(char == "I") return 1;
        if(char == "V") return 5;
        if(char == "X") return 10;
        if(char == "L") return 50;
        if(char == "C") return 100;
        if(char == "D") return 500;
        if(char == "M") return 1000;
        return 0;
   }
   /**
    * 七个不同的符号代表罗马数字，其值如下：

    符号	值
    I	1
    V	5
    X	10
    L	50
    C	100
    D	500
    M	1000
    罗马数字是通过添加从最高到最低的小数位值的转换而形成的。将小数位值转换为罗马数字有以下规则：

    如果该值不是以 4 或 9 开头，请选择可以从输入中减去的最大值的符号，将该符号附加到结果，减去其值，然后将其余部分转换为罗马数字。
    如果该值以 4 或 9 开头，使用 减法形式，表示从以下符号中减去一个符号，例如 4 是 5 (V) 减 1 (I): IV ，9 是 10 (X) 减 1 (I)：IX。仅使用以下减法形式：4 (IV)，9 (IX)，40 (XL)，90 (XC)，400 (CD) 和 900 (CM)。
    只有 10 的次方（I, X, C, M）最多可以连续附加 3 次以代表 10 的倍数。你不能多次附加 5 (V)，50 (L) 或 500 (D)。如果需要将符号附加4次，请使用 减法形式。
    给定一个整数，将其转换为罗马数字.
    * 
   */

  function intToRoman(uint256 num) public pure returns (string memory){
        uint256[13] memory values = [1000, 900, 500, 400, 100, 90, 50, 40, 10, 9, 5, 4, 1];
        string[13] memory symbols = ["M", "CM", "D", "CD", "C", "XC", "L", "XL", "X", "IX", "V", "IV", "I"];

        string memory result = "";
        for(uint256 i=0; i<values.length; i++){
            while(num >= values[i]){
                num -= values[i];
                result = string(abi.encodePacked(result, symbols[i]));
            }
        }
        return result;
   }

   function mergeSort(uint256[] memory arr) public pure returns (uint256[] memory){
        if(arr.length <=1){
            return arr;
        }
        uint256 mid = arr.length / 2;
        uint256[] memory left = new uint256[](mid);
        uint256[] memory right = new uint256[](arr.length - mid);

        for(uint256 i=0; i<mid; i++){
            left[i] = arr[i];
        }
        for(uint256 i=mid; i<arr.length; i++){
            right[i - mid] = arr[i];
        }

        left = mergeSort(left);
        right = mergeSort(right);

        return merge(left, right);
   }

    function merge(uint256[] memory left, uint256[] memory right) internal pure returns (uint256[] memory){
          uint256[] memory result = new uint256[](left.length + right.length);
          uint256 i=0;
          uint256 j=0;
          uint256 k=0;
    
          while(i<left.length && j<right.length){
                if(left[i] <= right[j]){
                 result[k++] = left[i++];
                }else{
                 result[k++] = right[j++];
                }
          }
          while(i<left.length){
                result[k++] = left[i++];
          }
          while(j<right.length){
                result[k++] = right[j++];
          }
          return result;
    }

    /**
     * 二分法查找
     * 
    */
    function search(nums []int, target int) int {
        int left = 0;
        int right = len(nums) - 1;
       while(left <= right){
           int mid = (left + right) / 2;
           if(nums[mid] == target){
              return mid;
           }else if(nums[mid] < target){
              left = mid + 1;
           }else{
              right = mid - 1;
           }
      }
      return -1;
    }

}   