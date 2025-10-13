// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "../../contracts/day09/MyToken.sol";
import "forge-std/Script.sol";

/*
forge script scripts/day13/Deploy.s.sol \
  --rpc-url sepolia \
  --broadcast \
  --verify \
  --etherscan-api-key xxx

 */
contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // 部署合约（构造参数可以换成你自己的）
        MyToken token = new MyToken("MyToken", "MTK",1000);

        vm.stopBroadcast();

        console.log("MyToken deployed to:", address(token));
    }
}