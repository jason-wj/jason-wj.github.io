---
title: 以太坊vm系列4-动态数据处理
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
abbrlink: 639ef287
date: 2018-07-20 11:40:28
---
## 前言
本文主要是讲Solidity以及EVM对动态数据的复杂的数据类型的处理方式，了解了这些基本情况，对我们编写经济的合约或者设计新的vm，都有极大的帮助。
动态数据分为这三大类：
1. 映射(Mappings)：mapping(bytes32 => uint256)， mapping(address => string)等等
2. 数组(Arrays)：[]uint256，[]byte等等
3. 字节数组(Byte arrays)：只有两种类型：string，bytes
<!--more-->
本文参考的是Howard是量子链的大神的文章，末尾处有文章出处，根据小编的理解，做了大量的调整和补充。
指令集可参考：[以太坊vm系列1-指令集汇总](/articles/715e1612)，里面有详细的汇总和解释
讲之前，小编先要给大家脑补一点：
把EVM理解为一个键-值(key-value)数据库，而每个key都限制为32字节。
另外，本文所有合约都是在Remix上编译的

## 映射
带有映射的一个简单合约：
```JavaScript
pragma solidity ^0.4.11;
contract Test {
    mapping(uint256 => uint256) items;
    constructor() public {
      items[0xc0fefe] = 0x42;
    }
}
```
编译器开启`optimize`编译该合约。
映射存储相关字节码：`62c0fefe600090815260205260427f79826054ee948a209ff4a6c9064d7398508d2c1909a392f899d301c6d232187c55`
对应的汇编指令：
```armasm
PUSH3 0xC0FEFE       //62 0xc0fefe，  将0xc0fefe压入栈，此时栈中数据stack[c0x0fefe]
PUSH1 0x0            //60 0x0，       将0x0压入栈，此时栈中数据stack[c0x0fefe，0x0]
SWAP1                //90，           从栈顶起，将前两个数据交换。此时栈中数据stack[0x0 c0x0fefe]
DUP2                 //81，           栈顶起，将栈中第2个元素复制并加入栈顶。此时栈中数据stack[0x0 c0x0fefe 0x0]
MSTORE               //52，           先后pop出两个元素x,y，内存中将y存在x对应地址。此时栈中数据stack[0x0]，内存数据memory{'0x0位置存储c0x0fefe'}
PUSH1 0x20           //60 0x20，      将0x20压入栈，此时栈中数据stack[0x0 0x20]
MSTORE               //52，           先后pop出两个元素x,y，内存中将y存在x对应地址。此时栈中数据stack[]，内存数据memory{'0x0位置存储c0x0fefe'，'0x20位置存储0x0'}
PUSH1 0x42           //60 0x42，      将0x20压入栈，此时栈中数据stack[0x42]，内存数据memory{'0x0位置存储c0x0fefe'，'0x20位置存储0x0'}
PUSH32 0x7982...     //60 0x7982...， 将0x79826054EE948A209FF4A6C9064D7398508D2C1909A392F899D301C6D232187C压入栈，此时栈中数据stack[0x42 0x79826054EE948A209FF4A6C9064D7398508D2C1909A392F899D301C6D232187C]，内存数据memory{'0x0位置存储c0x0fefe'，'0x20位置存储0x0'}
SSTORE               //55，           栈顶推出两位，将数值0x42存储在存储器的0x79826054EE948A209FF4A6C9064D7398508D2C1909A392F899D301C6D232187C的位置上。此时栈为空stack[]，内存数据memory{'0x0位置存储c0x0fefe'，'0x20位置存储0x0'}，此处发现这个内存貌似没什么用处。。。
```
上面的指令是不是很诡异？还记得我们前面说的，evm看成是个k-v数据库，k有32字节。
`0x7982...（32字节）`其实就是`0xc0fefe`使用`keccak256`哈希运算后的结果，用它来作为key。因为编译期间我们使用了`optimize`，Solidity会预先帮我们把`0xc0fefe`哈希生成`0x7982...（32字节）`
也就是说，上面的两条`MSTORE`指令貌似并没什么卵用，这块Solidity的优化器要是能进一步完善下，没准就又可以省下几个gas了。
`MSTORE`指令是进行内存操作，很便宜，操作一次3gas。

