---
title: 以太坊源码解读-第3讲-trie模块源码解读（1）
mathjax: true
copyright: true
original: true
explain: 文中可能会根据需要做部分调整
date: 2018-04-17 14:44:59
categories: [原创,以太坊,源码解读]
tags: [ethereum]
---

## 前言
了解以太坊的同学都知道，以太坊中有三大重要的状态：`账户状态`、`交易状态`、`收据状态`（不要问小编它们有什么用\-\_\-）。这三大状态怎么保存，怎样保证这些信息的安全？这就离不开我们这次要讲的以太坊`trie`模块了。
<!-- more -->
它提供了一种强大的数据结构`Merkle Patricia Tries`，我们亲切的称它为`MPT`。正是它维护着我们的这三种状态，让整个以太坊平稳有序的进行着。
看到这么强大的东西，是不是经不起诱惑了？那我们就快来解刨吧。

## MPT的前世今生
* MPT是这三种结构的组合：Trie，Patricia Trie，Merkle tree。每一种都非常经典，为了更好的了解以太坊，小编专门整理了三篇文章，值得一读（依次从上往下读）：
	[`浅谈标准Trie树（字典树）`](/articles/original/ethereum/src_analysis/以太坊源码解读-第3讲-trie模块源码解读.html)
	[`Patricia树介绍`](/articles/original/blockchain/Patricia树介绍.html)
	[`Merkle Tree（默克尔树）算法解析`](/articles/reprint/blockchain/Merkle-Tree（默克尔树）算法解析.html)
	正是这三种树的进一步柔和，才有了今天以太坊上大名鼎鼎的MPT。
* MPT是什么，它相比上面有什么优势？建议大家看看小编整理的这篇文章：
	[`Merkle Patricia Tree (MPT) 以太坊merkle技术分析`](/articles/reprint/blockchain/Merkle-Patricia-Tree-MPT-以太坊merkle技术分析.html)

注意，上面这篇文章只是宏观上的介绍，MPT也只是大概讲讲是什么样的逻辑，具体细节，且听下回分析。
## MPT中的编码概念
MPT中会涉及到三种编码：`KEYBYTES encoding`、`HEX encoding`、`COMPACT encoding`，每种编码在特定场合都有其重要的作用，小编曾尝试通过网络中的相关文章来了解这些编码是怎么生成的，但无奈啊，这些文章一个比一个写的复杂，一堆数学公式和专业术语，越看越看不懂。。。
终于，小编还是看完源码后，弯回来，自己来解释下这三种编码具体是怎么实现的。毕竟，了解了这些基础后，再看源码就会容易很多。吸取以前看的文章的不足之处，这次小编一定讲的通俗易懂：

### KEYBYTES encoding
这就是原生的字节，没有添加任何防腐剂：go语言中的`byte`,长度为8，范围是0～255。二进制表示的话，就是`00000000~11111111`。
也就是说，一串普通数据通过`KEYBYTES encoding`编码后，就是由`很多byte`组成的一个`byte[]`数组，也就是我么说的字节数组。
这个编码搞开发的应该都懂，不难理解。

### HEX encoding
我想，把它称为半字节编码(`nibble`)更好一些，具体细节一会儿讲。
在内存中，这种编码访问会更容易，不要问为什么，小编也不知道。。。涉及到硬件效率相关，貌似是因为16进制更容易计算。
具体这种编码是怎么实现的？这块小编重点讲讲。
用`KEYBYTES encoding`编码（上面有讲，就是go中普通的byte）转为`hex`编码的过程来演示，大家可能会更容易理解，先看代码演示：
```go
//申明一个byte数据t，值为249，这个t可以理解为就是`KEYBYTES encoding`编码数据
//它将会被转为`hex`编码
var t byte = 249

//为了方便演示这里加一个l变量，表示t的长度为1，也就是总共一个字节
var l = 1  
//hex编码t总共会用到的空间大小
l := 2*l + 1  
//开辟l大小的空间，传说中的nibbles
var nibbles = make([]byte, l)  
//将s的高4位存入nibbles的第一个字节
nibbles[0] = s / 16
//将s的低4位存入nibbles的第二个字节
nibbles[1] = s % 16
//nibbles的最后一位存入标示符，代表这个是hex编码
nibbles[l-1] = 16
fmt.Println(nibbles)
```
最后输出编码为hex的结果nibbles：
	```go
	[15 9 16]  //原先数据的高4位保存位15，低4位保存位9，16表示该hex编码是通过KEYBYTES编码转换的
	```

