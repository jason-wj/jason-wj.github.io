---
title: (nodejs入门)第8讲-Cookie的使用
copyright: true
original: true
date: 2018-03-31 00:26:16
categories: [原创,nodejs,入门教程]
tags: [nodejs]
---
## cookie概述
* cookie 是存储于访问者的计算机中的变量。可以让我们用同一个浏览器访问同一个域名的时候共享数据。
* HTTP是无状态协议。简单地说，当你浏览了一个页面，然后转到同一个网站的另一个页面，服务器无法认识到这是同一个浏览器在访问同一个网站。每一次的访问，都是没有任何关系的。
* Cookie是一个简单到爆的想法：当访问一个页面的时候，服务器在下行HTTP报文中，命令浏览器存储一个字符串; 浏览器再访问同一个域的时候，将把这个字符串携带到上行HTTP请求中。第一次访问一个服务器，不可能携带cookie。 必须是服务器得到这次请求，在下行响应报头中，携带cookie信息，此后每一次浏览器往这个服务器发出的请求，都会携带这个cookie。
<!-- more -->

## cookie特点
* cookie保存在浏览器本地
* 正常设置的cookie是不加密的，用户可以自由看到;
* 用户可以删除cookie，或者禁用它
* cookie可以被篡改
* cookie可以用于攻击
* cookie存储量很小。未来实际上要被localStorage替代，但是后者IE9兼容。

## cookie的使用
* 安装
```text
npm instlal cookie-parser --save
```
* app.js中加入如下内容：
```js
var cookieParser = require('cookie-parser'); //引入
app.use(cookieParser());
res.cookie("name",'wj',{maxAge: 10000, httpOnly: true});
req.cookies.name
```
* cookie属性说明
```text
domain: 域名
name=value：键值对，可以设置要保存的 Key/Value，注意这里的 name 不能和其他属性项的名字一样
Expires： 过期时间（秒），在设置的某个时间点后该 Cookie 就会失效，如 expires=Wednesday, 09-Nov-99 23:12:40 GMT
maxAge： 最大失效时间（毫秒），设置在多少后失效
secure： 当 secure 值为 true 时，cookie 在 HTTP 中是无效，在 HTTPS 中才有效
Path： 表示 cookie 影响到的路，如 path=/。如果路径不能匹配时，浏览器则不发送这个Cookie
httpOnly：是微软对COOKIE做的扩展。如果在COOKIE中设置了“httpOnly”属性，则通过程序（JS脚本、applet等）将无法读取到COOKIE信息，防止XSS攻击产生
singed：表示是否签名cookie, 设为true 会对这个cookie 签名，这样就需要用res.signedCookies而不是res.cookies访问它。被篡改的签名cookie 会被服务器拒绝，并且cookie 值会重置为它的原始值.设为true，标示只有在nodejs服务端可以操作cookie
```
* 设置cookie
```js
res.cookie('rememberme', '1', { maxAge: 900000, httpOnly: true }) 
res.cookie('name', 'tobi', { domain: '.example.com', path: '/admin', secure: true }); 
res.cookie('rememberme', '1', { expires: new Date(Date.now() + 900000), httpOnly: true });
```
* 获取cookie
```js
req.cookies.name
```
* 删除cookie
```js
res.cookie('rememberme', '', { expires: new Date(0)}); 
res.cookie('username','zhangsan',{domain:'.ccc.com',maxAge:0,httpOnly:true});
```
## 加密cookie
* 配置中间件的时候需要传参
```js
var cookieParser = require('cookie-parser');
app.use(cookieParser('123456'));
```
* 设置cookie的时候配置signed属性
```js
res.cookie('userinfo','hahaha',{domain:'.ccc.com',maxAge:900000,httpOnly:true,signed:true});
```
* signedCookies调用设置的cookie
```js
console.log(req.signedCookies);
```