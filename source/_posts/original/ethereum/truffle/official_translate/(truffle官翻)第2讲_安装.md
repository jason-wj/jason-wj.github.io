---
title: (truffle官翻)第2讲 安装
copyright: true
original: true
date: 2018-03-24 10:13:02
categories: [原创,以太坊,truffle,官翻]
tags: [ethereum,truffle]
---
* 这是mac版安装方式，其余linux可参考  
* 是以太坊最受欢迎的一个框架，需要nodejs支持，安装nodejs  
    * nodejs安装  
    ```bash
    brew install nodejs
    ```  
    * 使用npm安装到所有model都在这个路径路径：/usr/lib/node_modules
<!-- more -->

* 下载并安装truffle  
    ```bash
    npm install -g truffle  //其中-g参数指定将包安装到全局环境中。
    ```
* 查看truffle版本  
    ```bash
    truffle version
    ```