其实，Solidity编译器之所以可以预先将`0xc0fefe`哈希生成`0x7982...（32字节）`，是因为直接数组中设置的的常量，但如果改成是变量，那又会变成什么样子？我们继续往下分析。
也不是说上面的两个`MSTORE`没用，等看完小编后面写的内容，就知道若Solidity编译器的hash生成失效，汇编会用这两个内存值来进行汇编层次的hash运算。在上面的汇编代码中，只能说是Solidity优化不彻底。

`ps:keccak256是一种hash计算标准，老权威了。。。`

## 汇编代码中的`keccak256`
改造一下上面的合约，将`0xc0fefe`提到外部变量：
```JavaScript
pragma solidity ^0.4.11;
contract Test {
    mapping(uint256 => uint256) items;
    uint256 i = 0xC0FEFE;
    constructor() public {
      items[i] = 0x42;
    }
}
```
编译器开启`optimize`编译该合约。
映射存储相关字节码：`600154600090815260208190526040902060429055`
对应的汇编指令：
`ps:0xc0fefe存储在存储器0x1地址的汇编过程，小编这里就不列出来了，以下都是该过程完成后的操作`
```armasm
PUSH1 0x1    //60 0x1， 将0x0压入栈，此时栈中数据stack[0x1]
SLOAD        //54，     取出栈顶元素，转为hash长度（表示在db中的地址），在db中是否存在对应值,并读取出,此处返回`0xc0fefe`，push到栈中。此时栈中数据stack[0xc0fefe]
PUSH1 0x0    //60 0x0， 将0x0压入栈，此时栈中数据stack[0xc0fefe 0x0]
SWAP1        //90，     从栈顶起，将前两个数据交换。此时栈中数据stack[0x0 0xc0fefe]
DUP2         //81，     从栈顶起，将栈中第2个元素复制并加入栈顶。此时栈中数据stack[0x0 0xc0fefe 0x0]
MSTORE       //52，     先后pop出两个元素x,y，内存中将y存在x对应地址。此时栈中数据stack[0x0]，内存数据memory{'0x0位置存储0xc0fefe'}
PUSH1 0x20   //60 0x20，将0x20压入栈，此时栈中数据stack[0x0 0x20]
DUP2         //81，     从栈顶起，将栈中第2个元素复制并加入栈顶。此时栈中数据stack[0x0 0x20 0x0]
SWAP1        //90，     从栈顶起，将前两个数据交换。此时栈中数据stack[0x0 0x0 0x20]
MSTORE       //52，     先后pop出两个元素x,y，内存中将y存在x对应地址。此时栈中数据stack[0x0]，内存数据memory{'0x0位置存储0xc0fefe','0x0位置存储0x20'}
PUSH1 0x40   //60 0x40，将0x20压入栈，此时栈中数据stack[0x0 0x40]
SWAP1        //90，     从栈顶起，将前两个数据交换。此时栈中数据stack[0x40 0x0]
KECCAK256    //20，     该过程在evm中是`SHA3操作`，pop出栈中两个元素偏离值m和大小n，结合内存中的两个数据x,y生成为32字节的hash，然后压入栈。此时栈中数据stack[0x79826054EE948A209FF4A6C9064D7398508D2C1909A392F899D301C6D232187C]，内存数据memory{}
PUSH1 0x42   //60 0x42，将0x20压入栈，此时栈中数据stack[0x79826054EE948A209FF4A6C9064D7398508D2C1909A392F899D301C6D232187C 0x42]
SWAP1        //90，     从栈顶起，将前两个数据交换。此时栈中数据stack[0x42 0x79826054EE948A209FF4A6C9064D7398508D2C1909A392F899D301C6D232187C]
SSTORE       //55，     栈顶推出两位，将数值0x42存储在存储器的0x79826054EE948A209FF4A6C9064D7398508D2C1909A392F899D301C6D232187C地址。此时栈中数据stack[]
```
这下应该知道`MSTORE`两次操作的目的了吧？
KECCAK256主要是操作栈和内存中的数据，成本大体为：
1. 操作一次KECCAK256需要支付30gas
2. 每个32字节，需要支付6gas

 小编这么理解KECCAK256从栈中的两个数据，这个过程的费用已经包含在30gas中，而内存中两个32字节的数据操作是需要手续费，每个6gas，总共费用为：30+6x2=42gas。
 知道优化的重要性了吧？

 are you ok？

