[TOC]
# 编写测试及控制执行

在 Rust 中，测试是通过函数的方式实现的，它可以用于验证被测试代码的正确性。测试函数往往依次执行以下三种行为：

1. 设置所需的数据或状态
2. 运行想要测试的代码
3. 判断( assert )返回的结果是否符合预期

## 测试函数

的 `adder` 包：

```shell
$ cargo new adder --lib
     Created library `adder` project
$ cd adder
```

创建成功后，在 *src/lib.rs* 文件中可以发现如下代码:

```rust
#[cfg(test)]
mod tests {
    #[test]
    fn it_works() {
        assert_eq!(2 + 2, 4);
    }
}
```

其中，`tests` 就是一个测试模块，`it_works` 则是我们的主角：测试函数。

在测试函数中，还使用到了一个内置的断言：`assert_eq`，该宏用于对结果进行断言：`2 + 2` 是否等于 `4`。

## cargo test

下面使用 `cargo test` 命令来运行项目中的所有测试:

```shell
$ cargo test
   Compiling adder v0.1.0 (file:///projects/adder)
    Finished test [unoptimized + debuginfo] target(s) in 0.57s
     Running unittests (target/debug/deps/adder-92948b65e88960b4)

running 1 test
test tests::it_works ... ok

test result: ok. 1 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 0.00s

   Doc-tests adder

running 0 tests

test result: ok. 0 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 0.00s
```

上面测试输出中，有几点值得注意:

- 测试用例是分批执行的，`running 1 test` 表示下面的输出 `test result` 来自一个测试用例的运行结果。
- `test tests::it_works` 中包含了测试用例的名称
- `test result: ok` 中的 `ok` 表示测试成功通过
- `1 passed` 代表成功通过一个测试用例(因为只有一个)，`0 failed` : 没有测试用例失败，`0 ignored` 说明我们没有将任何测试函数标记为运行时可忽略，`0 filtered` 意味着没有对测试结果做任何过滤，`0 measured` 代表 基准测试(benchmark) 的结果

## 自定义失败信息

默认的失败信息在有时候并不是我们想要的，来看一个例子：

```rust
pub fn greeting(name: &str) -> String {
    format!("Hello {}!", name)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn greeting_contains_name() {
        let result = greeting("Sunface");
        assert!(result.contains("孙飞"));
    }
}
```

使用 `cargo test` 运行后，错误如下：

```shell
test tests::greeting_contains_name ... FAILED

failures:

---- tests::greeting_contains_name stdout ----
thread 'tests::greeting_contains_name' panicked at 'assertion failed: result.contains(\"孙飞\")', src/lib.rs:12:9
note: run with `RUST_BACKTRACE=1` environment variable to display a backtrace


failures:
    tests::greeting_contains_name
```

可以看出，这段报错除了告诉我们错误发生的地方，并没有更多的信息，那再来看看该如何提供一些更有用的信息：

```rust
fn greeting_contains_name() {
    let result = greeting("Sunface");
    let target = "孙飞";
    assert!(
        result.contains(target),
        "你的问候中并没有包含目标姓名 {} ，你的问候是 `{}`",
        target,
        result
    );
}
```

这段代码跟之前并无不同，只是为 `assert!` 新增了几个格式化参数，这种使用方式与 `format!` 并无区别。再次运行后，输出如下：

```shell
---- tests::greeting_contains_name stdout ----
thread 'tests::greeting_contains_name' panicked at '你的问候中并没有包含目标姓名 孙飞 ，你的问候是 `Hello Sunface!`', src/lib.rs:14:9
note: run with `RUST_BACKTRACE=1` environment variable to display a backtrace
```

## 测试 panic

在之前的例子中，我们通过 `panic` 来触发报错，但是如果一个函数本来就会 `panic` ，而我们想要检查这种结果呢？

也就是说，我们需要一个办法来测试一个函数是否会 `panic`，对此， Rust 提供了 `should_panic` 属性注解，和 `test` 注解一样，对目标测试函数进行标注即可：

```rust
pub struct Guess {
    value: i32,
}

impl Guess {
    pub fn new(value: i32) -> Guess {
        if value < 1 || value > 100 {
            panic!("Guess value must be between 1 and 100, got {}.", value);
        }

        Guess { value }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    #[should_panic]
    fn greater_than_100() {
        Guess::new(200);
    }
}
```

上面是一个简单的猜数字游戏，`Guess` 结构体的 `new` 方法在传入的值不在 [1,100] 之间时，会直接 `panic`，而在测试函数 `greater_than_100` 中，我们传入的值 `200` 显然没有落入该区间，因此 `new` 方法会直接 `panic`，为了测试这个预期的 `panic` 行为，我们使用 `#[should_panic]` 对其进行了标注。

```shell
running 1 test
test tests::greater_than_100 - should panic ... ok

test result: ok. 1 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 0.00s
```

从输出可以看出， `panic` 的结果被准确的进行了测试，那如果测试函数中的代码不再 `panic` 呢？例如：

```rust
fn greater_than_100() {
    Guess::new(50);
}
```

此时显然会测试失败，因为我们预期一个 `panic`，但是 `new` 函数顺利的返回了一个 `Guess` 实例:

```shell
running 1 test
test tests::greater_than_100 - should panic ... FAILED

failures:

---- tests::greater_than_100 stdout ----
note: test did not panic as expected // 测试并没有按照预期发生 panic
```

### expected

虽然 `panic` 被成功测试到，但是如果代码发生的 `panic` 和我们预期的 `panic` 不符合呢？因为一段糟糕的代码可能会在不同的代码行生成不同的 `panic`。

鉴于此，我们可以使用可选的参数 `expected` 来说明预期的 `panic` 长啥样：

```rust
// --snip--
impl Guess {
    pub fn new(value: i32) -> Guess {
        if value < 1 {
            panic!(
                "Guess value must be greater than or equal to 1, got {}.",
                value
            );
        } else if value > 100 {
            panic!(
                "Guess value must be less than or equal to 100, got {}.",
                value
            );
        }

        Guess { value }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    #[should_panic(expected = "Guess value must be less than or equal to 100")]
    fn greater_than_100() {
        Guess::new(200);
    }
}
```

这段代码会通过测试，因为通过增加了 `expected` ，我们成功指定了期望的 `panic` 信息，大家可以顺着代码推测下：把 `200` 带入到 `new` 函数中看看会触发哪个 `panic`。

如果注意看，你会发现 `expected` 的字符串和实际 `panic` 的字符串可以不同，前者只需要是后者的字符串前缀即可，如果改成 `#[should_panic(expected = "Guess value must be less than")]`，一样可以通过测试。

## 使用 Result<T, E>

在之前的例子中，`panic` 扫清一切障碍，但是它也不是万能的，例如你想在测试中使用 `?` 操作符进行链式调用该怎么办？那就得请出 `Result<T, E>` 了：

