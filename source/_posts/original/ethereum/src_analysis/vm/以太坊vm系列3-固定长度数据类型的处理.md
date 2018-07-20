---
title: 以太坊vm系列3-固定长度数据类型的处理
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
  - EVM
abbrlink: 8ddcbc00
date: 2018-07-19 21:33:04
---
## 前言
本文主要是讲Solidity以及EVM对数组、结构题等复杂的数据类型的处理方式，了解了这些基本情况，对我们编写经济的合约或者设计新的vm，都有极大的帮助。
<!--more-->
本文参考的是Howard是量子链的大神的文章，末尾处有文章出处，根据小编的理解，做了大量的调整和补充。
指令集可参考：[以太坊vm系列1-指令集汇总](/articles/715e1612)，里面有详细的汇总和解释
另外，本文所有合约都是在Remix上编译的

## SLOAD和STORE指令的一些整理
通过前一篇文章[`《以太坊vm系列2-基础篇》`](/articles/4b0172c1)我们了解到：
1. 合约的数据，在EVM中，是使用一个个的32字节的槽器来存储的
2. SSTORE和SLOAD指令消耗的手续费是普通指令的很多倍，并且在合约整个过程中，基本都是这两条指令来主导。

结合前面，再做一些新的补充：
1. 合约中，声明变量时候，并没有在存储器中开辟空间，只是依次给出对应在存储器上的位置，不收手续费。只有真正往对应地址赋值的时候，才会计算手续费。
2. `SLOAD`指令读取某个地址上的数据，若该地址没有被初始化（也就是未赋值或使用），则返回0x0
3. Solidity并没有非常智能，即使某个地址没有赋值，它也会去`SLOAD`来获取0x0，花费了gas。汇编角度看，完全可以直接用0x0取代此时`SLOAD`所扮演的角色。

## 结构体的存储
含有结构体的合约代码：
```JavaScript
pragma solidity ^0.4.11;
contract Test {
    struct Tuple {
      uint256 a;
      uint256 b;
      uint256 c;
      uint256 d;
      uint256 e;
      uint256 f;
    }
    Tuple t;
    constructor () public{
      t.f = 0xC0FEFE;
    }
}
```
先说一下这些变量在存储器槽的存储方式：t.a存在0x0位置、t.b存在0x01位置、t.c存在0x2位置。。。
编译，使用`optimize`设置

看看相应的字节码：`62c0fefe600555`
再看看汇编指令：
```armasm
PUSH3 0xC0FEFE  //62 c0fefe，将0xC0FEFE压入栈，此时栈中数据stack[c0x0fefe]
PUSH1 0x5       //60 0x5，   将0x5压入栈，此时栈中数据stack[0xc0fefe 0x5]
SSTORE          //55，       两数出栈，将0xc0fefe存储0x5地址之中
```
从中我们可以看出，合约结构体中其余声明的变量，并没有被写入到存储器中，也就是手，只有`t.f`才会收取手续费

## 固定长度数组
含有固定长度数组的合约代码：
```JavaScript
pragma solidity ^0.4.11;
contract Test {
    uint256[6] numbers;
    constructor() public{
      numbers[5] = 0xC0FEFE;
    }
}
```
编译，使用`optimize`设置。

看看相应的字节码：`62c0fefe600555`
再看看汇编指令：
```armasm
PUSH3 0xC0FEFE  //62 c0fefe，将0xC0FEFE压入栈，此时栈中数据stack[c0x0fefe]
PUSH1 0x5       //60 0x5，   将0x5压入栈，此时栈中数据stack[0xc0fefe 0x5]
SSTORE          //55，       两数出栈，将0xc0fefe存储0x5地址之中
```
哈哈，和上面结构体的汇编是一模一样。

## 数组边界检查
上面我们看到结构体和数组存储布局以及指令都是一样的，但是如果我们编译时候去掉`optimize`配置，两者指令差距是蛮大的。
在数组中，Solidity会进行数组边界检查
先看看相应的字节码：`62c0fefe60006005600681101515602357fe5b0181905550`
再看看汇编指令：
```armasm
PUSH3 0xC0FEFE  //62 c0fefe，将0xC0FEFE压入栈，此时栈中数据stack[c0x0fefe]
PUSH1 0x0       //60 0x0， 将0x0压入栈，此时栈中数据stack[c0x0fefe 0x0]
PUSH1 0x5       //60 0x5， 将0x5压入栈，此时栈中数据stack[c0x0fefe 0x0 0x5]
PUSH1 0x6       //60 0x6， 将0x6压入栈，此时栈中数据stack[c0x0fefe 0x0 0x5 0x6]
DUP2            //81，     从栈顶起，将栈中第2个元素复制并加入栈顶。此时栈中数据stack[c0x0fefe 0x0 0x5 0x6 0x5]
LT              //10，     栈中pop出栈顶元素x，与栈中新的栈顶元素y比较，栈顶修改为新的运算结果（x<y，则y=1否则y=0）。此时栈中数据stack[c0x0fefe 0x0 0x5 1]
ISZERO          //15，     判断栈顶元素若大于0，则栈顶元素改为0，否则改为1。此时栈中数据stack[c0x0fefe 0x0 0x5 0]
ISZERO          //15，     判断栈顶元素若大于0，则栈顶元素改为0，否则改为1。此时栈中数据stack[c0x0fefe 0x0 0x5 1]
PUSH1 0x23      //60 0x23，将0x23压入栈，此时栈中数据stack[c0x0fefe 0x0 0x5 1 23]
JUMPI           //57，     栈中先后pop出两个值x,y，x表示跳转到第几个JUMPDEST，而y表示一个标记（若为0，则跳到下一个JUMPDEST）,若y不为0，则由x决定跳到第几个。此时栈中数据stack[c0x0fefe 0x0 0x5] 
INVALID         //无，      程序停止执行
JUMPDEST        //5b，     JUMPI可跳到此处，继续执行后面的命令。此时栈中数据stack[c0x0fefe 0x0 0x5]
ADD             //01，     stack[c0x0fefe 0x5]
DUP2            //81，     stack[c0x0fefe 0x5 c0x0fefe]
SWAP1           //90，     stack[c0x0fefe c0x0fefe 0x5]
SSTORE          //55，     栈顶推出两位，将数值c0x0fefe存储在存储器的0x5的位置上。此时栈中数据stack[c0x0fefe],存储器数据store{`c0x0fefe数值存在0x5地址`}
POP             //50，     丢弃栈顶数据。此时栈中数据stack[]，存储器数据store{`c0x0fefe数值存在0x5地址`}
```
从中可以看出，汇编中做了很多的判断，确保数据没有越界，若越界，程序则会退出。`JUMPI`和`JUMPDEST`作用小编是大概猜的，问题应该不大，等后面看了源码再来修改。
不过，明显感觉到编译器处理的优点啰嗦，也就是手Solidity还是有待提高的。

