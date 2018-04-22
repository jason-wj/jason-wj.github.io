---
title: 以太坊源码解读-第3讲-trie模块源码解读（2）
mathjax: true
copyright: true
original: true
date: 2018-04-19 15:40:25
categories: [原创,以太坊,源码解读]
tags: [ethereum]
---
## 前言
这一部分，我们主要是讲trie源码的实现，要理解代码的实现过程，是需要先了解一下理论内容的，建议大家先看看我的上一篇文章：[以太坊源码解读-第3讲-trie模块源码解读（1）](/articles/original/ethereum/src_analysis/以太坊源码解读-第3讲-trie模块源码解读（1）.html)
<!-- more -->

## encoding.go源码解读
trie模块中，这个文件是我们首先要掌握的，这个主要是讲三种编码（`KEYBYTES encoding`、`HEX encoding`、`COMPACT encoding`）的实现与转换，trie中全程都需要用到这些，该文件中主要实现了如下功能：
1. hex编码转换为Compact编码：`hexToCompact()`
2. Compact编码转换为hex编码：`compactToHex()`
3. keybytes编码转换为Hex编码：`keybytesToHex()`
4. hex编码转换为keybytes编码：`hexToKeybytes()`
5. 获取两个字节数组的公共前缀的长度：`prefixLen()`

但是，小编不会去讲这块的源码内容了，因为[以太坊源码解读-第3讲-trie模块源码解读（1）](/articles/original/ethereum/src_analysis/以太坊源码解读-第3讲-trie模块源码解读（1）.html)这篇文章里已经穿插了很多相关的源码，重点都已经在其中解释的很详细了。
如果还有哪些地方不了解，大家可以留言或者微信与小编联系。

## node.go源码解读
大家得先看懂[以太坊源码解读-第3讲-trie模块源码解读（1）](/articles/original/ethereum/src_analysis/以太坊源码解读-第3讲-trie模块源码解读（1）.html)关于节点方面的内容，否则很难理解小编下面要讲的源码。

### node的结构与定义
以太坊为MPT中的node定义了一套基本接口规则：
```go
type node interface {
	fstring(string) string
	cache() (hashNode, bool)  //保存缓存
	canUnload(cachegen, cachelimit uint16) bool  //除去缓存，cache次数的计数器
}
```
以太坊依据上面的规则为MTP定义了四种类型的节点，代码如下：
```go
type (
	fullNode struct {
		Children [17]node  //对应了黄皮书里面的分支节点
		flags    nodeFlag
	}
	shortNode struct {  //对应了黄皮书里面的扩展节点
		Key   []byte
		Val   node  //可能指向叶子节点，也可能指向分支节点。
		flags nodeFlag
	}
	hashNode  []byte
	valueNode []byte  //叶子节点值，但是该叶子节点最终还是会包装在shortNode中
)
```
分为这四种节点：
* fullNode
这就是传说中的分支节点，会发现它里面定义了17个node，其中16个对应的16进制的0~9a~f，第17个还没搞清楚。nodeFlag稍后再说。
* shortNode
它本身若是扩展节点，则它的属性Val可能指向分支节点或者叶子节点，但要知道，叶子节点本身同样是用shortNode表示的；
它本身若是叶子节点，则Val的值为rlp编码的数据，而key则是该数据的完整hash(经过hex编码的)
* valueNode：这是给叶子节点用的，但是要知道它不能单独使用，而是要放在shortNode中使用的，用于存放rlp编码的原始数据
* hashNode：这个同样不能单独使用，我们在上面节点定义中发现了，会涉及到`nodeFlag`，先来看看定义：
```go
type nodeFlag struct {
	hash  hashNode // cached hash of the node (may be nil)
	gen   uint16   // cache generation counter
	dirty bool     // whether the node has changes that must be written to the database
}
```
在其中发现了hashNode，这个属性是用来标记nodeFlag所属的node当前的hash值，若node有任何变化，则该hash就会发生变化。
nodeFlag中的gen，只要对应的node发生一次变化，计数就加一
nodeFlage中的bool，只要对应的node发生变化，它就变成true，表示要把数据重新刷新到DB中(以太坊用levelDB存储MTP信息)
参考：https://blog.csdn.net/ddffr/article/details/78773013







