// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

/*
   从零实现 ERC-20
    - ERC-20 接口（`totalSupply`/`transfer`/`approve`/`transferFrom`/`allowance`）
    - 事件`Transfer`/`Approval`
 */
/*
 * 为什么需要授权机制？
 * - ERC20 的授权机制本质上是为了实现 用户授予第三方地址在限定额度内代为转账的能力，这既提升了安全性，又为复杂的链上交互（如交易所、合约交互、自动扣费）提供了必要基础。
 */
contract MyToken {

    string public name = "MyToken";                 // 货币名称
    string public symbol = "MTK";                   // 货币标记
    uint8 public decimals = 18;                     // 它表示 代币的最小分割单位，18 是业界最常用的默认值（和以太币 ETH 一样）。
    uint256 public totalSupply;                     // 总供应链

    mapping(address => uint256) private balances;   // 每个账户余额

    // 授权额度 mapping: owner => (spender => amount)
    // 每个账户（owner）针对每个被授权人（spender）能够代替自己花费多少代币。
    mapping(address => mapping(address => uint256)) private allowances;

    // 转账事件
    event Transfer(address indexed from, address indexed to, uint256 value);
    // 授权事件
    event Approval(address indexed owner, address indexed spender, uint256 value);

    // 初始发行代币给部署者
    constructor(uint256 initialSupply){
        // 10 ** uint256(decimals)：因为 Solidity 里 ** 是幂运算，这里表示 10^18 次方
        // totalSupply 转换成最小单位存储（int类型）
        totalSupply = initialSupply * (10 ** uint256(decimals));
        balances[msg.sender] = totalSupply;
        // address(0) 是 Solidity 里全零地址（0x0000000000000000000000000000000000000000）。
        // 铸造（Mint）代币： 从 0x0 -> 某用户，表示“从无到有”生成代币（新币）
        // 销毁（Burn）代币： 从某用户 -> 0x0，表示“从有到无”销毁代币
        emit Transfer(address(0), msg.sender, totalSupply);
    }

    // 定义 public ，合约内外都能访问；external 只能外部访问或用 this. 访问
    function balanceOf(address account) public view returns (uint256){
        return balances[account];
    }

    // 转账给 `to`
    function transfer(address to, uint256 amount) public returns (bool) {
        require(to != address(0), "ERC20: transfer to the zero address");
        require(balances[msg.sender] >= amount, "ERC20: transfer amount exceeds balance");
        balances[msg.sender] -= amount;
        balances[to] += amount;
        emit Transfer(msg.sender,to, amount);
        return true;
    }

    //  授权 spender 从当前用户花费 amount
    function approve(address spender, uint256 amount) public returns (bool){
        require(spender != address(0), "ERC20: approve to the zero address");
        allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    // 查询授权额度
    function allowance(address owner, address spender) public view returns (uint256){
        return allowances[owner][spender];
    }

    // 有授权记录，才能发起
    // spender 从 from 地址转账给 to
    function transferFrom(address from, address to, uint256 amount) public returns (bool){
        require(to != address(0), "ERC20: transfer to zero address");
        require(balances[from] >= amount, "ERC20: amount exceeds balance");
        require(allowances[from][msg.sender] >= amount, "ERC20: amount exceeds allowance");

        // 更新余额和授权
        balances[from] -= amount;
        balances[to] += amount;
        allowances[from][msg.sender] -= amount;

        emit Transfer(from, to, amount);
        return true;
    }

}
