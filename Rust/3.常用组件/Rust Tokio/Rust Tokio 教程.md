[TOC]
# 介绍

​	Tokio 是一个事件驱动的非阻塞 I/O 平台，用于 Rust 编写异步应用程序。

​	Tokio 不适合的场景： 

* Tokio 是为 IO 密集型设计，不适用 CPU 密集型。CPU 密集应该使用 [rayon](https://docs.rs/rayon/latest/rayon/) 。
* 读取大量文件。与普通线程池相比，Tokio 没有优势，因为操作系统通常不提供异步文件API。
* 发送单个 web 请求。单请求，应该使用 [reqwest](https://docs.rs/reqwest/latest/reqwest/) 。



# 设置

​	官方提供 Mini-Redis ，用于学习 Tokio。

```bash
# 安装 
$ cargo install mini-redis
# 启动
$ mini-redis-server
```

​	新开一个单独终端。

```bash
$ mini-redis-cli get foo
```

​	会返回 `(nil)`。

# Hello Tokio

## 实例代码

​	创建 crate

```bash
$ cargo new my-redis
$ cd my-redis
```

​	添加 `Cargo.toml` 依赖

```toml
tokio = { version = "1", features = ["full"] }
mini-redis = "0.4"
```

​	编写代码（`main.rs`）

```rust
use mini_redis::Result;
use mini_redis::client;

#[tokio::main]
async fn main() -> Result<()> {
  	// 异步建立 TCP 连接
    let mut client = client::connect("127.0.0.1:6379").await?;
    client.set("hello", "world".into()).await?;
    let result = client.get("hello").await?;
    println!("got value from the server; result={:?}", result);
    Ok(())
}
```

​	确保 `mini-redis-server` 运行，执行 `cargo run` 。	

## 分析代码

```rust
let mut client = client::connect("127.0.0.1:6379").await?;
```

​	该[`client::connect`](https://docs.rs/mini-redis/0.4/mini_redis/client/fn.connect.html)函数由 crate 提供`mini-redis`。它与指定的远程地址异步建立 TCP 连接。连接建立后，`client`将返回一个句柄。尽管该操作是异步执行的，但我们编写的代码**看起来像是** 同步的。唯一能表明该操作是异步的，就是 `.await`操作符。

### 编译时绿色线程

​	Rust 使用 `async/await` 的功能实现异步编程。执行异步操作的函数带有 `async` 标记。`connect` 函数的定义如下：

```rust
use mini_redis::Result;
use mini_redis::client::Client;
use tokio::net::ToSocketAddrs;

pub async fn connect<T: ToSocketAddrs>(addr: T) -> Result<Client> {
    // ...
}
```

​	该`async fn`定义看起来像一个常规的同步函数，但实际上是异步运行的。Rust`async fn`在**编译**时将其转换为异步运行。任何对 `.await` 的调用都会将`async fn`控制权交还给线程。当操作在后台执行时，线程可以执行其他工作。

> ​	虽然其他语言[`async/await`](https://en.wikipedia.org/wiki/Async/await)也实现了异步操作，但 Rust 采取了独特的方法。首先，Rust 的异步操作是**惰性的**。这导致了与其他语言不同的运行时语义。



### 使用 `async/await`

​	异步函数的调用方式与其他Rust函数类似，但是，调用这些函数时，函数不会导致函数体执行。相反，调用 `async fn` 返回一个表示操作的值。这些概念上类似于零参数闭包。要实际运行该操作，应该对返回值使用 `.await` 运算符。

```rust
async fn say_world() {
    println!("world");
}

#[tokio::main]
async fn main() {
    let op = say_world();
    println!("hello");
    op.await;
}
```

​	输出

```rust
hello
world
```

​	`async fn` 的返回值是一个匿名类型，它实现了`Future`  trait。



### 异步 `main` 函数

​	 `main` 函数，是一个 `async fn`、用 `#[tokio::main]` 注释。

​	异步函数必须由运行时（runtime）执行。运行时包含异步任务 **调度程序、事件驱动I/O、计时器**等。运行时不会自动启动，因此需要由主函数来启动它。

​	在 Rust 的异步编程中，**运行时（Runtime）** 是异步任务执行的核心引擎。以下是关键点的解释：

#### **运行时的作用**

- **异步任务调度**：管理多个异步任务（`Future`），决定何时执行、挂起或恢复任务。
- **事件驱动 I/O**：监听系统事件（如网络数据到达、文件读写完成），通知任务继续执行。
- **计时器管理**：处理延时操作（如 `tokio::time::sleep`），在指定时间唤醒任务。
- **资源管理**：分配线程池、管理任务队列等底层资源。

####  **为什么需要手动启动运行时？**

- **零成本抽象原则**：Rust 不强制捆绑特定运行时，允许开发者按需选择（如 `tokio`、`async-std`）。
- **灵活性**：不同场景需要不同配置（如单线程/多线程运行时），手动启动可定制参数。
- **显式开销**：避免未使用的运行时占用资源（如嵌入式系统需轻量级方案）。

> Rust 的异步函数本质是**惰性的**：它们需要运行时驱动才能执行。运行时提供任务调度和 I/O 事件循环等基础设施，而开发者需显式初始化运行时（通过 `#[tokio::main]` 或手动构建），否则异步代码将无法执行。



#### `#[tokio::main]` 宏

​	`#[tokio::main]` 函数是一个宏。它将 `async fn main()` 转换为 进入同步 `fn main()` ，初始化运行时实例并执行异步主函数。

```rust
#[tokio::main]
async fn main() {
    println!("hello");
}
```

​	变为以下：

```rust
fn main() {
    let mut rt = tokio::runtime::Runtime::new().unwrap();
    rt.block_on(async {
        println!("hello");
    })
}
```

# 生成任务（Spawning）

​	开始实现 Redis 服务端上的逻辑。

​	先将 client 代码移动，重新创建新的 `src/main.rs`。

```bash
$ mkdir -p examples
$ mv src/main.rs examples/hello-redis.rs
```

## 接受套接字（Socket）

​	Redis 服务器需要做的第一件事就是接受入站 TCP 套接字。这是通过绑定[`tokio::net::TcpListener`](https://docs.rs/tokio/1/tokio/net/struct.TcpListener.html)到端口**6379**来实现的。然后循环接受套接字。每个套接字都会被处理，然后关闭。现在，我们将读取命令，将其打印到标准输出并返回错误。

```rust
use tokio::net::{TcpListener, TcpStream};
use mini_redis::{Connection, Frame};

#[tokio::main]
async fn main() {
  	// 绑定端口
    let listener = TcpListener::bind("127.0.0.1:6379").await.unwrap();
  	// 循环处理
    loop {
        let (socket, _) = listener.accept().await.unwrap();
        process(socket).await;
    }
}

async fn process(socket: TcpStream) {
  	// 这里使用 mini_redis 的 Frame，避免直接读取字节流操作
    let mut connection = Connection::new(socket);
    if let Some(frame) = connection.read_frame().await.unwrap() {
        println!("GOT: {:?}", frame);
        let response = Frame::Error("unimplemented".to_string());
        connection.write_frame(&response).await.unwrap();
    }
}
```

## 并发

​	我们的服务器出了点小问题（除了只响应错误之外）。它每次只能处理一个入站请求。当连接被接受后，服务器会一直处于 accept 循环块中，直到响应完全写入套接字。

​	我们希望 Redis 服务器能够处理**大量**并发请求。为此，我们需要增加一些并发性。

​	为了并发处理连接，每个入站连接都会生成一个新任务。连接将在此任务上进行处理。

```rust
use tokio::net::TcpListener;

#[tokio::main]
async fn main() {
    let listener = TcpListener::bind("127.0.0.1:6379").await.unwrap();
    loop {
        let (socket, _) = listener.accept().await.unwrap();
      	// 每个 Socket 都会创建一个任务
        tokio::spawn(async move {
            process(socket).await;
        });
    }
}
```

### 任务

​	Tokio 任务是一个异步绿色线程，它们通过将一个 `async` 块传递给  `tokio::spawn` 来创建。该`tokio::spawn`函数返回一个 `JoinHandle`，调用者可以使用它来与生成的任务进行交互。该 块可能有一个返回值。调用者可以使用`.await`来获取返回值。

```rust
#[tokio::main]
async fn main() {
    let handle = tokio::spawn(async {
        "return value"
    });

		// 等待 JoinHandle 返回结果，当任务在执行过程中遇到错误时，JoinHandle会返回Err
    let out = handle.await.unwrap();
    println!("GOT {}", out);
}
```

​	任务是调度程序管理的执行单元。生成任务会将其提交给 Tokio 调度程序，调度程序会确保任务在有工作时执行。生成的任务可以在其生成的同一线程上执行，也可以在不同的运行时线程上执行。任务生成后也可以在线程之间移动。

​	Tokio 中的任务非常轻量。实际上，它们只需要一次分配和 64 字节内存。应用程序可以自由地生成数千个甚至数百万个任务。

### `'static`  边界

​	当你在 Tokio 运行时生产一个任务时，其类型的生命周期必须是 `'static` 。这意味着生成的任务不得包含对任务外部拥有的数据的任何引用。

> ​	一个常见的误解是，Rust 的`'static`生命周期总是意味着“永远存在”，但事实并非如此。一个值存在`'static`并不意味着存在内存泄漏。

​	例如以下代码将无法编辑：

```rust
use tokio::task;

#[tokio::main]
async fn main() {
    let v = vec![1, 2, 3];

    task::spawn(async {
      	// async block may outlive the current function, but
        //      it borrows `v`, which is owned by the current function
        println!("Here's a vec: {:?}", v);
    });
}
```

​	发生这种情况的原因是，默认情况下，变量不会移动到异步代码块中。`v` 变量归 `main` 函数所有。

​	通过添加 `move` 关键字，将 `v `变量 移动到异步代码块中，修复这个问题。

```rust 	
   task::spawn(async move {
        println!("Here's a vec: {:?}", v);
    });
```

​	如果同时有多个任务访问，则必须使用 `Arc` 来共享。

​	请注意，错误消息提到参数类型*超出了*其 `'static`生命周期。这个术语可能相当令人困惑，因为 `'static`生命周期持续到程序结束，所以如果它超过了生命周期，难道不会发生内存泄漏吗？解释是，必须超出生命周期的是*类型*，而不是 *值*`'static`，并且该值可能在其类型不再有效之前就被销毁。

​	当我们说一个值是 时`'static`，这意味着永远保留该值是合理的。这一点很重要，因为编译器无法推断新生成的任务会持续存在多久。我们必须确保该任务能够永远存在，这样 Tokio 才能让它根据需要运行。



### `Send`  边界

​	通过 ` tokio::spawn`  创建的任务，必须实现 `Send`。 这允许 Tokio 运行时在  `.await`  暂停时在线程之间移动任务。

> Send 特征，表示可以再线程边界传输的类型。当编译器确定合适时，该特征将自动实现。

​	只有当在 `.await` 之间保持的所有数据都实现了 `Send`，任务（Tasks）本身才能被视为 `Send`。	

​	调用 `.await`  时，任务会返回调度程序。下次执行任务时，它会从上次返回的位置继续执行。为了实现这个一点，所有在`.await` 之后使用的状态都必须由任务保存。如果此状态实现了`Send` ，就可以跨线程移动，那么任务本身就可以跨线程移动。



例如，以下能编译：

```rust
use tokio::task::yield_now;
use std::rc::Rc;

#[tokio::main]
async fn main() {
    tokio::spawn(async {
        // 在 await 之前，rc 会被 drop 调
        {
            let rc = Rc::new("hello");
            println!("{}", rc);
        }
      	// 当任务 yield 的时候，rc 不需要保存
        yield_now().await;
    });
}
```

以下不能编译：

```rust
use tokio::task::yield_now;
use std::rc::Rc;

#[tokio::main]
async fn main() {
    tokio::spawn(async {
        let rc = Rc::new("hello");
      	// rc 在 await 之后被使用，它就必须被保存
        yield_now().await;
      	// future cannot be sent between threads safely
        println!("{}", rc);
    });
}
```

​	因为 `Rc` 不是线程安全的，替换成 `Arc` 就可以。

### 存储数据

​	我们现在将实现`process`处理传入命令的函数。我们将使用`HashMap`来存储值。`SET`命令将插入到 中 `HashMap`，`GET`值将加载它们。此外，我们将使用循环来为每个连接接受多个命令。

```rust
use tokio::net::TcpStream;
use mini_redis::{Connection, Frame};

async fn process(socket: TcpStream) {
    use mini_redis::Command::{self, Get, Set};
    use std::collections::HashMap;
		// HashMap 存储
    let mut db = HashMap::new();

    let mut connection = Connection::new(socket);

    // 使用 `read_frame` 从 connection 中解析字节
    while let Some(frame) = connection.read_frame().await.unwrap() {
        let response = match Command::from_frame(frame).unwrap() {
            Set(cmd) => {
                // 以 `Vec<u8>` 存储数据
                db.insert(cmd.key().to_string(), cmd.value().to_vec());
                Frame::Simple("OK".to_string())
            }
            Get(cmd) => {
                if let Some(value) = db.get(cmd.key()) {
                    Frame::Bulk(value.clone().into())
                } else {
                    Frame::Null
                }
            }
            cmd => panic!("unimplemented {:?}", cmd),
        };

        // 将数据写入
        connection.write_frame(&response).await.unwrap();
    }
}
```

# 共享数据

​	到目前为止，我们已经有一个可以正常工作的键值服务器。但是，它有一个主要缺陷：状态无法跨连接共享。

## 策略

​	在 Tokio 中，有几种不同的方式共享状态：

1. 使用互斥锁保护共享状态
2. 产生一个任务来 管理状态并使用消息传递对其进行操作

​	通常，对于简单的数据，你会使用第一种方法；对于需要异步操作（例如 I/O 原语）的数据，你会使用第二种方法。在本章中，共享状态为`HashMap`，操作为`insert` 和`get`。这两个操作都不是异步的，因此我们将使用 `Mutex`。

## 添加 `bytes` 依赖项

​	Mini-Redis 在处理网络中字节数组结构的时候， 不使用 `Vec<u8>` ，而是使用 [bytes](https://docs.rs/bytes/1.10.1/bytes/struct.Bytes.html) 中的 `Bytes` 。相对于  `Vec<u8>`，`Bytes` 实例调用 `clone()` 并不会复制底层数据，`Bytes` 实例是指向某些底层数据额引用计数句柄，实现浅克隆。

​	`Cargo.toml` 中添加依赖：

```xml
bytes = "1"
```

## 初始化 `HashMap`

​	`HashMap` 将在多个任务（甚至多个线程）之间共享，必须封装在 `Arc<Mutex<HashMap>>`。`Arc` 保证多线程共享，`Mutex` 保证并发修改。

```rust
use bytes::Bytes;
use std::collections::HashMap;
use std::sync::{Arc, Mutex};
// 	为了方便，使用类型别名。
type Db = Arc<Mutex<HashMap<String, Bytes>>>;
```

​	然后，修改 `main` 函数，初始化 `HashMap`。

```rust
#[tokio::main]
async fn main() {
    let listener = TcpListener::bind("127.0.0.1:6379").await.unwrap();

    println!("Listening");
		// 初始化 HashMap，获取 Arc handle
    let db = Arc::new(Mutex::new(HashMap::<String, Bytes>::new()));

    loop {
        let (socket, _) = listener.accept().await.unwrap();
				// clone 共享对象
        let db = db.clone();
        tokio::spawn(async move {
            process(socket, db).await;
        });
    }
}
```

​	在 Tokio 中，**handle** 一词用于 提供共某些共享状态访问的值的引用。

### 使用 `std::sync::Mutex` 还是 `tokio::sync::Mutex`

​	注意，使用 `std::sync::Mutex` 而**不是** `tokio::sync::Mutex` 来保护 `HashMap` 。一个常见的错误是，在异步代码中无条件地使用`tokio::sync::Mutex`。

​	异步互斥锁（async mutex）是一种在 `.await` 调用期间**保持锁定状态**的互斥锁。当异步任务持有锁后调用`.await` （如I/O操作）时，锁不会被释放。



**同步锁 vs 异步锁**

- 同步锁（如`std::sync::Mutex`）：
  - 抢不到锁时，会卡住当前线程（就像堵车时干等着）。
  - 后果：同一个线程的其他任务也被卡住，无法执行。
- 异步锁（如`tokio::sync::Mutex`）：
  - 抢不到锁时，会暂时"挂起"任务（就像把车停到路边等，让其他车先过）。
  - 但注意：它底层其实还是用同步锁实现的！换用异步锁通常解决不了根本问题。

**黄金法则** ✅ 

​	在异步代码中：

- **可以用同步锁**：如果同时抢锁的任务很少（低竞争），**且不会在 `.await` 等待期间一直占着锁不放**。
- **必须用异步锁**：如果需要在 `.await` 等待期间（比如等网络数据时）持续占用锁。



## 更新 `process()`

​	`process` 函数，添加 `HashMap` 的共享句柄（handle）作为参数。同时，操作 `HashMap` 的时候，需要先获取锁。 `HashMap` 的值类型现在是 `Bytes` （可以方便地克隆它）。

```rust
async fn process(socket: TcpStream, db: Db) {
    use mini_redis::Command::{self, Get, Set};
    
    let mut connection = Connection::new(socket);
    while let Some(frame) = connection.read_frame().await.unwrap() {
        let response = match Command::from_frame(frame).unwrap() {
            Set(cmd) => {
              	// 先锁，在插入
                let mut db = db.lock().unwrap();
                db.insert(cmd.key().to_string(), cmd.value().clone());
                Frame::Simple("OK".to_string())
            }
            Get(cmd) => {
              	// 先锁，在查询
                let db = db.lock().unwrap();
                if let Some(value) = db.get(cmd.key()) {
                    Frame::Bulk(value.clone())
                } else {
                    Frame::Null
                }
            }
            cmd => panic!("unimplemented {:?}", cmd),
        };

        connection.write_frame(&response).await.unwrap();
    }
}
```

## 使用 `MutexGuard` 锁  `.await`

​	以下代码会编译错误：

```rust
use std::sync::{Mutex, MutexGuard};

async fn increment_and_do_stuff(mutex: &Mutex<i32>) {
    let mut lock: MutexGuard<i32> = mutex.lock().unwrap();
    *lock += 1;
  
    do_something_async().await;
} // 锁离开作用域才会释放
```

​	为了避免这种情况，需要做如下修改。

```rust
async fn increment_and_do_stuff(mutex: &Mutex<i32>) {
    {
        let mut lock: MutexGuard<i32> = mutex.lock().unwrap();
        *lock += 1;
    } // 锁离开作用域才会释放

    do_something_async().await;
}
```

以下无用：

```rust
use std::sync::{Mutex, MutexGuard};

// This fails too.
async fn increment_and_do_stuff(mutex: &Mutex<i32>) {
    let mut lock: MutexGuard<i32> = mutex.lock().unwrap();
    *lock += 1;
    drop(lock);

    do_something_async().await;
}
```

​	你不应该试图通过以不需要 `Send` 的方式生成任务来规避这个问题，因为如果 Tokio 在 `.await` ，当任务持有锁时可能会安排其他任务在同一线程上运行，而这个其他任务也可能尝试锁定互斥锁，这将导致死锁，因为等待锁定互斥锁的任务会阻止持有互斥锁的任务是否互斥锁。

### 避免在 `.await` 中持有锁

​	处理互斥锁的最安全的方法是将其包装在结构中，并仅在该结构上的非异步方法内锁定互斥锁。

```rust
use std::sync::Mutex;

struct CanIncrement {
    mutex: Mutex<i32>,
}
impl CanIncrement {
  	// 未标记异步方法
    fn increment(&self) {
        let mut lock = self.mutex.lock().unwrap();
        *lock += 1;
    }
}

async fn increment_and_do_stuff(can_incr: &CanIncrement) {
    can_incr.increment();
    do_something_async().await;
}
```

​	这种模式可以保证不会遇到 `Send` 错误，因为互斥锁保护器不会出现在异步函数的任何地方。当使用 `MutexGuard` 实现了`Send` 时，它还可以防止死锁。

### 使用 Tokio 的异步互斥锁

​	[`tokio::sync::Mutex`](https://docs.rs/tokio/1/tokio/sync/struct.Mutex.html)Tokio 提供的类型也可以使用。

​	Tokio 互斥锁的主要特点是它可以跨线程持有而不会`.await`出现任何问题。异步互斥锁比普通互斥锁更昂贵，通常最好使用另外两种方法之一。

```rust
use tokio::sync::Mutex; 

async fn increment_and_do_stuff(mutex: &Mutex<i32>) {
    let mut lock = mutex.lock().await;
    *lock += 1;

    do_something_async().await;
} // lock goes out of scope here
```

## 任务、线程和争用

​	当争用程度最低时，使用阻塞互斥锁来保护短临界区是一种可接受的策略。当锁发生争用时，执行任务的线程必须阻塞并等待互斥锁。这不仅会阻塞当前任务，还会阻塞当前线程上调度的所有其他任务。

​	默认情况下，Tokio 运行时使用多线程调度。任务被调度到运行时管理的任意数量的线程上。如果调度执行大量任务，并且它们都需要访问互斥锁，则会发生竞争。

​	另一方法，如果使用 `current_thread` 运行时，互斥锁永远不会发生竞争。（`current_thread` 是轻量级的单线程）

​	如果同步互斥锁的竞争成为问题，可以考虑以下选项：

* 让专用任务管理状态并使用消息传递
* 将互斥锁分片
* 重构代码避免互斥

### 互斥分片

​	在 `HashMap` 的例子中，每个键都是独立的，因此互斥分片很适合。

```rust
type ShardedDb = Arc<Vec<Mutex<HashMap<String, Vec<u8>>>>>;

fn new_sharded_db(num_shards: usize) -> ShardedDb {
    let mut db = Vec::with_capacity(num_shards);
    for _ in 0..num_shards {
        db.push(Mutex::new(HashMap::new()));
    }
    Arc::new(db)
}
```

​	首先使用键来识别它属于哪个分片，然后在查询该键。

```rust
let shard = db[hash(key) % db.len()].lock().unwrap();
shard.insert(key, value);
```

​	更复杂的可以参考，[flurry](https://docs.rs/flurry/latest/flurry/)，这是 Java’s `ConcurrentHashMap` 的移植。

# 消息通道（channel）

​	假设我们要并发运行两个 Redis 命令。我们可以为每个命令创建一个任务。可以尝试以下代码：

```rust
use mini_redis::client;

#[tokio::main]
async fn main() {
    let mut client = client::connect("127.0.0.1:6379").await.unwrap();

    // 产生两个任务，一个得到一个键，另一个设置一个键
    let t1 = tokio::spawn(async {
        let res = client.get("foo").await;
    });

    let t2 = tokio::spawn(async {
        client.set("foo", "bar".into()).await;
    });

    t1.await.unwrap();
    t2.await.unwrap();
}
```

​	这个无法编译，由于 `Client` 没有实现 `Copy` ，无法实现共享。此外，`Client::set`需要`&mut self`，这意味着调用它需要独占访问权限。我们可以为每个任务打开一个连接，但这并不理想。

## 消息传递

​	该模式涉及生成一个专用任务来管理 `client` 资源。任何希望发送请求的任务都会向该 `client` 任务发送一条消息。该 `client` 任务代表发送者发出请求，并将响应发送回发送者。 	

​	使用此策略，可以建立单个连接。管理的任务 `client` 能够获得独占访问权限，以便调用 `get` 和 `set`。此外，该通道充当缓冲区。当任务繁忙时，可以向其发送操作。

## Tokio 的 channel

​	Tokio 提供了多个channel，每个都有不同用途：

* `mpsc`：多生产者、单消费者
* `oneshot`：单生产、单消费，只能发送单个值
* `broadcast`：多生产、多消费，每个接受者都能看到每个值
* `watch`：多生产，多消费，不保留历史记录，接受者只能看到最新的值

​	

​	如果需要一个多生产多消费通道，并且每个消息只能一个消费者可见，那么可以使用 [async_channel](https://docs.rs/async-channel/latest/async_channel/) crate。

## 定义消息类型

​	定义 `Command` 枚举，并为每种命令类型定义结构。

```rust
use bytes::Bytes;

#[derive(Debug)]
enum Command {
    Get {
        key: String,
    },
    Set {
        key: String,
        val: Bytes,
    }
}
```

## 创建通道

```rust
use tokio::sync::mpsc;

#[tokio::main]
async fn main() {
    // 创建容量32的通道
    let (tx, mut rx) = mpsc::channel(32);

    // ... Rest comes here
}
```

​	创建的通道容量为 32。如果消息的发送速度快于接收速度，通道就会存储这些消息。一旦 32 条消息存入通道，调用 `send(...).await` 就会进入休眠状态，直到接收方移除一条消息为止。

```rust
use tokio::sync::mpsc;

#[tokio::main]
async fn main() {
    let (tx, mut rx) = mpsc::channel(32);
  	// 通过 clone 可以实现多发送者
    let tx2 = tx.clone();

    tokio::spawn(async move {
        tx.send("sending from first handle").await.unwrap();
    });

    tokio::spawn(async move {
        tx2.send("sending from second handle").await.unwrap();
    });

    while let Some(message) = rx.recv().await {
        println!("GOT = {}", message);
    }
}
```

​	当每个 `Sender` 超出范围或被丢弃时， 无法再向频道发送更多消息。此时， `Receiver` 上的 `recv` 调用将返回 `None` ，这意味着所有发送者都已消失并且通道已关闭。



## 创建管理器任务

​	创建一个任务处理来自通道的消息。首先，与 Redis 建立客户端连接。然后，通过 Redis 连接发出接收到的命令。

```rust
use mini_redis::client;

// 使用 move 关键字，移动 rx 的所有权
let manager = tokio::spawn(async move {
    let mut client = client::connect("127.0.0.1:6379").await.unwrap();

    // 接受通道消息
    while let Some(cmd) = rx.recv().await {
        use Command::*;

        match cmd {
            Get { key } => {
                client.get(&key).await;
            }
            Set { key, val } => {
                client.set(&key, val).await;
            }
        }
    }
});
```

​	修改任务，通过通道发送命令。

```rust
// 克隆 发送
let tx2 = tx.clone();

// 创建2个任务，一个 Get，一个 Set
let t1 = tokio::spawn(async move {
    let cmd = Command::Get {
        key: "foo".to_string(),
    };

    tx.send(cmd).await.unwrap();
});

let t2 = tokio::spawn(async move {
    let cmd = Command::Set {
        key: "foo".to_string(),
        val: "bar".into(),
    };

    tx2.send(cmd).await.unwrap();
});
```

​	在 `main` 函数的底部，调用 `.await` ，确保命令在进程退出之前完成。

```rust
t1.await.unwrap();
t2.await.unwrap();
manager.await.unwrap();
```

## 接受响应

​	最后一步，接收管理器任务的响应， `GET` 命令需要获取值，而 `SET` 命令需要知道操作是否成功完成。

​	为了传递响应，我们使用了 `oneshot` 通道 (oneshot channel)。 `oneshot` 通道是一个单生产者、单消费者的通道，专门针对发送单个值进行了优化。在我们的例子中，这个单个值就是响应。

​	与 `mpsc` 类似， `oneshot::channel()` 返回发送方和接收方句柄。

```rust
use tokio::sync::oneshot;

let (tx, rx) = oneshot::channel();
```

​	与 `mpsc` 不同，它无需指定容量，因为容量始终为 1。此外，这两个句柄都无法克隆。

​	为了接收来自管理器任务的响应，在发送命令之前，需要 `oneshot` 通道已创建。通道的 `Sender` 包含在发送给管理器任务的命令中。接收方部分用于接收响应。

​	首先，更新 `Command` 以包含 `Sender` 。为了方便起见，使用类型别名来引用 `Sender`

```rust
use tokio::sync::oneshot;
use bytes::Bytes;
// 由请求者提供，并通过管理器任务，发送给接收者
type Responder<T> = oneshot::Sender<mini_redis::Result<T>>;

#[derive(Debug)]
enum Command {
    Get {
        key: String,
        resp: Responder<Option<Bytes>>,
    },
    Set {
        key: String,
        val: Bytes,
        resp: Responder<()>,
    },
}
```

​	现在，更新发出命令的任务以包含 `oneshot::Sender` 。

```rust
let t1 = tokio::spawn(async move {
  	// 创建一次性响应通道
    let (resp_tx, resp_rx) = oneshot::channel();
    let cmd = Command::Get {
        key: "foo".to_string(),
      	// 命令中包含，一次性响应的发送者
        resp: resp_tx,
    };

    // 发送 GET 命令
    tx.send(cmd).await.unwrap();

    // 等待一次性响应的接收信息
    let res = resp_rx.await;
    println!("GOT = {:?}", res);
});

let t2 = tokio::spawn(async move {
    let (resp_tx, resp_rx) = oneshot::channel();
    let cmd = Command::Set {
        key: "foo".to_string(),
        val: "bar".into(),
        resp: resp_tx,
    };

    tx2.send(cmd).await.unwrap();

    let res = resp_rx.await;
    println!("GOT = {:?}", res);
});
```

​	最后，更新管理器任务以通过 `oneshot` 通道发送响应。

```rust
while let Some(cmd) = rx.recv().await {
    match cmd {
        Command::Get { key, resp } => {
            let res = client.get(&key).await;
            // 通过一次性响应通道返回结果
            let _ = resp.send(res);
        }
        Command::Set { key, val, resp } => {
            let res = client.set(&key, val).await;
            let _ = resp.send(res);
        }
    }
}
```

​	在 `oneshot::Sender` 上调用 `send` 会立即完成，并且不需要一个 `.await` 。这是因为在 `oneshot` 通道上 `send` 总是会立即失败或成功，而无需任何形式的等待。



# 输入/输出

​	Tokio 中的 I/O 操作方式与 `std` 中的非常相似，但是是异步的。它有一个用于读取的 trait（ [`AsyncRead`](https://docs.rs/tokio/1/tokio/io/trait.AsyncRead.html) ）和一个用于写入的 trait（ [`AsyncWrite`](https://docs.rs/tokio/1/tokio/io/trait.AsyncWrite.html) ）。

## `AsyncRead` and `AsyncWrite`

​	这两个 trait 提供了异步读取和写入字节流的功能。这些 trait 中的方法通常不会被直接调用，就像你不会从 `Future` 中手动调用 `poll` 方法一样。

​	让我们简单看一下其中几个方法。所有这些函数都是 `async` 并且必须与 `.await` 一起使用。

### `async fn read()`

​	[`AsyncReadExt::read`](https://docs.rs/tokio/1/tokio/io/trait.AsyncReadExt.html#method.read) 提供了一种异步方法，用于将数据读入缓冲区，并返回读取的字节数。

​	**注意：** 当 `read()` 返回 `Ok(0)` 时，表示流已关闭。任何后续的 `read()` 调用都将立即返回 `Ok(0)` 完成。对于 [`TcpStream`](https://docs.rs/tokio/1/tokio/net/struct.TcpStream.html) 实例，这表示套接字的读取部分已关闭。

```rust
use tokio::fs::File;
use tokio::io::{self, AsyncReadExt};

#[tokio::main]
async fn main() -> io::Result<()> {
    let mut f = File::open("foo.txt").await?;
    let mut buffer = [0; 10];

    // read up to 10 bytes
    let n = f.read(&mut buffer[..]).await?;

    println!("The bytes: {:?}", &buffer[..n]);
    Ok(())
}
```

### `async fn read_to_end()`

​	[`AsyncReadExt::read_to_end`](https://docs.rs/tokio/1/tokio/io/trait.AsyncReadExt.html#method.read_to_end) 从流中读取所有字节直到 EOF。

```rust
use tokio::io::{self, AsyncReadExt};
use tokio::fs::File;

#[tokio::main]
async fn main() -> io::Result<()> {
    let mut f = File::open("foo.txt").await?;
    let mut buffer = Vec::new();

    // read the whole file
    f.read_to_end(&mut buffer).await?;
    Ok(())
}
```

### `async fn write()`

​	[`AsyncWriteExt::write`](https://docs.rs/tokio/1/tokio/io/trait.AsyncWriteExt.html#method.write) 将缓冲区数据写入，返回写入了多少字节。

```rust
use tokio::io::{self, AsyncWriteExt};
use tokio::fs::File;

#[tokio::main]
async fn main() -> io::Result<()> {
    let mut file = File::create("foo.txt").await?;

    // Writes some prefix of the byte string, but not necessarily all of it.
    let n = file.write(b"some bytes").await?;

    println!("Wrote the first {} bytes of 'some bytes'.", n);
    Ok(())
}
```

### `async fn write_all()`

​	[`AsyncWriteExt::write_all`](https://docs.rs/tokio/1/tokio/io/trait.AsyncWriteExt.html#method.write_all) 将整个缓冲区写入写入器。

```rust
use tokio::io::{self, AsyncWriteExt};
use tokio::fs::File;

#[tokio::main]
async fn main() -> io::Result<()> {
    let mut file = File::create("foo.txt").await?;

    file.write_all(b"some bytes").await?;
    Ok(())
}
```

## 辅助函数

​	此外，与 `std` 一样， [`tokio::io`](https://docs.rs/tokio/1/tokio/io/index.html) 模块包含许多有用的实用函数以及用于处理[标准输入的 ](https://docs.rs/tokio/1/tokio/io/fn.stdin.html)API， [标准输出](https://docs.rs/tokio/1/tokio/io/fn.stdout.html)和[标准错误 ](https://docs.rs/tokio/1/tokio/io/fn.stderr.html)。

```rust
use tokio::fs::File;
use tokio::io;

#[tokio::main]
async fn main() -> io::Result<()> {
    let mut reader: &[u8] = b"hello";
    let mut file = File::create("foo.txt").await?;

  	//  tokio::io::copy 异步将读取器的全部内容复制到写入器中。
    io::copy(&mut reader, &mut file).await?;
    Ok(())
}
```

## Echo 服务器

​	为了练习一下异步 I/O。我们将编写一个 Echo 服务器。

​	Echo 服务器绑定一个 `TcpListener` 并循环接受入站连接。对于每个入站连接，都会从套接字读取数据并立即将其写回套接字。客户端将数据发送到服务器，并接收完全相同的数据。

### 使用 `io::copy()`

​	首先，我们将使用 [`io::copy`](https://docs.rs/tokio/1/tokio/io/fn.copy.html) 实用程序实现回显逻辑。

​	这是一个 TCP 服务器，需要一个 accept 循环。每个接受的套接字都会生成一个新任务来处理。

```rust
use tokio::io;
use tokio::net::TcpListener;

#[tokio::main]
async fn main() -> io::Result<()> {
    let listener = TcpListener::bind("127.0.0.1:6142").await?;

    loop {
        let (mut socket, _) = listener.accept().await?;

        tokio::spawn(async move {
            // copy 数据
        });
    }
}
```

​	如前所述，此实用函数接受一个读取器和一个写入器，并将数据从一个读取器复制到另一个写入器。但是，我们只有一个 `TcpStream` 。这个值**同时**实现了 `AsyncRead` 和 `AsyncWrite` 接口。因为 `io::copy` 要求读取器和写入器都使用 `&mut` ，套接字不能用于这两个参数。

### 拆分 reader 和 writer

​	为了解决这个问题，我们必须将套接字拆分成读取器句柄和写入器句柄。拆分读取器/写入器组合的最佳方法取决于具体的类型。

​	任何读取器 + 写入器类型都可以使用 [`io::split`](https://docs.rs/tokio/1/tokio/io/fn.split.html) 进行拆分。此函数接受单个值并返回单独的读取器和写入器句柄。这两个句柄可以独立使用，甚至可以用于不同的任务。

```rust
use tokio::io::{self, AsyncReadExt, AsyncWriteExt};
use tokio::net::TcpStream;

#[tokio::main]
async fn main() -> io::Result<()> {
    let socket = TcpStream::connect("127.0.0.1:6142").await?;
  	// 将 Socket 拆分 reader 和 writer
    let (mut rd, mut wr) = io::split(socket);

  	// 创建一个任务，通过 wr 写入数据
    tokio::spawn(async move {
        wr.write_all(b"hello\r\n").await?;
        wr.write_all(b"world\r\n").await?;

        Ok::<_, io::Error>(())
    });

    let mut buf = vec![0; 128];
    loop {
        let n = rd.read(&mut buf).await?;
        if n == 0 {
            break;
        }
        println!("GOT {:?}", &buf[..n]);
    }

    Ok(())
}
```

​	因为 `io::split` 支持**任何**实现 `AsyncRead + AsyncWrite` 并返回独立句柄的值，所以 `io::split` 在内部使用 `Arc` 和 `Mutex` 。使用 `TcpStream` 可以避免这种开销 `TcpStream` 提供两种专门的分割功能。

​	[`TcpStream::split`](https://docs.rs/tokio/1/tokio/net/struct.TcpStream.html#method.split) 返回一个读取器 和写入器句柄。此专用 `split` 是零成本的。无需 `Arc` 或 `Mutex` 还提供了 [`into_split`](https://docs.rs/tokio/1/tokio/net/struct.TcpStream.html#method.into_split) 支持仅以 `Arc` 为代价跨任务移动的句柄。

​	因为 `io::copy()` 是在拥有 `TcpStream` 的同一个任务上调用的，所以我们可以使用 [`TcpStream::split`](https://docs.rs/tokio/1/tokio/net/struct.TcpStream.html#method.split) 。服务器中处理 echo 逻辑的任务变为：

```rust
tokio::spawn(async move {
  	// 使用 TcpStream.split 拆分
    let (mut rd, mut wr) = socket.split();
    
    if io::copy(&mut rd, &mut wr).await.is_err() {
        eprintln!("failed to copy");
    }
});
```

### 复制数据

​	现在我们来看看如何通过手动复制数据来编写回显服务器。为此，我们使用 [`AsyncReadExt::read`](https://docs.rs/tokio/1/tokio/io/trait.AsyncReadExt.html#method.read) 和 [`AsyncWriteExt::write_all`](https://docs.rs/tokio/1/tokio/io/trait.AsyncWriteExt.html#method.write_all) 。

```rust
use tokio::io::{self, AsyncReadExt, AsyncWriteExt};
use tokio::net::TcpListener;

#[tokio::main]
async fn main() -> io::Result<()> {
    let listener = TcpListener::bind("127.0.0.1:6142").await?;

    loop {
        let (mut socket, _) = listener.accept().await?;

        tokio::spawn(async move {
          	// 从套接字读取一些数据到缓冲区，然后将缓冲区的内容写回到套接字
            let mut buf = vec![0; 1024];

            loop {
                match socket.read(&mut buf).await {
                    // 当 TCP 流的读取部分关闭时，对 read() 调用将返回 Ok(0) 。此时退出读取循环非常重要。
                    Ok(0) => return,
                    Ok(n) => {
                        // 从 Socket 中 copy 数据到 buf
                        if socket.write_all(&buf[..n]).await.is_err() {
                            // 异常返回
                            return;
                        }
                    }
                    Err(_) => {
                        // 异常返回
                        return;
                    }
                }
            }
        });
    }
}
```

# 生成数据帧（Framing）

​	生产数据帧是将字节流转换为帧流的过程。数据帧是两个节点之间传输的数据单位。Redis 协议帧定义如下：

```rust
use bytes::Bytes;

enum Frame {
    Simple(String),
    Error(String),
    Integer(u64),
    Bulk(Bytes),
    Null,
    Array(Vec<Frame>),
}
```

​	请注意，该帧仅由数据组成，不包含任何语义。命令的解析和执行发生在更高层。

​	对于 HTTP，可能看起来像：

```rust
enum HttpFrame {
    RequestHead {
        method: Method,
        uri: Uri,
        version: Version,
        headers: HeaderMap,
    },
    ResponseHead {
        status: StatusCode,
        version: Version,
        headers: HeaderMap,
    },
    BodyChunk {
        chunk: Bytes,
    },
}
```

​	为了实现 Mini-Redis 的框架，我们将实现一个`Connection`包装`TcpStream`并读取/写入`mini_redis::Frame`值的结构。

```rust
use tokio::net::TcpStream;
use mini_redis::{Frame, Result};

struct Connection {
    stream: TcpStream,
    // ... other fields here
}

impl Connection {
    /// Read a frame from the connection.
    /// 
    /// Returns `None` if EOF is reached
    pub async fn read_frame(&mut self)
        -> Result<Option<Frame>>
    {
        // implementation here
    }

    /// Write a frame to the connection.
    pub async fn write_frame(&mut self, frame: &Frame)
        -> Result<()>
    {
        // implementation here
    }
}
```

## 读取缓存

​	该`read_frame`方法等待接收到整个帧后再返回。单次调用`TcpStream::read()`可以返回任意数量的数据。它可以包含整个帧、部分帧或多个帧。如果接收到部分帧，则数据将被缓冲，并从套接字读取更多数据。如果接收到多个帧，则返回第一帧，其余数据将被缓存，直到下次调用`read_frame`。

​	创建一个名为 的新文件`connection.rs`。`Connection`需要一个读取缓冲区字段。数据从套接字读取到缓冲区。当解析完一个帧后，相应的数据将从缓冲区中移除。

​	我们将使用[`BytesMut`](https://docs.rs/bytes/1/bytes/struct.BytesMut.html)作为缓冲区类型。这是 的可变版本 [`Bytes`](https://docs.rs/bytes/1/bytes/struct.Bytes.html)。

```rust
use bytes::BytesMut;
use tokio::net::TcpStream;

pub struct Connection {
    stream: TcpStream,
    buffer: BytesMut,
}

impl Connection {
    pub fn new(stream: TcpStream) -> Connection {
        Connection {
            stream,
            // 分配缓冲区
            buffer: BytesMut::with_capacity(4096),
        }
    }
}
```

​	接下来我们实现该`read_frame()`方法。

```rust
use tokio::io::AsyncReadExt;
use bytes::Buf;
use mini_redis::Result;

pub async fn read_frame(&mut self)
    -> Result<Option<Frame>>
{
  	// 循环
    loop {
      	// 从缓存中判断是否包含完整数据帧，是就返回
        if let Some(frame) = self.parse_frame()? {
            return Ok(Some(frame));
        }

      	// 否则，就继续从 Socket 写入缓冲区，再次循环
        if 0 == self.stream.read_buf(&mut self.buffer).await? {
            if self.buffer.is_empty() {
                return Ok(None);
            } else {
                return Err("connection reset by peer".into());
            }
        }
    }
}	
```

## 解析缓存

​	现在，我们来看一下这个`parse_frame()`函数。解析分为两步完成。

1. 确保缓冲了完整的帧并找到该帧的结束索引。
2. 解析数据帧。



​	该`mini-redis`板条箱为我们提供了这两个步骤的功能：

1. [`Frame::check`](https://docs.rs/mini-redis/0.4/mini_redis/frame/enum.Frame.html#method.check)
2. [`Frame::parse`](https://docs.rs/mini-redis/0.4/mini_redis/frame/enum.Frame.html#method.parse)



​	我们还将重用`Buf`抽象来提供帮助。将 `Buf`传入 `Frame::check`。当`check`函数迭代传入的缓冲区时，内部游标将前进。`check`返回时，缓冲区的内部游标指向帧的末尾。

​	对于`Buf`类型，我们将使用[`std::io::Cursor<&[u8\]>`](https://doc.rust-lang.org/stable/std/io/struct.Cursor.html)。

```rust
use mini_redis::{Frame, Result};
use mini_redis::frame::Error::Incomplete;
use bytes::Buf;
use std::io::Cursor;

fn parse_frame(&mut self)
    -> Result<Option<Frame>>
{
    // 创建内部缓存的游标  Create the `T: Buf` type.
    let mut buf = Cursor::new(&self.buffer[..]);

    // 检查是否有完整的数据帧可用
    match Frame::check(&mut buf) {
        Ok(_) => {
            // 获取数据帧的长度
            let len = buf.position() as usize;
            // 重置内部游标
            buf.set_position(0);
            // 解析数据帧
            let frame = Frame::parse(&mut buf)?;
            // 将缓存中的数据帧抛弃
            self.buffer.advance(len);
            // 返回数据帧
            Ok(Some(frame))
        }
        // 缓存中数据不足
        Err(Incomplete) => Ok(None),
        // 异常
        Err(e) => Err(e.into()),
    }
}
```



## 写入缓存

​	另一半是`write_frame(frame)`函数。该函数将整个帧写入套接字。为了最大限度地减少`write` 系统调用，写入操作将被缓冲。它会维护一个写入缓冲区，帧在写入套接字之前会被编码到该缓冲区中。然而，与 不同 `read_frame()`，在写入套接字之前，整个帧并不总是被缓冲到字节数组中。

​	考虑一个批量流帧。正在写入的值为`Frame::Bulk(Bytes)`。批量帧的线路格式是帧头，它由`$` 字符和数据长度（以字节为单位）组成。帧的主要内容是`Bytes`值的内容。如果数据很大，将其复制到中间缓冲区会很昂贵。

​	为了实现缓冲写入，我们将使用[`BufWriter`结构体](https://docs.rs/tokio/1/tokio/io/struct.BufWriter.html)。该结构体使用 初始化`T: AsyncWrite`并实现`AsyncWrite` 自身。当`write`调用时`BufWriter`，写入操作不会直接发送到内部写入器，而是发送到缓冲区。当缓冲区已满时，内容将被刷新到内部写入器，并清除内部缓冲区。在某些情况下，还可以进行一些优化，以允许绕过缓冲区。

​	首先，`Connection`更新结构：

```rust
use tokio::io::BufWriter;
use tokio::net::TcpStream;
use bytes::BytesMut;

pub struct Connection {
  	// 使用 BufWriter
    stream: BufWriter<TcpStream>,
    buffer: BytesMut,
}

impl Connection {
    pub fn new(stream: TcpStream) -> Connection {
        Connection {
            stream: BufWriter::new(stream),
            buffer: BytesMut::with_capacity(4096),
        }
    }
}
```

​	接下来就是`write_frame()`。

```rust
use tokio::io::{self, AsyncWriteExt};
use mini_redis::Frame;

async fn write_frame(&mut self, frame: &Frame)
    -> io::Result<()>
{
    match frame {
        Frame::Simple(val) => {
            self.stream.write_u8(b'+').await?;
            self.stream.write_all(val.as_bytes()).await?;
            self.stream.write_all(b"\r\n").await?;
        }
        Frame::Error(val) => {
            self.stream.write_u8(b'-').await?;
            self.stream.write_all(val.as_bytes()).await?;
            self.stream.write_all(b"\r\n").await?;
        }
        Frame::Integer(val) => {
            self.stream.write_u8(b':').await?;
            self.write_decimal(*val).await?;
        }
        Frame::Null => {
            self.stream.write_all(b"$-1\r\n").await?;
        }
        Frame::Bulk(val) => {
            let len = val.len();

            self.stream.write_u8(b'$').await?;
            self.write_decimal(len as u64).await?;
            self.stream.write_all(val).await?;
            self.stream.write_all(b"\r\n").await?;
        }
        Frame::Array(_val) => unimplemented!(),
    }

    self.stream.flush().await;

    Ok(())
}
```

​	这里使用的函数由 提供[`AsyncWriteExt`](https://docs.rs/tokio/1/tokio/io/trait.AsyncWriteExt.html)。也可以使用 `TcpStream`，但不建议在没有中间缓冲区的情况下发出单字节写入。

- [`write_u8`](https://docs.rs/tokio/1/tokio/io/trait.AsyncWriteExt.html#method.write_u8)向写入器写入一个字节。
- [`write_all`](https://docs.rs/tokio/1/tokio/io/trait.AsyncWriteExt.html#method.write_all)将整个切片写入写入器。
- [`write_decimal`](https://github.com/tokio-rs/mini-redis/blob/tutorial/src/connection.rs#L225-L238)由mini-redis实现

​	该函数以对 的调用结束`self.stream.flush().await`。由于 `BufWriter`将数据写入中间缓冲区，因此对 的调用`write`并不能保证数据一定会写入套接字。在返回之前，我们希望将帧写入套接字。对 `flush()` 的调用会将缓冲区中所有待处理的数据写入套接字。

​	另一种选择是**不要**在`write_frame() `中调用 `flush()` ，而是在 `Connection` 上提供一个 `flush()` 函数。这将允许调用者在写入缓冲区中写入多个小帧，然后使用一个`write`系统调用将它们全部写入套接字。这样做会使 `Connection`API 变得复杂。简洁是 Mini-Redis 的目标之一，因此我们决定`flush().await`在 中包含该调用`fn write_frame()`。

# 深入异步

​	我们已经完成了对异步 Rust 和 Tokio 的相当全面的浏览。现在我们将更深入地研究 Rust 的异步运行时模型。

## 异步任务（Futures）

```rust
use tokio::net::TcpStream;

async fn my_async_fn() {
    println!("hello from async");
    let _socket = TcpStream::connect("127.0.0.1:3000").await.unwrap();
    println!("async TCP operation complete");
}

#[tokio::main]
async fn main() {
    let what_is_this = my_async_fn();
    // 不会有日志输出
    what_is_this.await;
  	// 日志输出，socket 被关闭
}
```

​	`my_async_fn()` 返回的值是一个 Future。Future 是一个实现了标准库提供的 [`std::future::Future`](https://doc.rust-lang.org/std/future/trait.Future.html) 特性的值。它们包含正在进行的异步计算。

​	[`std::future::Future`](https://doc.rust-lang.org/std/future/trait.Future.html) 特征定义是：

```rust
use std::pin::Pin;
use std::task::{Context, Poll};

pub trait Future {
  	// 关联类型 Output 是 Future 完成后生成的类型
    type Output;

  	// pin 是 Rust 支持的借用方式。
    fn poll(self: Pin<&mut Self>, cx: &mut Context)
        -> Poll<Self::Output>;
}
```

​	与其他语言中 Future 的实现方式不同，Rust Future 并不 表示在后台发生的计算，Rust Future **是**计算本身。Future 的所有者负责 通过轮询 Future 来推进计算。这是通过调用 `Future::poll` 。

### 实现 `Future`

​	实现一个非常简单的 Future。这个 Future 将会：等到特定的时间点 ，输出一些文本到 STDOUT。 

```rust
use std::future::Future;
use std::pin::Pin;
use std::task::{Context, Poll};
use std::time::{Duration, Instant};

struct Delay {
    when: Instant,
}

impl Future for Delay {
  	// 输出 str
    type Output = &'static str;

    fn poll(self: Pin<&mut Self>, cx: &mut Context<'_>)
        -> Poll<&'static str>
    {
      	// 大于等于 传入时间
        if Instant::now() >= self.when {
            println!("Hello world");
            Poll::Ready("done")
        } else {
            // Ignore this line for now.
            cx.waker().wake_by_ref();
            Poll::Pending
        }
    }
}

#[tokio::main]
async fn main() {
    let when = Instant::now() + Duration::from_millis(10);
    let future = Delay { when };

    let out = future.await;
    assert_eq!(out, "done");
}
```

### Async fn as a Future

​	在主函数中，我们实例化 Future 并对其调用 `.await` 。在异步函数中，我们可以对任何实现了 `Future` 值调用 `.await` 。反过来，调用 `async` 函数会返回一个实现了 Future 的匿名类型。 `Future` . 对于 `async fn main()` 来说，生成的 Future 大致如下：

```rust
use std::future::Future;
use std::pin::Pin;
use std::task::{Context, Poll};
use std::time::{Duration, Instant};

enum MainFuture {
    // Initialized, never polled
    State0,
    // Waiting on `Delay`, i.e. the `future.await` line.
    State1(Delay),
    // The future has completed.
    Terminated,
}

impl Future for MainFuture {
    type Output = ();

    fn poll(mut self: Pin<&mut Self>, cx: &mut Context<'_>)
        -> Poll<()>
    {
        use MainFuture::*;

        loop {
            match *self {
                State0 => {
                    let when = Instant::now() +
                        Duration::from_millis(10);
                    let future = Delay { when };
                    *self = State1(future);
                }
                State1(ref mut my_future) => {
                    match Pin::new(my_future).poll(cx) {
                        Poll::Ready(out) => {
                            assert_eq!(out, "done");
                            *self = Terminated;
                            return Poll::Ready(());
                        }
                        Poll::Pending => {
                            return Poll::Pending;
                        }
                    }
                }
                Terminated => {
                    panic!("future polled after completion")
                }
            }
        }
    }
}
```

​	Rust Future 是**状态机** 。在这里， `MainFuture` 表示为 Future 可能状态的 `enum` 。Future 从 `State0` 状态开始。调用 `poll` 时，Future 会尝试尽可能地推进其内部状态。如果 Future 能够完成，则会返回 `Poll::Ready` 其中包含异步计算的输出。

​	如果 Future 无法完成，通常是由于等待的资源尚未准备好，则返回 `Poll::Pending` 。接收 `Poll::Pending` 向调用者表明未来将在稍后完成，调用者应稍后再次调用 `poll` 。

​	我们还看到，Future 是由其他 Future 组成的。在外部 Future 上调用 `poll` 会导致调用内部 Future 的 `poll` 函数。

## 执行器（Executors）

​	Rust 异步函数返回 Future。Future 必须调用 `poll` 才能推进其状态。Future 是由其他 Future 组成的。那么，问题来了，最外层的 Future 上究竟是什么调用了 `poll` 呢？

​	回想一下，要运行异步函数，它们必须传递给 `tokio::spawn` 或作为带有注释的主函数 `#[tokio::main]` 。这将导致将生成的外部 Future 提交给 Tokio 执行器。执行器负责在外部 Future 上调用 `Future::poll` ，从而驱动异步计算完成。

### Mini Tokio

```rust
use std::collections::VecDeque;
use std::future::Future;
use std::pin::Pin;
use std::task::{Context, Poll};
use std::time::{Duration, Instant};
use futures::task;

fn main() {
    let mut mini_tokio = MiniTokio::new();

    mini_tokio.spawn(async {
        let when = Instant::now() + Duration::from_millis(10);
        let future = Delay { when };

        let out = future.await;
        assert_eq!(out, "done");
    });

    mini_tokio.run();
}

type Task = Pin<Box<dyn Future<Output = ()> + Send>>;

struct MiniTokio {
    tasks: VecDeque<Task>,
}

impl MiniTokio {
    fn new() -> MiniTokio {
        MiniTokio {
            tasks: VecDeque::new(),
        }
    }

    /// MiniTokio 实例中，生成一个 异步任务
    fn spawn<F>(&mut self, future: F)
    where
        F: Future<Output = ()> + Send + 'static,
    {
        self.tasks.push_back(Box::pin(future));
    }

    fn run(&mut self) {
        let waker = task::noop_waker();
        let mut cx = Context::from_waker(&waker);

        while let Some(mut task) = self.tasks.pop_front() {
            if task.as_mut().poll(&mut cx).is_pending() {
                self.tasks.push_back(task);
            }
        }
    }
}
```

​	这将运行 `Delay` 块。Delay 实例将根据请求的延迟时间进行创建，并等待执行。然而，我们目前的实现存在一个重大**缺陷** 。我们的执行器永远不会进入睡眠状态。执行器会不断循环执行**所有** 生成 Future 并对其进行轮询。大多数情况下，Future 尚未准备好 执行更多工作，并再次返回 `Poll::Pending` 。该过程会消耗 CPU 周期，通常效率不高。

​	理想情况下，我们希望 mini-tokio 仅在 Future 能够取得进展时才轮询 Future。这种情况发生在任务被阻塞的资源准备好执行请求的操作时。如果任务想要从 TCP 套接字读取数据，那么我们希望仅在 TCP 套接字收到数据时轮询该任务。在我们的例子中，任务在到达给定的 `Instant` 被阻塞。理想情况下，mini-tokio 只会在该时刻过去后轮询该任务。

## 唤醒器（Wakers）

​	Wakers 是一个系统，资源可以通过它通知等待的任务，该资源已准备好继续执行某些操作。

​	我们再看一下 `Future::poll` 定义：

```
fn poll(self: Pin<&mut Self>, cx: &mut Context)
    -> Poll<Self::Output>;
```

​	`poll` 的 `Context` 参数有一个 `waker()` 方法。该方法返回一个 [`Waker`](https://doc.rust-lang.org/std/task/struct.Waker.html) 绑定到当前任务。Waker 有一个 `wake()` 方法。调用此方法会向执行器发出信号，告知其关联的任务应该被安排执行。资源在转换为就绪状态时会调用 `wake()`，通知执行器轮询该任务将能够取得进展。

### 更新 `Delay`

```rust
use std::future::Future;
use std::pin::Pin;
use std::task::{Context, Poll};
use std::time::{Duration, Instant};
use std::thread;

struct Delay {
    when: Instant,
}

impl Future for Delay {
    type Output = &'static str;

    fn poll(self: Pin<&mut Self>, cx: &mut Context<'_>)
        -> Poll<&'static str>
    {
        if Instant::now() >= self.when {
            println!("Hello world");
            Poll::Ready("done")
        } else {
            // 从 当前任务，获取 waker 
            let waker = cx.waker().clone();
            let when = self.when;

            // 创建一个 a timer thread.
            thread::spawn(move || {
                let now = Instant::now();

                if now < when {
                    thread::sleep(when - now);
                }
								// 时间到了，调用唤醒
                waker.wake();
            });

            Poll::Pending
        }
    }
}
```

​	现在，一旦请求的持续时间过去，调用任务就会收到通知，执行器可以确保再次计划任务。下一步是更新 mini-tokio 以监听唤醒通知。

### 更新 Mini Tokio

​	下一步是更新 Mini Tokio 以接收唤醒器通知。我们希望执行器仅在任务被唤醒时运行任务，为此，Mini Tokio 将提供自己的唤醒器。调用唤醒器时，其关联的任务将排队等待执行。Mini-Tokio 在轮询 Future 时将这个唤醒器传递给 Future。

​	更新后的 Mini Tokio 将使用通道来存储计划任务。通道允许将任务排队以从任何线程执行。唤醒者必须是 `Send` 和`Sync `。

```rust
use std::sync::mpsc;
use std::sync::Arc;

struct MiniTokio {
    scheduled: mpsc::Receiver<Arc<Task>>,
    sender: mpsc::Sender<Arc<Task>>,
}

struct Task {
    // This will be filled in soon.
}
```



```rust
use std::sync::{Arc, Mutex};

// 拥有 Future 结构和 Poll 方法
struct TaskFuture {
    future: Pin<Box<dyn Future<Output = ()> + Send>>,
    poll: Poll<()>,
}

struct Task {
    // Mutex 是互斥，只有一个线程能访问
    task_future: Mutex<TaskFuture>,
    executor: mpsc::Sender<Arc<Task>>,
}

impl Task {
  	// 调用 schedule 会往 executor 通道发当前任务的消息
    fn schedule(self: &Arc<Self>) {
        self.executor.send(self.clone());
    }
}
```



```rust
use futures::task::{self, ArcWake};
use std::sync::Arc;
impl ArcWake for Task {
  	// 唤醒当前任务
    fn wake_by_ref(arc_self: &Arc<Self>) {
        arc_self.schedule();
    }
}
```



```rust
impl MiniTokio {
  	// 该函数在循环中运行，从通道接收计划任务。由于任务在唤醒时被推送到通道中，因此这些任务在执行时能够取得进展。
    fn run(&self) {
        while let Ok(task) = self.scheduled.recv() {
            task.poll();
        }
    }

  	// 创建 MiniTokio 实例，包含 通道
    fn new() -> MiniTokio {
        let (sender, scheduled) = mpsc::channel();

        MiniTokio { scheduled, sender }
    }

  	// 创建 任务
    fn spawn<F>(&self, future: F)
    where
        F: Future<Output = ()> + Send + 'static,
    {
        Task::spawn(future, &self.sender);
    }
}

impl TaskFuture {
    fn new(future: impl Future<Output = ()> + Send + 'static) -> TaskFuture {
        TaskFuture {
            future: Box::pin(future),
            poll: Poll::Pending,
        }
    }

    fn poll(&mut self, cx: &mut Context<'_>) {
        if self.poll.is_pending() {
            self.poll = self.future.as_mut().poll(cx);
        }
    }
}

impl Task {
    fn poll(self: Arc<Self>) {
        let waker = task::waker(self.clone());
        let mut cx = Context::from_waker(&waker);
        let mut task_future = self.task_future.try_lock().unwrap();
        task_future.poll(&mut cx);
    }

    fn spawn<F>(future: F, sender: &mpsc::Sender<Arc<Task>>)
    where
        F: Future<Output = ()> + Send + 'static,
    {
        let task = Arc::new(Task {
            task_future: Mutex::new(TaskFuture::new(future)),
            executor: sender.clone(),
        });

        let _ = sender.send(task);
    }
}
```



# 选择（Select ）

​	现在将介绍一些与 Tokio 并发执行异步代码的其他方法。

## `tokio::select!`

​	`tokio：：select！` 宏允许等待多个异步计算，并在**单个**计算完成时返回。

```rust
use tokio::sync::oneshot;

#[tokio::main]
async fn main() {
    let (tx1, rx1) = oneshot::channel();
    let (tx2, rx2) = oneshot::channel();

    tokio::spawn(async {
        let _ = tx1.send("one");
    });

    tokio::spawn(async {
        let _ = tx2.send("two");
    });

    tokio::select! {
        val = rx1 => {
            println!("rx1 completed first with {:?}", val);
        }
        val = rx2 => {
            println!("rx2 completed first with {:?}", val);
        }
    }
}
```

​	使用两个一次性通道。任一通道都可以先完成。这 `select！` 语句在两个通道上等待，并将 `val` 绑定到任务返回的值。当 `tx1` 或 `tx2` 完成时，将执行关联的块。

​	未**完成的**分支将被删除。在示例中，计算正在等待每个通道的 `oneshot：：Receiver`。这 `oneshot：：` 尚未完成的通道的接收器被删除。

### 取消

​	对于异步 Rust，取消是通过删除 future 来执行的。回想一下 [“深度异步”](https://tokio.rs/tokio/tutorial/async)，异步 Rust 作是使用 futures 实现的，而 future 是惰性的。仅当轮询未来时，该作才会继续。如果丢弃 future，则无法继续作，因为所有关联的状态都已丢弃。

​	Futures 或其他类型可以实现 `Drop` 来清理后台资源。Tokio 的 `oneshot：：Receiver` 通过向发送方发送关闭通知来实现 `Drop`。发送方可以接收此通知，并通过删除它来中止正在进行的作。

```rust
use tokio::sync::oneshot;

async fn some_operation() -> String {
    // Compute value here
}

#[tokio::main]
async fn main() {
    let (mut tx1, rx1) = oneshot::channel();
    let (tx2, rx2) = oneshot::channel();

    tokio::spawn(async {
        tokio::select! {
            val = some_operation() => {
                let _ = tx1.send(val);
            }
            _ = tx1.closed() => {
                // `some_operation()` is canceled, the
                // task completes and `tx1` is dropped.
            }
        }
    });

    tokio::spawn(async {
        let _ = tx2.send("two");
    });

    tokio::select! {
        val = rx1 => {
            println!("rx1 completed first with {:?}", val);
        }
        val = rx2 => {
            println!("rx2 completed first with {:?}", val);
        }
    }
}
```

### Future 实现

​	为了帮助更好地理解 `select！` 的工作原理，让我们看看 `Future` 是怎么实现的。这是一个简化版本。在实践中，`select！` 包括其他功能，例如随机选择要首先轮询的分支。

```rust
use tokio::sync::oneshot;
use std::future::Future;
use std::pin::Pin;
use std::task::{Context, Poll};

// MySelect 包含每个分支
struct MySelect {
    rx1: oneshot::Receiver<&'static str>,
    rx2: oneshot::Receiver<&'static str>,
}

impl Future for MySelect {
    type Output = ();

  	// 当 `MySelect` 轮询，则轮询第一个分支。如果准备就绪，则使用该值，并且 `MySelect` 完成。
  	// ` 在 .await` 收到来自 future 的输出后，future将被删除。
    // 这导致两个分支的 future 被删除。由于一个分支未完成，因此该作实际上被取消。
    fn poll(mut self: Pin<&mut Self>, cx: &mut Context<'_>) -> Poll<()> {
        if let Poll::Ready(val) = Pin::new(&mut self.rx1).poll(cx) {
            println!("rx1 completed first with {:?}", val);
            return Poll::Ready(());
        }

        if let Poll::Ready(val) = Pin::new(&mut self.rx2).poll(cx) {
            println!("rx2 completed first with {:?}", val);
            return Poll::Ready(());
        }

        Poll::Pending
    }
}

#[tokio::main]
async fn main() {
    let (tx1, rx1) = oneshot::channel();
    let (tx2, rx2) = oneshot::channel();

    // use tx1 and tx2

    MySelect {
        rx1,
        rx2,
    }.await;
}
```

> 当 Future 返回 `Poll：:Pending` 时，它**必须**确保唤醒者在未来的某个时间点发出信号。忘记这样做会导致任务无限期挂起。



## 语法

​	`select！` 宏可以处理两个以上的分支。目前限制为 64 个分支机构。每个分支的结构如下：

```text
<pattern> = <async expression> => <handler>,
```

​	当计算 `select` 宏时，所有 `<async 表达式>`s 将聚合并并发执行。表达式完成后，结果将与 `<pattern>` 进行匹配。如果结果与模式匹配，则删除所有剩余的异步表达式并执行 `<handler>`。这 `<handler>` 表达式可以访问`由 <pattern>` 建立的任何绑定。

​	`<pattern>` 的基本情况是变量名称，异步表达式的结果绑定到变量名称，` 并且 <handler>` 可以访问该变量。这就是为什么在原始示例中，`val` 用于 `<pattern>` 和  `<Chandler>` 能够访问 `val`.

​	如果 `<pattern>` 与异步计算的结果**不**匹配，则其余异步表达式将继续并发执行，直到下一个表达式完成。此时，相同的逻辑将应用于该结果。

​	因为 `select！` 采用任何异步表达式，所以可以定义更复杂的计算来选择。

​	在这里，我们选择`oneshot`和 TCP 连接的输出。

```rust
use tokio::net::TcpStream;
use tokio::sync::oneshot;

#[tokio::main]
async fn main() {
    let (tx, rx) = oneshot::channel();

    // Spawn a task that sends a message over the oneshot
    tokio::spawn(async move {
        tx.send("done").unwrap();
    });

    tokio::select! {
        socket = TcpStream::connect("localhost:3465") => {
            println!("Socket connected {:?}", socket);
        }
        msg = rx => {
            println!("received message first {:?}", msg);
        }
    }
}
```

```rust
use tokio::net::TcpListener;
use tokio::sync::oneshot;
use std::io;

#[tokio::main]
async fn main() -> io::Result<()> {
    let (tx, rx) = oneshot::channel();

    tokio::spawn(async move {
        tx.send(()).unwrap();
    });

    let mut listener = TcpListener::bind("localhost:3465").await?;

    tokio::select! {
        _ = async {
            loop {
                let (socket, _) = listener.accept().await?;
                tokio::spawn(async move { process(socket) });
            }

            // Help the rust type inferencer out
            Ok::<_, io::Error>(())
        } => {}
        _ = rx => {
            println!("terminating accept loop");
        }
    }

    Ok(())
}
```

## 返回值

​	`tokio::select！` 宏返回计算的 `<handler>` 表达式的结果。

```rust
async fn computation1() -> String {
    // .. computation
}

async fn computation2() -> String {
    // .. computation
}

#[tokio::main]
async fn main() {
    let out = tokio::select! {
        res1 = computation1() => res1,
        res2 = computation2() => res2,
    };

    println!("Got = {}", out);
}
```

​	因此， **要求每个** 分支的计算结果为相同类型。如果不需要 `select！` 表达式的输出，最好将表达式的计算结果设置为 `（）。`

## 错误

​	使用 `？` 运算符会从表达式传播错误。其工作原理取决于 `？` 是从异步表达式还是从处理程序使用。在异步表达式中使用 `？` 会将错误传播到异步表达式之外。这将异步表达式的输出设置为 `Result`。使用 `？` 立即将错误传播出 `select！` 表达式。让我们再看看 accept 循环示例：

```rust
use tokio::net::TcpListener;
use tokio::sync::oneshot;
use std::io;

#[tokio::main]
async fn main() -> io::Result<()> {
    // [setup `rx` oneshot channel]

    let listener = TcpListener::bind("localhost:3465").await?;

    tokio::select! {
        res = async {
            loop {
                let (socket, _) = listener.accept().await?;
                tokio::spawn(async move { process(socket) });
            }

            // Help the rust type inferencer out
            Ok::<_, io::Error>(())
        } => {
            res?;
        }
        _ = rx => {
            println!("terminating accept loop");
        }
    }

    Ok(())
}
```

​	请注意 `listener.accept（）.await？`。运算符 `？` 将错误从该表达式传播到 `res` 绑定。发生错误时，`res` 将设置为 `err（_） 的 Err（_）` 中。然后，在处理程序中，再次使用 `？` 运算符。` res？` 语句将错误传播出 `main` 函数。

## 模式匹配

​	`select！` 宏分支语法定义为：

```text
<pattern> = <async expression> => <handler>,
```

​	到目前为止，我们只对 `<pattern>` 使用了变量绑定。但是，可以使用任何 Rust 模式。例如，假设我们从多个 MPSC 通道接收，我们可以执行以下作：

```rust
use tokio::sync::mpsc;

#[tokio::main]
async fn main() {
    let (mut tx1, mut rx1) = mpsc::channel(128);
    let (mut tx2, mut rx2) = mpsc::channel(128);

    tokio::spawn(async move {
        // Do something w/ `tx1` and `tx2`
    });

    tokio::select! {
        Some(v) = rx1.recv() => {
            println!("Got {:?} from rx1", v);
        }
        Some(v) = rx2.recv() => {
            println!("Got {:?} from rx2", v);
        }
        else => {
            println!("Both channels closed");
        }
    }
}
```

​	在此示例中，`select！` 表达式等待从 `rx1` 接收值 和 `rx2`。如果通道关闭，`recv（）` 返回 `None`。这**与模式不**匹配，并且分支被禁用。`select！` 表达式将继续等待其余分支。

​	请注意，此 `select！` 表达式包括一个 `else` 分支。` select！` expression 必须计算为值。使用模式匹配时，可以 没有**一个**分支与其关联的模式匹配。如果发生这种情况，则评估 `else` 分支。

## 借用

​	生成任务时，生成的异步表达式必须拥有其所有数据。这 `select！` 宏没有这个限制。每个分支的异步表达式可以借用数据并并发运行。遵循 Rust 的借用规则，多个异步表达式可以不可变地借用一条数据 **，或者**单个异步表达式可以不可变地借用一条数据。

```rust
use tokio::io::AsyncWriteExt;
use tokio::net::TcpStream;
use std::io;
use std::net::SocketAddr;

async fn race(
    data: &[u8],
    addr1: SocketAddr,
    addr2: SocketAddr
) -> io::Result<()> {
    tokio::select! {
        Ok(_) = async {
            let mut socket = TcpStream::connect(addr1).await?;
            socket.write_all(data).await?;
            Ok::<_, io::Error>(())
        } => {}
        Ok(_) = async {
            let mut socket = TcpStream::connect(addr2).await?;
            socket.write_all(data).await?;
            Ok::<_, io::Error>(())
        } => {}
        else => {}
    };

    Ok(())
}
```

​	`data`变量是从两个异步表达式中**不可变地**借用的。当其中一个作成功完成时，另一个作将被删除。因为我们在 `Ok（_）` 上进行模式匹配，如果一个表达式失败，另一个表达式将继续执行。

​	当涉及到每个分支的 `<handler>` 时，`select！` 保证仅运行一个 `<handler>`。因此，每个 `<handler>` 都可以以可变借用方式借用相同的数据。

​	例如，这在两个处理程序中都进行了修改：

```rust
use tokio::sync::oneshot;

#[tokio::main]
async fn main() {
    let (tx1, rx1) = oneshot::channel();
    let (tx2, rx2) = oneshot::channel();

    let mut out = String::new();

    tokio::spawn(async move {
        // Send values on `tx1` and `tx2`.
    });

    tokio::select! {
        _ = rx1 => {
            out.push_str("rx1 completed");
        }
        _ = rx2 => {
            out.push_str("rx2 completed");
        }
    }

    println!("{}", out);
}
```

## 循环

​	`select！` 宏经常在循环中使用。本节将介绍一些示例，以展示在循环中使用 `select！` 宏的常见方法。我们首先选择多个渠道：

```rust
use tokio::sync::mpsc;

#[tokio::main]
async fn main() {
    let (tx1, mut rx1) = mpsc::channel(128);
    let (tx2, mut rx2) = mpsc::channel(128);
    let (tx3, mut rx3) = mpsc::channel(128);

    loop {
        let msg = tokio::select! {
            Some(msg) = rx1.recv() => msg,
            Some(msg) = rx2.recv() => msg,
            Some(msg) = rx3.recv() => msg,
            else => { break }
        };

        println!("Got {:?}", msg);
    }

    println!("All channels have been closed.");
}
```

​	本例选择三个通道接收器。当消息是 在任何通道上接收，它都会写入 STDOUT。当通道关闭时， `recv（）` 返回 `None`。通过使用图案匹配，` select！` 宏继续等待剩余通道。当所有通道都 closed，则计算 `else` 分支并终止循环。

​	`select！` 宏随机选择要首先检查准备情况的分支。当多个通道具有待处理值时，将选择一个随机通道进行接收。这是为了处理接收循环处理消息的速度慢于将消息推送到通道中的速度，这意味着通道开始填满的情况。如果`select！` **没有**随机选择一个分支先检查，在循环的每次迭代中，都会先检查 `rx1`。如果 `rx1` 始终包含新消息，则永远不会检查其余通道。

### 恢复异步操作

​	现在我们将展示如何跨多个调用运行异步作 `select！` 在此示例中，我们有一个项类型为 `i32` 的 MPSC 通道和一个异步函数。我们想运行异步函数，直到它完成或在通道上收到偶数整数。

```rust
async fn action() {
    // Some asynchronous logic
}

#[tokio::main]
async fn main() {
    let (mut tx, mut rx) = tokio::sync::mpsc::channel(128);    
    
    let operation = action();
    tokio::pin!(operation);
    
    loop {
        tokio::select! {
            _ = &mut operation => break,
            Some(v) = rx.recv() => {
                if v % 2 == 0 {
                    break;
                }
            }
        }
    }
}
```

​	请注意，它不是在 `select！` 宏中调用 `action（），` 而是调用 循环**之外** 。`action（）` 的返回被分配给`operation `， **而不**调用 `.await`。然后我们在`operation`时调用 `tokio：:pin！`

​	在 `select！` 循环中，我们不是传入`operation`，而是传入 `&mut 作 `。` operation`变量正在跟踪正在进行的异步作。循环的每次迭代都使用相同的作，而不是发出新的 `action （）` 号召。

​	另一个 `select！` 分支接收来自通道的消息。如果消息是偶数的，我们就完成了循环。否则，请再次启动 `select！`



### 修改分支

​	让我们看一个稍微复杂的循环。我们有：

1. `i32` 值的通道。
2. 要对 `i32` 值执行的异步作。

​	我们要实现的逻辑是：

1. 等待频道上的**偶数** 。
2. 使用偶数作为输入启动异步 operation。
3. 等待 operation，但同时在频道上监听更多偶数。
4. 如果在现有operation完成之前收到新的偶数，请中止现有operation并使用新的偶数重新开始。

```rust
async fn action(input: Option<i32>) -> Option<String> {
    // If the input is `None`, return `None`.
    // This could also be written as `let i = input?;`
    let i = match input {
        Some(input) => input,
        None => return None,
    };
    // async logic here
}

#[tokio::main]
async fn main() {
    let (mut tx, mut rx) = tokio::sync::mpsc::channel(128);
    
    let mut done = false;
    let operation = action(None);
    tokio::pin!(operation);
    
    tokio::spawn(async move {
        let _ = tx.send(1).await;
        let _ = tx.send(3).await;
        let _ = tx.send(2).await;
    });
    
    loop {
        tokio::select! {
            res = &mut operation, if !done => {
                done = true;

                if let Some(v) = res {
                    println!("GOT = {}", v);
                    return;
                }
            }
            Some(v) = rx.recv() => {
                if v % 2 == 0 {
                    // `.set` is a method on `Pin`.
                    operation.set(action(Some(v)));
                    done = false;
                }
            }
        }
    }
}
```

## 每个任务并发

​	`tokio：：spawn` 和 `select！` 启用并发异步运行 操作。但是，用于运行并发作的策略有所不同。这 `tokio：：spawn` 函数采用异步作并生成一个新任务来运行它。任务是 Tokio 运行时计划的对象。Tokio 独立安排了两个不同的任务。它们可以在不同的操作系统线程上同时运行。因此，生成的任务与生成的线程具有相同的限制：不借用。

​	`select！` 宏在同一**任务上**同时运行所有分支。因为 `select！` 宏的所有分支都在同一任务上执行，所以它们永远不会**同时**运行。`select！` 宏对单个任务进行异步作。



# 流（Stream）

​	流是一系列异步值。它是异步等效于 Rust 的 [`std::iter::Iterator`](https://doc.rust-lang.org/book/ch13-02-iterators.html)，由 [`Stream`](https://docs.rs/futures-core/0.3/futures_core/stream/trait.Stream.html) 表示 特性。流可以在`异步`函数中迭代。它们也可以是 使用适配器进行转换。Tokio 在 [`StreamExt`](https://docs.rs/tokio-stream/0.1/tokio_stream/trait.StreamExt.html) 特征。

## 迭代

​	目前，Rust 编程语言不支持异步 `for` 循环。相反，迭代流是使用 `while let` 循环与 [`StreamExt::next（） 的 Ext::next（）`](https://docs.rs/tokio-stream/0.1/tokio_stream/trait.StreamExt.html#method.next) 中。

```rust
use tokio_stream::StreamExt;

#[tokio::main]
async fn main() {
    let mut stream = tokio_stream::iter(&[1, 2, 3]);

    while let Some(v) = stream.next().await {
        println!("GOT = {:?}", v);
    }
}
```

​	与迭代器一样，`next（）` 方法返回 `Option<T>`，其中 `T` 是流的值类型。接收 `None` 表示流迭代已终止。

## 适配器

​	接受一个 [`Stream`](https://docs.rs/futures-core/0.3/futures_core/stream/trait.Stream.html) 并返回另一个 [`Stream`](https://docs.rs/futures-core/0.3/futures_core/stream/trait.Stream.html) 的函数通常称为“流适配器”，因为它们是“适配器模式”的一种形式。常见的流适配器包括 [`map`](https://docs.rs/tokio-stream/0.1/tokio_stream/trait.StreamExt.html#method.map)、[`take`](https://docs.rs/tokio-stream/0.1/tokio_stream/trait.StreamExt.html#method.take) 和 [`filter`](https://docs.rs/tokio-stream/0.1/tokio_stream/trait.StreamExt.html#method.filter)。



## 实现流

​	[`Stream`](https://docs.rs/futures-core/0.3/futures_core/stream/trait.Stream.html) 特征与 [`Future`](https://doc.rust-lang.org/std/future/trait.Future.html) 特征非常相似。

```rust

use std::pin::Pin;
use std::task::{Context, Poll};

pub trait Stream {
    type Item;

    fn poll_next(
        self: Pin<&mut Self>, 
        cx: &mut Context<'_>
    ) -> Poll<Option<Self::Item>>;

    fn size_hint(&self) -> (usize, Option<usize>) {
        (0, None)
    }
}
```

​	`Stream::poll_next（）` 函数与 `Future::poll` 非常相似，不同之处在于它可以重复调用以从流中接收许多值。正如我们在 [Async 中深入](https://tokio.rs/tokio/tutorial/async)看到的那样，当流**尚未**准备好返回值时，`Poll::Pending` 而是返回。任务的唤醒器已注册。一旦流应该是 再次轮询，唤醒者会收到通知。

​	通常，在手动实现 `Stream` 时，它是通过组合 future 和其他流来完成的。例如，让我们[以我们在 Async](https://tokio.rs/tokio/tutorial/async) 中实现的`延迟`未来为基础进行深入构建。我们将其转换为以 10 毫秒的间隔产生 `（）` 三次的流。

```rust
use tokio_stream::Stream;
use std::pin::Pin;
use std::task::{Context, Poll};
use std::time::Duration;

struct Interval {
    rem: usize,
    delay: Delay,
}

impl Interval {
    fn new() -> Self {
        Self {
            rem: 3,
            delay: Delay { when: Instant::now() }
        }
    }
}

impl Stream for Interval {
    type Item = ();

    fn poll_next(mut self: Pin<&mut Self>, cx: &mut Context<'_>)
        -> Poll<Option<()>>
    {
        if self.rem == 0 {
            // No more delays
            return Poll::Ready(None);
        }

        match Pin::new(&mut self.delay).poll(cx) {
            Poll::Ready(_) => {
                let when = self.delay.when + Duration::from_millis(10);
                self.delay = Delay { when };
                self.rem -= 1;
                Poll::Ready(Some(()))
            }
            Poll::Pending => Poll::Pending,
        }
    }
}
```

### `async-stream`

​	使用 [`Stream`](https://docs.rs/futures-core/0.3/futures_core/stream/trait.Stream.html) 特征手动实现流可能会很乏味。不幸的是，Rust 编程语言尚不支持 `async/await` 用于定义流的语法。这正在进行中，但尚未准备好。

​	[`async-stream`](https://docs.rs/async-stream) crate 可作为临时解决方案使用。此 crate 提供了一个 `stream！` 宏，用于将输入转换为流。使用这个 crate，可以这样实现上述间隔：

```rust
use async_stream::stream;
use std::time::{Duration, Instant};

stream! {
    let mut when = Instant::now();
    for _ in 0..3 {
        let delay = Delay { when };
        delay.await;
        yield ();
        when += Duration::from_millis(10);
    }
}
```







> 参考资料：
>
> 1. https://tokio.rs/tokio/tutorial
> 2. https://docs.rs/tokio/latest/tokio/
> 3. https://draft.ryhl.io/blog/shared-mutable-state/

