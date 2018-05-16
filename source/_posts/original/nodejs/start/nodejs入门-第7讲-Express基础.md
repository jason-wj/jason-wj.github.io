---
title: (nodejs入门)第7讲-Express基础
copyright: true
original: true
categories:
  - 原创
  - nodejs
  - 入门教程
tags:
  - nodejs
abbrlink: 7b750cf6
date: 2018-03-27 09:33:03
---
## 概述
Express 是一个基于Node.js 平台，快速、开放、极简的 web 开发框架 Express框架是后台的Node框架，所以和jQuery、zepto、yui、bootstrap都不一个东西。 Express在后台的受欢迎的程度类似前端的jQuery，就是企业的事实上的标准。 
Express特点：
1. Express 是一个基于 Node.js 平台的极简、灵活的 web 应用开发框架，它提供一系列强大的特性，帮助你创建各种 Web 和移动设备应用。
2. 丰富的 HTTP 快捷方法和任意排列组合的 Connect 中间件，让你创建健壮、友好
的 API 变得既快速又简单
3. Express 不对 Node.js 已有的特性进行二次抽象，我们只是在它之上扩展了 Web 应用所需的基本功能。
<!-- more -->

## 安装及使用
### 安装
小编使用了intelliJ idea开发工具，直接新建的默认项目就是Express的，目录划分，基本配置已经规划好，这个安装过程不复杂，不熟悉的可以去网上别的地方找找看。

## 使用（demo）
* 新建项目：
```text
mkdir test
cd test
npm init --yes
npm install express  --save
vim app.js
```
* app.js中输入如下内容并保存：
```js
var express = require('express');
/*引入express*/
var app = new express();
/*实例化express 赋值给app*/
//配置路由 匹配URl地址实现不同的功能
app.get('/', function (req, res) {
    res.send('首页');
})
app.get('/search', function (req, res) {
    res.send('搜索');
    //?keyword=华为手机&enc=utf-8&suggest=1.his.0.0&wq
})
app.get('/login', function (req, res) {
    res.send('登录');
})
app.get('/register', function (req, res) {
    res.send('注册');
})
app.listen(3000, "127.0.0.1");
```
* 运行服务器，启动项目
```text
node app.js
```
## Express中的路由
路由（Routing）是由一个 URI（或者叫路径）和一个特定的 HTTP 方法（GET、POST 等）组成的，涉及到应用如何响应客户端对某个网站节点的访问

### 简单的路由配置
* 当用get请求访问一个网址的时候，做什么事情：
    ```js
    app.get("网址",function(req,res){ });
    ```
* 当用post访问一个网址的时候，做什么事情：
    ```js
    app.post("网址",function(req,res){ });
    ```
* user 节点接受 PUT 请求
    ```js
    app.put('/user', function (req, res) {
        res.send('Got a PUT request at /user');
    });
    ```
* user 节点接受 DELETE 请求
    ```js
    app.delete('/user', function (req, res) {
        res.send('Got a DELETE request at /user');
    });
    ```
### 动态路由配置：
```js
app.get("/user/:id", function (req, res) {
    var id = req.params["id"];
    res.send(id);
});
```

### 路由的正则匹配：
```js
app.get('/ab*cd', function (req, res) {
    res.send('ab*cd');
});
```

### 路由里面获取Get传值
```js
app.get('/news', function (req, res) {
    console.log(req.query);
});
```

## EJS的安装和使用
### 安装
```text
npm install ejs --save 
或者:
npm install ejs --save-dev
```
### 使用
1. 编写js代码
```js
var express = require("express");
var app = express();
app.set("view engine", "ejs");
app.get("/", function (req, res) {
    res.render("news", {"news": ["我是小新闻啊", "我也是啊", "哈哈哈哈"]});
});
app.listen(3000);
```
2. 指定模板位置 ，默认模板位置在views
```html
app.set('views', __dirname + '/views');
```
3. Ejs引入模板
```html
<%- include header.ejs %>
```
4. Ejs绑定数据
```html
<%=h%>
```
5. Ejs绑定html数据
```html
<%-h%>
```
6. Ejs模板判断语句
```html
<% if(true){ %> 
    <div>true</div> 
<%} else{ %> 
    <div>false</div> 
<%} %>
```
7. Ejs模板中循环数据
```html
<%for(var i=0;i<list.length;i++) 
    { %> <li><%=list[i] %></li> 
<%}%>
```
8. Ejs后缀修改为Html
```text
这是一个小技巧，看着.ejs的后缀总觉得不爽，使用如下方法，可以将模板文件的后缀换成我们习惯的.html。 
1.在app.js的头上定义ejs:,代码如下: 
var ejs = require('ejs');
2.注册html模板引擎代码如下： 
app.engine('html',ejs.__express); 
3.将模板引擎换成html代码如下: 
app.set('view engine', 'html'); 
4.修改模板文件的后缀为.html。
```

