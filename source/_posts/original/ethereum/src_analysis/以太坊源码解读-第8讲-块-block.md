---
title: 以太坊源码解读-第8讲-块(block)
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
abbrlink: '10e60082'
date: 2018-12-16 20:00:47
---
## 前言
`块`贯穿了这个区块链的始终，前面的几篇文章总讲到块的生成，但具体到底怎么一回事，一直没提。
因此，小编认为还是有必要把一个block的细节梳理一下，本文主要是讲`core->types->block.go`文件中的内容。
<!-- more -->
一个块分为head和body，而body中又分为交易记录和叔块信息，大体分布如下：
 {% asset_img 1.jpg  一个块的整体结构 %}
下面一一来解释

## Header
### 结构体
来看看一个块的head中都有哪些：
参考：https://blog.csdn.net/niyuelin1990/article/details/80423823
https://blog.csdn.net/qq_18252955/article/details/80179208
```go
type Header struct {
	// 指向父区块(parentBlock)的指针。除了创世块(Genesis Block)外，每个区块有且只有一个父区块。
	ParentHash  common.Hash    `json:"parentHash"       gencodec:"required"`

	// Block结构体的成员uncles的RLP哈希值。uncles是一个Header数组，它的存在，颇具匠心。
	UncleHash   common.Hash    `json:"sha3Uncles"       gencodec:"required"`

	// 挖掘出这个区块的作者地址。在每次执行交易时系统会给与一定补偿的Ether，这笔金额就是发给这个地址的。
	Coinbase    common.Address `json:"miner"            gencodec:"required"`

	//StateDB中的“state Trie”的根节点的RLP哈希值。Block中，每个账户以stateObject对象表示，账户以Address为唯一标示，其信息在相关交易(Transaction)的执行中被修改。所有账户对象可以逐个插入一个Merkle-PatricaTrie(MPT)结构里，形成“state Trie”。
	Root        common.Hash    `json:"stateRoot"        gencodec:"required"`

	//Block中 “tx Trie”的根节点的RLP哈希值。Block的成员变量transactions中所有的tx对象，被逐个插入一个MPT结构，形成“tx Trie”。
	TxHash      common.Hash    `json:"transactionsRoot" gencodec:"required"`

	//可以用来确认一笔交易成功与否，Block中的 “Receipt Trie”的根节点的RLP哈希值。Block的所有Transaction执行完后会生成一个Receipt数组，这个数组中的所有Receipt被逐个插入一个MPT结构中，形成”Receipt Trie”。
	ReceiptHash common.Hash    `json:"receiptsRoot"     gencodec:"required"`

	//布隆过滤器，用来快速判断一个参数Log对象是否存在于一组已知的Log集合中。
	Bloom       Bloom          `json:"logsBloom"        gencodec:"required"`

	//区块的难度。Block的Difficulty由共识算法基于parentBlock的Time和Difficulty计算得出，它会应用在区块的‘挖掘’阶段。
	Difficulty  *big.Int       `json:"difficulty"       gencodec:"required"`

	//块号 Block的Number等于其父区块Number +1。
	Number      *big.Int       `json:"number"           gencodec:"required"`

	//区块内所有Gas消耗的理论上限。该数值在区块创建时设置，与父区块有关。具体来说，根据父区块的GasUsed同GasLimit * 2/3的大小关系来计算得出。
	GasLimit    uint64         `json:"gasLimit"         gencodec:"required"`
	
	//区块内所有Transaction执行时所实际消耗的Gas总和。
	GasUsed     uint64         `json:"gasUsed"          gencodec:"required"`
	
	//区块“应该”被创建的时间。由共识算法确定，一般来说，要么等于parentBlock.Time + 15s，要么等于当前系统时间。
	Time        *big.Int       `json:"timestamp"        gencodec:"required"`
	
	//区块相关的附加信息
	Extra       []byte         `json:"extraData"        gencodec:"required"`

	//该哈希值与Nonce值一起能够证明在该区块上已经进行了足够的计算（用于验证该区块挖矿成功与否的Hash值
	MixDigest   common.Hash    `json:"mixHash"          gencodec:"required"`
	
	//一个64bit的哈希数，它被应用在区块的”挖掘”阶段，并且在使用中会被修改。
	Nonce       BlockNonce     `json:"nonce"            gencodec:"required"`
}
```
其中的`gencodec`不是本文重点，有兴趣的可以单独去了解下这是什么，其实它主要就是扩展json的使用。
`有时间再解释`