代码里有些地方是不是还很懵逼？小编来解释一下：
* hex编码的目的是：
要将一个原始字节数组byte[]，其中的每个byte都拆分位高4位和低4位，分别放在同为字节数组的nibbles[]中（`bibbles的数组长度为原始字节数组的2倍再加1`）。其中依次高4位放在nibbles[]的偶数位，低4位放在nibbles[]的奇数位，最后一位设置为16（二进制表示`00010000`），表示这个hex编码是通过`KEYBYTES`编码转换的。
* 还不懂？小编继续换种方式解释：
	* 先记住：`一个byte的长度为8，范围是0～255。二进制表示的话，就是：00000000~11111111`。
	* 要将byte值为`249`的数据转为hex编码，首先将`249`转为二进制表示：`11111001`，看清楚，高4位是1111，低4位是1001
	* 249除以16得到的值为15，15的二进制表示是：1111，看清楚了吗？这就是249的高4位，
	* 249除以16得到的余数为9，9的二进制表示是：1001，看清楚了吗？这就是249的低4位，
	* `249`的长度为l=1，因此nibbles[]字节数组的长度为2\*l+1=3，就是说，hex编码需要用3个byte才能表示了原来的`249`，nibbles的偶数位nibbles[0]存入`249`的高4位`00001111`，nibbles的奇数位nibbles[1]的低4位存入`249`的低4位`00001001`,最后一位nibbles[2]存入16（也就是二进制`00010000`）,发现了吗？hex中的每一个byte都表示一个16进制数。
	* 因此`249`最终hex编码结果为：[`00001111`,`00001001`,`00010000`]，也就是[15 9 16]
	* 这下该懂了吧，再不懂就只能弯回去再读几遍了。。小编自认为对这个hex编码的解释算是很仔细啦。。
* 小编还要补充的重要内容是，很重要，否则很难理解`COMPACT encoding`编码：
	* `KEYBYTES encoding`编码的数据转成`HEX encoding`的编码的数据后，该byte[]最后一个是一定有后缀的，值为`16`，并且除去后缀后，剩余的编码长度为偶数。具体看上面的解释。
	* 但是，对于从其它渠道（不要管哪个渠道）生成的hexo编码，可能会有前缀，也可能前缀后缀都有。记着，`后缀永远是16，前缀为任何数。`

### COMPACT encoding
这种编码也就是黄皮书里讲的`Hex-Prefix Encoding`编码，可以看作是`HEX encoding`编码的另一种形式，在磁盘存储数据的时候，会节省磁盘空间。同样，这种编码的实现方式小编也需要好好讲讲。
既然都说了它是`HEX encoding`编码的另一种形式，也就是说，`COMPACT encoding`需要经过`HEX encoding`转换实现的。
咱们先通过代码来看一下hex编码是怎样转换为COMPACT编码的（`先知道，hex是有前缀的，前面提到过`）：
```go
// 测试案例，将hex编码{1,2,3,4,5}转换成Compact编码，并输出
func TestHexToCompact(t *testing.T) {
	testBytes := []byte{1, 2, 3, 4, 5}
	fmt.Print(hexToCompact(testBytes))
}

//用于hex编码是转换为COMPACT编码
func hexToCompact(hex []byte) []byte {
	terminator := byte(0) //初始化一个值为0的byte
	if hasTerm(hex) { //验证hex有后缀编码，
		terminator = 1  //hex有后缀编码则先设置个变量为1，后面有用
		hex = hex[:len(hex)-1]  //此处只是去掉后缀部分的hex编码
	}
	//Compact开辟的空间长度为hex编码的一半再加1，这个1对应的空间是Compact的前缀
	buf := make([]byte, len(hex)/2+1) 
	//若hex有后缀，则Compact的前缀初始化为32；
	//若hex无后缀，则Compact的前缀初始化为0；
	buf[0] = terminator << 5 
	if len(hex)&1 == 1 { //hex 长度为奇数，则逻辑上说明hex有前缀
		//buf[0]值若为16，则标记hex编码长度不小于16时是肯定有前缀；
		//buf[0]值为若48，标记hex编码长度不小于48时，同时有前缀有后缀
		buf[0] |= 1 << 4 
		//下面的或操作是为了之后Compact编码转回成hex编码时，能够恢复hex[0]
		buf[0] |= hex[0]  
		hex = hex[1:] //此时获取的hex编码无前缀无后缀
	}
	//若hex无前缀无后缀，则Compact的前缀buf[0]为0；
	/若hex只有后缀，则Compact的前缀buf[0]为32；
	decodeNibbles(hex, buf[1:]) //将hex编码映射到compact编码中
	return buf
}


func decodeNibbles(nibbles []byte, bytes []byte) {
	for bi, ni := 0, 0; ni < len(nibbles); bi, ni = bi+1, ni+2 {
		bytes[bi] = nibbles[ni]<<4 | nibbles[ni+1] //高4位低4位还原，代码不精妙吗？
	}
}
```
最后输出的Compact编码结果为：
	```go
	//17为compact前缀，因为17大于16小于32，则说明hex编码没有前缀无后缀；
	[17 35 69]  
	```
看完代码和注释，是不是头晕？上面那片代码是小编半夜整理的，愣改了两个小时才注释好，小编已经头晕的不行了。。
它的目的其实是为了两个目的：
1. 当然是编码为Compact
2. 判断hex编码：`只有前缀`；`只有后缀`；`前缀后缀都有`；`前缀后缀都没`这四种情况。
	* Compact的前缀等于`0`：前缀后缀都没
	* Compact的前缀不小于等于`16`：只有前缀
	* Compact的前缀等于`32`：只有后缀
	* 
明天再解释。。。

### 总结一下
在以太坊中，`KEYBYTES encoding`不会直接转位`COMPACT encoding`，需要先经过`HEX encoding`。
三种编码中，目前以太坊只支持如下转换：
* `KEYBYTES encoding`转`HEX encoding`
* `HEX encoding`转`KEYBYTES encoding`
* `HEX encoding`转`COMPACT encoding`
* `COMPACT encoding`转`HEX encoding`