##  利用 Express. static 托管静态文件
1. 如果你的静态资源存放在多个目录下面，你可以多次调用 `express.static` 中间件：
    ```js
    app.use(express.static('public'));
    ```
    现在，public 目录下面的文件就可以访问了。
    ```text
    http://localhost:3000/images/kitten.jpg 
    http://localhost:3000/css/style.css 
    http://localhost:3000/js/app.js 
    http://localhost:3000/images/bg.png 
    http://localhost:3000/hello.html
    ```
2. 如果你希望所有通过 express.static 访问的文件都存放在一个“虚拟（virtual）”目录（即目录根本不存在）下面，可以通过为静态资源目录指定一个挂载路径的方式来实现，如下所示：
    ```js
    app.use('/static', express.static('public'));
    ```
    现在，你就可以通过带有 “/static” 前缀的地址来访问 public 目录下面的文件了。
    ```text
    http://localhost:3000/static/images/kitten.jpg 
    http://localhost:3000/static/css/style.css 
    http://localhost:3000/static/js/app.js 
    http://localhost:3000/static/images/bg.png 
    http://localhost:3000/static/hello.html
    ```

## Express 中间件
Express 是一个自身功能极简，完全是由路由和中间件构成一个的 web 开发框架：从本质上来说，`一个 Express 应用就是在调用各种中间件`。 
`中间件（Middleware）` 是一个函数，它可以访问请求对象（request object (req)）, 响应对象（response object (res)）。和 web 应用中处理请求-响应循环流程中的中间件，一般被命名为 `next` 的变量。
`中间件的功能包括`： 
* 执行任何代码。 
* 修改请求和响应对象。 
* 终结请求-响应循环。 
* 调用堆栈中的下一个中间件
通俗的说，中间件就是`匹配路由之前和匹配路由之后做的一系列操作`

如果我的get、post回调函数中，没有next参数，那么就匹配上第一个路由，就不会往下匹配了。如果想往下匹配的话，那么需要写next()

Express 应用可使用如下几种中间件：
* 应用级中间件
* 路由级中间件 
* 错误处理中间件 
* 内置中间件 
* 第三方中间件

下面详细介绍这几种中间件

### 应用级中间件
```js
app.use(function (req, res, next) {
    /*匹配任何路由*/
    //res.send('中间件');
    console.log(new Date());
    next(); /*表示匹配完成这个中间件以后程序继续向下执行*/
})
app.get('/', function (req, res) {
    res.send('根');
})
app.get('/index', function (req, res) {
    res.send('首页');
})
```
用use匹配一个方法，等打印完log后，被匹配到等方法再开始执行。`权限判断用的比较多`

### 路由中间件
```js
app.get("/news", function (req, res, next) {
    console.log("1");
    next();
});
app.get("/news", function (req, res) {
    console.log("2");
});
```
路由地址相同，在处理该路由前，先进行一系列操作，然后next()向下执行，开始执行。

### 错误处理中间件
```js
app.get('/index', function (req, res) {
    res.send('首页');
})
/*中间件相应404*/
app.use(function (req, res) {  //use没有指定路由，匹配所有路由，只要路由状态为404，就跳转页面
    //res.render('404',{});
    res.status(404).render('404', {});
})
```

### 内置中间件
```js
//静态服务 index.html
app.use('/static', express.static("./static"));
/*匹配所有的路径*/
app.use('/news', express.static("./static"));
```

### 第三方中间件
`新版express中，body-parser已经被集成其中，可直接express.json`，不需要额外通过`npm install body-parser`安装。
```text
body-parser中间件 第三方的 获取post提交的数据 
1.cnpm install body-parser --save 
2.var bodyParser = require('body-parser')  
3.设置中间件 
//处理form表单的中间件
// parse application/x-www-form-urlencoded 
app.use(bodyParser.urlencoded({ extended: false })); 获取form表单提交的数据 
// parse application/json 
app.use(bodyParser.json()); 提交的json数据的数据 
4.req.body 获取数据
```

## 获取Get Post请求的参数
* GET请求的参数在URL中，在原生Node中，需要使用url模块来识别参数字符串。在Express中，不需要使用url模块了。可以直接使用`req.query`对象。
* POST请求在express中不能直接获得，可以使用`body-parser`模块。使用后，将可以用req.body得到参数。但是如果表单中含有文件上传，那么还是需要使用`formidable`模块。
1. 安装
```js
npm install body-parser
```
2. 使用`req.body`获取post过来的参数
```js
var express = require('express')
var bodyParser = require('body-parser')  
var app = express()
// parse application/x-www-form-urlencoded
app.use(bodyParser.urlencoded({extended: false}))
// parse application/json
app.use(bodyParser.json())
app.use(function (req, res) {
    res.setHeader('Content-Type', 'text/plain')
    res.write('you posted:\n')
    res.end(JSON.stringify(req.body, null, 2))
})
```
