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
块贯穿了这个区块链的始终，前面的几篇文章总讲到块的生成，但具体到底怎么一回事，一直没提。
因此，小编认为还是有必要把一个block的细节梳理一下，本文主要是讲`core->types->block.go`文件中的内容。
<!-- more -->
一个块分为head和body，我们分开来讲

## Header
### 结构体
来看看一个块的head中都有哪些：
```go
type Header struct {
	ParentHash  common.Hash    `json:"parentHash"       gencodec:"required"`
	UncleHash   common.Hash    `json:"sha3Uncles"       gencodec:"required"`
	Coinbase    common.Address `json:"miner"            gencodec:"required"`
	Root        common.Hash    `json:"stateRoot"        gencodec:"required"`
	TxHash      common.Hash    `json:"transactionsRoot" gencodec:"required"`
	ReceiptHash common.Hash    `json:"receiptsRoot"     gencodec:"required"`
	Bloom       Bloom          `json:"logsBloom"        gencodec:"required"`
	Difficulty  *big.Int       `json:"difficulty"       gencodec:"required"`
	Number      *big.Int       `json:"number"           gencodec:"required"`
	GasLimit    uint64         `json:"gasLimit"         gencodec:"required"`
	GasUsed     uint64         `json:"gasUsed"          gencodec:"required"`
	Time        *big.Int       `json:"timestamp"        gencodec:"required"`
	Extra       []byte         `json:"extraData"        gencodec:"required"`
	MixDigest   common.Hash    `json:"mixHash"          gencodec:"required"`
	Nonce       BlockNonce     `json:"nonce"            gencodec:"required"`
}
```
其中的`gencodec`不是本文重点，有兴趣的可以单独去了解下这是什么，其实它主要就是扩展json的使用。
`有时间再解释`
