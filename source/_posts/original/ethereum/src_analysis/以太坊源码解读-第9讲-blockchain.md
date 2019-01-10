---
title: 以太坊源码解读-第9讲-blockchain
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
abbrlink: a749acc8
date: 2019-01-04 17:25:20
---
## 前言
多条链分叉时候，如何选择？链中的块如何验证？每个块是如何组合的？怎样插入？还原？。。。
要理清这些问题，就必须了解`core->blockchain.go`其中的原理
<!-- more -->
这里代表的就是区块链的精髓，会牵涉到多个文件，我们一一来介绍。

## 先来看blockchain结构体
描述了一条链的结构，如下：
```go
type BlockChain struct {
	//硬分叉的一些配置
	chainConfig *params.ChainConfig
	//主要是trie节点的缓存配置，其中包括是否允许缓存、trie最多允许缓存的容量(MB)、缓存flush超时时间
	cacheConfig *CacheConfig       
	//用来存储最终数据的地方
	db     ethdb.Database 
	//根据块号优先级来对其中的trie树进行gc
	triegc *prque.Prque
	// trie进行gc前的延时
	gcproc time.Duration  
	//一条链的头部信息，这个是非线程安全的，具体后面再来分析
	hc            *HeaderChain

	// 下面几个个是一些事件，后面再来补充
	rmLogsFeed    event.Feed
	chainFeed     event.Feed
	chainSideFeed event.Feed
	chainHeadFeed event.Feed
	logsFeed      event.Feed
	scope         event.SubscriptionScope
	//创世区块
	genesisBlock  *types.Block

	//全局的一个读写锁，用来锁定链的操作
	mu      sync.RWMutex 
	//插入锁
	chainmu sync.RWMutex 
	//待定
	procmu  sync.RWMutex

	//下面这些后面再来解释
	checkpoint       int
	//当前的区块头    
	currentBlock     atomic.Value
	// 当前的快速同步的区块头. 
	currentFastBlock atomic.Value 

	//处理块和编码使用一些缓存
	stateCache    state.Database 
	bodyCache     *lru.Cache     
	bodyRLPCache  *lru.Cache     
	receiptsCache *lru.Cache     
	blockCache    *lru.Cache 
	//暂时还不能插入的区块存放位置
	futureBlocks  *lru.Cache     

	//链推出管道
	quit    chan struct{} 
	//原子操作，暂时不确定要干嘛
	running int32 
	//用于中断块处理过程        
	procInterrupt int32
	//等待链的关闭          
	wg            sync.WaitGroup 

	//共识引擎
	engine    consensus.Engine
	//用于处理块的接口
	processor Processor 
	//块和状态验证接口
	validator Validator 
	vmConfig  vm.Config

	//错误块的缓存
	badBlocks      *lru.Cache
	//一个方法，用来判断是否需要保留某个块              
	shouldPreserve func(*types.Block) bool 
}
```

## 链的初始化
生成一个全节点的链的入口，这是使用数据库里面的信息来构造的，来看看这个方法具体做了哪些内容：
```go
func NewBlockChain(db ethdb.Database, cacheConfig *CacheConfig, chainConfig *params.ChainConfig, engine consensus.Engine, vmConfig vm.Config, shouldPreserve func(block *types.Block) bool) (*BlockChain, error) {
	if cacheConfig == nil {
		//设置默认的缓存参数
		cacheConfig = &CacheConfig{
			//默认节点256T
			TrieNodeLimit: 256 * 1024 * 1024,
			TrieTimeLimit: 5 * time.Minute,
		}
	}
	bodyCache, _ := lru.New(bodyCacheLimit)
	bodyRLPCache, _ := lru.New(bodyCacheLimit)
	receiptsCache, _ := lru.New(receiptsCacheLimit)
	blockCache, _ := lru.New(blockCacheLimit)
	futureBlocks, _ := lru.New(maxFutureBlocks)
	badBlocks, _ := lru.New(badBlockLimit)

	bc := &BlockChain{
		chainConfig:    chainConfig,
		cacheConfig:    cacheConfig,
		db:             db,
		triegc:         prque.New(nil),
		stateCache:     state.NewDatabase(db),
		quit:           make(chan struct{}),
		shouldPreserve: shouldPreserve,
		bodyCache:      bodyCache,
		bodyRLPCache:   bodyRLPCache,
		receiptsCache:  receiptsCache,
		blockCache:     blockCache,
		futureBlocks:   futureBlocks,
		engine:         engine,
		vmConfig:       vmConfig,
		badBlocks:      badBlocks,
	}
	bc.SetValidator(NewBlockValidator(chainConfig, bc, engine))
	bc.SetProcessor(NewStateProcessor(chainConfig, bc, engine))

	var err error
	bc.hc, err = NewHeaderChain(db, chainConfig, engine, bc.getProcInterrupt)
	if err != nil {
		return nil, err
	}
	bc.genesisBlock = bc.GetBlockByNumber(0)
	if bc.genesisBlock == nil {
		return nil, ErrNoGenesis
	}
	if err := bc.loadLastState(); err != nil {
		return nil, err
	}
	// Check the current state of the block hashes and make sure that we do not have any of the bad blocks in our chain
	for hash := range BadHashes {
		if header := bc.GetHeaderByHash(hash); header != nil {
			// get the canonical block corresponding to the offending header's number
			headerByNumber := bc.GetHeaderByNumber(header.Number.Uint64())
			// make sure the headerByNumber (if present) is in our current canonical chain
			if headerByNumber != nil && headerByNumber.Hash() == header.Hash() {
				log.Error("Found bad hash, rewinding chain", "number", header.Number, "hash", header.ParentHash)
				bc.SetHead(header.Number.Uint64() - 1)
				log.Error("Chain rewind was successful, resuming normal operation")
			}
		}
	}
	// Take ownership of this particular state
	go bc.update()
	return bc, nil
}
```