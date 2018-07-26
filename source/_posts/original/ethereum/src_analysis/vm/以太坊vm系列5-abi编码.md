---
title: 以太坊vm系列5- abi编码（暂不更新本文）
mathjax: false
copyright: true
original: true
top: false
notice: false
categories:
  - 原创
  - 以太坊
  - 源码解读
tags:
  - ethereum
  - EVM
abbrlink: 6065d2dc
date: 2018-07-23 08:57:14
---
## 前言
abi是什么？
前面我们认识到的是智能合约直接在EVM上的表示方式，但是，比如我想用java端程序去访问智能合约的某个方法，难道让java开发人员琢磨透汇编和二进制的表示，再去对接？
这明显是不可能的，为此abi产生了。这是一个通用可读的json格式的数据，任何别的客户端开发人员或者别的以太坊节点只要指定要调用的方法，通过abi将其解析为字节码并传递给evm，evm来计算处理该字节码并返回结果给前端。
这个应该解释清楚了吧？
<!--more-->
abi就起到这么一个作用，类似于传统的客户端和服务器端地址好交互规则，比如json格式的数据，然后进行交互。

`忽略后面所写内容，暂不考虑`
## 先来看个案例
我们创建一个合约：
```JavaScript
pragma solidity ^0.4.11;
contract C {
  uint256 a;
  function setA(uint256 _a) public {
    a = _a;
  }
  function getA() public returns(uint256) {
    return a;
  }
}
```
执行方法`setA(1)`，然后该方法会被解析成：`0xee919d500000000000000000000000000000000000000000000000000000000000000001`,总共36个字节，其中前4个字节取的是`setA(uint256)`经过keccak256运算生成的hash的前`4`个字节，剩下1为一个32字节的数据(uint256类型的数据，当然是32字节)
`0xee919d500000000000000000000000000000000000000000000000000000000000000001`会被传到智能合约（比如solidity或别的可以接受的程序），它会将这些输入字节解释为方法调用，并为setA(1)执行适当的汇编代码。
流程如下：
{% asset_img 1.png  方法执行的整个流程 %}

## 外部方法调用
编译好的合约是怎样处理输入源的？先来这么一个合约：
```JavaScript
pragma solidity ^0.4.11;
contract C {
  uint256 a;
  function setA(uint256 _a) public payable {
    a = _a;
  }
}
```

`本文暂停更新，待进一步搞懂后再继续更新`
