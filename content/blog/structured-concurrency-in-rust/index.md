---
title: Structured Concurrency in Rust
draft: false
date: 2020-02-15
description: "并发，是程序员在日常编程中难以绕开的话题，本文介绍一种并发编程范式-结构化并发(Structured Concurrency)。首先给出它的概念和现状，然后着重介绍 Rust 的一个实现 - task_scope，最后给出一个例子展示如何在实践中使用。"
author: lerencao
tags:
- rust
- concurrency
keywords:
- rust
- concurrency
- structured
- goto
- scope
categories:
- blog
---


并发，是程序员在日常编程中难以绕开的话题，本文介绍一种并发编程范式-结构化并发(Structured Concurrency)。首先给出它的概念和现状，然后着重介绍 Rust 的一个实现 - task_scope，最后给出一个例子展示如何在实践中使用。
## The Pain of concurrency programming

熟悉 Go 语言的朋友都知道，可以通过 `go myfunc()` 轻易的创建一个和当前协程并发执行的 task。但是，当程序变复杂， *go statement* 变的越来越多时，就会遇到各种 task 生命周期的问题。

- 这个 task 什么时候开始，什么时候结束？
- 怎么做到当所有 subtask 都结束，main task再结束？
- 假如某个 subtask 失败，main task 如何cancel 掉其他subtask？
- 如何保证所有 subtask 在某个特定的超时时间内返回，无论它成功还是失败？
- 更进一步，如何保证 main task 在规定的时间内返回，无论其成功还是失败，同时 cancel 掉它产生的所有 subtask？
- main task 已经结束了，subtask 还在 running，是不是存在资源泄漏？

以上只是我根据自己过往的经验，随便列举的几类问题。当然这些问题在 Golang 里面都是可以解的，具体可以参考 Golang Official Blog 里几篇讲 Golang Concurrency Patterns 的文章。它需要程序按照一些特定的行为方式去组织，比如说方法参数带上 `Context`，通过它去传递 cancellation 信号。

