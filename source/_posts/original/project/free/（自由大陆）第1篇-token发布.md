---
title: （Free项目）第1篇-token发布
mathjax: false
copyright: true
original: true
date: 2018-05-12 16:42:15
categories: [原创,项目,FREE]
tags: [free]
---
## 前言
小编token大概写了一些，要问具体是怎么规划的，token将来是如何运转如何奖惩，这个小编也没想好。
ERC223和ERC20多次考虑后，还是先用ERC20来搞事了。
<!--more-->
先大概发出个雏形，反正也不是正式发币，以后想好了再完善。

## token业务规划
小编在此正式宣布，小编的这个区块链产品叫做：`Freedom Mainland`，中文名是`自由大陆`
token的名称就是`FREE`，可不要理解成免费额，一点都不便宜。
具体有哪些业务，小编还是那句话，没想好，总共就按1亿的发行量，永不增发：
* 其中80%用于奖励`自由大陆`中，完成某些任务，达成某些条件的用户，直到币全部用完。
* 剩余20%没考虑好，先放着吧，目前打算一半用于后面的项目维护，一半用于项目成员的奖励（一个人也是算成员的额～\_～）

## token实现
小编看过很多项目的token设计，有的直接发个token.sol就完事了，有的稍微好点，但是也来来回回的把代码写的反而难懂了。
本着简洁安全的原则，小编选择继承`openzeppelin-solidity`项目中的token设计，`openzeppelin-solidity`是什么，小编不想详细解释，只想说，这个项目是以太坊标准规范的权威实现，不相信的可以看看，各种项目的token几乎都是用的它里面的源码。
有了选择方向，然后就要选择开发框架，不用想，肯定是truffle。
呵呵，为了避免被合约漏洞，小编也给自己的token加上pause功能啦。

### 源码
完整的truffle架构的项目发github上了[free-token](https://github.com/jason-wj/free-token)
代码也不多，就先发出来了，就先这么发出来了，后面再根据需要改：
```solidity
pragma solidity ^0.4.0;

import "openzeppelin-solidity/contracts/lifecycle/Pausable.sol";
import "openzeppelin-solidity/contracts/token/ERC20/StandardToken.sol";

contract FreeToken is StandardToken, Ownable, Pausable{

    string public constant name = "Free Token";
    string public constant symbol = "FREE";
    uint256 public constant decimals = 18;

    string public version = "1.0";
    uint256 public currentSupply;
    uint256 public saleAmount;

    event Mint(uint256 currentSupply, uint256 saleAmount, address indexed to, uint256 amount);

    function FreeToken() public {
        totalSupply_ = 1e8 * 10 ** decimals; //姑且发行一个亿吧
        saleAmount = 8e7 * 10 ** decimals; //对合格用户奖励的总额度
        currentSupply = 0;
    }

    //只有合约发布者可以给某用户奖励
    function mintByOwner(address _to, uint256 _amount) onlyOwner external returns (bool) {
        return mint(_to, _amount);
    }

    //奖励给某用户
    function mint(address _to, uint256 _amount) internal whenNotPaused returns (bool) {
        require(currentSupply.add(_amount) <= saleAmount);
        currentSupply = currentSupply.add(_amount);
        balances[_to] = balances[_to].add(_amount);
        Mint(currentSupply,saleAmount, _to, _amount);
        return true;
    }

    function transfer(address _to, uint256 _value) public whenNotPaused returns (bool) {
        return super.transfer(_to, _value);
    }

    function transferFrom(address _from, address _to, uint256 _value) public whenNotPaused returns (bool) {
        return super.transferFrom(_from, _to, _value);
    }

    function approve(address _spender, uint256 _value) public whenNotPaused returns (bool) {
        return super.approve(_spender, _value);
    }

    function increaseApproval(address _spender, uint _addedValue) public whenNotPaused returns (bool success) {
        return super.increaseApproval(_spender, _addedValue);
    }

    function decreaseApproval(address _spender, uint _subtractedValue) public whenNotPaused returns (bool success) {
        return super.decreaseApproval(_spender, _subtractedValue);
    }
}
```
一个token是不是so easy ?怪不得那帮人天天没事干就发空气币，这么几行代码就够了。

## 问题
小编打算将币分发给满足条件的用户，这样一来，分发肯定会异常频繁，因此，若是再以太坊下正式运行这个项目，以后不说交易速度慢，手续费想想也头大。
后期若是EOS稳定，小编会考虑把自己的项目搞上去的。


