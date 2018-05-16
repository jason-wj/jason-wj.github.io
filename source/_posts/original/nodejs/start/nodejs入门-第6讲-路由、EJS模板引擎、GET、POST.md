---
title: (nodejs入门)第6讲-路由、EJS模板引擎、GET、POST
copyright: true
original: true
explain: 文中可能会根据需要做部分调整
categories:
  - 原创
  - nodejs
  - 入门教程
tags:
  - nodejs
abbrlink: 6f0adc44
date: 2018-03-26 22:43:49
---
## 路由
1. 官方解释： 路由（Routing）是由一个 URI（或者叫路径）和一个特定的 HTTP 方法（GET、POST 等）组成的，涉及到应用如何响应客户端对某个网站节点的访问。 
2. 非官方解释： 路由指的就是针对不同请求的URL，处理不同的业务逻辑
<!-- more -->
{% asset_img 1.png  路由%}

## EJS模板引擎
EJS是后台模板，可以把我们数据库和文件读取的数据显示到Html页面上面。
### 安装
```text
npm install ejs –save
```
### Nodejs中使用
```js
ejs.renderFile(filename, data, options, function(err, str){
    // str => Rendered HTML string
});
```
### EJS常用标签
* <% %>流程控制标签 
* <%= %>输出标签（原文输出HTML标签） 
* <%- %>输出标签（HTML会被浏览器解析）
```html
<a href="<%= url %>"><img src="<%= imageURL %>" alt=""></a>
```
    ```html
    <ul> 
        <% for(var i = 0 ; i < news.length ; i++){ %> 
            <li><%= news[i] %></li>
        <% } %>
    </ul>
    ```

## Get、Post
超文本传输协议（HTTP）的设计目的是保证客户端机器与服务器之间的通信。
在客户端和服务器之间进行请求-响应时，两种最常被用到的方法是：GET 和 POST。
* GET - 从指定的资源请求数据。（一般用于获取数据）
```js
var urlinfo=url.parse(req.url,true); 
urlinfo.query();
```
* POST - 向指定的资源提交要被处理的数据。（一般用于提交数据）
```js
var postData = ''; // 数据块接收中
req.on('data', function (postDataChunk) {
    postData += postDataChunk;
}); // 数据接收完毕，执行回调函数
req.on('end', function () {
    try {
        postData = JSON.parse(postData);
    } catch (e) {
    }
    req.query = postData;
    console.log(querystring.parse(postData));
});
```

