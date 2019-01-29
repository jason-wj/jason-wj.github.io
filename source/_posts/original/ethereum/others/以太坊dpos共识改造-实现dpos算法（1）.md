---
title: 以太坊dpos共识改造-实现dpos算法（1）
mathjax: true
copyright: true
original: true
top: false
notice: false
categories:
  - 原创
  - 以太坊
  - 综合
tags:
  - ethereum
abbrlink: 2092aa9f
date: 2019-01-29 15:00:53
---
dpos是什么，为什么要改造成dpos，这些问题小编就不解释了。可参考：[委托股权证明原理(DPOS)--翻译及解读(/articles/bbe43e3f)]
对以太坊做dpos共识改造，从0开始是不可能的，这里小编参考了[美图以太坊dpos改造](https://github.com/meitu/go-ethereum)。美图实验室的改造相比较来说更加直观，网上这方面对信息不多，为此，小编参考该项目重头敲了一遍这个共识。收益颇多，也发现了很多不足的地方。
<!-- more -->
美图官方发布的改造教程解说并不多，讲述的内容也很简洁。为此，小编通过这篇文章详细解释下dpos在以太坊中的改造细节。自我总结的同时，希望能对大家有所帮助。
美图是在ethereum1.7.4上改造dpos的，而小编是在1.8.20上改造的，会有一些差异，但影响不大。
本文最后会介绍这次改造中的不足之处，后续会逐步完善。

## 本文源码下载
本文是在以太坊基础上改造的，整个源码迟些时候会放在github上，其实这源码就是美图官方的，只是小编根据自己的想法做了一些改动。
每个阶段的改动，都会单独切换一个分支。
分阶段实现，更容易理解这次改造的过程。
dpos相关源码位置都有对应的单元测试，可快速验证每个方法。
关键地方，小编都加入了中文注释。

## dpos整体框架
小编先前在[以太坊源码解读-第6.1讲-共识模块入口设计](/articles/3673b530)以及[以太坊源码解读-第6.2讲-pow共识算法实现](/articles/231042d1)中解释过，
实现一套共识算法，是需要在以太坊提供的共识引擎之下完成。
这里先说一下本文dpos的全局参数：
1. 每隔10秒钟生成一个块，
2. 每一天（24小时）进行一轮新的选举
3. 验证人有21个
4. 验证人最小人数为15人（计算方式：21*2/3+1）

美图DPOS的实现方案如下图所示：
{% asset_img 1.png  Dpos算法整体结构 %}
注意区分候选人和验证人，`验证人是候选人之一，但候选人不一定是验证人`
从上图可以看出，分成三大部分，这里简述一下其中每部分的作用：
1. dpos_context和dpos_context_pro：用来存储和操作验证人、投票、候选人等信息，是通过trie来将这些信息存储在leveldb中。这些信息主要分为5部分：
    1. EpochTrie：记录当前周期的验证人列表
    2. DelegateTrie：记录每个候选人对应的投票人，一个候选人有不同的投票人
    3. VoteTrie：记录投票人对应的候选人，每个投票人只能对应一个候选人
    4. MintCntTrie：记录验证人在当前周期内的出块数
    5. CandidateTrie：候选人集合，其中包含了验证人
2. epoch_context：dpos验证阶段的处理，图中可知，主要完成四部分内容：
    1. CountVotes:获取候选人及其对应投票数（积分）
    2. KickoutValidator：踢除不合格的验证人
    3. LookupValidator：获取当前验证人，就是确定应该由哪个验证人来出块
    4. TryElec：发起新一轮选举，从候选人中选出验证人
3. Dpos：实现共识引擎，dpos的主体

来看看dpos算在在以太坊中的结构：
```sh
.
|____params.go
|____context
| |____dpos_context.go
| |____dpos_context_proto.go
|____dpos_test.go
|____api.go
|____epoch_context_test.go
|____epoch_context.go
|____dpos.go
```
正对应上面提到的3部分内容。

整个实现过程，小编也建议按照上面1、2、3的顺序来实现。下面小编就按照这个步骤来一一讲解。

## dpos_context和dpos_context_pro
上面小编说过，dpos选举的数据信息都会以trie的形式保存在以太坊的leveldb之中。dpos_context和dpos_context_pro就是用来处理这一过程的。
就是说，这一过程是对trie树的操作过程
小编想要说的是dpos_context_pro是为了方便外部对接而通过gencodec将dpos_context自动转换生成的。也就是说真正的核心是dpos_context。
理解dpos_context.go中内容尤为重要。

先来看看结构体其结构体和重要参数：
```go
var (
	epochPrefix     = []byte("epoch-")
	delegatePrefix  = []byte("delegate-")
	votePrefix      = []byte("vote-")
	candidatePrefix = []byte("candidate-")
	mintCntPrefix   = []byte("mintCnt-")
)

type DposContext struct {
	EpochTrie     *trie.Trie //记录每个周期的验证人列表
	DelegateTrie  *trie.Trie //记录候选人->投票人
	VoteTrie      *trie.Trie //记录投票人->候选人
	CandidateTrie *trie.Trie //记录候选人列表
	MintCntTrie   *trie.Trie //记录验证人在周期内的出块数目

	db ethdb.Database
}
```
很直观，dpos的五个前缀，后续操作的数据将会在这些前缀之后保存，索引很容易找到结果。
以太坊trie树是一种kv类型对，上面提到的五种trie，具体数据是如下格式来保存：
1. EpochTrie数据格式：
   key：epoch-validator
   value：xxxxxxxxxxxxxxx (`ps`：xxxxxxxxxxxxxxx表示经过rlp序列化的所有验证人地址)
2. DelegateTrie数据格式：
   key：delegate-候选人地址-投票人地址
   value：投票人地址
3. VoteTrie数据格式：
   key：vote-投票人地址
   value：候选人地址
4. CandidateTrie数据格式：
   key：candidate-候选人地址
   value；候选人地址
5. MintCntTrie数据格式：
   key；mintCnt-周期数（2进制）-验证人
   value：当前验证人本周期总共挖块数（2进制å）
`ps`：此处是小编自己理解，可能不正确：`其中，第5个加入周期数的目的：若不加入周期数，则这五棵trie经过rlp生成的hash，每一轮有可能都一样，对其签名会造成很大困扰`


接着看看DposContext的几个重要方法：

### Copy():复制当前dpos状态
将当前DposContext对象复制出来，其实就是复制出当前Dpos状态，一般用于快照操作。拿到某时刻的状态。

### Snapshot():快照，同上
快照。其实就是调用了上面提到的Copy()方法。

### RevertToSnapShot()：快照读取
这个其实就是将快照信息转移到主体DposContext中，描述不好理解，贴代码，一目了然：
```go
func (d *DposContext) RevertToSnapShot(snapshot *DposContext) {
	d.EpochTrie = snapshot.EpochTrie
	d.DelegateTrie = snapshot.DelegateTrie
	d.CandidateTrie = snapshot.CandidateTrie
	d.VoteTrie = snapshot.VoteTrie
	d.MintCntTrie = snapshot.MintCntTrie
}
```

### KickoutCandidate()：踢除候选人
该方法用于踢掉某个候选人（候选人有可能是验证人）
该方法在这里就不贴具体代码了，
删除某个候选人，需要涉及到三个trie：
1. CandidateTrie：删掉对应候选人
2. DelegateTrie：删掉候选人何其对应的投票人
3. VoteTrie：删掉投票人对应的候选人

从中也可以看出：`一个候选人可以有不同的投票人；一个投票人只能为一个候选人投票`

### BecomeCandidate()：成为候选人
任何拥有以太坊账户的人，都可以成为候选人。
当然，真正线上的这一过程，是需要严格控制的。

### Delegate()：为某候选人投票
每轮选举，一个投票人只能为一个候选人投票，若该投票人已经为某候选人投票，想要再给新的候选人投票，则会覆盖原先旧的投票记录

### UnDelegate()：取消某投票人投票记录
1. 判断投票人是否已经投过票，以及给谁投的票
2. 投票人不是给候选人candidate投的票，则不可以做取消操作
3. 将候选人对应投票人删除
4. 将投票人对应候选人删除

### GetValidators()：获取验证人列表
获取当前验证人列表

### SetValidators()：设置当前验证人
设置当前验证人

### 不足之处
1. dpos_context和dpos_context_pro很容易让人感到凌乱，这是因为要跟别的模块交互的缘故，毕竟header只有hash，并没有具体块数据来支撑trie。
后期如何将两者融合，或者用新的解决方案来处理，这是需要考虑的一个问题。
2. 整体的数据操作方法没问题，但并没有做太大约束，比如成为候选人的条件等，当然，这属于dpos细节设计过程，这需要自行根据需要来设计。

### 小节
这一部分的实现，小编没有给出具体源码，主要是考虑到篇幅，另外一个原因是实现本身并没有太复杂的逻辑。
定义了db中要存储的前缀和具体数据。这部分内容还是很容易理解的。
trie由于新增了前缀操作，为此做了一些改动，这个改动在本文最后给出。

## epoch_context
这一部分属于对验证人的操作过程，比如统计投票数、踢除不合格验证人等操作。属于dpos最重要的一部分。目前提供了以下几个方法，这里一一来详细说明

### CountVotes() 统计投票数
一个候选人会拥有多个投票人，该方法目的就是统计出所有候选人中，每个候选人分别拥有多少投票数。
目前是这样进行统计的：
1. 通过candidateTrie获取所有候选人
2. 通过delegateTrie检测某候选人是否有投票（备注：delegateTrie表示候选人对应的投票人，也就是只要检测该候选人是否有投票人即可）
3. 一个候选人有多个投票人，将该候选人所有的投票人的账户余额相加的结果，就是当前候选人的投票数，比如每个投票人当前账户分别拥有1000wei，该候选人有5个投票人，则该候选人的投票数就是5000，将`候选人->投票数`记录在map
4. 将map结果返回，其中就是所有候选人投票数

### KickoutValidator() 踢除不合格验证人
踢除当前周期内不合格的验证人，
如果一个周期内，一个验证人的出块数不够50%，则将其踢出。比如：一周期是24小时（86400秒），每隔10秒产生一个块，总共有21个验证人，则86400/10/21*0.5=206块，就是说，一个验证人一个周期生成的块数不足206块，则该验证人在新的一轮选举中被踢除。
要确保踢出验证人后，剩余的所有候选人的人数在一个安全阈值内，一般是要满足总验证人的2/3

### LookupValidator() 获取当前验证人,也就是调度验证人
该方法是根据当前周期以及出块时间从验证人列表中选择一个正确的验证人。

### TryElect() 开始选举验证人
该过程用于从候选人中选择验证人。
1. 若上一个块的周期和当前块的周期不是同一周期，则触发选举 
2. 获取上一周期验证人以及对应的出块数
3. 踢除上一周期不合格的验证人
4. 获取所有候选人及其对应的投票数，选择最高21位作为验证人
5. 将21位验证人顺序随机打乱

### 不足之处
候选人数量需要限制

### 小节
本小节主要是对验证人的操作，目的就是踢掉不合格的验证人，选择新的验证人。
这些都属于dpos内部逻辑。

## Dpos
这个模块是用来实现以太坊共识引擎接口的。
需要知道，dpos中，不需要叔块概念、不需要难度概念。
先来看看Dpos的结构体：
```go
type Dpos struct {
	config *DposConfig
	db     ethdb.Database //存储验证人相关信息

	signer common.Address //打包人
	signFn SignerFn

	//ARCCache是一个线程安全的固定大小的自适应替换缓存工具。
	//ARC是对标准LRU缓存的一种改进，它跟踪使用的频率和最近情况。
	//这样就避免了对新条目的突然访问，无法将经常使用的旧条目逐出。
	//它为标准的LRU缓存增加了一些额外的跟踪开销，计算上它大约是成本的2倍，并且额外的内存开销与缓存的大小成线性关系。
	//ARC已获得IBM专利，但类似于需要设置参数的TwoQueueCache（2Q,双队列缓存).
	signatures           *lru.ARCCache //等待验签的块
	confirmedBlockHeader *types.Header //被确认了的块头部
	mu   sync.RWMutex
	stop chan bool
}
```
主要的方法如下所示。

### VerifyHeader() 验证头部
验证块头部信息。
这里重要的一点是`header.Extra`数据，其中包含有ecp256k1签名信息，需要确保其中该信息。

### VerifySeal() 验证块签名信息
1. 创世块不验证
2. 根据块的生成时间，获取该块的验证人地址，判断该验证人是否为块的签名人
3. 另外重要的一点是：updateConfirmedBlockHeader()，这一步要更新待确认块的位置，让用户知道，当前哪些块被确认了，哪些块还没有。

### Prepare() 初始化准备
对头部信息设置

### Finalize() 奖励分发并进行新的选举
1. 为块生成者分发奖励
2. 若父块和当前块是同一周期，则不选举；否则进行选举

### Seal() 打包签名
对当前块进行签名
签名信息保存在header.extra中

### SealHash() 返回head头部hash
这个方法是用来生成一个块头部的hash，来看看源码：
```go
func (d *Dpos) SealHash(header *types.Header) (hash common.Hash) {
	hasher := sha3.NewLegacyKeccak256()
	rlp.Encode(hasher, []interface{}{
		header.ParentHash,
		header.UncleHash,
		header.Validator,
		header.Coinbase,
		header.Root,
		header.TxHash,
		header.ReceiptHash,
		header.Bloom,
		header.Difficulty,
		header.Number,
		header.GasLimit,
		header.GasUsed,
		header.Time,
		header.Extra[:len(header.Extra)-65], //这里记录签名信息
		header.MixDigest,
		header.Nonce,
		header.DposContext.Root(),
	})
	hasher.Sum(hash[:0])
	return hash
}
```
使用rlp编码，然后生成一个hash，这个就代表一个head，其中dpos部分，发现这样一行代码：`header.DposContext.Root()`，这表示dpos中的五棵trie被编码为一个hash存入其中。

### CheckValidator() 检测验证人是否有效
1. 上一个块和当前块时间是否正确
2.根据块当前时间获取验证人，然后跟header.signer比较是否一致

### 小节
这一部分主要就是实现共识引擎的接口，相比较于pow，dpos的实现要容易很多

## 总结
1. 以太坊的理念是，每个功能都模块化，但是dpos的改造，将其中的内容都被扩散到不同的模块，耦合度过高。
2. 本文中，更多描述的是dpos在以太坊共识模块中的实现，这个过程相对来说要好理解，但是，如果将以太坊切换为dpos，这才是工程中的难点，这个过程小编也正在验证，后续会发出新的文章来专门讲解这一过程。
3. 补充一下，上面提到的每个模块，都有对应的单元测试，可以快速验证每个方法。