## 动态数组
动态数组是什么东西？这里就不用问小编了吧？
动态数组在Solidity中主要包含两大类：
1. 数组(Arrays)：[]uint256，[]byte等等
2. 字节数组(Byte arrays)：只有两种类型：string，bytes

需要知道的是，在Solidity中，数组是更加昂贵的映射。数组里面的元素会按照顺序排列在存储器中：
```
0x290d...e563
0x290d...e564
0x290d...e565
0x290d...e566
```
动态数组拥有这样一些信息：
1. length表示一共有多少个元素
2. 边界检查。当读取或写入时索引值大于length就会报错
3. 比映射更加复杂的存储打包行为
4. 当数组变小时，自动清除未使用的存储槽
5. 字节数组bytes和string的特殊优化让短数组(小于32字节)存储更加高效

### 一个简单的动态数组
合约代码：
```JavaScript
pragma solidity ^0.4.11;
contract Test {
    uint256[] chunks;
    constructor() public {
      chunks.push(0xAA);
      chunks.push(0xBB);
      chunks.push(0xCC);
    }
}
```
优化器优化后的Solidity进行编译，汇编指令：
```armasm
PUSH1 0x0       stack[0x0]
DUP1            stack[0x0 0x0]
SLOAD           stack[0x0 0x0]
PUSH1 0x1       stack[0x0 0x0 0x1]
DUP2            stack[0x0 0x0 0x1 0x0]
DUP2            stack[0x0 0x0 0x1 0x0 0x1]
ADD             stack[0x0 0x0 0x1 0x1]
DUP4            stack[0x0 0x0 0x1 0x1 0x0]
SSTORE          stack[0x0 0x0 0x1] store{0x0地址存入0x1}
DUP3            stack[0x0 0x0 0x1 0x0]
DUP1            stack[0x0 0x0 0x1 0x0 0x0]
MSTORE          stack[0x0 0x0 0x1] memory{0x0地址存入0x0}  此memory无效
PUSH1 0xAA      stack[0x0 0x0 0x1 0xAA]
PUSH32 0x290... stack[0x0 0x0 0x1 0xAA 0x290DECD9548B62A8D60345A988386FC84BA6BC95484008F6362F93160EF3E563]
SWAP3           stack[0x0 0x290DECD9548B62A8D60345A988386FC84BA6BC95484008F6362F93160EF3E563 0x1 0xAA 0x0]
DUP4            stack[0x0 0x290DECD9548B62A8D60345A988386FC84BA6BC95484008F6362F93160EF3E563 0x1 0xAA 0x0 0x290DECD9548B62A8D60345A988386FC84BA6BC95484008F6362F93160EF3E563]
ADD             stack[0x0 0x290DECD9548B62A8D60345A988386FC84BA6BC95484008F6362F93160EF3E563 0x1 0xAA 0x290DECD9548B62A8D60345A988386FC84BA6BC95484008F6362F93160EF3E563] 
SSTORE          stack[0x0 0x290DECD9548B62A8D60345A988386FC84BA6BC95484008F6362F93160EF3E563 0x1] store{'0x0地址存入0x1','0xAA地址存入0x290DECD9548B62A8D60345A988386FC84BA6BC95484008F6362F93160EF3E563'}

DUP3            stack[0x0 0x290DECD9548B62A8D60345A988386FC84BA6BC95484008F6362F93160EF3E563 0x1 0x0]
SLOAD           stack[0x0 0x290DECD9548B62A8D60345A988386FC84BA6BC95484008F6362F93160EF3E563 0x1 0x1] store{'0x0地址存入0x1','0xAA地址存入0x290DECD9548B62A8D60345A988386FC84BA6BC95484008F6362F93160EF3E563'}

DUP1            stack[0x0 0x290DECD9548B62A8D60345A988386FC84BA6BC95484008F6362F93160EF3E563 0x1 0x1 0x1]
DUP3            stack[0x0 0x290DECD9548B62A8D60345A988386FC84BA6BC95484008F6362F93160EF3E563 0x1 0x1 0x1 0x1]
ADD             stack[0x0 0x290DECD9548B62A8D60345A988386FC84BA6BC95484008F6362F93160EF3E563 0x1 0x1 0x2]
DUP5            stack[0x0 0x290DECD9548B62A8D60345A988386FC84BA6BC95484008F6362F93160EF3E563 0x1 0x1 0x2 0x0]
SSTORE          stack[0x0 0x290DECD9548B62A8D60345A988386FC84BA6BC95484008F6362F93160EF3E563 0x1 0x1] store{'0x0地址存入0x2','0xAA地址存入0x290DECD9548B62A8D60345A988386FC84BA6BC95484008F6362F93160EF3E563'}
PUSH1 0xBB      stack[0x0 0x290DECD9548B62A8D60345A988386FC84BA6BC95484008F6362F93160EF3E563 0x1 0x1 0xBB]
SWAP1           stack[0x0 0x290DECD9548B62A8D60345A988386FC84BA6BC95484008F6362F93160EF3E563 0x1 0xBB 0x1]
DUP4            stack[0x0 0x290DECD9548B62A8D60345A988386FC84BA6BC95484008F6362F93160EF3E563 0x1 0xBB 0x1 0x290DECD9548B62A8D60345A988386FC84BA6BC95484008F6362F93160EF3E563]
ADD             stack[0x0 0x290DECD9548B62A8D60345A988386FC84BA6BC95484008F6362F93160EF3E563 0x1 0xBB 0x290DECD9548B62A8D60345A988386FC84BA6BC95484008F6362F93160EF3E564]
SSTORE          stack[0x0 0x290DECD9548B62A8D60345A988386FC84BA6BC95484008F6362F93160EF3E563 0x1] store{'0x0地址存入0x2','0xAA地址存入0x290DECD9548B62A8D60345A988386FC84BA6BC95484008F6362F93160EF3E563','0xBB地址存入0x290DECD9548B62A8D60345A988386FC84BA6BC95484008F6362F93160EF3E564'}
DUP3            stack[0x0 0x290DECD9548B62A8D60345A988386FC84BA6BC95484008F6362F93160EF3E563 0x1 0x0]
SLOAD           stack[0x0 0x290DECD9548B62A8D60345A988386FC84BA6BC95484008F6362F93160EF3E563 0x1 0x2]
SWAP1           stack[0x0 0x290DECD9548B62A8D60345A988386FC84BA6BC95484008F6362F93160EF3E563 0x2 0x1]
DUP2            stack[0x0 0x290DECD9548B62A8D60345A988386FC84BA6BC95484008F6362F93160EF3E563 0x2 0x1 0x2]
ADD             stack[0x0 0x290DECD9548B62A8D60345A988386FC84BA6BC95484008F6362F93160EF3E563 0x2 0x3]
SWAP1           stack[0x0 0x290DECD9548B62A8D60345A988386FC84BA6BC95484008F6362F93160EF3E563 0x3 0x2]
SWAP3           stack[0x2 0x290DECD9548B62A8D60345A988386FC84BA6BC95484008F6362F93160EF3E563 0x3 0x0]
SSTORE          stack[0x2 0x290DECD9548B62A8D60345A988386FC84BA6BC95484008F6362F93160EF3E563]  store{'0x0地址存入0x3','0xAA地址存入0x290DECD9548B62A8D60345A988386FC84BA6BC95484008F6362F93160EF3E563','0xBB地址存入0x290DECD9548B62A8D60345A988386FC84BA6BC95484008F6362F93160EF3E564'}
PUSH1 0xCC      stack[0x2 0x290DECD9548B62A8D60345A988386FC84BA6BC95484008F6362F93160EF3E563 0xCC]  store{'0x0地址存入0x3','0xAA地址存入0x290DECD9548B62A8D60345A988386FC84BA6BC95484008F6362F93160EF3E563','0xBB地址存入0x290DECD9548B62A8D60345A988386FC84BA6BC95484008F6362F93160EF3E564'}
SWAP2           stack[0xCC 0x290DECD9548B62A8D60345A988386FC84BA6BC95484008F6362F93160EF3E563 0x2]
ADD             stack[0xCC 0x290DECD9548B62A8D60345A988386FC84BA6BC95484008F6362F93160EF3E565]
SSTORE          stack[]  store{'0x0地址存入0x3','0xAA地址存入0x290DECD9548B62A8D60345A988386FC84BA6BC95484008F6362F93160EF3E563','0xBB地址存入0x290DECD9548B62A8D60345A988386FC84BA6BC95484008F6362F93160EF3E564','0xCC地址存入0x290DECD9548B62A8D60345A988386FC84BA6BC95484008F6362F93160EF3E565'}
```

