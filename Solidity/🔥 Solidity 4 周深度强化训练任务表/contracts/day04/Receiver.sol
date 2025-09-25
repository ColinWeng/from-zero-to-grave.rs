// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

/**
 * 编写两个合约`Sender`/`Receiver`，通过`call`调用对方的方法
 */
contract Receiver {

    // 定义一个接收事件
    event Received(address indexed from, uint256 indexed amount, string message);

    // 普通函数，可被 call 调用
    function foo(string calldata _message) external payable returns(uint256 ){
        emit Received(msg.sender, msg.value,_message);
        return 111;
    }

    // 特殊函数 receive
    // 用于直接接收 ETH（没有data且有receive时执行）
    receive() external payable {
        emit Received(msg.sender, msg.value,"Receive was called");
    }

    // 特殊函数 fallback
    // 接收 ETH，没有函数匹配，会调用
    fallback() external payable {
        emit Received(msg.sender, msg.value,"Fallback was called");
    }
}
