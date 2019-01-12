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
	//主要是trie节点的缓存配置，其中包括是否允许缓存、trie最多允许缓存的容量(MB)、缓存刷新到磁盘的时间
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

## 链的构建过程
生成一个全节点的链的入口，这是使用数据库里面的信息来构造的，来看看这个方法具体做了哪些内容：
```go
func NewBlockChain(db ethdb.Database, cacheConfig *CacheConfig, chainConfig *params.ChainConfig, engine consensus.Engine, vmConfig vm.Config, shouldPreserve func(block *types.Block) bool) (*BlockChain, error) {
	if cacheConfig == nil {
		//设置默认的缓存参数
		cacheConfig = &CacheConfig{
			//默认节点256T
			TrieNodeLimit: 256 * 1024 * 1024,
			//将缓存刷新到磁盘的时间
			TrieTimeLimit: 5 * time.Minute,
		}
	}
	//初始化缓存
	bodyCache, _ := lru.New(bodyCacheLimit)
	bodyRLPCache, _ := lru.New(bodyCacheLimit)
	receiptsCache, _ := lru.New(receiptsCacheLimit)
	blockCache, _ := lru.New(blockCacheLimit)
	futureBlocks, _ := lru.New(maxFutureBlocks)
	badBlocks, _ := lru.New(badBlockLimit)
	//链结构体赋值
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
	//设置验证机制，这里会调用block_validator.go文件中的内容
	bc.SetValidator(NewBlockValidator(chainConfig, bc, engine))
	//设置处理块机制，这里会调用state_processor.go文件中的内容
	bc.SetProcessor(NewStateProcessor(chainConfig, bc, engine))

	var err error
	//链的头部，这块牵涉到headerchain.go文件
	bc.hc, err = NewHeaderChain(db, chainConfig, engine, bc.getProcInterrupt)
	if err != nil {
		return nil, err
	}
	//创世块的设置
	bc.genesisBlock = bc.GetBlockByNumber(0)
	if bc.genesisBlock == nil {
		return nil, ErrNoGenesis
	}
	//加载最新状态
	if err := bc.loadLastState(); err != nil {
		return nil, err
	}
	// 手动检查链中是否有坏块，BadHashes中手动存入一些坏块地址，一般硬分叉使用
	for hash := range BadHashes {
		if header := bc.GetHeaderByHash(hash); header != nil {
			//获取规范的区块链上面同样高度的区块头,
			//如果这个区块头确实是在我们的规范的区块链上的话,我们需要回滚到这个区块头的高度 - 1，此时高度为最新块
			//要确保规范块里没有坏块（硬分叉的块、非法块）
			//header.Number指向当前最新块
			headerByNumber := bc.GetHeaderByNumber(header.Number.Uint64())
			if headerByNumber != nil && headerByNumber.Hash() == header.Hash() {
				log.Error("Found bad hash, rewinding chain", "number", header.Number, "hash", header.ParentHash)
				//会一直往上一个块回滚，直到稳定
				bc.SetHead(header.Number.Uint64() - 1) 
				log.Error("Chain rewind was successful, resuming normal operation")
			}
		}
	}
	//异步，将未来块（就是还在缓存中暂时没加入的块）加入到规范链中
	//其中会涉及到一个块的插入概念
	go bc.update() 
	return bc, nil
}
```
这里面最重要的几个部分：
1. 坏块的检查，
2. 是从db中加载最新状态的过程，也就是`bc.loadLastState()`这个方法，
3. 块的插入，`InsertChain()`方法

接下来一一介绍这几部分内容

### 坏块的检查
BadHashes 可以手工禁止接受一些区块的hash值.在blocks.go里面.
可以避免一些硬分叉问题，保证链的正统性。

### bc.loadLastState()加载最新状态
从db中加载链的最新状态，这部分代码量也非常大，如下：
```go
func (bc *BlockChain) loadLastState() error {
	// 获取最新一个块的hash头部
	head := rawdb.ReadHeadBlockHash(bc.db)
	if head == (common.Hash{}) {
		log.Warn("Empty database, resetting chain")
		return bc.Reset() //使用创世块初始化链
	}
	// 根据块的hash获取当前块
	currentBlock := bc.GetBlockByHash(head)
	if currentBlock == nil {
		log.Warn("Head block missing, resetting chain", "hash", head)
		return bc.Reset() //使用创世块初始化链
	}
	// 看当前块的hash和db中记录能否联系上，不能则一直回滚
	if _, err := state.New(currentBlock.Root(), bc.stateCache); err != nil {
		log.Warn("Head state missing, repairing chain", "number", currentBlock.Number(), "hash", currentBlock.Hash())
		//repair，会一直回滚，直到能够获取到状态的树
		if err := bc.repair(&currentBlock); err != nil {
			return err
		}
	}
	// 设置最新块
	bc.currentBlock.Store(currentBlock)

	// 设置当前链head
	currentHeader := currentBlock.Header()
	if head := rawdb.ReadHeadHeaderHash(bc.db); head != (common.Hash{}) {
		if header := bc.GetHeaderByHash(head); header != nil {
			currentHeader = header
		}
	}
	bc.hc.SetCurrentHeader(currentHeader)

	// 设置轻量级的块
	bc.currentFastBlock.Store(currentBlock)
	if head := rawdb.ReadHeadFastBlockHash(bc.db); head != (common.Hash{}) {
		if block := bc.GetBlockByHash(head); block != nil {
			bc.currentFastBlock.Store(block)
		}
	}

	// 日志展示
	...
	return nil
}
```

