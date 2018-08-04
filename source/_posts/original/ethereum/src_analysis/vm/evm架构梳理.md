---
title: evm架构梳理
mathjax: false
copyright: true
original: true
top: false
notice: false
explain: 文中可能会根据需要做部分调整
categories:
  - 原创
  - 以太坊
  - 源码解读
tags:
  - ethereum
  - EVM
abbrlink: 414c120c
date: 2018-08-03 14:30:03
---
## 前言
这段时间在看evm，不是说evm偏底层就不该了解。它是支撑整个ethereum运行等基石，把握了它才能把握了以太坊的整个设计方向。
<!--more-->
小编这段时间研究后，只能说，真的是长见识了。。
小编把evm的代码抽离出来了，还没写完，等后面完的差不多了，就会提交到github
目前源码还没看完，只知道一个新建合约在evm中的整个流程

## 整体架构
先上图，精心绘制的
{% asset_img 1.png evm整体架构 %}

## evm文件结构图
.
|____memory.go                    //数据内存管理，指令涉及到内存操作的部分
|____memory_table.go              //内存的读取等操作
|____opcodes.go                   //指令符号定义等
|____analysis.go
|____gas_table_test.go            //gas价格测试
|____gas_table.go                 //gas汇总
|____evm.go                       //evm创建字节码合约，调用合约的入口
|____gas.go                       //用于设定每个指令的gas费用
|____logger.go                    //日志
|____logger_test.go               //日志测试
|____int_pool_verifier_empty.go   //注意文件里面，顶部的+build符号，这是用来验证整数池是否正常的（初始化）
|____int_pool_verifier.go         //同上，这个过程是需要手动编译用的
|____interface.go                 //数据物理存储，调用的外部接口，指令sstore执行后保存会用到
|____analysis_test.go             
|____instructions.go              //每条指令具体执行的函数
|____gen_structlog.go
|____contracts.go                 //预编译合约
|____contracts_test.go            //预编译合约测试
|____noop.go
|____instructions_test.go         //指令测试
|____opt_test.go                  //指令执行测试
|____doc.go
|____stack.go                     //栈，指令操作
|____stack_table.go               //栈验证的一些方法
|____common.go                    //一些公用的工具
|____interpreter.go               //解析指令，就是从合约字节编码中获取
|____intpool.go                   //整数池
|____jump_table.go                //指令执行方法的具体实现
|____contract.go                  //字节码合约，外部传入的编码被映射到其中  
|____errors.go                    //错误管理

## 具体说明
其实图中已经讲的很详细，
看源码的话，建议从evm的create入手，看看创建一个字节码合约要经历哪些步骤。
另外一定要知道intpool、stack、memory的作用，另外，指令的定义，执行等，也一定要了解。否则很难明白这个evm在做什么。

## 一些有意义的内容
从源码中，小编了解到了一些内容：
1. 栈道深度是1024
2. 一条指令不能超过8个字节，也就是64位
3. 总共有7个硬分叉，在/go-ethereum/params/config.go中可以看出，难道是7次硬分叉？，其中`HomesteadBlock`、`ByzantiumBlock`、`ConstantinopleBlock`属于ethereum的3个里程碑，第4个还没出现，还在开发中
	```golang
	func (c *ChainConfig) IsHomestead(num *big.Int) bool {
		return isForked(c.HomesteadBlock, num)
	}
	// IsDAO returns whether num is either equal to the DAO fork block or greater.
	func (c *ChainConfig) IsDAOFork(num *big.Int) bool {
		return isForked(c.DAOForkBlock, num)
	}
	func (c *ChainConfig) IsEIP150(num *big.Int) bool {
		return isForked(c.EIP150Block, num)
	}
	func (c *ChainConfig) IsEIP155(num *big.Int) bool {
		return isForked(c.EIP155Block, num)
	}
	func (c *ChainConfig) IsEIP158(num *big.Int) bool {
		return isForked(c.EIP158Block, num)
	}
	func (c *ChainConfig) IsByzantium(num *big.Int) bool {
		return isForked(c.ByzantiumBlock, num)
	}
	func (c *ChainConfig) IsConstantinople(num *big.Int) bool {
		return isForked(c.ConstantinopleBlock, num)
	}
	```
4. 忘了。。。。。。
