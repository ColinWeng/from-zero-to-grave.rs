## **D1 — Solidity 基础复盘 + 银行合约**

- **学习点**：
    - 状态变量（`storage`/`memory`/`calldata`）
    - `public/private/internal/external` 可见性
    - `require` / `revert` / `assert`
- **实操任务**：
  
    - 写一个 `Bank.sol` 合约：
        - 存款（`deposit()`）
        - 查询余额（`getBalance()`）
        - 提款（`withdraw(uint amount)`）
- **测试**：
  
    - 用 Hardhat 写 JS/TS 单元测试（chai + ethers.js）
      
        ```bash
        npx hardhat test
        ```
    
- **输出**：
  
    - 合约代码 + 测试覆盖率截图

--------

### 示例代码

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

/*
 * 写一个 `Bank.sol` 合约：
    - 存款（`deposit()`）
    - 查询余额（`getBalance()`）
    - 提款（`withdraw(uint amount)`）
 */
contract Bank {

    // 存储用户的余额
    mapping(address => uint256) private balances;

    event DepositEvent(address indexed user, uint256 amount);
    event WithdrawEvent(address indexed user, uint256 amount);

    // 存款（`deposit()`）
    // 要让用户调用，并能支付，所以需要 external 和 payable
    // 全局变量 `msg.value` 表示 本次调用发送的 Wei 数量
    function deposit() external payable {
        require(msg.value > 0, "deposit value must > 0");
        balances[msg.sender] += msg.value;
        // 发送存款事件
        emit DepositEvent(msg.sender, msg.value);
    }

    // 查询余额（`getBalance()`）
    // 查询自己的余额，不会进行修改，所以需要 external 和 view
    // 全局变量 `msg.sender` 表示 当前调用者地址
    function getBalance() external view returns (uint256) {
        return balances[msg.sender];
    }

    // 提款（`withdraw(uint amount)`）
    function withdraw(uint amount) external {
        require(amount > 0, "withdraw amount value must > 0");
        require(balances[msg.sender] >= amount, "Insufficient balance");
        // 先减，防止重入
        balances[msg.sender] -= amount;
        // 发起转账
        (bool sent,) = payable(msg.sender).call{value: amount}("");
        // 校验转账结果
        require(sent, "call failed");
        //  发送转账事件
        emit WithdrawEvent(msg.sender, amount);
    }
}
```

###  测试代码

创建 `Bank.t.sol` 文件

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {Test} from "forge-std/Test.sol";
import {Bank} from "./Bank.sol";

contract BankTest is Test {

    Bank bank;

    address user1;
    address user2;

    function setUp() public {
        // 给测试地址生成
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        // 部署合约
        bank = new Bank();

        // 给 user1 & user2 初始 ETH 余额
        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);
    }

    // 测试存款
    function testDeposit() public {
        uint256 depositAmount = 1 ether;

        // 以 user1 身份调用 deposit
        vm.prank(user1);
        bank.deposit{value: depositAmount}();

        uint256 balance = bank.getBalance();
        // 注意：调用 getBalance() 时，默认 msg.sender 是本合约（Test），而不是 user1
        // 所以我们用 vm.prank 来指定 msg.sender
        vm.prank(user1);
        uint256 userBalance = bank.getBalance();

        assertEq(userBalance, depositAmount);
    }

    // 测试提款成功
    function testWithdraw() public {
        uint256 depositAmount = 1 ether;

        // user1 存款
        vm.prank(user1);
        bank.deposit{value: depositAmount}();

        // user1 提款
        vm.startPrank(user1);
        bank.withdraw(depositAmount);
        vm.stopPrank();

        // 验证余额应为 0
        vm.prank(user1);
        uint256 finalBalance = bank.getBalance();
        assertEq(finalBalance, 0);
    }

    // 测试提款失败（余额不足）
    function testWithdrawRevertWhenInsufficientBalance() public {
        vm.prank(user1);
        vm.expectRevert(bytes("Insufficient balance"));
        bank.withdraw(1 ether);
    }

    // 测试事件 — 存款
    function testDepositEvent() public {
        vm.expectEmit(true, true, true, true);
        emit Bank.Deposit(user1, 1 ether);

        vm.prank(user1);
        bank.deposit{value: 1 ether}();
    }

    // 测试事件 — 提款
    function testWithdrawEvent() public {
        vm.prank(user1);
        bank.deposit{value: 1 ether}();

        vm.expectEmit(true, true, true, true);
        emit Bank.Withdraw(user1, 1 ether);

        vm.prank(user1);
        bank.withdraw(1 ether);
    }
}
```

