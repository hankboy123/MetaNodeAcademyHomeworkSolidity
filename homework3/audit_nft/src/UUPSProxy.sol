// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// 代理合约
contract UUPSProxy {
    // 逻辑合约地址存储在EIP-1967指定槽位
    bytes32 private constant _IMPLEMENTATION_SLOT = 
        0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
    
    // 构造函数，设置初始逻辑合约
    constructor(address _logic, bytes memory _data) {
        require(_logic != address(0), "Invalid logic address");
        _setImplementation(_logic);
        
        // 可选的初始化调用
        if (_data.length > 0) {
            (bool success, ) = _logic.delegatecall(_data);
            require(success, "Initialization failed");
        }
    }
    
    // 回退函数，委托调用逻辑合约
    fallback() external payable virtual {
        _delegate(_implementation());
    }
    
    receive() external payable virtual {
        _delegate(_implementation());
    }
    
    // 获取当前逻辑合约地址
    function _implementation() internal view returns (address impl) {
        assembly {
            impl := sload(_IMPLEMENTATION_SLOT)
        }
    }
    
    // 委托调用实现
    function _delegate(address implementation) internal {
        assembly {
            calldatacopy(0, 0, calldatasize())
            
            let result := delegatecall(
                gas(),
                implementation,
                0,
                calldatasize(),
                0,
                0
            )
            
            returndatacopy(0, 0, returndatasize())
            
            switch result
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
    }
    
    // 内部函数：设置新的逻辑合约
    function _setImplementation(address newImplementation) private {
        require(
            Address.isContract(newImplementation),
            "ERC1967: new implementation is not a contract"
        );
        
        assembly {
            sstore(_IMPLEMENTATION_SLOT, newImplementation)
        }
    }
}

// 地址工具库
library Address {
    function isContract(address account) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }
}