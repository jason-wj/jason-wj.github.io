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
先来看看一个块有哪些内容：
 {% asset_img 1.jpg  一个块的整体结构 %}
 从图中，我们大体将一个块分为两部分，左半部分为Head，又半部分为Body.
 Header相对轻量，涵盖了Block的所有属性，包括特征标示，前向指针，和内部数据集的验证哈希值等；body相对重量，持有内部数据集。每个Block的Header部分，Body部分，以及一些特征属性，都以[k,v]形式单独存储在底层数据库中。

## Block
上面大概提到Body中有两部分内容，但真实的实现中，还有一些别的内容，如下结构。
{% asset_img 2.jpg  一个块的整体结构 %}
下面是一个完整块的结构体描述，我们来看看一个块中具体到底有哪些内容：
```go
type Block struct {
	//头部
	header       *Header
	//叔块
	uncles       []*Header
	//交易信息
	transactions Transactions

	// 缓存数据操作
	hash atomic.Value
	size atomic.Value

	//难度值相关，具体使用不明确，后面再来补坑
	td *big.Int

	//内部使用，暂不明确，后面再来补坑
	ReceivedAt   time.Time
	ReceivedFrom interface{}
}
```
### 第一种生成块的方式
根据传入信息生成一个完整块，
这里会看到交易树和收据树的处理，而状态树是在header中生成一个roothash，这个有兴趣可以单独去看，后面涉及到再专门去讲
```go
func NewBlock(header *Header, txs []*Transaction, uncles []*Header, receipts []*Receipt) *Block {
	//可以看出此处是复制的一个header，而td直接为0
	b := &Block{header: CopyHeader(header), td: new(big.Int)}

	if len(txs) == 0 {
		b.header.TxHash = EmptyRootHash //空的hash,rlp空的时候生成的
	} else {
		//这里可以看出，只要有一笔交易被篡改，交易树的hash就会变
		b.header.TxHash = DeriveSha(Transactions(txs)) //根据传入的信息生成交易树的hash，
		b.transactions = make(Transactions, len(txs)) 
		copy(b.transactions, txs)//具体的交易信息保存在块中
	}

	if len(receipts) == 0 {
		b.header.ReceiptHash = EmptyRootHash //空的hash,rlp空的时候生成的
	} else {
		b.header.ReceiptHash = DeriveSha(Receipts(receipts)) //收据树列表hash
		b.header.Bloom = CreateBloom(receipts) //根据收据树生成一个布隆过滤器
	}

	if len(uncles) == 0 {
		b.header.UncleHash = EmptyUncleHash
	} else {
		b.header.UncleHash = CalcUncleHash(uncles) //将所有叔块生成一个hash
		b.uncles = make([]*Header, len(uncles))
		for i := range uncles {
			b.uncles[i] = CopyHeader(uncles[i]) //拷贝叔块
		}
	}
	return b
}
```

### 第二种生成块的方式

## Header
这是一个块的头部

### 结构体
来看看一个块的head中都有哪些：
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

	//Block中 交易树的根hash，由所有的交易生成的。“tx Trie”的根节点的RLP哈希值。Block的成员变量transactions中所有的tx对象，被逐个插入一个MPT结构，形成“tx Trie”。
	TxHash      common.Hash    `json:"transactionsRoot" gencodec:"required"`

	//收据树。可以用来确认一笔交易成功与否，Block中的 “Receipt Trie”的根节点的RLP哈希值。Block的所有Transaction执行完后会生成一个Receipt数组，这个数组中的所有Receipt被逐个插入一个MPT结构中，形成”Receipt Trie”。
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

Root，TxHash和ReceiptHash，分别取自三个MPT类型对象：stateTrie, txTrie, 和receiptTrie的根节点哈希值。 
分别理解为是：`账户状态树`、`交易树`、`收据树`
receiptTrie 必须在Block的所有交易执行完成才能生成；txTrie 理论上只需tx数组transactions即可，不过依然被限制在所有交易执行完后才生成；最有趣的是stateTrie，由于它存储了所有账户的信息，比如余额，发起交易次数，虚拟机指令数组等等，所以随着每次交易的执行，stateTrie 其实一直在变化，这就使得Root值也在变化中
> [以太坊系列---Block核心数据结构](https://blog.csdn.net/niyuelin1990/article/details/80423823)

### header对应的方法
只有两个方法

#### Hash()
该方法主要是将头部内容生成一个hash，过程是：先将头部rlp序列化，再用keccak256将其生成一个32位的hash值，这是该方法的代码：
```go
func (h *Header) Hash() common.Hash {
	//rlpHash方法就是为了实现：将头部rlp序列化，再用keccak256将其生成一个32位的hash值
	return rlpHash(h) 
}
```

#### Size()
该方法用于近似的估算和限制各种缓存的消耗，主要是计算结构体中，指针类型数据的消耗
func (h *Header) Size() common.StorageSize {
	return common.StorageSize(unsafe.Sizeof(*h)) + common.StorageSize(len(h.Extra)+(h.Difficulty.BitLen()+h.Number.BitLen()+h.Time.BitLen())/8)
}

## Body
body是一个简单的(可变的、不安全的)数据容器，用于存储和移动区块的数据内容(交易列表和叔块)在一起
可以理解成是一个中间载体，但不是块的一部分。
```go
type Body struct {
	//交易记录
	Transactions []*Transaction
	//叔块信息
	Uncles       []*Header
}
```