bash 执行 `npx hardhat test solidity`。

> 使用  IntelliJ IDEA 开发，环境配置好，可以直接运行。



### TypeScript 测试

test 目录下创建 `Bank.ts` 。

```ts
import {expect} from "chai";
import {network} from "hardhat";

const {ethers} = await network.connect();

describe("Bank Contract (TypeScript)", function () {

    it("should allow deposit and update balance correctly", async function () {
        // 获取测试账户
        const [user1, user2] = await ethers.getSigners();
        const bank = await ethers.deployContract("Bank");
        await bank.waitForDeployment();

        const depositAmount = ethers.parseEther("1.0");

        await expect(
            bank.connect(user1).deposit({value: depositAmount})
        )
            .to.emit(bank, "Deposit")
            .withArgs(user1.address, depositAmount);

        const balance = await bank.connect(user1).getBalance();
        expect(balance).to.equal(depositAmount);
    });

});
```

比较下，更倾向于 Solidity 测试 的方式。



---

## **D2 — Ownable 权限控制**

- **学习点**：
    - OpenZeppelin `Ownable`
    - `modifier` 用法
- **实操任务**：
    - 在 `Bank.sol` 中增加只有 `owner` 能调用的 `closeBank()` 函数
- **测试**：
    - 用 Foundry `.t.sol` 写权限测试
      
        ```bash
        forge test
        ```
    
- **输出**：Foundry 测试通过截图

--------

### 示例代码

安装 OpenZeppelin 依赖

```bash
npm install @openzeppelin/contracts
forge install OpenZeppelin/openzeppelin-contracts   
```



```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

// 引入 OpenZeppelin Ownable
// 如果有  '"@openzeppelin/contracts/access/Ownable.sol"' cannot be resolved 的提示 ，
// 执行 
//     npm install @openzeppelin/contracts
//     如果出现（fatal: not a git repository (or any of the parent directories） 
//     执行  git init
//     forge install OpenZeppelin/openzeppelin-contracts   
import "@openzeppelin/contracts/access/Ownable.sol";

/*
    在`Bank.sol`中增加只有`owner`能调用的`closeBank()`函数
 */
// 继承 抽象合约 Ownable
contract Bank is Ownable {

    mapping(address => uint256) private balances;

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    // 新增关闭事件
    event BankClosed(address indexed owner, uint256 remainingBalance);

    /*
     * 在 Solidity 中，合约的构造函数执行顺序是：
        父合约的构造函数 会在子合约的构造函数体执行 之前 调用。
        执行顺序按照继承关系，从最顶层的父合约向下。
        如果父合约有构造函数参数，可以在子合约构造函数的签名后一对括号里传入（像你写的 Ownable(msg.sender)）。
     */
    constructor() Ownable(msg.sender){
        // 默认 owner 是部署者
    }

    function deposit() external payable {
        require(msg.value > 0, "deposit value must > 0");
        balances[msg.sender] += msg.value;
        emit Deposit(msg.sender, msg.value);
    }

    function getBalance() external view returns (uint256) {
        return balances[msg.sender];
    }

    function withdraw(uint amount) external {
        require(amount > 0, "withdraw amount value must > 0");
        require(balances[msg.sender] >= amount, "Insufficient balance");
        balances[msg.sender] -= amount;
        (bool sent,) = payable(msg.sender).call{value: amount}("");
        require(sent, "call failed");
        emit Withdraw(msg.sender, amount);
    }

    // 只有 owner 可以关闭银行
    function closeBank() external onlyOwner {
        // mapping(address => uint256) private balances 记录用户余额，
        // address(this).balance 直接读取 EVM 合约上的 balance，
        // 当前合约地址的余额
        uint256 remaining = address(this).balance;
        // 转账所有资金给 owner
        if (remaining > 0) {
            (bool sent,) = payable(owner()).call{value: remaining}("");
            require(sent, "Transfer failed");
        }
        emit BankClosed(owner(), remaining);
    }
}
```