## 打包行为
上一篇文章：[`《以太坊vm系列2-基础篇》`](/articles/4b0172c1)中，对这一部分已经做了很详细的解释，很多位操作的技巧，终归一句话，Solidity编译器使用优化器（`optimize`）尽可能的将两个小规模的数打包到一个32字节的槽中，以便减少燃料费的使用。

## 干扰优化器（`optimize`）
这次干扰的做法是，我们将变量放在不同的方法下赋值。
```JavaScript
pragma solidity ^0.4.11;
contract Test {
    uint64 a;
    uint64 b;
    uint64 c;
    uint64 d;
    constructor() public {
      setAB();
      setCD();
    }
    function setAB() internal {
      a = 0xaaaa;
      b = 0xbbbb;
    }
    function setCD() internal {
      c = 0xcccc;
      d = 0xdddd;
    }
}
```
使用`optimize`优化编译，生成的关键`armasm`汇编指令如下：
```armasm
tag1:                                            //结构体
  JUMP [in]  setAB()                             //跳转到tag5的setAB()方法
tag4:
  JUMP [in]  setCD()
tag5:                                            //跳转到tag7的setAB()方法
  JUMPDEST   function setAB() internal {\n ...
  ...                                            //处理A，B
  SSTORE                                         //将A，B保存在本地
  JUMP [out]                                     //跳回到调用A，B的地方
tag7:                                            //setCD()函数
  JUMPDEST   function setCD() internal {\n ...   
  ...                                            //保存C，D
  SSTORE                                         //将C，D保存在本地
  JUMP [out]                                     //跳回到调用C，D的地方
```
`ps：每个tag代表一个不同的模块`
指令非常的长，小编只列出一些。这里我们主要能看到里面有两个`sstore`就行。
要知道，正常的优化中4个变量a、b、c、d加起来总共是32个字节，根据我们对[`《以太坊vm系列2-基础篇》`](/articles/4b0172c1)中`打包`的理解，应该是一次性写入存储器中的，也就是只调用一次`sstore`。
但是，这里`sstroe`却调用了两次。也就是说说，Solidity目前并不能优化垮方法的变量。

也就是说，为了减少`sstore`方法的调用，降低成本，我们目前最合适的做法就是将变量的赋值都写在同一个方法中：
```JavaScript
a = 0xaaaa;
b = 0xbbbb;
c = 0xcccc;
d = 0xdddd;
```

## 再次干扰优化器（`optimize`）
这次的干扰我们的做法是，为定长数组中的每个变量赋值：
```JavaScript
pragma solidity ^0.4.11;
contract C {
    uint64[4] numbers;
    constructor () public {
      numbers[0] = 0x0;
      numbers[1] = 0x1111;
      numbers[2] = 0x2222;
      numbers[3] = 0x3333;
    }
}
```
使用`optimize`优化编译，生成的关键`armasm`汇编指令如下：
```
...armasm
SSTORE      //保存数组到存储器
...
```
ok，这里出现意外了，只调用了一次`SSTORE`。小编是参考的[Howard原文](https://medium.com/@hayeah/diving-into-the-ethereum-vm-part-2-storage-layout-bc5349cb11b7)，可能是Solidity的优化器升级的缘故，其中提到的调用4次`sstore`的情况并没有发生。
这次干扰在此算是被优化器抵御了。
好吧，这是一件好事，说明Solidity也在不断进步。也不影响我们继续探索，这里我们去掉`optimize`优化，重新编译下代码，再来看指令：
```armasm
SLOAD
SSTORE      //保存numbers[0]到存储器
SLOAD
SSTORE      //保存numbers[1]到存储器
SLOAD
SSTORE      //保存numbers[2]到存储器
SLOAD
SSTORE      //保存numbers[3]到存储器
```
呵呵，看出来了吧，优化和不优化，手续费差异蛮大的。

## 总结
1. Solidity会尽可能的打包将数据存在一个32字节的槽中
2. Solidity不能对跨方法对赋值进行优化。
3. 相信Solidity会越走越好。

>量子链-Howard英文原文：https://medium.com/@hayeah/diving-into-the-ethereum-vm-part-2-storage-layout-bc5349cb11b7
>xuli中文翻译：https://lilymoana.github.io/evm_part2.html
