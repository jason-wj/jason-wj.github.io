---
title: 以太坊dpos共识改造-实现dpos算法
mathjax: true
copyright: true
original: true
top: false
notice: false
date: 2019-01-27 16:09:53
categories:
  - 原创
  - 以太坊
  - 综合
tags:
  - ethereum
---
dpos是什么，为什么要改造成dpos，这些问题小编就不解释了。可参考：[委托股权证明原理(DPOS)--翻译及解读(/articles/bbe43e3f)]
对以太坊做dpos共识改造，从0开始是不可能的，这里小编参考了[美图以太坊dpos改造](https://github.com/meitu/go-ethereum)。美图实验室的改造相比较来说更加直观，网上这方面对信息不多，为此，小编参考该项目重头敲了一遍这个共识。收益颇多，也发现了很多不足的地方。
<!-- more -->
美图官方发布的改造教程解说并不多，讲述的内容也很简洁。为此，小编通过这篇文章详细解释下dpos在以太坊中的改造细节。自我总结的同时，希望能对大家有所帮助。
美图是在ethereum1.7.4上改造dpos的，而小编是在1.8.20上改造的，会有一些差异，但影响不大。
本文最后会介绍这次改造中的不足之处，后续会逐步完善。

## dpos整体框架
小编先前在[以太坊源码解读-第6.1讲-共识模块入口设计](/articles/3673b530)以及[以太坊源码解读-第6.2讲-pow共识算法实现](/articles/231042d1)中解释过，
实现一套共识算法，是需要在以太坊提供的共识引擎之下完成。
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
1. dpos_context和dpos_context_pro很容易让人感到凌乱。
后期如何将两者融合，或者用新的解决方案来处理，这是需要考虑的一个问题。
2. 整体的数据操作方法没问题，但美图并没有做太大约束，比如成为候选人的条件等。

### 总结
定义了db中要存储的前缀和具体数据，



## epoch_context

### 不足之处

## Dpos

### 不足之处

## 总结
以太坊的理念是，每个功能都模块化，但是dpos的改造，将其中的内容都被扩散到不同的模块，耦合度过高。