###  测试代码

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {Test} from "forge-std/Test.sol";
import {Bank} from "./Bank.sol";

contract BankTest is Test {

    Bank public bank;
    address owner;
    address user1;
    address user2;

    function setUp() public {
        owner = makeAddr("owner");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        vm.deal(owner, 100 ether);
        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);

        vm.startPrank(owner);
        bank = new Bank();
        vm.stopPrank();
    }

    function testBalancesMatchContractBalance() public {
        // 以 user1 身份调用 deposit
        vm.prank(user1);
        bank.deposit{value: 5 ether}();

        vm.prank(user1);
        uint256 user1Balance = bank.getBalance();

        // 以 user2 身份调用 deposit
        vm.prank(user2);
        bank.deposit{value: 3 ether}();

        vm.prank(user2);
        uint256 user2Balance = bank.getBalance();

        // 获取逻辑余额总和
        uint256 totalLogicBalance = user1Balance + user2Balance;
        // 获取真实链上余额
        uint256 contractBalance = address(bank).balance;

        assertEq(totalLogicBalance, contractBalance, "The total logical balance should be equal to the real balance of the contract");
    }

    function testCloseBankTransfersAllToOwner() public {
        // 用户1存 5 ETH
        vm.prank(user1);
        bank.deposit{value: 5 ether}();

        uint256 ownerBefore = owner.balance;

        // 🎯 声明我们期望捕获的事件
        vm.expectEmit(true, false, false, true);
        emit Bank.BankClosed(owner, 5 ether); // 注意这里要加 Bank. 前缀调用事件签名

        // owner 关闭银行
        vm.startPrank(owner);
        bank.closeBank();
        vm.stopPrank();

        // 验证合约余额为 0
        assertEq(address(bank).balance, 0, "The contract balance should be 0");

        // 验证 owner 收到资金
        assertEq(owner.balance, ownerBefore + 5 ether, "owner All funds should be received");
    }
}
```



---

## **D3 — Withdraw Pattern（拉取支付）**

- **学习点**：
    - 重入风险与解决
    - 存储用户余额，**提现时用户自己调用**
- **实操任务**：
    - 新建 `PullPaymentBank.sol`
    - 存款时增加余额记录
    - 提现时读取余额 → 转账 → 余额清零
- **测试**：
    - 测试多账户互不影响余额
- **输出**：Hardhat & Foundry 都测试通过

---

### 示例代码

```solidity
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/*
- 新建`PullPaymentBank.sol`
- 存款时增加余额记录
- 提现时读取余额 → 转账 → 余额清零
 */
