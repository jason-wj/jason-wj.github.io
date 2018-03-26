---
title: (nodejs入门)第1讲 开启并分析第一个应用
copyright: true
original: true
explain: 文中可能会根据需要做部分调整
date: 2018-03-25 23:27:48
categories: [原创,nodejs,入门教程]
tags: [nodejs,区块链]
---
## 创建第一个应用
NodeJS本身就实现了一个http服务器，不需要额外再部署类似tomcat等服务器。这个概念需要先明白。
### 步骤
1. 创建一个目录，用于存放项目
    ```
    mkdir testProject
    ```
2. 新建一个test.js文件，编译如下：
    ```js
    var http = require('http');  //引入http模块
    http.createServer(function (request, response) {
       // 发送 HTTP 头部
       // HTTP 状态值: 200 : OK
       //设置HTTP 头部，状态码是200，文件类型是html，字符集是utf8
       responerse.writeHead(200,{"Content-Type":"text/html;charset=UTF-8"});
       // 发送响应数据 "Hello BlockChain"
       response.end("Hello BlockChain!"); //结束响应，否则浏览器一直在请求
    }).listen(8888);
    // 终端打印如下信息
    console.log('此处后台打印，服务器正在8080端口监听');    
    ```
<!-- more --> 
3. 在当前目录下运行：
    ```
    node test.js
    ```
4. 在浏览器输入如下地址,即可在画面中显示返回结果：
   ```
   127.0.0.1:8080
   ```
5. 总结，node本身就是一个js运行环境

## HTTP模块、URL模块
Node.js中，将不同的功能划分成了不同的modele。
### HTTP模块
在上一节的案例中，已经使用到了HTTP模块，server的回调中，有两个参数，一个是request，一个是response.我们可以通过它们发出请求，再获取请求结果，HTTP的协议基础，在此就不解释了。
使用`request.url`可以获取到所请求的`url`，关于url的识别，可以参考下一个`url`模块。

### URL模块
1. 进入node环境：
```js
node
```
    或者：
    ```js
    var url= require("url")
    ```
2. 解析url，生成一个具体结构：
```js
url.parse("http://www.wjblog.com")
// url.parse("http://www.wjblog.com",true),第二个参数，若设为true，可将query值变为对象形式
```
    返回结果：
    ```js
    Url {
      protocol: 'http:',
      slashes: true,
      auth: null,
      host: 'www.wjblog.com',
      port: null,
      hostname: 'www.wjblog.com',
      hash: null,
      search: null,
      query: null,
      pathname: '/',
      path: '/',
      href: 'http://www.wjblog.com/' }
    ```
3. 将结构转成url
```js
url.format({
protocol: 'http:',
slashes: true,
auth: null,
host: 'www.wjblog.com',
port: null,
hostname: 'www.wjblog.com',
hash: null,
search: null,
query: {},
pathname: '/',
path: '/',
href: 'http://www.wjblog.com/' });
```
    返回结果：
    http://www.wjblog.com/
4. 添加或者替换标签
```js
url.resolve('http://www.wjblog.top/tags/','Hexo'); //此为添加
url.resolve('http://www.wjblog.top/Hexo','about'); //此为替换
```
    返回结果：
    ```js
    http://www.wjblog.top/tags/Hexo
    http://www.wjblog.top/about
    ```

## 自启动工具supervisor
`注意`：**新版的nodejs已经默认支持热部署，以下功能为第三方模块提供的，仅供参考**
`supervisor`会不停的`watch`应用下面的所有文件，发现有文件被修改，就重新载入程序文件这样就实现了部署，修
改了程序文件后马上就能看到变更后的结果。
1. 安装`supervisor`，根目录输入如下：
```text
npm install -g supervisor  // -g全局安装
```
2. 使用使用`supervisor`启动应用
```js
supervisor test.js
```
    显示结果
    ```text
    Running node-supervisor with
      program 'test.js'
      --watch '.'
      --extensions 'node,js'
      --exec 'node'
    
    Starting child process with 'node test.js'
    Watching directory '/Users/wj/Documents/wj_project/nodejs/testProject/' for changes.
    Press rs for restarting the process.

    ```

