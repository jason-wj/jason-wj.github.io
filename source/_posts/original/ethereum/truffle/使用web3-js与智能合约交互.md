---
title: 使用web3.js与智能合约交互
copyright: true
original: true
explain: 文中可能会根据需要做部分调整
date: 2018-03-26 14:40:58
categories: [原创,以太坊,truffle]
tags: [truffle,contracts]
---
使用truffle编译并发布智能合约到以太坊私有网络后，接下来，就该开放接口给前端使用了。这时会面临个问题，怎样和以太坊的智能合约进行交互？
大体两种方式：
1. 直接使用原生的web3.js与智能合约操作，小编尝试了以下，操作起来很麻烦，总之很别扭。
2. 使用`truffle-contract`模块来操作智能合约，它将原生的web3.js进行了一些必要的封装，简化了操作方式，用着很顺手，基本类似于写truffle测试用例时候的语法格式。但是[官方](https://github.com/trufflesuite/truffle-contract)有些地方的使用方法讲的很模糊，小编在此进一步翻译一下。
<!-- more -->

## truffle-contract的使用 (`需要有nodejs基础`)
 
1. truffle编译智能合约，发布到以太坊私有网络。生成的json文件放在接口项目的某文件夹下：
`备注：`编译发布智能合约可以参考此处：http://www.wjblog.top/categories/%E5%8E%9F%E5%88%9B/%E4%BB%A5%E5%A4%AA%E5%9D%8A/truffle/%E5%AE%98%E7%BF%BB/
```
小编在此处放的：
testProject/assert/contract/token/CrowdsaleFCToken
```
2. 项目根目录安装web3.js以及truffle-contract:
```
npm install web3.js
npm install truffle-contract
```
3. 核心代码，头部声明：
小编用的nodejs的express框架，主要看方法内部就可以，别的地方不用深究
```js
var Web3 = require('web3');  //导入web3模块
var contract = require('truffle-contract');  //导入truffle-contract模块
var crowdsaleToken = require('../assert/contract/token/CrowdsaleFCToken') //导入（json文件）指定的已经发布到以太坊私有网络中的合约，该合约应该位于第1步提到的地方。
var web3 = new Web3();  //实例化web3
var token = contract(crowdsaleToken);  //实例化合约，contract方法可以将json解析，并将最终合约文件信息返回
web3.setProvider(new web3.providers.HttpProvider());  //设置网络
token.setProvider(web3.currentProvider);
```
4. 核心代码，具体合约中的方法以及变量的调用：
```js
router.get('/send', function(req, res, next) {
    try {
        token.deployed().then(function (instance) {
            //调用智能合约方法
            instance.getTokenExchangeAmount(6000000000000000,100,18,8).then(function (result) {
                res.send(result);
            });
            
            //调用智能合约方法
            instance.balanceOf(web3.eth.coinbase).then(function (result) {
                res.send(result);
            });
            
            //调用合约中的全局变量或常量
            instance.saleAmount.call().then(function (result) {
               res.send(result);
            });
        });
    }catch (err){
        console.log(err);
    }
});
```
    代码中，`deployed()`标示使用以太坊默认账户操作，也就是`coinbase`账户，也可以使用`at(账户地址)`来指定别的账户。
5. 整体的使用方式就是上面提到的那些了，这么一展示，之后看[官方](https://github.com/trufflesuite/truffle-contract)的文档就很容易了