哈哈，是不是crazy？小编把每步执行后，栈stack、内存memory、存储器storage中数据状态记录下了。
不想看上面代码的，小编直接来解释吧：
1. 内存memory没毛用，只是浪费gas。
2. 总共执行了6次`SSTORE`指令，总共执行了3次`SLOAD`指令。小编按先后顺序解释下这几个命令具体干啥了
	1. 第1次执行`SLOAD`
	   去地址0x0读取当前数组长度，返回0
	2. 第1次执行`SSTORE`
	   在地址0x0记录当前数组长度为1
	3. 第2次执行`SSTORE`
	   在一个hash地址记录数据0xAA
	4. 第2次执行`SLOAD`
	   去地址0x0读取当前数组长度，返回1
	5. 第3次执行`SSTORE`
	   在地址0x0记录当前数组长度为2
	6. 第4次执行`SSTORE`
	   在一个hash地址记录数据0xBB
	7. 第3次执行`SLOAD`
	   去地址0x0读取当前数组长度，返回2
	8. 第5次执行`SSTORE`
	   在地址0x0记录当前数组长度为3
	9. 第6次执行`SSTORE`
	   在一个hash地址记录数据0xCC

看出来了吧，数组长度，每加入一个数据，则更新一次。两种数据都需要`sstore`
所以说，相比较于动态数组，反而映射更加节省gas。