```rust
#[cfg(test)]
mod tests {
    #[test]
    fn it_works() -> Result<(), String> {
        if 2 + 2 == 4 {
            Ok(())
        } else {
            Err(String::from("two plus two does not equal four"))
        }
    }
}
```

如上所示，测试函数不会再使用 `assert_eq!` 导致 `panic`，而是手动进行了逻辑判断，并返回一个 `Result`。当然，当这么实现时，`#[should_panic]` 将无法再被使用。

## 测试用例的并行或顺序执行

当运行多个测试函数时，默认情况下是为每个测试都生成一个线程，然后通过主线程来等待它们的完成和结果。这种模式的优点很明显，那就是并行运行会让整体测试时间变短很多，运行过大量测试用例的同学都明白并行测试的重要性：生命苦短，我用并行。

但是有利就有弊，并行测试最大的问题就在于共享状态的修改，因为你难以控制测试的运行顺序，因此如果多个测试共享一个数据，那么对该数据的使用也将变得不可控制。

例如，我们有多个测试，它们每个都会往该文件中写入一些**自己的数据**，最后再从文件中读取这些数据进行对比。由于所有测试都是同时运行的，当测试 `A` 写入数据准备读取并对比时，很有可能会被测试 `B` 写入新的数据，导致 `A` 写入的数据被覆盖，然后 `A` 再读取到的就是 `B` 写入的数据。结果 `A` 测试就会失败，而且这种失败还不是因为测试代码不正确导致的！

解决办法也有，我们可以让每个测试写入自己独立的文件中，当然，也可以让所有测试一个接着一个顺序运行:

```rust
$ cargo test -- --test-threads=1
```

首先能注意到的是该命令行参数是第二种类型：提供给编译后的可执行文件的，因为它在 `--` 之后进行传递。其次，细心的同学可能会想到，线程数不仅仅可以指定为 `1`，还可以指定为 `4`、`8`，当然，想要顺序运行，就必须是 `1`。

## 测试函数中的 println!

默认情况下，如果测试通过，那写入标准输出的内容是不会显示在测试结果中的:

```rust
fn prints_and_returns_10(a: i32) -> i32 {
    println!("I got the value {}", a);
    10
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn this_test_will_pass() {
        let value = prints_and_returns_10(4);
        assert_eq!(10, value);
    }

    #[test]
    fn this_test_will_fail() {
        let value = prints_and_returns_10(8);
        assert_eq!(5, value);
    }
}
```

上面代码使用 `println!` 输出收到的参数值，来看看测试结果:

```shell
running 2 tests
test tests::this_test_will_fail ... FAILED
test tests::this_test_will_pass ... ok

failures:

---- tests::this_test_will_fail stdout ----
I got the value 8
thread 'main' panicked at 'assertion failed: `(left == right)`
  left: `5`,
 right: `10`', src/lib.rs:19:9
note: run with `RUST_BACKTRACE=1` environment variable to display a backtrace


failures:
    tests::this_test_will_fail

test result: FAILED. 1 passed; 1 failed; 0 ignored; 0 measured; 0 filtered out; finished in 0.00s
```

大家注意看，`I got the value 4` 并没有被输出，因为该测试顺利通过了，如果就是想要看所有的输出，该怎么办呢？

```rust
$ cargo test -- --show-output
```

如上所示，只需要增加一个参数，具体的输出就不再展示，总之这次大家一定可以顺利看到 `I got the value 4` 的身影。

## 执行运行一部分测试

### 运行单个测试

这个很简单，只需要将指定的测试函数名作为参数即可：

```shell
$ cargo test one_hundred
running 1 test
test tests::one_hundred ... ok

test result: ok. 1 passed; 0 failed; 0 ignored; 0 measured; 2 filtered out; finished in 0.00s
```

此时，只有测试函数 `one_hundred` 会被运行，其它两个由于名称不匹配，会被直接忽略。同时，在上面的输出中，Rust 也通过 `2 filtered out` 提示我们：有两个测试函数被过滤了。

但是，如果你试图同时指定多个名称，那抱歉:

```shell
$ cargo test one_hundred,add_two_and_two
$ cargo test one_hundred add_two_and_two
```

这两种方式统统不行，此时就需要使用名称过滤的方式来实现了。

### 通过名称来过滤测试

我们可以通过指定部分名称的方式来过滤运行相应的测试:

```shell
$ cargo test add
running 2 tests
test tests::add_three_and_two ... ok
test tests::add_two_and_two ... ok

test result: ok. 2 passed; 0 failed; 0 ignored; 0 measured; 1 filtered out; finished in 0.00s
```

事实上，你不仅可以使用前缀，还能使用名称中间的一部分：

```shell
$ cargo test and
running 2 tests
test tests::add_two_and_two ... ok
test tests::add_three_and_two ... ok

test result: ok. 2 passed; 0 failed; 0 ignored; 0 measured; 1 filtered out; finished in 0.00s
```

其中还有一点值得注意，那就是测试模块 `tests` 的名称也出现在了最终结果中：`tests::add_two_and_two`，这是非常贴心的细节，也意味着我们可以通过**模块名称来过滤测试**：

```shell
$ cargo test tests

running 3 tests
test tests::add_two_and_two ... ok
test tests::add_three_and_two ... ok
test tests::one_hundred ... ok

test result: ok. 3 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 0.00s
```

### 忽略部分测试

有时候，一些测试会非常耗时间，因此我们希望在 `cargo test` 中对它进行忽略，如果使用之前的方式，我们需要将所有需要运行的名称指定一遍，这非常麻烦，好在 Rust 允许通过 `ignore` 关键字来忽略特定的测试用例:

```rust
#[test]
fn it_works() {
    assert_eq!(2 + 2, 4);
}

#[test]
#[ignore]
fn expensive_test() {
    // 这里的代码需要几十秒甚至几分钟才能完成
}
```

在这里，我们使用 `#[ignore]` 对 `expensive_test` 函数进行了标注，看看结果：

```shell
$ cargo test
running 2 tests
test expensive_test ... ignored
test it_works ... ok

test result: ok. 1 passed; 0 failed; 1 ignored; 0 measured; 0 filtered out; finished in 0.00s

   Doc-tests adder

running 0 tests

test result: ok. 0 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 0.00s
```

输出中的 `test expensive_test ... ignored` 意味着该测试函数被忽略了，因此并没有被执行。

当然，也可以通过以下方式运行被忽略的测试函数：

```shell
$ cargo test -- --ignored
running 1 test
test expensive_test ... ok

test result: ok. 1 passed; 0 failed; 0 ignored; 0 measured; 1 filtered out; finished in 0.00s

   Doc-tests adder

running 0 tests

test result: ok. 0 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 0.00s
```

### 组合过滤

上面的方式虽然很强大，但是单独使用依然存在局限性。好在它们还能组合使用，例如还是之前的代码：

