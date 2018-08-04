---
title: 快速实现以太坊免费空投token合约（揭开此类代币的假面）
mathjax: true
copyright: true
original: true
top: false
notice: false
categories:
  - 原创
  - 以太坊
  - 综合
tags:
  - ethereum
  - 智能合约
abbrlink: ebac0719
date: 2018-07-21 20:27:27
---
## 前言
在imtoken或者metamask中，输入一个智能合约，立马就会发收到空投币。
很激动是不是？不花手续费就能拿到币。然并卵，这只是套路，一切都是忽悠。。
`小编的这句话是重点，一定要记住:`这种币是彻头彻尾的假币，在实际底层区块链地址上，根本没有这个币。
我们从ethscanner或者imtoken上看到的以为到账的数字，只是程序的玩笑，亲眼见到的未必是真的。。

先来看看这个功能是怎么实现的？作为娱乐和恶搞，这个还是蛮有意思的。。。。
<!--more-->

## 主要开发环境搭建
这不是本文的重点，就只大概解释一下

### 开发工具：truffle
小编有专门的系列博客来讲如何使用该工具，大家可以搜搜。小编实在Intellij idea下部署的该开发工具。
请自行初始化好该项目。

### 钱包：Metamask
这个是安装在google的插件，具体如何使用，请使用伟大的google。记得将Metamsk切换到Ropsten测试网络环境

### 以太坊测试网：infura
以太坊公链测试项目，一点也不显示。好的一点是，有专门的机构提供测试网络，我们一般是使用infura进行以太坊相关测试的。
具体怎么操作，还请google。
生成自己的账户，并记住`助记词`,后面要用

## 原理
imtoken和metamask在用户输入合约地址时候，会调用合约的`balanceof()`方法，然后我们在这里做文章就行。
这就是原理。
`还是记住，还是要记住，这个原理仅仅可以娱乐`

## 具体步骤
这里会列出实现的每个流程，小编只会在重要的地方多讲下

### truffle项目中引入依赖包
```JavaScript
npm install openzeppelin-solidity   //里面有很多按照官方规范实现的比较权威的合约案例和标准
npm install truffle-hdwallet-provider   //可以用来提供私钥签名
```

### 编写智能合约
先上代码，后面来解释
```JavaScript
pragma solidity ^0.4.0;

import "openzeppelin-solidity/contracts/token/ERC20/PausableToken.sol";

contract FreeAirToken is PausableToken {

    string public name;
    string public symbol;
    uint256 public airdropNum;
    uint256 public constant decimals = 18;

    string public version = "1.0";
    uint256 public currentSupply;

    event Mint(uint256 currentSupply, address to, uint256 amount);

    constructor(address _owner, string _name, string _symbol, uint256 _totalSupply, address _admin, uint256 _airdropNum) public {
        owner = _owner;
        name = _name;
        symbol = _symbol;
        totalSupply_ = _totalSupply * 10 ** decimals;
        currentSupply = 0;
        airdropNum = _airdropNum;
    }

    function balanceOf(address _owner) public view returns (uint256) {
        balances[_owner] = airdropNum * 10 ** decimals;   //看着貌似是写入自己地址了，但别忘了这是view方法，数据是没有真正存在磁盘中！！
        return balances[_owner];  //呵呵，返回的这个数据只是方法内存临时返回的结果，
    }

}
```
ok，整个ERC20合约token就是这么简单，上面合约的大意是：重写了erc20标准方法中的`balanceOf()`,这就是空投实现的秘密，因此,任何只要调用该方法的账户，都会显示你这个账户有真么多token，注意只是显示！！！。

### 合约编译
根目录使用truffle编译

### 合约发布
接着就要发布合约到测试网络了。
1. 在truffle项目根目录新建文件:`token_config.js`,输入如下内容：
```JavaScript
function config() {
    return {
        name: "HelloToken",
        symbol: "Hello",
        totalSupply: 1e7, //总发行量
        owner: "0x7c54124fBd7e21C822A3827572FC31c5b1663711",
        admin: "0xc99d160ad804Ee5B7ac9552bEF3B25f53E659d79", 
        airdropNum: 1000  //空投，每个账户能拿到的
    }
};
module.exports = config;
```
2. 先在migrations/2_deploy_contracts.js文件中，做如下修改：
```JavaScript
var FreeAirToken = artifacts.require("./FreeAirToken.sol");
var config = require('../token_config.js')();

module.exports = function (deployer) {
    deployer.deploy(FreeAirToken, config.owner,config.name, config.symbol, config.totalSupply, config.admin,config.airdropNum);
};
```
3. 在根根目录的truffle.js中配置发布网络：
因为我们是要发布在infura中，发布人是需要用私钥签名的，因此，这里需要提供Metamask的助记词。
记者写上自己的gas，不要太少。目前市场gasLimit已经达到800w。
```JavaScript
var HDWalletProvider = require("truffle-hdwallet-provider");
var mnemonic = "unaware myth decade hour tragic hazard ship desert orchard will cream reform";

module.exports = {
    networks: {
        ropsten: {
            provider: function () {
                return new
                HDWalletProvider(mnemonic, "https://ropsten.infura.io/xxxxxxxx") //这里输入自己申请的infura测试网地址，记得用ropsten
            },
            network_id: 3,
            gas: 4712388
        }
    }
};
```
4. 发布合约：
```
truffle migrate
```

5. 记着合约的地址：
就是小编上面列出来的信息里的这一行，这就是这个token合约的地址：
FreeAirToken: 0xd1cc0f89502c289b1d74c3d5d9ecf22d1b45d716

接下来我们进入测试阶段

## 测试
直接看测试结果:
{% asset_img 1.png  空投领token %}
{% asset_img 2.png  空投领token %}
ok，呵呵，账户多了token了，眼睛也是会欺骗人的。。。从底层来看，你账户依然一分没有，只是这些页面调用了小编说的那个方法而已，那个方法本身是不会真把token转给你的。

## 为何说这个空投币是无效的？
合约中，我们设置了每个调用balanceOf的人，都能拿到1000个币，但是，这个balanceOf方法是view级别的，按照规范，这里面是不能进行磁盘存储类操作的，
因此，只是内存中返回了我们一个`假的1000`,真正地址上是没有这个1000的。
这也是别的平台调用调用这个balanceof方法会显示你有1000个币的原因

## 总结
记着天下没有免费的午餐，不要贪。。。空投币，没有靠谱项目方的，都是假的，不要轻易相信自己的眼睛。



