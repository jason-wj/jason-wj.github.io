---
title: (nodejs入门)第9讲-Session的使用
copyright: true
original: true
date: 2018-03-31 00:51:04
categories: [原创,nodejs,入门教程]
tags: [nodejs]
---
## 概述
session 是另一种记录客户状态的机制，不同的是Cookie 保存在客户端浏览器中，而session 保存在服
务器上。
### 用途
* session 运行在服务器端，当客户端第一次访问服务器时，可以将客户的登录信息保存。
* 当客户访问其他页面时，可以判断客户的登录状态，做出提示，相当于登录拦截。
* session 可以和Redis 或者数据库等结合做持久化操作，当服务器挂掉时也不会导致某些客户信息（购物车）
  丢失。

## Session 的工作流程
当浏览器访问服务器并发送第一次请求时，服务器端会创建一个session 对象，生成一个类似于
key,value 的键值对，然后将key(cookie)返回到浏览器(客户)端，浏览器下次再访问时，携带key(cookie)，
找到对应的session(value)。客户的信息都保存在session 中

## express-session 的使用
* 安装
```text
npm install express-session --save
```
* 在app.js中加入如下代码：
```js
var session = require("express-session");
app.use(session({
    secret: 'keyboard cat',
    resave: true,
    saveUninitialized: true
}))
req.session.username = "张三"; //设置值
req.session.username  //获取值
```

## express-session 的常用参数:
```js
app.use(session({
    secret: '12345',
    name: 'name',
    cookie: {maxAge: 60000},
    resave: false,
    saveUninitialized: true
}))
```
* secret：一个String 类型的字符串，作为服务器端生成session 的签名。
* name：返回客户端的key 的名称，默认为connect.sid,也可以自己设置。
* resave：强制保存session 即使它并没有变化,。默认为true。建议设置成false。don't save session if unmodified
* saveUninitialized：强制将未初始化的session 存储。当新建了一个session 且未设定属性或值时，它就处于未初始化状态。在设定一个cookie 前，这对于登陆验证，减轻服务端存储压力，权限控制是有帮助的。（默认：true）。建议手动添
* cookie：设置返回到前端key 的属性，默认值为{ path: ‘/’, httpOnly: true, secure: false, maxAge: null }。
* rolling：在每次请求时强行设置cookie，这将重置cookie 过期时间（默认：false）

## express-session 的常用方法:
```js
req.session.destroy(function(err) { 
    /*销毁session*/
})
req.session.username='张三'; //设置session
req.session.username //获取session
req.session.cookie.maxAge=0; //重新设置cookie 的过期时间
```

## 负载均衡配置Session，把Session 保存到数据库里面
* 需要安装express-session 和connect-mongo 模块
* app.js里输入如下内容：
```js
var session = require("express-session");
const MongoStore = require('connect-mongo')(session);
app.use(session({
    secret: 'keyboard cat',
    resave: false,
    saveUninitialized: true,
    rolling:true,
    cookie:{
        maxAge:100000
    },
    store: new MongoStore({
        url: 'mongodb://127.0.0.1:27017/student',
        touchAfter: 24 * 3600 // time period in seconds
    })
}))
```

## Cookie 和Session 区别
* cookie 数据存放在客户的浏览器上，session 数据放在服务器上。
* cookie 不是很安全，别人可以分析存放在本地的COOKIE 并进行COOKIE欺骗考虑到安全应当使用session。
* session 会在一定时间内保存在服务器上。当访问增多，会比较占用你服务器的性能考虑到减轻服务器性能方面，应当使用COOKIE。
* 单个cookie保存的数据不能超过4K，很多浏览器都限制一个站点最多保存20个cookie。

  