```rust
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn it_works() {
        assert_eq!(2 + 2, 4);
    }

    #[test]
    #[ignore]
    fn expensive_test() {
        // 这里的代码需要几十秒甚至几分钟才能完成
    }

    #[test]
    #[ignore]
    fn expensive_run() {
        // 这里的代码需要几十秒甚至几分钟才能完成
    }
}
```

然后运行 `tests` 模块中的被忽略的测试函数

```shell
$ cargo test tests -- --ignored
running 2 tests
test tests::expensive_test ... ok
test tests::expensive_run ... ok

test result: ok. 2 passed; 0 failed; 0 ignored; 0 measured; 1 filtered out; finished in 0.00s
```

运行名称中带 `run` 且被忽略的测试函数：

```shell
$ cargo test run -- --ignored
running 1 test
test tests::expensive_run ... ok

test result: ok. 1 passed; 0 failed; 0 ignored; 0 measured; 2 filtered out; finished in 0.
```

## [dev-dependencies]

与 `package.json`( Nodejs )文件中的 `devDependencies` 一样， Rust 也能引入只在开发测试场景使用的外部依赖。

其中一个例子就是 [`pretty_assertions`](https://docs.rs/pretty_assertions/1.0.0/pretty_assertions/index.html)，它可以用来扩展标准库中的 `assert_eq!` 和 `assert_ne!`，例如提供彩色字体的结果对比。

在 `Cargo.toml` 文件中添加以下内容来引入 `pretty_assertions`：

```toml
# standard crate data is left out
[dev-dependencies]
pretty_assertions = "1"
```

然后在 `src/lib.rs` 中添加:

```rust
pub fn add(a: i32, b: i32) -> i32 {
    a + b
}

#[cfg(test)]
mod tests {
    use super::*;
    use pretty_assertions::assert_eq; // 该包仅能用于测试

    #[test]
    fn test_add() {
        assert_eq!(add(2, 3), 5);
    }
}
```

在 `tests` 模块中，我们通过 `use pretty_assertions::assert_eq;` 成功的引入之前添加的包，由于 `tests` 模块明确的用于测试目的，这种引入并不会报错。 大家可以试试在正常代码(非测试代码)中引入该包，看看会发生什么。

## 生成测试二进制文件

在有些时候，我们可能希望将测试与别人分享，这种情况下生成一个类似 `cargo build` 的可执行二进制文件是很好的选择。

事实上，在 `cargo test` 运行的时候，系统会自动为我们生成一个可运行测试的二进制可执行文件:

```shell
$ cargo test
 Finished test [unoptimized + debuginfo] target(s) in 0.00s
     Running unittests (target/debug/deps/study_cargo-0d693f72a0f49166)
```

这里的 `target/debug/deps/study_cargo-0d693f72a0f49166` 就是可执行文件的路径和名称，我们直接运行该文件来执行编译好的测试:

```shell
$ target/debug/deps/study_cargo-0d693f72a0f49166

running 3 tests
test tests::add_two_and_two ... ok
test tests::add_three_and_two ... ok
test tests::one_hundred ... ok

test result: ok. 3 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 0.00s
```

如果你只想生成编译生成文件，不想看 `cargo test` 的输出结果，还可以使用 `cargo test --no-run`.



# 单元测试和集成测试

## 单元测试

单元测试目标是测试某一个代码单元(一般都是函数)，验证该单元是否能按照预期进行工作，例如测试一个 `add` 函数，验证当给予两个输入时，最终返回的和是否符合预期。

在 Rust 中，单元测试的惯例是将测试代码的模块跟待测试的正常代码放入同一个文件中，例如 `src/lib.rs` 文件中有如下代码:

```rust
pub fn add_two(a: i32) -> i32 {
    a + 2
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn it_works() {
        assert_eq!(add_two(2), 4);
    }
}
```

`add_two` 是我们的项目代码，为了对它进行测试，我们在同一个文件中编写了测试模块 `tests`，并使用 `#[cfg(test)]` 进行了标注。

### 条件编译 #[cfg(test)]

上面代码中的 `#[cfg(test)]` 标注可以告诉 Rust 只有在 `cargo test` 时才编译和运行模块 `tests`，其它时候当这段代码是空气即可，例如在 `cargo build` 时。这么做有几个好处：

- 节省构建代码时的编译时间
- 减小编译出的可执行文件的体积

其实集成测试就不需要这个标注，因为它们被放入单独的目录文件中，而单元测试是跟正常的逻辑代码在同一个文件，因此必须对其进行特殊的标注，以便 Rust 可以识别。

在 `#[cfg(test)]` 中，`cfg` 是配置 `configuration` 的缩写，它告诉 Rust ：当 `test` 配置项存在时，才运行下面的代码，而 `cargo test` 在运行时，就会将 `test` 这个配置项传入进来，因此后面的 `tests` 模块会被包含进来。

大家看出来了吗？这是典型的条件编译，`Cargo` 会根据指定的配置来选择是否编译指定的代码，事实上关于条件编译 Rust 能做的不仅仅是这些。

### 测试私有函数

关于私有函数能否被直接测试，编程社区里一直争论不休，甚至于部分语言可能都不支持对私有函数进行测试或者难以测试。无论你的立场如何，反正 Rust 是支持对私有函数进行测试的:

```rust
pub fn add_two(a: i32) -> i32 {
    internal_adder(a, 2)
}

fn internal_adder(a: i32, b: i32) -> i32 {
    a + b
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn internal() {
        assert_eq!(4, internal_adder(2, 2));
    }
}
```

`internal_adder` 并没有使用 `pub` 进行声明，因此它是一个私有函数。`tests` 作为另一个模块，是绝对无法对它进行调用的，因为它们根本不在同一个模块中！

但是在上述代码中，我们使用 `use super::*;` 将 `tests` 的父模块中的所有内容引入到当前作用域中，这样就可以非常简单的实现对私有函数的测试。

## 集成测试

与单元测试的同吃同住不同，集成测试的代码是在一个单独的目录下的。由于它们使用跟其它模块一样的方式去调用你想要测试的代码，因此只能调用通过 `pub` 定义的 `API`，这一点与单元测试有很大的不同。

如果说单元测试是对代码单元进行测试，那集成测试则是对某一个功能或者接口进行测试，因此单元测试的通过，并不意味着集成测试就能通过：局部上反映不出的问题，在全局上很可能会暴露出来。

### tests 目录

一个标准的 Rust 项目，在它的根目录下会有一个 `tests` 目录，大名鼎鼎的 [`ripgrep`](https://github.com/BurntSushi/ripgrep) 也不能免俗。

没错，该目录就是用来存放集成测试的，Cargo 会自动来此目录下寻找集成测试文件。我们可以在该目录下创建任何文件，Cargo 会对每个文件都进行自动编译，但友情提示下，最好按照合适的逻辑来组织你的测试代码。

首先来创建一个集成测试文件 `tests/integration_test.rs` ，注意，`tests` 目录一般来说需要手动创建，该目录在项目的根目录下，跟 `src` 目录同级。然后在文件中填入如下测试代码：

```rust
use adder;

#[test]
fn it_adds_two() {
    assert_eq!(4, adder::add_two(2));
}
```

这段测试代码是对之前**私有函数**中的示例进行测试，该示例代码在 `src/lib.rs` 中。

首先与单元测试有所不同，我们并没有创建测试模块。其次，`tests` 目录下的每个文件都是一个单独的包，我们需要将待测试的包引入到当前包的作用域后: `use adder`，才能进行测试 。在创建项目后，`src/lib.rs` 自动创建一个与项目同名的 `lib` 类型的包，由于我们的项目名是 `adder`，因此包名也是 `adder`。

因为 `tests` 目录本身就说明了它的特殊用途，因此我们无需再使用 `#[cfg(test)]` 来取悦 Cargo。后者会在运行 `cargo test` 时，对 `tests` 目录中的每个文件都进行编译运行。

```shell
$ cargo test
     Running unittests (target/debug/deps/adder-8a400aa2b5212836)

running 1 test
test tests::it_works ... ok

test result: ok. 1 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 0.00s

     Running tests/integration_test.rs (target/debug/deps/integration_test-2d3aeee6f15d1f20)

running 1 test
test it_adds_two ... ok

test result: ok. 1 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 0.00s

   Doc-tests adder

running 0 tests

test result: ok. 0 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 0.00s
```

运行 `cargo test` ，可以看到上述输出。测试内容有三个部分：单元测试，集成测试和文档测试。

首先是单元测试被运行 `Running unittests` ，其次就是我们的主角集成测试的运行 `Running tests/integration_test.rs`，可以看出，集成测试的输出内容与单元测试并没有大的区别。最后运行的是文档测试 `Doc-tests adder`。

### 共享模块

在集成测试的 `tests` 目录下，每一个文件都是一个独立的包，这种组织方式可以很好的帮助我们理清测试代码的关系，但是如果大家想要在多个文件中共享同一个功能该怎么做？例如函数 `setup` 可以用于状态初始化，然后多个测试包都需要使用该函数进行状态的初始化。

也许你会想要创建一个 `tests/common.rs` 文件，然后将 `setup` 函数放入其中：

```rust
pub fn setup() {
    // 初始化一些测试状态
    // ...
}
```

但是当我们运行 `cargo test` 后，会发现该函数被当作集成测试函数运行了，即使它并没有包含任何测试功能，也没有被其它测试文件所调用:

```shell
$ cargo test
     Running tests/common.rs (target/debug/deps/common-5c21f4f2c87696fb)

running 0 tests

test result: ok. 0 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 
```

显然，这个结果并不是我们想要的。**为了避免这种输出，我们不能创建 `tests/common.rs`，而是要创建 `tests/common/mod.rs`。**，此时再运行 `cargo test` 就不会再看到相应的输出。 原因是**通过这种文件组织和命名方式， Rust 不再将 `common` 模块看作是集成测试文件。**

总结来说，**`tests` 目录下的子目录中的文件不会被当作独立的包，也不会有测试输出**。

```rust
use adder;

mod common;

#[test]
fn it_adds_two() {
    common::setup();
    assert_eq!(4, adder::add_two(2));
}
```

此时，就可以在测试中调用 `common` 中的共享函数了，不过还有一点值得注意，为了使用 `common`，这里使用了 `mod common` 的方式来声明该模块。

### 二进制包的集成测试

目前来说，Rust 只支持对 `lib` 类型的包进行集成测试，对于二进制包例如 `src/main.rs` 是无能为力的。原因在于，我们无法在其它包中使用 `use` 引入二进制包，而只有 `lib` 类型的包才能被引入，例如 `src/lib.rs`。

这就是为何我们需要将代码逻辑从 `src/main.rs` 剥离出去放入 `lib` 包中，例如很多 Rust 项目中都同时有 `src/main.rs` 和 `src/lib.rs` ，前者中只保留代码的主体脉络部分，而具体的实现通通放在类似后者的 `lib` 包中。

这样，我们就可以对 `lib` 包中的具体实现进行集成测试，由于 `main.rs` 中的主体脉络足够简单，当集成测试通过时，意味着 `main.rs` 中相应的调用代码也将正常运行。

## 总结

Rust 提供了单元测试和集成测试两种方式来帮助我们组织测试代码以解决代码正确性问题。

单元测试针对的是具体的代码单元，例如函数，而集成测试往往针对的是一个功能或接口 API，正因为目标上的不同，导致了两者在组织方式上的不同：

- 单元测试的模块和待测试的代码在同一个文件中，且可以很方便地对私有函数进行测试
- 集成测试文件放在项目根目录下的 `tests` 目录中，由于该目录下每个文件都是一个包，我们必须要引入待测试的代码到当前包的作用域中，才能进行测试，正因为此，集成测试只能对声明为 `pub` 的 API 进行测试



# 断言 assertion

在编写测试函数时，断言决定了我们的测试是通过还是失败，它为结果代言。在前面，大家已经见识过 `assert_eq!` 的使用，下面一起来看看 Rust 为我们提供了哪些好用的断言。

## 断言列表

在正式开始前，来看看常用的断言有哪些:

- `assert!`, `assert_eq!`, `assert_ne!`, 它们会在所有模式下运行
- `debug_assert!`, `debug_assert_eq!`, `debug_assert_ne!`, 它们只会在 `Debug` 模式下运行

## assert_eq!

`assert_eq!` 宏可以用于判断两个表达式返回的值是否相等 :

```rust
fn main() {
    let a = 3;
    let b = 1 + 2;
    assert_eq!(a, b);
}
```

当不相等时，当前线程会直接 `panic`:

```rust
fn main() {
    let a = 3;
    let b = 1 + 3;
    assert_eq!(a, b, "我们在测试两个数之和{} + {}，这是额外的错误信息", a, b);
}
```

运行后报错如下:

```shell
$ cargo run
thread 'main' panicked at 'assertion failed: `(left == right)`
  left: `3`,
 right: `4`: 我们在测试两个数之和3 + 4，这是额外的错误信息', src/main.rs:4:5
note: run with `RUST_BACKTRACE=1` environment variable to display a backtrace
```

可以看到，错误不仅按照预期发生了，我们还成功的定制了错误信息! 这种格式化输出的方式跟 `println!` 并无区别，具体参见 [`std::fmt`](https://doc.rust-lang.org/std/fmt/index.html)。

因为涉及到相等比较( `==` )和错误信息打印，因此两个表达式的值必须实现 `PartialEq` 和 `Debug` 特征，其中所有的原生类型和大多数标准库类型都实现了这些特征，而对于你自己定义的结构体、枚举，如果想要对其进行 `assert_eq!` 断言，则需要实现 `PartialEq` 和 `Debug` 特征:

- 若希望实现个性化相等比较和错误打印，则需手动实现
- 否则可以为自定义的结构体、枚举添加 `#[derive(PartialEq, Debug)]` 注解，来[自动派生]对应的特征

## assert_ne!

`assert_ne!` 在使用和限制上与 `assert_eq!` 并无区别，唯一的区别就在于，前者判断的是两者的不相等性。

我们将之前报错的代码稍作修改：

```rust
fn main() {
    let a = 3;
    let b = 1 + 3;
    assert_ne!(a, b, "我们在测试两个数之和{} + {}，这是额外的错误信息", a, b);
}
```

由于 `a` 和 `b` 不相等，因此 `assert_ne!` 会顺利通过，不再报错。

## assert!

`assert!` 用于判断传入的布尔表达式是否为 `true`:

```rust
// 以下断言的错误信息只包含给定表达式的返回值
assert!(true);

fn some_computation() -> bool { true }

assert!(some_computation());

// 使用自定义报错信息
let x = true;
assert!(x, "x wasn't true!");

// 使用格式化的自定义报错信息
let a = 3; let b = 27;
assert!(a + b == 30, "a = {}, b = {}", a, b);
```

来看看该如何使用 `assert!` 进行单元测试 :

```rust
#[derive(Debug)]
struct Rectangle {
    width: u32,
    height: u32,
}

impl Rectangle {
    fn can_hold(&self, other: &Rectangle) -> bool {
        self.width > other.width && self.height > other.height
    }
}


#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn larger_can_hold_smaller() {
        let larger = Rectangle {
            width: 8,
            height: 7,
        };
        let smaller = Rectangle {
            width: 5,
            height: 1,
        };

        assert!(larger.can_hold(&smaller));
    }
}
```

## debug_assert! 系列

`debug_assert!`, `debug_assert_eq!`, `debug_assert_ne!` 这三个在功能上与之前讲解的版本并无区别，主要区别在于，`debug_assert!` 系列只能在 `Debug` 模式下输出，例如如下代码：

```rust
fn main() {
    let a = 3;
    let b = 1 + 3;
    debug_assert_eq!(a, b, "我们在测试两个数之和{} + {}，这是额外的错误信息", a, b);
}
```

在 `Debug` 模式下运行输出错误信息：

```shell
$ cargo run
thread 'main' panicked at 'assertion failed: `(left == right)`
  left: `3`,
 right: `4`: 我们在测试两个数之和3 + 4，这是额外的错误信息', src/main.rs:4:5
note: run with `RUST_BACKTRACE=1` environment variable to display a backtrace
```

但是在 `Release` 模式下却没有任何输出:

```shell
$ cargo run --release
```

若一些断言检查会影响发布版本的性能时，大家可以使用 `debug_assert!` 来避免这种情况的发生。



# 用 GitHub Actions 进行持续集成

[GitHub Actions](https://github.com/features/actions) 是官方于 2018 年推出的持续集成服务，它非常强大，本文将手把手带领大家学习如何使用 `GitHub Actions` 对 Rust 项目进行持续集成。

持续集成是软件开发中异常重要的一环，大家应该都听说过 `Jenkins`，它就是一个拥有悠久历史的持续集成工具。简单来说，持续集成会定期拉取同一个项目中所有成员的相关代码，对其进行自动化构建。

## GitHub Actions

而本文的主角正是这样的持续集成平台，它由 GitHub 官方提供，并且跟 GitHub 进行了深度的整合，其中 `actions` 代表了代码拉取、测试运行、登陆远程服务器、发布到第三方服务等操作行为。

最妙的是 GitHub 发现这些 `actions` 其实在很多项目中都是类似的，意味着 `actions` 完全可以被多个项目共享使用，而不是每个项目都从零开发自己的 `actions`。

若你需要某个 `action`，不必自己写复杂的脚本，直接引用他人写好的 `action` 即可，整个持续集成过程，就变成了多个 `action` 的组合，这就是` GitHub Actions` 最厉害的地方。

### action 的分享与引用

既然 `action` 这么强大，我们就可以将自己的 `action` 分享给他人，也可以引用他人分享的 `action`，有以下几种方式：

1. 将你的 `action` 放在 GitHub 上的公共仓库中，这样其它开发者就可以引用，例如 [github-profile-summary-cards](https://github.com/vn7n24fzkq/github-profile-summary-cards) 就提供了相应的 `action`，可以生成 GitHub 用户统计信息，然后嵌入到你的个人主页中，具体效果[见这里](https://github.com/sunface)
2. GitHub 提供了一个[官方市场](https://github.com/marketplace?type=actions)，里面收集了许多质量不错的 `actions`，并支持在线搜索
3. [awesome-actions](https://github.com/sdras/awesome-actions)，由三方开发者收集并整理的 actions
4. [starter workflows](https://github.com/actions/starter-workflows)，由官方提供的工作流( workflow )模版

对于第一点这里再补充下，如果你想要引用某个代码仓库中的 `action` ，可以通过 `userName/repoName` 方式来引用: 例如你可以通过 `actions/setup-node` 来引用 `github.com/actions/setup-node` 仓库中的 `action`，该 `action` 的作用是安装 Node.js。

由于 `action` 是代码仓库，因此就有版本的概念，你可以使用 `@` 符号来引入同一个仓库中不同版本的 `action`，例如:

```yml
actions/setup-node@master  # 指向一个分支
actions/setup-node@v2.5.1    # 指向一个 release
actions/setup-node@f099707 # 指向一个 commit
```

如果希望深入了解，可以进一步查看官方的[文档](https://docs.github.com/cn/actions/creating-actions/about-custom-actions#using-release-management-for-actions)。

## Actions 基础

在了解了何为 GitHub Actions 后，再来通过一个基本的例子来学习下它的基本概念，注意，由于篇幅有限，我们只会讲解最常用的部分，如果想要完整的学习，请移步[这里](https://docs.github.com/en/actions)。

### 创建 action demo

首先，为了演示，我们需要创建一个公开的 GitHub 仓库 `rust-action`，然后在仓库主页的导航栏中点击 `Actions` ，你会看到如下页面 :

![img](https://pic1.zhimg.com/80/v2-4bb58f042c7a285219910bfd3c259464_1440w.jpg)

接着点击 `set up a workflow yourself ->` ，你将看到系统为你自动创建的一个工作流 workflow ，在 `rust-action/.github/workflows/main.yml` 文件中包含以下内容:

```yml
# 下面是一个基础的工作流，你可以基于它来编写自己的 GitHub Actions
name: CI

# 控制工作流何时运行
on:
  # 当 `push` 或 `pull request` 事件发生时就触发工作流的执行，这里仅仅针对 `main` 分支
  push:
    branches: [main]
  pull_request:
    branches: [main]

  # 允许用于在 `Actions` 标签页中手动运行工作流
  workflow_dispatch:

# 工作流由一个或多个作业( job )组成，这些作业可以顺序运行也可以并行运行
jobs:
  # 当前的工作流仅包含一个作业，作业 id 是 "build"
  build:
    # 作业名称
    name: build rust action
    # 执行作业所需的运行器 runner
    runs-on: ubuntu-latest

    # steps 代表了作业中包含的一系列可被执行的任务
    steps:
      # 在 $GITHUB_WORKSPACE 下 checks-out 当前仓库，这样当前作业就可以访问该仓库
      - uses: actions/checkout@v2

      # 使用运行器的终端来运行一个命令
      - name: Run a one-line script
        run: echo Hello, world!

      # 使用运行器的终端运行一组命令
      - name: Run a multi-line script
        run: |
          echo Add other actions to build,
          echo test, and deploy your project.
```

### 查看工作流信息

通过内容的注释，大家应该能大概理解这个工作流是怎么回事了，在具体讲解前，我们先完成 `Actions` 的创建，点击右上角的 `Start Commit` 绿色按钮提交，然后再回到 `Actions` 标签页，你可以看到如下界面:

![img](https://pic2.zhimg.com/80/v2-301a8feac57633f34f9cd638ac139c22_1440w.jpg)

这里包含了我们刚创建的工作流及当前的状态，从右下角可以看出，该工作流的运行时间是 `now` 也就是现在，`queued` 代表它已经被安排到了运行队列中，等待运行。

等过几秒(也可能几十秒后)，刷新当前页面，就能看到成功运行的工作流：

![img](https://pic3.zhimg.com/80/v2-99fb593bc3140f71c316ce0ba6249911_1440w.png)

还记得之前配置中的 `workflow_dispatch` 嘛？它允许工作流被手动执行：点击左边的 `All workflows -> CI` ，可以看到如下页面。

![img](https://pic3.zhimg.com/80/v2-cc1d9418f6befb5a089cde659666e65e_1440w.png)

页面中通过蓝色的醒目高亮提示我们 `this workflow has a workflow_dispatch event trigger`，因此可以点击右边的 `Run workflow` 手动再次执行该工作流。

> 注意，目前 `Actions` 并不会自动渲染最新的结果，因此需要刷新页面来看到最新的结果

点击 `Create main.yml` 可以查看该工作流的详细信息：

![img](https://pic1.zhimg.com/80/v2-94b46f23b5d63de35eae7f0425bb99b7_1440w.jpg)

至此，我们已经初步掌握 `GitHub Actions` 的用法，现在来看看一些基本的概念。

### 基本概念

- **GitHub Actions**，每个项目都拥有一个 `Actions` ，可以包含多个工作流
- **workflow 工作流**，描述了一次持续集成的过程
- **job 作业**，一个工作流可以包含多个作业，因为一次持续集成本身就由多个不同的部分组成
- **step 步骤**，每个作业由多个步骤组成，按照顺序一步一步完成
- **action 动作**，每个步骤可以包含多个动作，例如上例中的 `Run a multi-line script` 步骤就包含了两个动作

可以看出，每一个概念都是相互包含的关系，前者包含了后者，层层相扣，正因为这些精心设计的对象才有了强大的 `GitHub Actions`。

### on

`on` 可以设定事件用于触发工作流的运行：

1. 一个或多个 GitHub 事件，例如 `push` 一个 `commit`、创建一个 `issue`、提交一次 `pr` 等等，详细的事件列表参见[这里](https://docs.github.com/en/actions/using-workflows/events-that-trigger-workflows)
2. 预定的时间，例如每天零点零分触发，详情见[这里](https://docs.github.com/en/actions/using-workflows/events-that-trigger-workflows#schedule)

```yml
on:
  schedule: -cron:'0 0 * * *'
```

1. 外部事件触发，例如你可以通过 `REST API` 向 GitHub 发送请求去触发，具体请查阅[官方文档](https://docs.github.com/en/actions/using-workflows/events-that-trigger-workflows#repository_dispatch)

### jobs

工作流由一个或多个作业 `job` 组成，这些作业可以顺序运行也可以并行运行，同时我们还能使用 `needs` 来指定作业之间的依赖关系：

```yml
jobs:
  job1:

  job2:
    needs: job1

  job3:
    needs: [job1, job2]
```

这里的 `job2` 必须等待 `job1` 成功后才能运行，而 `job3` 则需要等待 `job1` 和 `job2`。

### runs-on

指定作业的运行环境，运行器 `runner` 分为两种：`GitHub-hosted runner` 和 `self-hosted runner`，后者是使用自己的机器来运行作业，但是需要 GitHub 能进行访问并给予相应的机器权限，感兴趣的同学可以看看[这里](https://docs.github.com/en/actions/using-jobs/choosing-the-runner-for-a-job#choosing-self-hosted-runners)。

而对于前者，GitHub 提供了以下的运行环境：

![img](https://pic2.zhimg.com/80/v2-614999565cc513715aaf156c2e478991_1440w.jpg)

其中比较常用的就是 `runs-on:ubuntu-latest`。

### strategy.matrix

有时候我们常常需要对多个操作系统、多个平台、多个编程语言版本进行测试，为此我们可以配置一个 `matrix` 矩阵：

```yml
runs-on: ${{ matrix.os }}
strategy:
  matrix:
    os: [ubuntu-18.04, ubuntu-20.04]
    node: [10, 12, 14]
steps:
  - uses: actions/setup-node@v2
    with:
      node-version: ${{ matrix.node }}
```

大家猜猜，这段代码会最终构建多少个作业？答案是 `2 * 3 = 6`，通过 `os` 和 `node` 进行组合，就可以得出这个结论，这也是 `matrix` 矩阵名称的来源。

当然，`matrix` 能做的远不止这些，例如，你还可以定义自己想要的 `kv` 键值对，想要深入学习的话可以看看[官方文档](https://docs.github.com/en/actions/using-jobs/using-a-build-matrix-for-your-jobs)。

### strategy

除了 `matrix` ，`strategy` 中还能设定以下内容：

- `fail-fast` : 默认为 true ，即一旦某个矩阵任务失败则立即取消所有还在进行中的任务
- `max-paraller` : 可同时执行的最大并发数，默认情况下 GitHub 会动态调整

### env

用于设定环境变量，可以用于以下地方:

- env
- jobs.<job_id>.env
- jobs.<job_id>.steps.env

```yml
env:
  NODE_ENV: dev

jobs:
  job1:
    env:
      NODE_ENV: test

    steps:
      - name:
        env:
          NODE_ENV: prod
```

如果有多个 `env` 存在，会使用就近那个。

至此，`GitHub Actions` 的常用内容大家已经基本了解，下面来看一个实用的示例。

## 真实示例：生成 GitHub 统计卡片

相信大家看过不少用户都定制了自己的个性化 GitHub 首页，这个是通过在个人名下创建一个同名的仓库来实现的，该仓库中的 `Readme.md` 的内容会自动展示在你的个人首页中，例如 `Sunface` 的[个人首页](https://github.com/sunface) 和内容所在的[仓库](https://github.com/sunface/sunface)。

大家可能会好奇上面链接中的 GitHub 统计卡片如何生成，其实有两种办法:

- 使用 [github-readme-stats](https://github.com/anuraghazra/github-readme-stats)
- 使用 `GitHub Actions` 来引用其它人提供的 `action` 生成对应的卡片，再嵌入进来， `Sunface` 的个人首页就是这么做的

第一种的优点就是非常简单，缺点是样式不太容易统一，不能对齐对于强迫症来说实在难受 :( 而后者的优点是规规整整的卡片，缺点就是使用起来更加复杂，而我们正好借此来看看真实的 `GitHub Actions` 长什么样。

首先，在你的同名项目下创建 `.github/workflows/profile-summary-cards.yml` 文件，然后填入以下内容:

```yml
# 工作流名称
name: GitHub-Profile-Summary-Cards

on:
  schedule:
    # 每24小时触发一次
    - cron: "0 * * * *"
  # 开启手动触发
  workflow_dispatch:

jobs:
  # job id
  build:
    runs-on: ubuntu-latest
    name: generate

    steps:
      # 第一步，checkout 当前项目
      - uses: actions/checkout@v2
      # 第二步，引入目标 action: vn7n24fzkq/github-profile-summary-cards仓库中的 `release` 分支
      - uses: vn7n24fzkq/github-profile-summary-cards@release
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        with:
          USERNAME: ${{ github.repository_owner }}
```

当提交后，该工作流会自动在当前项目中生成 `profile-summary-card-output` 目录，然后将所有卡片放入其中，当然我们这里使用了定时触发的机制，并没有基于 `pr` 或`push` 来触发，如果你在编写过程中，希望手动触发来看看结果，请参考前文的手动触发方式。

这里我们引用了 `vn7n24fzkq/github-profile-summary-cards@release` 的 `action`，位于 `https://github.com/vn7n24fzkq/github-profile-summary-cards` 仓库中，并指定使用 `release` 分支。

接下来就可以愉快的[使用这些卡片](https://github.com/sunface/sunface/edit/master/Readme.md)来定制我们的主页了: )

## 使用 Actions 来构建 Rust 项目

其实 Rust 项目也没有什么特别之处，我们只需要在 `steps` 逐步构建即可，下面给出该如何测试和构建的示例。

### 测试

```yml
on: [push, pull_request]

name: Continuous integration

jobs:
  check:
    name: Check
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - uses: actions-rs/toolchain@v1
        with:
          profile: minimal
          toolchain: stable
          override: true
      - run: cargo check

  test:
    name: Test Suite
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - uses: actions-rs/toolchain@v1
        with:
          profile: minimal
          toolchain: stable
          override: true
      - run: cargo test

  fmt:
    name: Rustfmt
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - uses: actions-rs/toolchain@v1
        with:
          profile: minimal
          toolchain: stable
          override: true
      - run: rustup component add rustfmt
      - run: cargo fmt --all -- --check

  clippy:
    name: Clippy
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - uses: actions-rs/toolchain@v1
        with:
          profile: minimal
          toolchain: stable
          override: true
      - run: rustup component add clippy
      - run: cargo clippy -- -D warnings
```

## 构建

```yml
name: build
on:
  workflow_dispatch: {}
jobs:
  build:
    name: build
    runs-on: ${{ matrix.os }}
    strategy:
      matrix:
        build: [linux, macos, windows]
        include:
          - build: linux
            os: ubuntu-18.04
            rust: nightly
            target: x86_64-unknown-linux-musl
            archive-name: sgf-render-linux.tar.gz
          - build: macos
            os: macos-latest
            rust: nightly
            target: x86_64-apple-darwin
            archive-name: sgf-render-macos.tar.gz
          - build: windows
            os: windows-2019
            rust: nightly-x86_64-msvc
            target: x86_64-pc-windows-msvc
            archive-name: sgf-render-windows.7z
      fail-fast: false

    steps:
      - name: Checkout repository
        uses: actions/checkout@v2

      - name: Install Rust
        uses: actions-rs/toolchain@v1
        with:
          toolchain: ${{ matrix.rust }}
          profile: minimal
          override: true
          target: ${{ matrix.target }}

      - name: Build binary
        run: cargo build --verbose --release --target ${{ matrix.target }}
        env:
          RUST_BACKTRACE: 1

      - name: Strip binary (linux and macos)
        if: matrix.build == 'linux' || matrix.build == 'macos'
        run: strip "target/${{ matrix.target }}/release/sgf-render"

      - name: Build archive
        shell: bash
        run: |
          mkdir archive
          cp LICENSE README.md archive/
          cd archive
          if [ "${{ matrix.build }}" = "windows" ]; then
            cp "../target/${{ matrix.target }}/release/sgf-render.exe" ./
            7z a "${{ matrix.archive-name }}" LICENSE README.md sgf-render.exe
          else
            cp "../target/${{ matrix.target }}/release/sgf-render" ./
            tar -czf "${{ matrix.archive-name }}" LICENSE README.md sgf-render
          fi
      - name: Upload archive
        uses: actions/upload-artifact@v1
        with:
          name: ${{ matrix.archive-name }}
          path: archive/${{ matrix.archive-name }}
```



# 基准测试 benchmark

几乎所有开发都知道，如果要测量程序的性能，就需要性能测试。

性能测试包含了两种：压力测试和基准测试。前者是针对接口 API，模拟大量用户去访问接口然后生成接口级别的性能数据；而后者是针对代码，可以用来测试某一段代码的运行速度，例如一个排序算法。

而本文将要介绍的就是基准测试 `benchmark`，在 Rust 中，有两种方式可以实现：

- 官方提供的 `benchmark`
- 社区实现，例如 `criterion.rs`

事实上我们更推荐后者，原因在后文会详细介绍，下面先从官方提供的工具开始。

## 官方 benchmark

官方提供的测试工具，目前最大的问题就是只能在非 `stable` 下使用，原因是需要在代码中引入 `test` 特性: `#![feature(test)]`。

### 设置 Rust 版本

因此在开始之前，我们需要先将当前仓库中的 [`Rust 版本`](https://course.rs/appendix/rust-version.html#不稳定功能)从 `stable` 切换为 `nightly`:

1. 安装 `nightly` 版本：`$ rustup install nightly`
2. 使用以下命令确认版本已经安装成功

```shell
$ rustup toolchain list
stable-aarch64-apple-darwin (default)
nightly-aarch64-apple-darwin (override)
```

1. 进入 `adder` 项目(之前为了学习测试专门创建的项目)的根目录，然后运行 `rustup override set nightly`，将该项目使用的 `rust` 设置为 `nightly`

很简单吧，其实只要一个命令就可以切换指定项目的 Rust 版本，例如你还能在基准测试后再使用 `rustup override set stable` 切换回 `stable` 版本。

### 使用 benchmark

当完成版本切换后，就可以开始正式编写 `benchmark` 代码了。首先，将 `src/lib.rs` 中的内容替换成如下代码：

```rust
#![feature(test)]

extern crate test;

pub fn add_two(a: i32) -> i32 {
    a + 2
}

#[cfg(test)]
mod tests {
    use super::*;
    use test::Bencher;

    #[test]
    fn it_works() {
        assert_eq!(4, add_two(2));
    }

    #[bench]
    fn bench_add_two(b: &mut Bencher) {
        b.iter(|| add_two(2));
    }
}
```

可以看出，`benchmark` 跟单元测试区别不大，最大的区别在于它是通过 `#[bench]` 标注，而单元测试是通过 `#[test]` 进行标注，这意味着 `cargo test` 将不会运行 `benchmark` 代码：

```shell
$ cargo test
running 2 tests
test tests::bench_add_two ... ok
test tests::it_works ... ok

test result: ok. 2 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 0.00s
```

`cargo test` 直接把我们的 `benchmark` 代码当作单元测试处理了，因此没有任何性能测试的结果产生。

对此，需要使用 `cargo bench` 命令：

```shell
$ cargo bench
running 2 tests
test tests::it_works ... ignored
test tests::bench_add_two ... bench:           0 ns/iter (+/- 0)

test result: ok. 0 passed; 0 failed; 1 ignored; 1 measured; 0 filtered out; finished in 0.29s
```

看到没，一个截然不同的结果，除此之外还能看出几点:

- 单元测试 `it_works` 被忽略，并没有执行: `tests::it_works ... ignored`
- benchmark 的结果是 `0 ns/iter`，表示每次迭代( `b.iter` )耗时 `0 ns`，奇怪，怎么是 `0` 纳秒呢？别急，原因后面会讲

### 一些使用建议

关于 `benchmark`，这里有一些使用建议值得大家关注:

- 将初始化代码移动到 `b.iter` 循环之外，否则每次循环迭代都会初始化一次，这里只应该存放需要精准测试的代码
- 让代码每次都做一样的事情，例如不要去做累加或状态更改的操作
- 最好让 `iter` 之外的代码也具有幂等性，因为它也可能被 `benchmark` 运行多次
- 循环内的代码应该尽量的短小快速，因为这样循环才能被尽可能多的执行，结果也会更加准确

### 谜一般都得性能结果

在写 `benchmark` 时，你可能会遇到一些很纳闷的棘手问题，例如以下代码:

```rust
#![feature(test)]

extern crate test;

fn fibonacci_u64(number: u64) -> u64 {
    let mut last: u64 = 1;
    let mut current: u64 = 0;
    let mut buffer: u64;
    let mut position: u64 = 1;

    return loop {
        if position == number {
            break current;
        }

        buffer = last;
        last = current;
        current = buffer + current;
        position += 1;
    };
}
#[cfg(test)]
mod tests {
    use super::*;
    use test::Bencher;

    #[test]
    fn it_works() {
       assert_eq!(fibonacci_u64(1), 0);
       assert_eq!(fibonacci_u64(2), 1);
       assert_eq!(fibonacci_u64(12), 89);
       assert_eq!(fibonacci_u64(30), 514229);
    }

    #[bench]
    fn bench_u64(b: &mut Bencher) {
        b.iter(|| {
            for i in 100..200 {
                fibonacci_u64(i);
            }
        });
    }
}
```

通过`cargo bench`运行后，得到一个难以置信的结果：`test tests::bench_u64 ... bench: 0 ns/iter (+/- 0)`, 难道 Rust 已经到达量子计算机级别了？

其实，原因藏在`LLVM`中: `LLVM`认为`fibonacci_u64`函数调用的结果没有使用，同时也认为该函数没有任何副作用(造成其它的影响，例如修改外部变量、访问网络等), 因此它有理由把这个函数调用优化掉！

解决很简单，使用 Rust 标准库中的 `black_box` 函数:

```rust
 for i in 100..200 {
    test::black_box(fibonacci_u64(test::black_box(i)));
}
```

通过这个函数，我们告诉编译器，让它尽量少做优化，此时 LLVM 就不会再自作主张了:)

```shell
$ cargo bench
running 2 tests
test tests::it_works ... ignored
test tests::bench_u64 ... bench:       5,626 ns/iter (+/- 267)

test result: ok. 0 passed; 0 failed; 1 ignored; 1 measured; 0 filtered out; finished in 0.67s
```

嗯，这次结果就明显正常了。

## criterion.rs

官方 `benchmark` 有两个问题，首先就是不支持 `stable` 版本的 Rust，其次是结果有些简单，缺少更详细的统计分布。

因此社区 `benchmark` 就应运而生，其中最有名的就是 [`criterion.rs`](https://github.com/bheisler/criterion.rs)，它有几个重要特性:

- 统计分析，例如可以跟上一次运行的结果进行差异比对
- 图表，使用 [`gnuplots`](http://www.gnuplot.info/) 展示详细的结果图表

首先，如果你需要图表，需要先安装 `gnuplots`，其次，我们需要引入相关的包，在 `Cargo.toml` 文件中新增 :

```toml
[dev-dependencies]
criterion = "0.3"

[[bench]]
name = "my_benchmark"
harness = false
```

接着，在项目中创建一个测试文件: `$PROJECT/benches/my_benchmark.rs`，然后加入以下内容：

```rust
use criterion::{black_box, criterion_group, criterion_main, Criterion};

fn fibonacci(n: u64) -> u64 {
    match n {
        0 => 1,
        1 => 1,
        n => fibonacci(n-1) + fibonacci(n-2),
    }
}

fn criterion_benchmark(c: &mut Criterion) {
    c.bench_function("fib 20", |b| b.iter(|| fibonacci(black_box(20))));
}

criterion_group!(benches, criterion_benchmark);
criterion_main!(benches);
```

最后，使用 `cargo bench` 运行并观察结果：

```shell
     Running target/release/deps/example-423eedc43b2b3a93
Benchmarking fib 20
Benchmarking fib 20: Warming up for 3.0000 s
Benchmarking fib 20: Collecting 100 samples in estimated 5.0658 s (188100 iterations)
Benchmarking fib 20: Analyzing
fib 20                  time:   [26.029 us 26.251 us 26.505 us]
Found 11 outliers among 99 measurements (11.11%)
  6 (6.06%) high mild
  5 (5.05%) high severe
slope  [26.029 us 26.505 us] R^2            [0.8745662 0.8728027]
mean   [26.106 us 26.561 us] std. dev.      [808.98 ns 1.4722 us]
median [25.733 us 25.988 us] med. abs. dev. [234.09 ns 544.07 ns]
```

可以看出，这个结果是明显比官方的更详尽的，如果大家希望更深入的学习它的使用，可以参见[官方文档](https://bheisler.github.io/criterion.rs/book/getting_started.html)。



> 参考资料：
> 1. https://course.rs/test/intro.html