// 使用 openzeppelin 提供的防重入抽象类
contract PullPaymentBank is ReentrancyGuard{

    mapping(address => uint256) private balances;

    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);

    // 存款
    function deposit() external payable {
        require(msg.value > 0, "Deposit must be greater than 0");
        balances[msg.sender] += msg.value;
        emit Deposited(msg.sender, msg.value);
    }

    // 查看余额
    function getBalance() external view returns (uint256) {
        return balances[msg.sender];
    }

    // 提现 — 拉取支付模式
    // 使用 函数修改器（nonReentrant），防重入
    function withdraw() external nonReentrant {
        uint256 amount = balances[msg.sender];
        require(amount > 0, "No balance to withdraw");

        // 先将余额清零
        balances[msg.sender] = 0;

        // 再转账
        (bool sent, ) = payable(msg.sender).call{value: amount}("");
        require(sent, "Transfer failed");

        emit Withdrawn(msg.sender, amount);
    }
}
```

**关键点**：

1. **状态更新在先（balances 置为 0）**，外部调用在后 → 防止重入
2. 使用 `ReentrancyGuard` 双保险
3. `withdraw()` 时不传参数，只能提取自己余额 → 避免越权

### 测试代码

`PullPaymentBank.t.sol` 

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {Test} from "forge-std/Test.sol";
import {PullPaymentBank} from "./PullPaymentBank.sol";

contract PullPaymentBankTest is Test {
    PullPaymentBank public bank;
    address user1;
    address user2;

    function setUp() public {
        bank = new PullPaymentBank();
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);
    }


    function testMultipleAccountsIndependentBalances() public {
        // user1 存 5 ETH
        vm.prank(user1);
        bank.deposit{value: 5 ether}();

        // user2 存 3 ETH
        vm.prank(user2);
        bank.deposit{value: 3 ether}();

        // 检查各自余额
        vm.prank(user1);
        assertEq(bank.getBalance(), 5 ether);

        vm.prank(user2);
        assertEq(bank.getBalance(), 3 ether);

        // user1 提现
        vm.prank(user1);
        bank.withdraw();
        assertEq(user1.balance, 100 ether); // 提回来了

        // user2 不受影响
        vm.prank(user2);
        assertEq(bank.getBalance(), 3 ether);
    }

}

```

攻击合约 `ReentrancyAttackPull`

```solidity
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "./PullPaymentBank.sol";

/**
 * 恶意攻击合约，这个攻击合约会在收到钱时，尝试再次调用 withdraw() 来重入
 */
contract ReentrancyAttackPull {

    PullPaymentBank public bank;
    address public owner;

    constructor(address _bank) {
        bank = PullPaymentBank(_bank);
        owner = msg.sender;
    }

    // 在收到 ETH 时尝试再调用 withdraw()
    receive() external payable {
        if (address(bank).balance >= 1 ether) {
            bank.withdraw(); // 在安全合约里会失败
        }
    }

    // 启动攻击流程
    function attack() external payable {
        require(msg.value >= 1 ether, "Need >= 1 ETH");

        // 首先存入 1 ETH
        bank.deposit{value: msg.value}();

        // 发起第一次提现
        bank.withdraw();
    }

    // 提取本合约中资金
    function withdrawStolenFunds() external {
        require(msg.sender == owner, "Only owner");
        payable(owner).transfer(address(this).balance);
    }
}

```

测试重入攻击  `ReentrancyTestPull.t.sol`

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./ReentrancyAttackPull.sol";
import {Test} from "forge-std/Test.sol";

contract ReentrancyTestPull is Test {

    PullPaymentBank public bank;
    ReentrancyAttackPull public attacker;

    address deployer = makeAddr("deployer");
    address user1 = makeAddr("user1");

    function setUp() public {
        vm.startPrank(deployer);
        bank = new PullPaymentBank();
        vm.stopPrank();

        // 给 user1 和攻击合约一些启动资金
        vm.deal(user1, 10 ether);

        // 部署攻击合约
        vm.startPrank(user1);
        attacker = new ReentrancyAttackPull(address(bank));
        vm.stopPrank();
    }

    function testReentrancyFails() public {
        emit log_named_uint("Bank balance before", address(bank).balance);
        emit log_named_uint("Attacker balance before", address(attacker).balance);

        // user1 发动攻击
        vm.startPrank(user1);
        attacker.attack{value: 1 ether}();
        vm.stopPrank();

        emit log_named_uint("Bank balance after", address(bank).balance);
        emit log_named_uint("Attacker balance after", address(attacker).balance);

        // 验证银行还剩钱（攻击未造成损失）
        assertEq(address(bank).balance, 0, "Bank should remain empty after user's withdrawal");
        // 验证攻击者只拿回了自己的钱（没偷额外资金）
        assertEq(address(attacker).balance, 1 ether, "Attacker should only get its own deposit back");
    }
}