## 动态数组打包
这个小编就不详细讲了，前面[`《以太坊vm系列2-基础篇》`](/articles/4b0172c1)介绍了一些打包情况，
简单说就是，Solidity尽量优先填充满一个32字节的槽，尽量减少sstore的使用。
但是需要知道的是，由于数组需要进行边界检查和一些别的因素，动态数组中，每对一个数据存储，都需要执行一次`sstore`。就是说如下代码：
```JavaScript
pragma solidity ^0.4.11;
contract C {
    uint128[] s;
    function C() {
        s.length = 4;  //执行1次sstore，第1个槽
        s[0] = 0xAA;   //执行2次sstore，第2个槽
        s[1] = 0xBB;   //执行3次sstore，第2个槽
        s[2] = 0xCC;   //执行4次sstore，第3个槽
        s[3] = 0xDD;   //执行5次sstore，第3个槽
    }
}
```
可以发现，用了3个槽，执行了5次`sstore`。占用的槽少了，但sstore次数一点不会少。

## 字节数组和字符串
`bytes`和`string`是为字节和字符进行优化的特殊数组类型。如果数组的长度不大于31字节，第32个字节存储有效编码的长度（看了下面的实例就懂了）。长一点的字节数组跟正常数组的表示方式差不多。
`string`和`bytes`的情况都一样，这里就只演示`bytes`了。
字节数组赋值短的数据和长的数据，会有什么情况？一个个来试试

