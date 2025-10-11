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


  cast send 0xf37d842a936c35596a85adb8ec1db8ee9aa5b4e5 \
  "mint(address,uint256)" \
  0xf162E7beCA3bE717A71254676aFB274A9815B629 \
  100 \
  --rpc-url sepolia \
  --private-key 0x4b6865d1496bb2c1c1ba5c43c10e01eb05d0b9388d8c14c2fc14e064fecaf4aa

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