---
title: golang语言并发与并行——goroutine和channel的详细理解（一）
mathjax: false
copyright: true
original: false
explain: 文中可能会根据需要做部分调整
date: 2018-05-08 17:14:11
categories: [精品转载,Golang]
tags: [Golang]
authorship: CSDN-思维的深度
srcpath: https://blog.csdn.net/skh2015java/article/details/60330785
---
## 前言
如果不是我对真正并行的线程的追求，就不会认识到Go有多么的迷人。
Go语言从语言层面上就支持了并发，这与其他语言大不一样，不像以前我们要用Thread库 来新建线程，还要用线程安全的队列库来共享数据。
以下是我入门的学习笔记。
<!--more-->

## Go语言的goroutines、channel和死锁
### goroutine
Go语言中有个概念叫做goroutine, 这类似我们熟知的线程，但是更轻。
`wj小编补充几句：`
*goroutine就是golang语言版的`协程`，如果不了解这个概念，建议大家先读下小编整理的这篇文章：*
*[协程到底是个啥](/articles/reprint/common/协程到底是个啥.html)*
以下的程序，我们串行地去执行两次`loop`函数:
```golang
func loop() {
    for i := 0; i < 10; i++ {
        fmt.Printf("%d ", i)
    }
}

func main() {
    loop()
    loop()
}
```
毫无疑问，输出会是这样的:
```text
0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9
```
下面我们把一个loop放在一个goroutine里跑，我们可以使用关键字`go`来定义并启动一个goroutine:
```golang
func main() {
    go loop() // 启动一个goroutine
    loop()
}
```
这次的输出变成了:
```text
0 1 2 3 4 5 6 7 8 9
```
可是为什么只输出了一趟呢？明明我们主线跑了一趟，也开了一个goroutine来跑一趟啊。
原来，在goroutine还没来得及跑loop的时候，主函数已经退出了。
main函数退出地太快了，我们要想办法阻止它过早地退出，一个办法是让main等待一下:
```golang
func main() {
    go loop()
    loop()
    time.Sleep(time.Second) // 停顿一秒
}
```
这次确实输出了两趟，目的达到了。
可是采用等待的办法并不好，如果goroutine在结束的时候，告诉下主线说“Hey, 我块要跑完了，等等我！”（`wj小编改了下，这样更好理解`）就好了， 即所谓阻塞主线的办法，回忆下我们`Python`里面等待所有线程执行完毕的写法:
```python
for thread in threads:
    thread.join()
```
是的，我们也需要一个类似`join`的东西来阻塞住主线。那就是channel(信道)

### channel
channel即信道，信道是什么？简单说，是goroutine之间互相通讯的东西。类似我们Unix上的管道（可以在进程间传递消息）， 用来goroutine之间发消息和接收消息。其实，就是在做goroutine之间的内存共享。
使用`make`来建立一个信道:
```golang
var channel chan int = make(chan int)
// 或
channel := make(chan int)
```
那如何向信道存消息和取消息呢？ 一个例子:
```golang
func main() {
    var messages chan string = make(chan string)
    go func(message string) {
        messages <- message // 存消息
    }("Ping!")

    fmt.Println(<-messages) // 取消息
}
```
默认的，信道的存消息和取消息都是阻塞的 (叫做无缓冲的信道，不过缓冲这个概念稍后了解，先说阻塞的问题)。
也就是说, 无缓冲的信道在取消息和存消息的时候都会挂起当前的goroutine，除非另一端已经准备好。
比如以下的main函数和foo函数:
```golang
var ch chan int = make(chan int)

func foo() {
    ch <- 0  // 向ch中加数据，如果没有其他goroutine来取走这个数据，那么挂起foo, 直到main函数把0这个数据拿走
}

func main() {
    go foo()
    <- ch // 从ch取数据，如果ch中还没放数据，那就挂起main线，直到foo函数中放数据为止
}
```
那既然信道可以阻塞当前的goroutine, 那么回到上一部分「goroutine」所遇到的问题「如何让goroutine告诉主线我执行完毕了」 的问题来, 使用一个信道来告诉主线即可:
```golang
var complete chan int = make(chan int)

func loop() {
    for i := 0; i < 10; i++ {
        fmt.Printf("%d ", i)
    }

    complete <- 0 // 执行完毕了，发个消息
}


func main() {
    go loop()
    <- complete // 直到线程跑完, 取到消息. main在此阻塞住
}
```
如果不用信道来阻塞主线的话，主线就会过早跑完，loop线都没有机会执行、、、

其实，无缓冲的信道永远不会存储数据，只负责数据的流通，为什么这么讲呢？
* 从无缓冲信道取数据，必须要有数据流进来才可以，否则当前线阻塞
* 数据流入无缓冲信道, 如果没有其他goroutine来拿走这个数据，那么当前线阻塞
所以，你可以测试下，无论如何，我们测试到的无缓冲信道的大小都是0 (`len(channel)`)

如果信道正有数据在流动，我们还要加入数据，或者信道干涩，我们一直向无数据流入的空信道取数据呢？ 就会引起死锁

### 死锁
一个死锁的例子:
```golang
func main() {
    ch := make(chan int)
    <- ch // 阻塞main goroutine, 信道c被锁
}
```
执行这个程序你会看到Go报这样的错误:
```golang
fatal error: all goroutines are asleep - deadlock!
```
何谓死锁? 操作系统有讲过的，所有的线程或进程都在等待资源的释放。如上的程序中, 只有一个goroutine, 所以当你向里面加数据或者存数据的话，都会锁死信道， 并且阻塞当前 goroutine, 也就是所有的goroutine(其实就main线一个)都在等待信道的开放(没人拿走数据信道是不会开放的)，也就是死锁咯。
我发现死锁是一个很有意思的话题，这里有几个死锁的例子:
1. 只在单一的goroutine里操作无缓冲信道，一定死锁。比如你只在main函数里操作信道:
```golang
func main() {
    ch := make(chan int)
    ch <- 1 // 1流入信道，堵塞当前线, 没人取走数据信道不会打开
    fmt.Println("This line code wont run") //在此行执行之前Go就会报死锁
}
```
2. 如下也是一个死锁的例子:
```golang
var ch1 chan int = make(chan int)
var ch2 chan int = make(chan int)

func say(s string) {
    fmt.Println(s)
    ch1 <- <- ch2 // ch1 等待 ch2流出的数据
}

func main() {
    go say("hello")
    <- ch1  // 堵塞主线
}
```
其中主线等ch1中的数据流出，ch1等ch2的数据流出，但是ch2等待数据流入，两个goroutine都在等，也就是死锁。
3. 其实，总结来看，为什么会死锁？非缓冲信道上如果发生了流入无流出，或者流出无流入，也就导致了死锁。或者这样理解 Go启动的所有goroutine里的非缓冲信道一定要一个线里存数据，一个线里取数据，要成对才行 。所以下面的示例一定死锁:
```golang
c, quit := make(chan int), make(chan int)

go func() {
   c <- 1  // c通道的数据没有被其他goroutine读取走，堵塞当前goroutine
   quit <- 0 // quit始终没有办法写入数据
}()

<- quit // quit 等待数据的写
```
### 



