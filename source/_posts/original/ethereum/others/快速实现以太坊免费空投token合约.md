---
title: 快速实现以太坊免费空投token合约
mathjax: true
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
  - 智能合约
abbrlink: ebac0719
date: 2018-07-21 20:27:27
---
## 前言
在imtoken或者metamask中，输入一个智能合约，立马就会发收到空投币。
这样的事情，相信有不少小伙伴遇到过吧？是不是很神奇？今天小编来记录一下这歌功能是如何实现的。
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
        balances[_owner] = airdropNum * 10 ** decimals;   //空投的关键，小编只是演示。真实开发时，要自己判断业务逻辑来赋值
        return balances[_owner];
    }

    function mintByOwner(address _to, uint256 _amount) whenNotPaused onlyOwner external returns (bool) {
        return mint(_to, _amount);
    }

    function mint(address _to, uint256 _amount) internal whenNotPaused returns (bool) {
        require(currentSupply.add(_amount) <= totalSupply_);
        currentSupply = currentSupply.add(_amount);
        balances[_to] = balances[_to].add(_amount);
        emit Mint(currentSupply, _to, _amount);
        return true;
    }
}
```
ok，整个ERC20合约token就是这么简单，上面合约的大意是：通过whenNotPaused来控制整个合约是否可以使用。通过mintByOwner来让合约发布人手动分发token给其他人。
其中关于空投重要的一点方法是，重写了erc20标准方法中的`balanceOf()`,这就是空投实现的秘密，`小编只是演示`，因此,任何只要调用该方法的账户，都会收到指定数量的token，但是，显示中，要根据业务来判断，不能像小编这样鲁莽。

`ps：`是不是很意外，在view标示的balanceOf()方法中，居然可以写改变状态的内容，小编也百思不得其解， 按照Solidity规范，这是不可以的，难道这是bug？存在一年多的bug？

### 合约编译
根目录使用truffle编译:
```
truffle compile
```
编译时，`balanceOf()`方法会出现如下错误警告：
```
Function declared as view, but this expression (potentially) modifies the state and thus requires non-payable (the default) or payable.
```
请忽略，不影响生成编译后的文件。

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
正常发布成功的话，命令框里会有如下信息：
```
#xxx$ truffle migrate --network ropsten
Using network 'ropsten'.

Running migration: 1_initial_migration.js
  Deploying Migrations...
  ... 0x61a257d0552e61aa8c4f21d9f72aafdfd33c593ed05ed3bb5720e5d33e5f99e9
  Migrations: 0x64f6ad826cf24708217c5061150036c830cb85af
Saving successful migration to network...
  ... 0x925b1c389a871f3c914f69217369b3fb3eebe2233e431dcc4f61c2ca2911c73c
Saving artifacts...
Running migration: 2_deploy_contracts.js
  Deploying FreeAirToken...
  ... 0x105a310dba4fd217300c038fbce6c4a76d2c406d8d3347369a06977840bf1a99
  FreeAirToken: 0xd1cc0f89502c289b1d74c3d5d9ecf22d1b45d716
Saving successful migration to network...
  ... 0x285ce2d29e11d2a573bdff7350a189c241a686cb884fdc89f5ffaf02642680a0
Saving artifacts...
```
5. 记着合约的地址：
就是小编上面列出来的信息里的这一行：
FreeAirToken: 0xd1cc0f89502c289b1d74c3d5d9ecf22d1b45d716

ok，至此，能够纷发免费token的合约已经实现。接下来我们进入测试阶段

## 测试
本来小编想使用imtoken的钱包来测试，虽然能进入infura环境，但是输入合约地址的那个功能，imtoken本质上还是调用的公网的，并没进infura。
只好使用metamask来测了。
直接看测试结果:
{% asset_img 1.png  空投领token %}
{% asset_img 2.png  空投领token %}
ok，测试成功，至此，本文目的已完全实现。

## 总结
小编自始至终认为这个是Solidity不完善的缘故，是一个存在很久的bug，在view级别的方法中，是不应该进行状态改变的。每一次存储的调用，都会涉及到EVM里的`sstore`指令，光这一指令就有20000gas。
在这一问题被修复前，大家好好规划一下这个功能的使用吧。



