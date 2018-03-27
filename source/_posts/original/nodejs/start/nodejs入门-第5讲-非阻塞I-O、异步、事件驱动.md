---
title: (nodejs入门)第5讲-非阻塞I/O、异步、事件驱动
copyright: true
original: true
date: 2018-03-26 21:37:43
categories: [原创,nodejs,入门教程]
tags: [nodejs]
---
## 单线程 非阻塞I/O事件驱动
在Java、PHP或者.net等服务器端语言中，会为每一个客户端连接创建一个新的线程。而每个线程需要耗费大约2MB内存。也就是说，理论上，一个8GB内存的服务器可以同时连接的最大用户数为4000个左右。要让Web应用程序支持更多的用户，就需要增加服务器的数量，而Web应用程序的硬件成本当然就上升了。
Node.js不为每个客户连接创建一个新的线程，而仅仅使用一个线程。当有用户连接了，就触发一个内部事件，通过非阻塞I/O、事件驱动机制，让Node.js程序宏观上也是并行的。使用Node.js，一个8GB内存的服务器，可以同时处理超过4万用户的连接。
<!-- more -->
需要明白非阻塞的概念：
```js
console.log('1');
fs.readFile('mime.json',function(err,data){
    console.log(data);
    console.log('2');
})
console.log('3');
```
```text
结果为：
1
3
2
```
不会专门等2结束才执行3
## 回调处理异步
```js
function getData(callback) { //模拟请求数据
    var result = '';
    setTimeout(function () {
        result = '这是请求到的数据';
        callback(result);
    }, 200);
}
//非阻塞式的nodejs，需要通过如此回调才能按照期待获取结果
getData(function (data) {
    console.log(data);
})
```

## events模块处理异步
Node.js 有多个内置的事件，我们可以通过引入 events 模块，并通过实例化 EventEmitter 类来绑定和监听事件。
```js
// 引入 events 模块
var events = require('events');
var EventEmitter = new events.EventEmitter();
/*实例化事件对象*/
EventEmitter.on('toparent', function () {
    console.log('接收到了广播事件');
})
setTimeout(function () {
    console.log('广播');
    EventEmitter.emit('toparent');
    /*定时发送广播*/
}, 1000)
```