### InsertChain()，块的插入
插入区块链尝试把给定的区块插入到规范的链条,或者是创建一个分叉. 如果发生错误,那么会返回错误发生时候的index和具体的错误信息.
先来看插入块的入口：
```go
//这是一个总的方法，分为两部分，一部分用于插入多个块，
//另一部分属于累计的事件，将会被触发
func (bc *BlockChain) InsertChain(chain types.Blocks) (int, error) {
	n, events, logs, err := bc.insertChain(chain)
	bc.PostChainEvents(events, logs)
	return n, err
}
```
插入部分的实现，这部分代码量有点大，但必须理解（插入的块必须连续）：
```go
//insertChain方法会执行区块链插入,并收集事件信息. 因为需要使用defer来处理解锁,所以把这个方法作为一个单独的方法.
func (bc *BlockChain) insertChain(chain types.Blocks) (int, []interface{}, []*types.Log, error) {
	if len(chain) == 0 {
		return 0, nil, nil, nil
	}
	// 做一个完整性检查，提供的链实际上是有序的和相互链接的
	for i := 1; i < len(chain); i++ {
		if chain[i].NumberU64() != chain[i-1].NumberU64()+1 || chain[i].ParentHash() != chain[i-1].Hash() {
			//不满足基本规范，直接返回
			...
			return 0, nil, nil, fmt.Errorf("为节省篇幅，这个描述改动。表示：链不规范")
		}
	}
	// 锁机制
	bc.wg.Add(1)
	defer bc.wg.Done()

	bc.chainmu.Lock()
	defer bc.chainmu.Unlock()

	//使用队列来处理事件，这效果通常比用互斥锁的机制要快很多
	var (
		//起始时间，以太坊使用mclock.Now()来计算程序执行时间，这个更加精确
		stats         = insertStats{startTime: mclock.Now()}  
		//事件长度和待加入的块数一致
		events        = make([]interface{}, 0, len(chain))
		lastCanon     *types.Block
		coalescedLogs []*types.Log
	)
	//先检测这些块的合法性
	headers := make([]*types.Header, len(chain))
	seals := make([]bool, len(chain))

	for i, block := range chain {
		headers[i] = block.Header()
		seals[i] = true
	}
	abort, results := bc.engine.VerifyHeaders(bc, headers, seals)
	defer close(abort)

	// 这行不太理解，这是新版加入的一行代码，原先是没有的，可能是减少分叉带来的一些问题吧
	// 从一批块中恢复发件人，并将它们缓存回相同的数据结构中。
	// 没有进行验证，也没有对无效签名作出任何反应。这取决于稍后调用代码。
	// 签名人会在分叉转换上碰碰运气。为避免问题，将所有交易都打上同一个签名？
	senderCacher.recoverFromBlocks(types.MakeSigner(bc.chainConfig, chain[0].Number()), chain)

	// 处理每个块
	for i, block := range chain {
		// 如果这些块正在终止，则停止往后执行
		if atomic.LoadInt32(&bc.procInterrupt) == 1 {
			log.Debug("Premature abort during blocks processing")
			break
		}
		// 如果有坏块，则停止处理之后的每个块，估计是尝试硬分叉吧
		if BadHashes[block.Hash()] {
			bc.reportBlock(block, nil, ErrBlacklistedHash)
			return i, events, coalescedLogs, ErrBlacklistedHash
		}
		// 开始验证块
		bstart := time.Now()
		//结果输出
		err := <-results
		if err == nil {
			//验证块
			err = bc.Validator().ValidateBody(block)
		}
		switch {
		case err == ErrKnownBlock:
			//如果待插入的块比当前块的块号小，则忽略
			if bc.CurrentBlock().NumberU64() >= block.NumberU64() {
				stats.ignored++
				continue
			}

		case err == consensus.ErrFutureBlock:
			//如果该块的时间超过了当前时间+30s，则返回错误日志
			max := big.NewInt(time.Now().Unix() + maxTimeFutureBlocks)
			if block.Time().Cmp(max) > 0 {
				return i, events, coalescedLogs, fmt.Errorf("future block: %v > %v", block.Time(), max)
			}
			//若满足要求，则放入futureBlocks中，等待后续处理
			bc.futureBlocks.Add(block.Hash(), block)
			stats.queued++
			continue

		case err == consensus.ErrUnknownAncestor && bc.futureBlocks.Contains(block.ParentHash()):
		//块祖先不确定，并且缓存中有该块，则更新
			bc.futureBlocks.Add(block.Hash(), block)
			stats.queued++
			continue

		case err == consensus.ErrPrunedAncestor://块状态无效，状态树问题
			currentBlock := bc.CurrentBlock()
			//当前链的总难度
			localTd := bc.GetTd(currentBlock.Hash(), currentBlock.NumberU64())
			//新的链的总难度
			externTd := new(big.Int).Add(bc.GetTd(block.ParentHash(), block.NumberU64()-1), block.Difficulty())
			//如果当前链难度大于新的链的难度，则将其加入db
			if localTd.Cmp(externTd) > 0 {
				//这是用来构造竞争的分叉，直到他们超过了标准的总难度。
				if err = bc.WriteBlockWithoutState(block, externTd); err != nil {
					return i, events, coalescedLogs, err
				}
				continue
			}
			var winner []*types.Block
			//获取block的父块
			parent := bc.GetBlock(block.ParentHash(), block.NumberU64()-1)
			//检查状态trie是否完全存在于数据库中。
			//parent.Root表示的是状态树（账户），并不是每个块都有状态
			for !bc.HasState(parent.Root()) {
				winner = append(winner, parent)
				parent = bc.GetBlock(parent.ParentHash(), parent.NumberU64()-1)
			}
			//有状态树的被放在第一个，
			for j := 0; j < len(winner)/2; j++ {
				winner[j], winner[len(winner)-1-j] = winner[len(winner)-1-j], winner[j]
			}
			// 将该组block加入
			bc.chainmu.Unlock()
			_, evs, logs, err := bc.insertChain(winner)
			bc.chainmu.Lock()
			events, coalescedLogs = evs, logs

			if err != nil {
				return i, events, coalescedLogs, err
			}

		case err != nil:
			//其余错误直接返回日志
			bc.reportBlock(block, nil, err)
			return i, events, coalescedLogs, err
		}
		
		//获取父块
		var parent *types.Block
		if i == 0 {
			parent = bc.GetBlock(block.ParentHash(), block.NumberU64()-1)
		} else {
			parent = chain[i-1]
		}
		//返回一个状态树
		state, err := state.New(parent.Root(), bc.stateCache)
		if err != nil {
			return i, events, coalescedLogs, err
		}
		// 使用状态树处理待加入的块
		receipts, logs, usedGas, err := bc.processor.Process(block, state, bc.vmConfig)
		if err != nil {
			bc.reportBlock(block, receipts, err)
			return i, events, coalescedLogs, err
		}
		// 验证待加入的块的状态信息
		err = bc.Validator().ValidateState(block, parent, state, receipts, usedGas)
		if err != nil {
			bc.reportBlock(block, receipts, err)
			return i, events, coalescedLogs, err
		}
		//处理截止时间
		proctime := time.Since(bstart)

		// 写入区块和状态
		status, err := bc.WriteBlockWithState(block, receipts, state)
		if err != nil {
			return i, events, coalescedLogs, err
		}
		switch status {
		case CanonStatTy: //插入了新区块
			log.Debug("Inserted new block", "number", block.Number(), "hash", block.Hash(), "uncles", len(block.Uncles()),
				"txs", len(block.Transactions()), "gas", block.GasUsed(), "elapsed", common.PrettyDuration(time.Since(bstart)))

			coalescedLogs = append(coalescedLogs, logs...)
			blockInsertTimer.UpdateSince(bstart)
			events = append(events, ChainEvent{block, block.Hash(), logs})
			lastCanon = block

			bc.gcproc += proctime

		case SideStatTy:  // 插入了一个forked 区块
			log.Debug("Inserted forked block", "number", block.Number(), "hash", block.Hash(), "diff", block.Difficulty(), "elapsed",
				common.PrettyDuration(time.Since(bstart)), "txs", len(block.Transactions()), "gas", block.GasUsed(), "uncles", len(block.Uncles()))

			blockInsertTimer.UpdateSince(bstart)
			events = append(events, ChainSideEvent{block})
		}
		stats.processed++
		stats.usedGas += usedGas

		cache, _ := bc.stateCache.TrieDB().Size()
		stats.report(chain, i, cache)
	}
	// 事件加入
	if lastCanon != nil && bc.CurrentBlock().Hash() == lastCanon.Hash() {
		events = append(events, ChainHeadEvent{lastCanon})
	}
	return 0, events, coalescedLogs, nil
}
```

其中牵涉到两个重要的方法：`WriteBlockWithState()`以及`reorg()`，建议也去阅读下，里面会具体判断应该使用哪条链。难度高的和难度低的链如何处理等问题。时间和精力有限，本文暂时就分析到这里。

## 总结
这一部分，链的初始化，其中加入了大量的检测，最终目的就是要有一个规范的链生成，当出现异常块时，会一直往前回滚，直到找到正常的块为止。也就是找一个最新的正常块。