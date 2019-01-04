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
这里会看到交易树和收据树的处理，而状态树是在header中生成一个roothash，这个有兴趣可以单独去看，后面涉及到再专门去讲。
```go
//传入的header信息会随着传入的txs和receipts发生改变
func NewBlock(header *Header, txs []*Transaction, uncles []*Header, receipts []*Receipt) *Block {
	//可以看出此处是拷贝的一个header，而td直接为0
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
		b.header.ReceiptHash = EmptyRootHash //收据树，空的hash,rlp空的时候生成的
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
这种方式只是传入了header信息，区别于第一种：第一种会传入txs,receipts，会随着这些信息的变化，header发生变换。
```go
func NewBlockWithHeader(header *Header) *Block {
	return &Block{header: CopyHeader(header)}
}
```

### block的相关方法
列出目前还没被废弃的方法。
#### 序列化相关的两个方法：DecodeRLP和EncodeRLP
该方法将解码rlp字节流，
```go
func (b *Block) DecodeRLP(s *rlp.Stream) error {
	//extblock结构体是用来存储解析结果的，其中包括header、uncles、transacitions
	var eb extblock 
	_, size, _ := s.Kind()
	if err := s.Decode(&eb); err != nil {
		return err
	}
	b.header, b.uncles, b.transactions = eb.Header, eb.Uncles, eb.Txs
	b.size.Store(common.StorageSize(rlp.ListSize(size)))
	return nil
}
```
该方法将一个block进行rlp序列化，不解释
```go
func (b *Block) EncodeRLP(w io.Writer) error {
	return rlp.Encode(w, extblock{
		Header: b.header,
		Txs:    b.transactions,
		Uncles: b.uncles,
	})
}
```

#### 其余方法
主要都是用来对外展示块信息，都是比较基础的方法，很好理解，先不要太过深的考虑每个方法什么地方使用，当梳理完这些内容后，心里自然会有底。
```go
//返回叔块信息
func (b *Block) Uncles() []*Header          { return b.uncles }

// 展示交易信息
func (b *Block) Transactions() Transactions { return b.transactions }

//根据传入的hash返回其对应的交易信息，这个就是用来展示某交易是否在当前块中
func (b *Block) Transaction(hash common.Hash) *Transaction {
	for _, transaction := range b.transactions {
		if transaction.Hash() == hash {
			return transaction
		}
	}
	return nil
}

//返回当前块所在高度（*big.Int形式返回）
func (b *Block) Number() *big.Int     { return new(big.Int).Set(b.header.Number) }

//返回当前块所在高度（uint64形式返回）
func (b *Block) NumberU64() uint64        { return b.header.Number.Uint64() }

//获取当前块的总gas上限
func (b *Block) GasLimit() uint64     { return b.header.GasLimit }

//当前实际使用了的gas
func (b *Block) GasUsed() uint64      { return b.header.GasUsed }

//获取当前块的难度值
func (b *Block) Difficulty() *big.Int { return new(big.Int).Set(b.header.Difficulty) }

//当前块的时间戳
func (b *Block) Time() *big.Int       { return new(big.Int).Set(b.header.Time) }

//用来计算难度值
func (b *Block) MixDigest() common.Hash   { return b.header.MixDigest }

//用来计算难度值
func (b *Block) Nonce() uint64            { return binary.BigEndian.Uint64(b.header.Nonce[:]) }

//布隆过滤器
func (b *Block) Bloom() Bloom             { return b.header.Bloom }

//挖出当前块的账户地址
func (b *Block) Coinbase() common.Address { return b.header.Coinbase }

//状态树的根hash
func (b *Block) Root() common.Hash        { return b.header.Root }

//父块的hash
func (b *Block) ParentHash() common.Hash  { return b.header.ParentHash }

//交易树的根hash
func (b *Block) TxHash() common.Hash      { return b.header.TxHash }

//收据树的根hash
func (b *Block) ReceiptHash() common.Hash { return b.header.ReceiptHash }

//叔块的hash，这是由两个叔块数据生成的
func (b *Block) UncleHash() common.Hash   { return b.header.UncleHash }

//额外的一些数据
func (b *Block) Extra() []byte            { return common.CopyBytes(b.header.Extra) }

//当前块头部
func (b *Block) Header() *Header { return CopyHeader(b.header) }

//返回当前块的body，body主要就是交易和叔块
func (b *Block) Body() *Body { return &Body{b.transactions, b.uncles} }

//返回当前块的大小
func (b *Block) Size() common.StorageSize {
	if size := b.size.Load(); size != nil {
		return size.(common.StorageSize)
	}
	c := writeCounter(0)
	rlp.Encode(&c, b)
	b.size.Store(common.StorageSize(c))
	return common.StorageSize(c)
}

//共识算法校验一个块的时候会用到
func (b *Block) WithSeal(header *Header) *Block {
	cpy := *header

	return &Block{
		header:       &cpy,
		transactions: b.transactions,
		uncles:       b.uncles,
	}
}
// 返回一个块
func (b *Block) WithBody(transactions []*Transaction, uncles []*Header) *Block {
	block := &Block{
		header:       CopyHeader(b.header),
		transactions: make([]*Transaction, len(transactions)),
		uncles:       make([]*Header, len(uncles)),
	}
	copy(block.transactions, transactions)
	for i := range uncles {
		block.uncles[i] = CopyHeader(uncles[i])
	}
	return block
}

//返回一个块的hash
//第一次调用时候计算，之后会被缓存
func (b *Block) Hash() common.Hash {
	if hash := b.hash.Load(); hash != nil {
		return hash.(common.Hash)
	}
	v := b.header.Hash()
	b.hash.Store(v)
	return v
}
```

## Header
介绍完整个块的大体情况后，接着来详细看看块内部的内容，先来看header

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

`Root`，`TxHash`和`ReceiptHash`，分别取自三个MPT对象：`stateTrie`, `txTrie`, 和`receiptTrie`的根节点哈希值。 分别理解为是：`账户状态树`、`交易树`、`收据树`
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
可以理解成是一个中间载体，通过前面的描述应该可以理解，这是一个块的核心部分。
```go
type Body struct {
	//交易记录
	Transactions []*Transaction
	//叔块信息
	Uncles       []*Header
}
```

## 块的排序
block.go中的最后一部分内容就是这个块排序了，代码写的有点绕，但细看以下还是很容易理解的，主要就是根据块号的大小进行排序：
```go
type Blocks []*Block
type BlockBy func(b1, b2 *Block) bool

func (self BlockBy) Sort(blocks Blocks) {
	bs := blockSorter{
		blocks: blocks,
		by:     self,
	}
	sort.Sort(bs)
}

type blockSorter struct {
	blocks Blocks
	by     func(b1, b2 *Block) bool //使用哪种方式进行拍讯
}

//重写了排序的接口
func (self blockSorter) Len() int { return len(self.blocks) }
func (self blockSorter) Swap(i, j int) {
	self.blocks[i], self.blocks[j] = self.blocks[j], self.blocks[i]
}

func (self blockSorter) Less(i, j int) bool { return self.by(self.blocks[i], self.blocks[j]) }
func Number(b1, b2 *Block) bool { return b1.header.Number.Cmp(b2.header.Number) < 0 }
```

## 总结
本章一个目的，了解一个块里到底有什么东西啊，这个块是怎么划分的，了解了这些，我们才能进一步往下走。
最起码要知道，一个块里有三种类型的MPT，一个交易树、一个收据树、一个状态树（具体干嘛，前面都有解释）。