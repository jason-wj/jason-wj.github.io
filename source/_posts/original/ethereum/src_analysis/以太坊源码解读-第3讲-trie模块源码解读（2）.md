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
	fstring(string) string //用来打印节点信息，没别的作用
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
这就是传说中的分支节点，会发现它里面定义了17个node，其中16个对应的16进制的0~9a~f，第17个还没搞清楚，后面清楚了再来讲。nodeFlag稍后再说。
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
在其中发现了hashNode，这个属性是用来标记nodeFlag所属的node对象本身经过rlp编码后的hash值（该hash在hashNode中同样是经过hex编码的），若node有任何变化，则该hash就会发生变化。
nodeFlag中的gen，只要对应的node发生一次变化，计数就加一
nodeFlage中的bool，只要对应的node发生变化，它就变成true，表示要把数据重新刷新到DB中(以太坊用levelDB存储MTP信息)
小编认为，对node理解到此处就可以了，对node的具体操作，要结合MPT的具体操作来掌握，这就引出了我们的下一部分需要掌握的文件：trie.go

## trie.go源码解读
我们先来了解下以太坊给trie定义的结构：
```go
type Trie struct {
	db           *Database  //trei在levelDB中
	root         node  //根结点
	originalRoot common.Hash  //从db中恢复出完整的trie

	//cachegen表示当前trie树的版本，trie每次commit，则增加1
	//cachelimit如果当前的cache时代 - cachelimit参数 大于node的cache时代，那么node会从cache里面卸载，以便节约内存。
	cachegen, cachelimit uint16
}
```
具体我们来解读一下其中的每部分：
* db
* root 可以理解为当前root指向哪个节点，初始时候，没有内容，则root=nil，表示指向nil
* originalRoot
* cachegen
* cachelimit

想要真正掌握以太坊中的trie，小编建议还是从它的测试文件node_test.go作为入口来读取源码，这里面涉及到内容如果都看懂，那相信你对MPT了解已经非常深刻了。好，那咱们一个个来看：
### 一颗空树
当为一颗空树时候，也就是trie只有一个节点，且trie.root=nil。
此时使用trie.Hash()可以返回当前整个trie树的hash值。而emptyRoot是trie预先定义的一个空节点时候的hash常量，将当前trie的hash和它比较，可以校验当前trie是否为空树。具体代码如下：
注意，这些hash是真实值，从进一步的代码中，我们是可以得知，这些hash是使用hex转换回来的hash。
```go
func TestEmptyTrie(t *testing.T) {
	var trie Trie
	res := trie.Hash() //获取当前trie的hash
	exp := emptyRoot
	if res != common.Hash(exp) {
		t.Errorf("expected %x got %x", exp, res)
	}
}
```
###  从空树中添加一个节点
添加一个节点，也就是添加叶子结点，先来看代码：
```go
func TestNull(t *testing.T) {
	var trie Trie
	value := []byte("test")  //value为字节数组
	key := make([]byte, 32) //一个32位的hash，但是其中每一位都是0
	trie.Update(key, value)
	if !bytes.Equal(trie.Get(key), value) {
		t.Fatal("wrong value")
	}
}
```
初始时，tril.root指向的是nil。
value：要把一个字符串内容为"test"的数据存入trie中
key：应该是value对应的rlp编码后的hash值
从trie.Update()进入到trie.go的insert方法中：会发现，key和value被组成一个shortNode，表示一个叶子节点，插入到trie空树中。
然后trie.root指向这个叶子节点。
可以这么理解，此时这棵树有一个根结点和一个叶子结点。
为更好说明，上个图，大体如下：
{% asset_img 1.png  空树中添加到一个节点 %}




参考：https://blog.csdn.net/ddffr/article/details/78773013







