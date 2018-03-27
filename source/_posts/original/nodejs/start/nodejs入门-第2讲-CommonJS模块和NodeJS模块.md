---
title: (nodejs入门)第2讲-CommonJS规范和NodeJS模块
copyright: true
original: true
explain: 文中可能会根据需要做部分调整
date: 2018-03-26 18:42:59
categories: [原创,nodejs,入门教程]
tags: [nodejs]
---
## CommonJS规范
CommonJS规范的提出,主要是为了弥补当前JavaScript没有标准的缺陷。它的终极目标就是：提供一个类似Python，Ruby和Java语言的标准库,而不只是停留在小脚本程序的阶段。用CommonJS API编写出的应用，不仅可以利用 JavaScript开发客户端应用，而且还可以编写以下应：
* 服务器端JavaScript应用程序。
* 命令行工具。
* 桌面图形界面应用程序。

CommonJS就是模块化的标准，nodejs就是CommonJS（模块化）的实现。
<!-- more -->

## NodeJS中的模块化
### 可分为两类模块：
* 核心模块--`Node本身提供`
该部分模块在Node源代码的编译过程中，编译进了二进制执行文件。在Node进程启动时，部分核心模块就被直接加载进内存中，所以这部分核心模块引入时，文件定位和编译执行这两个步骤可以省略掉，并且在路径分析中优先判断，所以它的加载速度是最快的。如：HTTP模块 、URL模块、Fs模块都是nodejs内置的核心模块，可以直接引入使用。
* 文件模块--`用户提供`
该部分模块是在运行时动态加载，需要完整的路径分析、文件定位、编译执行过程、速度相比核心模块稍微慢一些，但是用的非常多。这些模块需要我们自己定义。

### 自定义模块的规定
1. 我们可以把公共的功能抽离成为一个单独的 js 文件作为一个模块，默认情况下面这个模块里面的方法或者属性，外面是没法访问的。如果要让外部可以访问模块里面的方法或者属性，就必须在模块里面通过 `exports` 或者`module.exports`暴露属性或者方法。 
2. 在需要使用这些模块的文件中，通过`require`的方式引入这个模块。这个时候就可以使用模块里面暴露的属性和方法。
3. 实例：
```js
// 定义一个tools.js的模块 
// 模块定义
var tools = { 
    sayHello: function() {
        return 'hello NodeJS';
        },
    add: function(x, y) { 
        return x + y; 
    } 
}; 
// 模块接口的暴露 
module.exports = tools; 
exports.sayHello = tools.sayHello; 
exports.add = tools.add;
```
    ```js
    var http = require('http'); // 引入自定义的tools.js模块 
    var tools= require('./tools');  //使用./tools.js或者./tools均可
    tools.sayHello(); //使用模块
    ```
4. 当在主目录中找不到需要的模块，就会去node_modules中找
## npm使用
```js
npm init  //生成json文件
```
npm安装的模块可以直接被require引用（依赖package.json），不需要路径