### 字节数组赋值短数据
先看合约代码：
```JavaScript
pragma solidity ^0.4.11;
contract Test {
    bytes s;
    constructor() public {
        s.push(0xAA);
        s.push(0xBB);
        s.push(0xCC);
    }
}
```
优化器编译后，指令就不展示了，一大坨。直接看看在数据在存储器中的格式：
```
key:   0x0000000000000000000000000000000000000000000000000000000000000000
value: 0xaabbcc0000000000000000000000000000000000000000000000000000000006
```
`value`最后面的06表示的是存储器此处的编码长度，而s的真实长度(长度问题在下面总结中描述原因)是：`编码长度/2=3`。
另外，也看出value中，数据是从左往右存储的。

### 字节数组赋值长数据
先看合约代码：
```JavaScript
pragma solidity ^0.4.11;
contract Test {
    bytes s;
    constructor() public {
       s.length = 32 * 4;
        s[31] = 0x1;
        s[63] = 0x2;
        s[95] = 0x3;
        s[127] = 0x4;
    }
}
```
直接来看在存储器中是如何存储的：
```
key:   0x0000000000000000000000000000000000000000000000000000000000000000
value: 0x0000000000000000000000000000000000000000000000000000000000000101

key:   0x290decd9548b62a8d60345a988386fc84ba6bc95484008f6362f93160ef3e563
value: 0x0000000000000000000000000000000000000000000000000000000000000001

key:   0x290decd9548b62a8d60345a988386fc84ba6bc95484008f6362f93160ef3e564
value: 0x0000000000000000000000000000000000000000000000000000000000000002

key:   0x290decd9548b62a8d60345a988386fc84ba6bc95484008f6362f93160ef3e565
value: 0x0000000000000000000000000000000000000000000000000000000000000003

key:   0x290decd9548b62a8d60345a988386fc84ba6bc95484008f6362f93160ef3e566
value: 0x0000000000000000000000000000000000000000000000000000000000000004
```
可以看出，总共5个地址，也就是在四个槽里存了数据（一个key表示一个地址）：
1. 第1个0x0地址存储的是数据编码长度。数据的实际长度(长度问题在下面总结中描述原因)：`长度=（编码长度-1）/2`,也就是0x101 - 1）/2=128
2. 第2到第5的4个槽，分别存放了数组里的四个数据
3. 看key的 最后一位，这几个地址都是连续的

### 长字节短字节的总结
1. 字节数组的汇编代码相当多。除了正常的边界检查和数组恢复大小等，它还需要对长度进行编码/解码，以及注意长字节数组和短字节数组之间的转换。
2. `为什么要编码长度？`
因为编码之后，可以很容易的测试出来字节数组是长还是短。注意对于长数组而言编码长度总是奇数，而短数组的编码长度总是偶数。汇编代码只需要查看一下最后一位是否为0，为0就是偶数（短数组），非0就是奇数（长数组）。


## 总结
1. 相比较于动态数组，反而映射更加节省gas。
2. 使用数组的复杂度超过了想象，
3. 这一节，小编感觉已经很吃力了。。。
4. 其实，走到这里，反而问题越来越多，为什么选择256？为什么这么复杂？越来越底层，小编感觉有点吃不消了，毕竟后面跟cpu等硬件兼容性考虑，实在不是小编的长项。只能点到为止了。小编也看了下qtum对evm的见解，想要理解到那种程度，还有好几个境界要走。