> [Go Concurrency Patterns: Context](https://blog.golang.org/context)
>
> [Go Concurrency Patterns: Pipelines and cancellation](https://blog.golang.org/pipelines)
>
> [Go Concurrency Patterns: Timing out, moving on](https://blog.golang.org/go-concurrency-patterns-timing-out-and)
>
> [Advanced Go Concurrency Patterns](https://blog.golang.org/advanced-go-concurrency-patterns)

在多线程模型中，上面几个问题给程序员带来了更多复杂性和更重的心智负担。我相信大部分 Java 程序员都无法准确的把上面几个问题都解决掉，这不是嘲讽，而是线程模型本身给使用者带来的诸多问题，这对使用者的要求实在是太高了。

那么，有没有一种编程范式，既可以解决这些问题，又具有相对比较低的认知门槛，同时也不需要像 Golang Context 那样侵入应用程序的接口？结构化并发(Structured Concurrency) 就是这样一种并发编程范式。

## Structured Concurrency

2016年，ZerMQ 的作者 Martin Sústrik 在他的[文章][1] 中第一次形式化的提出结构化并发这个概念。2018 年 Nathaniel J. Smith (njs) 在 Python 中实现了这一范式 - [trio](https://trio.readthedocs.io/en/stable/)，并在  [Notes on structured concurrency, or: Go statement considered harmful][2] 一文中进一步阐述了 Structured Concurrency。同时期，Roman Elizarov 也提出了[相同的理念][3]，并在 Kotlin 中实现了大家熟知的[kotlinx.coroutine][4]。2019年，OpenJDK loom project 也开始引入 structured concurrency，作为其轻量级线程和协程的一部分。

废话这么多，一方面是想提供更多的历史，方便读者更深入的了解，另一方面也是想说明，结构化并发虽然还是一个比较新的概念，具体的细节也在不断演进中，但已经有成熟的工业界实现，读者可以在自己熟悉的语言中应用该范式。

> lidill(C): http://libdill.org/
>
> trio(Python): https://trio.readthedocs.io/en/stable/
>
> kotin.coroutine: https://github.com/Kotlin/kotlinx.coroutines
>
> Venice(Swift): https://github.com/Zewo/Venice

Structured Concurrency 核心在于通过一种 structured 的方法实现并发程序，用具有明确入口点和出口点的控制流结构来封装并发“线程”（可以是系统级线程也可以是用户级线程，也就是协程，甚至可以是进程）的执行，确保所有派生“线程”在出口之前完成。

说的可能有点抽象，举个例子。

```go
func main_func() {
  go myfunc()
  go anotherfunc()
  <rest of program>...
}
```

``` mermaid
stateDiagram
    [*] --> m
    m --> s1
    m --> s2
    state join_state <<join>>
    s1 --> join_state
    m --> join_state
    s2 --> join_state
    join_state --> [*]
```

假设上图中的代码具有 structured concurrency 特性（这里用的是 golang 的语法来展示）。`main_func` 里，创建了两个子任务： `myfunc()`, `anotherfunc`，这里的 func 是一个控制流结构，入口就是 func 调用开始，出口是 func 调用结束，派生出来的两个子任务需要在 `main_func` 调用结束之前先完成。当 `main_func` 结束，它涉及到的资源也都会被释放掉。外部调用者无法也无需感知 main_func 里面到底是串行的还是并行的，它只需要调用 `main_func`，然后等待它结束即可。这就是所谓的 **Structured**。


> 大家应该都知道 `goto` 语句，一般不推荐使用它（见[Dijkstra: Go To Statement Considered Harmful][5]），使用 goto 的场景基本都可以用 if, else, for loop, while loop 这些控制结构组合表达，可以把这些控制结构叫做 structured statement。
>
> Structured Concurrency 的概念和 structured statement 类似，通过控制流来保证并发语义的可控，而不是 `go coroutine` 满天飞。
>
> 关于这方面的类比，njs 在 [Notes on structured concurrency, or: Go statement considered harmful][2] 中做了详细的说明，推荐阅读。

以上是 Structured Concurrency 的核心概念，看起来是不是很简单。下面就跟着我去看看，在 Rust 里你可以怎样实现 Structured Concurrency。

## Implement Structured Concurrency in Rust

目前 Rust 并没有一个成熟的库支持 Structured Concurrency 的编程范式。但是 [tokio#1879](https://github.com/tokio-rs/tokio/issues/1879) 这个 issue 中已经开始讨论了如何在 tokio 这个底层库中提供支持，以实现 structured concurrency 风格的编程。如果你比较感兴趣，欢迎去这里贡献你的力量。

本节以 Rust 社区另外一个库 - task_scope 来介绍这种编程范式。task_scope 是一个日本小哥写的一个试验性质的库。在阅读和试验它时，我认为它提供的接口在使用上很别扭，不便于实现更复杂的并发逻辑，于是基于自己的经验，我把它的对外接口抽象成 `Scope` 和 `CancelScope`。这两个概念是继承自 trio 的实现，`Scope` 对应 trio 的 `nursery`，`CancelScope` 对应 trio 的 `cancel_token`。fork 版本见 [startcoinorg/task_scope][6]。

### Scope

为了将具有 Structured Concurrency 行为的代码与普通的异步代码区别出来，我在 task_scope 中引入了 `Scope` 这个实体。所有 structured concurrency 的异步代码都必须在 `Scope` 的作用域中完成。下面给出用 task_scope 实现之前例子的伪代码。

```rust
let scope = Scope::new();
scope.run(|spawner| async {
  spawner.spawn(myfunc());
  spawner.spawn(anotherfunc());
  <rest of program>...
}).await;
```

Scope 作为 Structured Concurrency 的控制结构，任何想要进行 structured concurrency 编程的代码都必须初始化出一个 Scope 对象，调用 `Scope.run` 打开了这个控制结构的入口，在控制结构里面，可以随意的 spawn 子任务。`myfunc` 和 `anotherfunc` 都是运行在这个 scope 里。没有 Scope，父任务无法开启新的子任务，这保证了 Scope 是 Structured Concurrency 的唯一入口。最重要的是，只有当所有子任务都结束时，父任务才会结束，如果父任务在子任务结束前，就已经执行完自己的代码块，那么它需要暂停自己，并等待所有子任务结束。

Golang 的 `go` 语句最主要的问题是，当你调用了一个函数，并且函数返回了，然而你不知道它是否开启了一个/些后台任务，这些后台任务在函数返回后也不会结束（无论是有意的还是无意的）。这打破了函数的抽象，破坏了它的封装性。通过 Scope 抽象的 Structured Concurrency，就没有这个问题。任何一个函数都可以通过 scope 来运行多个并发的任务，但是函数无法返回，除非所有的子任务都完成了。因此，当一个函数返回了，你知道它是真的返回了，而不会有其他遗漏的子任务。



### Timeout and Cancellation

还记得我们在开篇提到的几个问题吗，里面涉及到超时和取消：*如何保证 main task 在规定的时间内返回，无论其成功还是失败，同时 cancel 掉它产生的所有 subtask？*
这一节，我们来聊聊这个问题。

我在 task_scope 中为 Scope 提供了一个方法 `pub fn cancel_scope(&self) -> CancelScope`，来获取这个 scope 的 *cancel_token*。调用 `CancelScope.cancel/force_cancel` 方法可以取消正在执行的 scope，前者给予 scope 一定的机会做优雅退出，后者则没有。以下是一个更加完善的例子，加入 cancel scope 的概念。

```rust
let scope = Scope::new();
let cancel_token = scope.cancel_scope();
scope.run(|spawner| async {
  let handle1 = spawner.spawn(myfunc());
  let handle2 = spawner.spawn(anotherfunc());
  <rest of program>...
  let result = select(handle1, handle2, delay(1000)).await;
  if let Err(Timeout) = result {
    cancel_token.cancel();
  }
}).await;
```

main task 的最后，加入一个超时判断，`select(handle1, handle2, delay(1000)).await`，如果 `handle1` 和 `handle2` 都没有在 `delay(1000)` 之后完成，那么就返回 `Timeout`，然后通过 `cancel_token.cancel()`取消scope的执行，这会导致 scope 里所有 child tasks 都收到 `Cancel` 信号，这些 child task 在下一次被调度器调度执行时，会直接退出执行。（task_scope 无法打断正在被调度器执行的 future，所以只能等到 future yield 后，下次被调度时退出，也就是说，future 中 await 的地方就是 cancel 信号的 *checkpoint*）。

## Scope in Scope

当并发逻辑变得复杂，我们就会遇到在 Scope 里面开启新 Scope 的情况。一般来讲， scope 会被封装在函数里，函数的外部调用者不知道函数里是否开启了 scope。假如说，外部调用者本身是在一个 scope 里调用这个函数，就会出现 scope in scope。这种情况下，Structured Concurrency 的特性依然保持不变。

```rust
let scope = Scope::new();
scope.run(|spawner| async {
  spawner.spawn(func_a());
  spawner.spawn(anotherfunc());
  <rest of program>...
}).await;

async fn func_a() {
    let scope = Scope::new();
    scope.run(|spawner| async {
      spawner.spawn(myfunc());
      <rest of program>...
  }).await
}
```

`func_a` 是一个封装有 scope 的函数，当它的子任务都完成时，它才会返回。外部调用 spawn 了 `func_a` 作为子任务执行，它也会等 `func_a` 完成后再结束。

timeout 和 cancellation 又如何处理的呢？当外部调用者的 scope 被 cancel 时， cancel 信号传递到每个 child task 里，child task future 检查自己是否被外部的 scope cancel 掉。

- 如果是 graceful cancel，它会给自己的子任务也发送 graceful cancel 信号，然后继续执行或者等待，直到所有子任务都退出；
- 如果是 force cancel，那它就给自己的子任务发送 force cancel ，然后直接退出。

这样，cancel 信号，就会通过 scope -> subscope -> sub-subscope 一层一层的往下传递，形成一个 cancel tree，通过 root 往下派发。

## Practice

讲完这些基本概念，最后给读者留一个比较经典的练习题去尝试下使用 Structured Concurrency 编程。

[Happy Eyeballs](https://en.wikipedia.org/wiki/Happy_Eyeballs) 算法是 njs 在[演示 trio](https://www.youtube.com/watch?v=oLkfnc_UMcE) 时使用的示例，他给出的 Python 实现可以在[这里](https://github.com/python-trio/trio/blob/master/trio/_highlevel_open_tcp_stream.py)找到。这是一个非常好的示例，强烈建议读者动手去试一试如何利用自己已有的经验去实现它（很有可能你写不出来），然后再尝试用 Strucutred Concurrency 的范式去实现。

最后，给出我用 task_scope 实现的 [Rust 版本](https://github.com/starcoinorg/task_scope/blob/master/examples/happy_eyeball.rs)。



[1]: http://250bpm.com/blog:71	"Structured Concurrency"
[2]: https://vorpus.org/blog/notes-on-structured-concurrency-or-go-statement-considered-harmful/	"note on structured concurrency"
[3]: https://medium.com/@elizarov/structured-concurrency-722d765aa952
[4]: https://github.com/Kotlin/kotlinx.coroutines	"kotlin coroutine"
[5]: https://homepages.cwi.nl/~storm/teaching/reader/Dijkstra68.pdf
[6]: https://github.com/starcoinorg/task_scope	"task_scope"

