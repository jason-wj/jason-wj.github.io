---
title: (truffle官翻)第13讲 编写外部脚本
copyright: true
original: true
categories:
  - 原创
  - 以太坊
  - truffle
  - 官翻
tags:
  - ethereum
  - truffle
abbrlink: 712f35b3
date: 2018-03-24 10:18:17
---
1. 有时候想写个外部脚本来和合约交互，Truffle已经替你想好了，你只要这么做就行
2. truffle develop环境中运行：  
    ```
    exec <path/to/file.js>
    ```
3. 文件结构
   为了使得脚本能正常运行，需要它们能通过js模块导出一个函数，并且有一个回调函数：  
     
    ```js
    module.exports = function(callback){
       //perform actions
    }
    ```  
    在脚本里，随便写，只要能运行就好。上面那个回调，当脚本结束后，会被执行