```



---------



## **D4 — 合约间调用**

- **学习点**：
    - `call` / `delegatecall` / `staticcall`
    - `fallback` / `receive`
- **实操任务**：
    - 编写两个合约 `Sender` / `Receiver`，通过 `call` 调用对方的方法
- **测试**：
    - 模拟发送 ETH；验证事件是否触发
- **输出**：JS 测试脚本执行结果截图

---

### 示例代码
Receiver.sol
```solidity
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
```
Sender.sol
```solidity
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
```



### 测试代码
D4_CallTest.t.sol
```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./Receiver.sol";
import "./Sender.sol";
import {Test} from "forge-std/Test.sol";

contract D4_CallTest is Test {

    Receiver public receiver;
    Sender public sender;
    address user;

    function setUp() public {
        receiver = new Receiver();
        sender = new Sender();
        user = makeAddr("user");
        vm.deal(user, 100 ether);
    }

    // 测试调用 foo
    function testCallFooWithETH() public {
        vm.prank(user);
        vm.expectEmit(true, true, false, true);
        emit Receiver.Received(address(sender), 1 ether, "Hello from Sender");

        sender.callFoo{value: 1 ether}(payable(address(receiver)), "Hello from Sender");
    }

    // 测试直接发送 ETH
    function testSendETH() public {
        vm.prank(user);
        vm.expectEmit(true, true, false, true);
        emit Receiver.Received(address(sender), 0.5 ether, "Receive was called");

        sender.sendETH{value: 0.5 ether}(payable(address(receiver)));
    }
}
```

--------



## **D5 — DAO 投票合约 & **D6 — Foundry 测试改造

- **学习点**：
    - `struct` 管理提案
    - `mapping` 存储投票记录
    - 时间戳控制开始/结束
- **实操任务**：
    - `createProposal(string desc)` 创建提案
    - `vote(uint proposalId)` 投票
    - `closeProposal(uint proposalId)` 关闭 & 计算结果
- **测试**：
    - Hardhat 测试：多人投票 & 时间过期不可投
- **输出**：投票逻辑测试通过截图

--------



- **学习点**：
  - Foundry `.t.sol` 测试写法
  - `setUp()` 初始化
  - 事件断言、fuzz 测试
- **实操任务**：
  - 给 DAO 投票合约加 `.t.sol` 测试
- **输出**：Foundry 测试覆盖率报告



---

### 示例代码

```solidity
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

/*
    - `createProposal(string desc)`创建提案
    - `vote(uint proposalId)`投票
    - `closeProposal(uint proposalId)`关闭 & 计算结果
 */
