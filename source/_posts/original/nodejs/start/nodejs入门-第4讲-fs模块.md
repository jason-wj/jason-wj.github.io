---
title: nodejs入门-第4讲-fs模块
copyright: true
original: true
date: 2018-03-26 20:26:49
categories: [原创,nodejs,入门教程]
tags: [nodejs]
---
## fs.stat 检测是文件还是目录
```js
const fs = require('fs')

fs.stat('test.js', function (error, stats) {
    if (error) {
        console.log(error)
    } else {
        console.log(stats)
        console.log(`文件：${stats.isFile()}`)
        console.log(`目录：${stats.isDirectory()}`)
    }
});
```
<!-- more -->
## fs.mkdir 创建目录
```js
const fs = require('fs')
fs.mkdir('logs', function(error) {
    if (error) {
        console.log(error)
    } else {
        console.log('成功创建目录：logs')
    }
})
```

## fs.writeFile 创建写入文件
```js
const fs = require('fs')

fs.writeFile('logs/hello.log', '您好 ~ \n', function (error) {
    if (error) {
        console.log(error)
    } else {
        console.log('成功写入文件')
    }
})
```

## fs.appendFile 追加文件
```js
const fs = require('fs')

fs.appendFile('logs/hello.log', 'hello ~ \n', function (error) {
    if (error) {
        console.log(error)
    } else {
        console.log('成功写入文件')
    }
})
```

## fs.readFile 读取文件
```js
const fs = require('fs')

fs.readFile('logs/hello.log', 'utf8', function (error, data) {
    if (error) {
        console.log(error)
    } else {
        console.log(data)
    }
})
```

## fs.readdir读取目录
```js
const fs = require('fs')

fs.readdir('logs', function (error, files) {
    if (error) {
        console.log(error)
    } else {
        console.log(files)
    }
})
```

## fs.rename 重命名
```js
const fs = require('fs')

fs.rename('logs/hello.log', 'logs/greeting.log', function (error) {
    if (error) {
        console.log(error)
    } else {
        console.log('重命名成功')
    }
})
```

## fs.rmdir 删除目录
```js
const fs = require('fs')

fs.rmdir('logs', function (error) {
    if (error) {
        console.log(error)
    } else {
        console.log('成功的删除了目录：logs')
    }
})
```

## fs.unlink删除文件
```js
const fs = require('fs')

fs.unlink(`logs/greeting.log`, function (error) {
    if (error) {
        console.log(error)
    } else {
        console.log(`成功的删除了文件`)
    }
})
```

## fs.createReadStream 从文件流中读取数据
```js
const fs = require('fs')

var fileReadStream = fs.createReadStream('data.json')
let count = 0;
var str = '';
fileReadStream.on('data', function (chunk) {
    console.log(`${ ++count } 接收到：${chunk.length}`);
    str += chunk
})
fileReadStream.on('end', function () {
    console.log('--- 结束 ---');
    console.log(count);
    console.log(str);
})
fileReadStream.on('error', function (error) {
    console.log(error)
})
```

## fs.createWriteStream 写入文件
```js
var fs = require("fs");

var data = '我是从数据库获取的数据，我要保存起来'; // 创建一个可以写入的流，写入到文件 output.txt 中 
var writerStream = fs.createWriteStream('output.txt'); // 使用 utf8 编码写入数据
writerStream.write(data, 'UTF8'); // 标记文件末尾
writerStream.end(); // 处理流事件 --> finish 事件
writerStream.on('finish', function () { /*finish - 所有数据已被写入到底层系统时触发。*/
    console.log("写入完成。");
});
writerStream.on('error', function (err) {
    console.log(err.stack);
});
console.log("程序执行完毕");
```
## 管道流
管道提供了一个输出流到输入流的机制。通常我们用于从一个流中获取数据并将数据传递到另外一个流中。
```js
var fs = require("fs");

// 创建一个可读流
var readerStream = fs.createReadStream('input.txt');
// 创建一个可写流
var writerStream = fs.createWriteStream('output.txt');
// 管道读写操作
// 读取 input.txt 文件内容，并将内容写入到 output.txt 文件中
readerStream.pipe(writerStream);
console.log("程序执行完毕");
```