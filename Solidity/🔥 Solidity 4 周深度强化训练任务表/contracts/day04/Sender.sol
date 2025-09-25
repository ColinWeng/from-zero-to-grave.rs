// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

contract Sender {

    // 调用 receiver 的 foo() 方法，同时可传 ETH
    // 因为对 _receiver 发起转账，所以需要是 address payable
    // _message 不需要修改，所以使用 calldata，比 memory 少 gas
    function callFoo(address payable _receiver, string calldata _message) external payable {
        (bool success, bytes memory data) = _receiver.call{value: msg.value}(
            // 对目标函数签名编码
            abi.encodeWithSignature("foo(string)", _message)
        );
        require(success, "call failed");

        // 这里需要用 (uint256)，没有括号会编译失败
        uint256 returnValue = abi.decode(data, (uint256));
        require(returnValue == 111, "Unexpected return value");
    }

    // 直接发送 ETH（测试 receive/fallback）
    function sendETH(address payable _receiver) external payable {
        (bool success,) = _receiver.call{value: msg.value}("");
        require(success, "send ETH failed");
    }
}