contract DaoVoting {

    struct Proposal {
        string description;             // 提案描述
        uint256 voteCount;              // 投票数
        uint256 startTime;              // 开始时间
        uint256 endTime;                // 结束时间
        bool closed;                    // 结束标记
        mapping(address => bool) voted; // 投票人
    }

    Proposal[] public proposals;        // 所有提案

    event ProposalCreated(uint256 proposalId, string description, uint256 startTime, uint256 endTime);
    event Voted(uint256 proposalId, address voter);
    event ProposalClosed(uint256 proposalId, uint256 finalVoteCount);

    // 创建提案
    /*
        时间单位：（需要注意润秒）
            1 seconds
            1 minutes
            1 hours
            1 days
            1 weeks
     */
    function createProposal(string calldata desc) external {
        uint256 start = block.timestamp;
        uint256 end = block.timestamp + 3 days;

        // 创建 Proposal 结构体并推入数组（这样描述可能不太合适）
        // 和 Java 不同，不能使用 new 去创建 struct。
        // .push() 是 storage 动态数组的标准初始化方式，
        proposals.push();
        Proposal storage p = proposals[proposals.length - 1];
        p.description = desc;
        p.voteCount = 0;
        p.startTime = start;
        p.endTime = end;
        p.closed = false;

        emit ProposalCreated(proposals.length - 1, desc, start, end);
    }

    // 投票，对一个提案进行投票，投了就是同意
    function vote(uint proposalId) external {
        // 校验议题
        require(proposalId < proposals.length, "Proposal not found");
        // 使用 storage，表示获取 storage 中的引用；memory 的话，会创建一个内存副本
        Proposal storage p = proposals[proposalId];
        // 校验时间
        require(block.timestamp >= p.startTime, "Voting not started");
        require(block.timestamp <= p.endTime, "Voting ended");
        // 校验投票人，p.voted[msg.sender] 不存在，默认值是 false
        require(!p.voted[msg.sender], "Already voted");

        p.voted[msg.sender] = true;
        p.voteCount += 1;

        emit Voted(proposalId, msg.sender);
    }

    // 关闭 & 计算结果，关闭提案并输出最终票数
    function closeProposal(uint proposalId) external {
        require(proposalId < proposals.length, "Proposal not found");
        Proposal storage p = proposals[proposalId];
        require(block.timestamp > p.endTime, "Voting still active");
        require(!p.closed, "Already closed");

        p.closed = true;
        emit ProposalClosed(proposalId, p.voteCount);
    }

    function getProposal(uint proposalId) external view returns (
        string memory description,
        uint256 voteCount,
        uint256 startTime,
        uint256 endTime,
        bool closed
    ){
        require(proposalId < proposals.length, "Proposal not found");
        Proposal storage p = proposals[proposalId];
        return (p.description, p.voteCount, p.startTime, p.endTime, p.closed);
    }
}

```

### 测试代码

```solidity
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./DaoVoting.sol";
import {Test} from "forge-std/Test.sol";

contract DaoVotingTest is Test {

    DaoVoting dao;
    address alice;
    address bob;
    address carol;

    function setUp() public {
        dao = new DaoVoting();
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        carol = makeAddr("carol");
    }

    function testCreateProposal() public {
        dao.createProposal("Hello DAO");

        (
            string memory description,
            uint256 voteCount,
            uint256 startTime,
            uint256 endTime,
            bool closed
        ) = dao.getProposal(0);

        assertEq(description, "Hello DAO");
        assertEq(voteCount, 0);
        assertFalse(closed);
        assertTrue(startTime < endTime);
    }

    function testVoteAndCount() public {
        dao.createProposal("Vote Test");

        vm.startPrank(alice);
        dao.vote(0);

        vm.startPrank(bob);
        dao.vote(0);

        vm.startPrank(carol);
        dao.vote(0);

        (, uint256 voteCount,,,) = dao.getProposal(0);

        assertEq(voteCount, 3);
    }

    function testCannotDoubleVote() public {
        dao.createProposal("No Double Voting");

        vm.startPrank(alice);
        dao.vote(0);

        vm.expectRevert(bytes("Already voted"));
        dao.vote(0);
    }

    function testCannotVoteAfterEndTime() public {
        dao.createProposal("Time Limit Test");

        (, , , uint256 endTime, ) = dao.getProposal(0);
        // Sets `block.timestamp`. 跳时间：超过结束时间
        vm.warp(endTime + 1);

        vm.expectRevert(bytes("Voting ended"));
        vm.prank(alice);
        dao.vote(0);
    }

    function testCloseProposal() public {
        dao.createProposal("Close Test");

        (, , , uint256 endTime, ) = dao.getProposal(0);
        vm.warp(endTime + 1);

        vm.expectEmit(true, false, false, true);
        emit DaoVoting.ProposalClosed(0, 0);
        dao.closeProposal(0);

        (, , , , bool closed) = dao.getProposal(0);
        assertTrue(closed);
    }
}
```



## **D7 — 本周复盘**

- 清理本周代码到 `week1/` 目录
- 整理本周笔记（模式、问题、优化）
- 上传 GitHub
