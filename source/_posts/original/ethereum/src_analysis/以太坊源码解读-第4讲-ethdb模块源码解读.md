---
title: 以太坊源码解读-第4讲-ethdb模块源码解读
mathjax: false
copyright: true
original: true
date: 2018-04-26 15:02:38
categories: [原创,以太坊,源码解读]
tags: [ethereum]
---
## 前言
看了trie模块的源码，我们知道了其中的节点数据是通过ethdb来进行磁盘db的读写操作的。其实ethdb是依赖google的一个开源kv数据库levelDB实现的。最终所有的数据都是存储在levelDB中。
我们会很好奇，什么是levelDB？在ethdb中是如何处理levelDB的？下面小编一步步来揭开它的面纱。
<!-- more -->

## 什么是levelDB

### 特点：
* 效率高，支持billion级别的数据量
* key和value都是任意长度的字节数组；
* entry（即一条K-V记录）默认是按照key的字典顺序存储的，当然开发者也可以重载这个排序函数；
* 提供的基本操作接口：Put()、Delete()、Get()、Batch()；
* 支持批量操作以原子操作进行；
* 可以创建数据全景的snapshot(快照)，并允许在快照中查找数据；
* 可以通过前向（或后向）迭代器遍历数据（迭代器会隐含的创建一个snapshot）；
* 自动使用Snappy压缩数据；
* 可移植性；

### 限制：
* 非关系型数据模型（NoSQL），不支持sql语句，也不支持索引；
* 一次只允许一个进程访问一个特定的数据库；
* 没有内置的C/S架构，就是说不包含网络服务架构，但开发者可以使用LevelDB库自己封装一个server；

## ethdb模块概述
这个模块不复杂，直接看里面的文件结构：
.
|____interface.go  数据库接口定义
|____database.go  对levelDB进行封装
|____database_test.go  测试案例，本文不讲这个，模块不复杂，不需要专门去探讨案例
|____memory_database.go  用于db测试，生产中不可使用。在trie模块中的测试案例应该见过很多次这个东西了
一目了然，只有四个文件。下面我们一个个来讲

## interface.go源码解读
这个是需要第一个掌握的源码内容，因为它为在以太坊中操作db定义了一套规则，因此，要想了解ethdb模块就得先了解这个文件。
接口规范，代码不多，老规矩，先贴代码：
```go
const IdealBatchSize = 100 * 1024 //批处理数据的时候用的值，这个值是根据实际调试经验确定的

//用于普通操作和批量操作写入数据
type Putter interface {
	Put(key []byte, value []byte) error
}

//定义了所有的数据库操作， 所有的方法都是多线程安全的。
type Database interface {
	Putter
	Get(key []byte) ([]byte, error) //获取
	Has(key []byte) (bool, error)  //判断
	Delete(key []byte) error  //删除
	Close()  //关闭
	NewBatch() Batch  //实例化新的批处理
}

//批量操作接口，不能多线程同时使用，当Write方法被调用的时候，数据库会提交写入的更改。
type Batch interface {
	Putter
	ValueSize() int   //批处理中的数据量
	Write() error
	Reset()
}
```
看到了吧，`全都是字节形式的数据。`
主要就是两大类，批处理操作和普通操作，两种方式的数据库操作。
没什么可以解释的

## memory_database.go 源码解读
看过trie模块代码的同学，应该很熟悉这个文件，官方解释说该文件仅供测试使用，可以说，这个文件只是模拟的一个数据库，并没有真正对接到levelDB，只是为了方便数据库的测试操作而使用。先来看代码，然后再解释，先上一坨代码：
```go
//定义一个模拟存储数据的<k,v>数据库，可以看到，数据是存在了内存map中
type MemDatabase struct {
	db   map[string][]byte
	lock sync.RWMutex
}

//用于实例化数据库，此处是为map开辟空间，没有指定具体大小
func NewMemDatabase() (*MemDatabase, error) {
	return &MemDatabase{
		db: make(map[string][]byte),
	}, nil
}

//用于实例化数据库，此处是为map开辟空间，指定了具体大小
func NewMemDatabaseWithCap(size int) (*MemDatabase, error) {
	return &MemDatabase{
		db: make(map[string][]byte, size),
	}, nil
}

//将数据存放到模拟的数据库里，也就是那个map里
func (db *MemDatabase) Put(key []byte, value []byte) error {
	db.lock.Lock() //注意读写锁额
	defer db.lock.Unlock() //defer是干嘛的，小编在别的文章里解释好多遍了。。

	db.db[string(key)] = common.CopyBytes(value) //　好，插进去了
	return nil
}

//根据key检测某个数据是否存在
func (db *MemDatabase) Has(key []byte) (bool, error) {
	db.lock.RLock()  //只读锁
	defer db.lock.RUnlock()

	_, ok := db.db[string(key)]
	return ok, nil
}

//根据key获取某value
func (db *MemDatabase) Get(key []byte) ([]byte, error) {
	db.lock.RLock()
	defer db.lock.RUnlock()

	if entry, ok := db.db[string(key)]; ok {
		return common.CopyBytes(entry), nil
	}
	return nil, errors.New("not found")
}

//获取db中所有的key，这样就可以在内存中验证某数据是否存在
func (db *MemDatabase) Keys() [][]byte {
	db.lock.RLock()
	defer db.lock.RUnlock()

	keys := [][]byte{}
	for key := range db.db {
		keys = append(keys, []byte(key))
	}
	return keys
}

//删除数据，没啥解释的
func (db *MemDatabase) Delete(key []byte) error {
	db.lock.Lock()
	defer db.lock.Unlock()

	delete(db.db, string(key))
	return nil
}

//关闭，但是这是模拟数据库，因此也没什么可以关闭的
func (db *MemDatabase) Close() {}

//实例化批量操作
func (db *MemDatabase) NewBatch() Batch {
	return &memBatch{db: db}
}

//db长度
func (db *MemDatabase) Len() int { return len(db.db) }

//给批量操作定义一个要写入的数据的结构体
type kv struct{ k, v []byte }

//内存中模拟的批量数据的格式
type memBatch struct {
	db     *MemDatabase //数据库
	writes []kv  //写入的数据长度
	size   int   //写入的数据长度
}

//插入数据前的预处理，把外部批量导入的数据，进行批处理结构体格式的组合，
func (b *memBatch) Put(key, value []byte) error {
	b.writes = append(b.writes, kv{common.CopyBytes(key), common.CopyBytes(value)})
	b.size += len(value)
	return nil
}

//把预处理好的数据插入到模拟数据库中
func (b *memBatch) Write() error {
	b.db.lock.Lock()
	defer b.db.lock.Unlock()

	for _, kv := range b.writes {
		b.db.db[string(kv.k)] = kv.v
	}
	return nil
}

//批处理数据的长度
func (b *memBatch) ValueSize() int {
	return b.size
}

//复原批处理，毕竟这只是数据库中间的操作过程
func (b *memBatch) Reset() {
	b.writes = b.writes[:0]
	b.size = 0
}
```
这个文件只是一个模拟的数据库，其实都是在内存中操作的。两部分，一个是数据库的操作，一个是批处理的操作。
上面小编基本都注释好了，应该很好理解吧？那小编就开始下一部分的讲解啦

## database.go源码解读
本来小编是想通过database_test.go中的测试用例来解读database.go源码的，但综合前面已经介绍的数据库相关内容，直接解释database.go源码应该更好一些。
这个文件真正的封装了google的levelDB，让我们来揭开一下这个神秘的面纱。

### 所引用的包
先来看看它引用了哪些包：
```go
import (
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/ethereum/go-ethereum/log"
	"github.com/ethereum/go-ethereum/metrics"
	"github.com/syndtr/goleveldb/leveldb"
	"github.com/syndtr/goleveldb/leveldb/errors"
	"github.com/syndtr/goleveldb/leveldb/filter"
	"github.com/syndtr/goleveldb/leveldb/iterator"
	"github.com/syndtr/goleveldb/leveldb/opt"
	"github.com/syndtr/goleveldb/leveldb/util"
)
```
可以看出，除了引用了go本身的包的，还引用了`github.com/syndtr/goleveldb/leveldb`中的东西，这个是使用go封装过的leveldb，在github中可以找到该源码。

### db数据结构
接着来看一下以太坊对levelDB的结构的封装
```go
var OpenFileLimit = 64  //限制同时最多只能打开64个文件？

//定义了一套用于记录操作db的结构
type LDBDatabase struct {
	fn string      // 用于存放报告的文件
	db *leveldb.DB // google的levelDB实例

	compTimeMeter  metrics.Meter // 计算压缩数据所要花费的时间
	compReadMeter  metrics.Meter // 压缩期间读取的数据
	compWriteMeter metrics.Meter // 压缩期间写入的数据
	diskReadMeter  metrics.Meter // 计算读取数据影响到的条数
	diskWriteMeter metrics.Meter // 计算写入数据影响到的条数

	quitLock sync.Mutex      // 停止时候的访问保护
	quitChan chan chan error // 退出db前的处理

	log log.Logger // 日志 db路径跟踪
}
```
我们首先看到的是一堆的`metrics`，这是以太坊自己用于统计数据，评估性能的模块，姑且不去考虑。
从结构中我们也大致了解到，这它主要就是用来记录数据库的使用情况，加上退出db时候的处理。

### LDBDatabase用于实例化的方法
```go
func NewLDBDatabase(file string, cache int, handles int) (*LDBDatabase, error) {
	logger := log.New("database", file)

	// 确保有一些缓存和文件
	if cache < 16 
		cache = 16
	if handles < 16 
		handles = 16
	logger.Info("Allocated cache and file handles", "cache", cache, "handles", handles)

	// 初始化，性能调优相关 leveldb
	db, err := leveldb.OpenFile(file, &opt.Options{
		OpenFilesCacheCapacity: handles,
		BlockCacheCapacity:     cache / 2 * opt.MiB,
		WriteBuffer:            cache / 4 * opt.MiB, 
		Filter:                 filter.NewBloomFilter(10),
	})
	if _, corrupted := err.(*errors.ErrCorrupted); corrupted 
		db, err = leveldb.RecoverFile(file, nil)
	// (Re)check for errors and abort if opening of the db failed
	if err != nil 
		return nil, err
	return &LDBDatabase{
		fn:  file,
		db:  db,
		log: logger,
	}, nil
}
```
这个大体上就是levelDB的初始化操作，被外面的LDBDatabase封装了

### LDBDatabase的方法
LDBDatabase的方法还是需要关注的。
封装之后的代码是支持多线程同时访问的，LDBDatabase中的方法是不需要进行安全处理的，可直接调用。

#### 先来看一些简单的方法
都是一些比较基础的方法操作，有一个需要注意：插入数据时候，其实是插入到了内存队列中，并未写入db磁盘。而删除时候会把队列和磁盘的都删除了。
剩下的小编就不解释了，都在代码里标注了：
```go
// 获取db的路径
func (db *LDBDatabase) Path() string {
	return db.fn
}

// 添加到leveldb的缓存队列中了，此时并没有写入磁盘
func (db *LDBDatabase) Put(key []byte, value []byte) error {
	return db.db.Put(key, value, nil)
}

//某key对应的数据是否存在
func (db *LDBDatabase) Has(key []byte) (bool, error) {
	return db.db.Has(key, nil)
}

// 某key对应的数据若存在，则返回数据
func (db *LDBDatabase) Get(key []byte) ([]byte, error) {
	dat, err := db.db.Get(key, nil)
	if err != nil 
		return nil, err
	return dat, nil
}

//根据key删除缓存队列和磁盘中的数据
func (db *LDBDatabase) Delete(key []byte) error {
	return db.db.Delete(key, nil)
}

//遍历的迭代器初始化
func (db *LDBDatabase) NewIterator() iterator.Iterator {
	return db.db.NewIterator(nil, nil)
}

// 根据提供的前缀，返回一个合适的迭代器，方便你查找该前缀子集的内容
func (db *LDBDatabase) NewIteratorWithPrefix(prefix []byte) iterator.Iterator {
	return db.db.NewIterator(util.BytesPrefix(prefix), nil)
}

//某次数据库操作结束后关闭该实例，停止metrics统计信息，防止多个因为启动的数据库实例过多造成内部资源竞争
func (db *LDBDatabase) Close() {
	db.quitLock.Lock()
	defer db.quitLock.Unlock()
	if db.quitChan != nil {
		errc := make(chan error)
		db.quitChan <- errc
		if err := <-errc; err != nil 
			db.log.Error("Metrics collection failed", "err", err)
	}
	err := db.db.Close()
	if err == nil 
		db.log.Info("Database closed")
	else 
		db.log.Error("Failed to close database", "err", err)
}

// 返回当前db实例
func (db *LDBDatabase) LDB() *leveldb.DB {
	return db.db
}

func (db *LDBDatabase) NewBatch() Batch {
	return &ldbBatch{db: db.db, b: new(leveldb.Batch)}
}
```

#### 再来看个比较复杂的方法
这个方法主要是配置db性能检测的属性，也就是记录leveldb中的一些计数器，如果没有收到`quitChan()`,则会一直运行监测，另外要记住是每3秒钟获取一次leveldb中的计数器信息，具体看代码：

```go
func (db *LDBDatabase) Meter(prefix string) {
	if !metrics.Enabled  //不检测，检测会消耗不少性能（个人感觉）
		return
	//根据传入的前缀，增加一些信息
	db.compTimeMeter = metrics.NewRegisteredMeter(prefix+"compact/time", nil)
	db.compReadMeter = metrics.NewRegisteredMeter(prefix+"compact/input", nil)
	db.compWriteMeter = metrics.NewRegisteredMeter(prefix+"compact/output", nil)
	db.diskReadMeter = metrics.NewRegisteredMeter(prefix+"disk/read", nil)
	db.diskWriteMeter = metrics.NewRegisteredMeter(prefix+"disk/write", nil)

	// 退出处理
	db.quitLock.Lock()
	db.quitChan = make(chan chan error)
	db.quitLock.Unlock()

	go db.meter(3 * time.Second) //启动线程，调用监控，这貌似是每3秒监控一次
}
```

#### 最后来看个最复杂的方法
周期性监测leveldb内部的计数器，然后把信息报告给检测器，来看代码
```
// 这是当前版本报告的图表样式:
//   Compactions
//    Level |   Tables   |    Size(MB)   |    Time(sec)  |    Read(MB)   |   Write(MB)
//   -------+------------+---------------+---------------+---------------+---------------
//      0   |          0 |       0.00000 |       1.27969 |       0.00000 |      12.31098
//      1   |         85 |     109.27913 |      28.09293 |     213.92493 |     214.26294
//      2   |        523 |    1000.37159 |       7.26059 |      66.86342 |      66.77884
//      3   |        570 |    1113.18458 |       0.00000 |       0.00000 |       0.00000
//
// 这是当前版本读写监控的文本样式:
// Read(MB):3895.04860 Write(MB):3654.64712
func (db *LDBDatabase) meter(refresh time.Duration) {
	// 创建一个计数器集合用于保存当前和先前的压缩值
	compactions := make([][]float64, 2)
	for i := 0; i < 2; i++
		compactions[i] = make([]float64, 3)
	// 用于保存读写的数据信息
	var iostats [2]float64
	// 一直循环来记录
	for i := 1; ; i++ {
		// 恢复数据状态
		stats, err := db.db.GetProperty("leveldb.stats")
		if err != nil 
			db.log.Error("Failed to read database stats", "err", err)
			return
		//找用于记录压缩table
		lines := strings.Split(stats, "\n")
		for len(lines) > 0 && strings.TrimSpace(lines[0]) != "Compactions" 
			lines = lines[1:]
		if len(lines) <= 3 {
			db.log.Error("Compaction table not found")
			return
		}
		lines = lines[3:]

		// 检索所有table
		for j := 0; j < len(compactions[i%2]); j++ 
			compactions[i%2][j] = 0
		for _, line := range lines {
			parts := strings.Split(line, "|")
			if len(parts) != 6 
				break
			for idx, counter := range parts[3:] {
				value, err := strconv.ParseFloat(strings.TrimSpace(counter), 64)
				if err != nil {
					db.log.Error("Compaction entry parsing failed", "err", err)
					return
				}
				compactions[i%2][idx] += value
			}
		}
		// Update all the requested meters
		if db.compTimeMeter != nil 
			db.compTimeMeter.Mark(int64((compactions[i%2][0] - compactions[(i-1)%2][0]) * 1000 * 1000 * 1000))
		if db.compReadMeter != nil 
			db.compReadMeter.Mark(int64((compactions[i%2][1] - compactions[(i-1)%2][1]) * 1024 * 1024))
		if db.compWriteMeter != nil 
			db.compWriteMeter.Mark(int64((compactions[i%2][2] - compactions[(i-1)%2][2]) * 1024 * 1024))

		// 初始化io操作的记录
		ioStats, err := db.db.GetProperty("leveldb.iostats")
		if err != nil {
			db.log.Error("Failed to read database iostats", "err", err)
			return
		}
		parts := strings.Split(ioStats, " ")
		if len(parts) < 2 {
			db.log.Error("Bad syntax of ioStats", "ioStats", ioStats)
			return
		}
		r := strings.Split(parts[0], ":")
		if len(r) < 2 {
			db.log.Error("Bad syntax of read entry", "entry", parts[0])
			return
		}
		read, err := strconv.ParseFloat(r[1], 64)
		if err != nil {
			db.log.Error("Read entry parsing failed", "err", err)
			return
		}
		w := strings.Split(parts[1], ":")
		if len(w) < 2 {
			db.log.Error("Bad syntax of write entry", "entry", parts[1])
			return
		}
		write, err := strconv.ParseFloat(w[1], 64)
		if err != nil {
			db.log.Error("Write entry parsing failed", "err", err)
			return
		}
		if db.diskReadMeter != nil {
			db.diskReadMeter.Mark(int64((read - iostats[0]) * 1024 * 1024))
		}
		if db.diskWriteMeter != nil {
			db.diskWriteMeter.Mark(int64((write - iostats[1]) * 1024 * 1024))
		}
		iostats[0] = read
		iostats[1] = write

		select {
		case errc := <-db.quitChan:
			errc <- nil
			return

		case <-time.After(refresh):
			// 超时
		}
	}
}
```

### 批处理相关
从前面我们也了解到了，有时候我们需要批量处理数据，具体在database.go中是如下定义和实现的：
```go
type ldbBatch struct {
	db   *leveldb.DB
	b    *leveldb.Batch
	size int
}

//注意这里只是写入内存队列，并没有插入db
func (b *ldbBatch) Put(key, value []byte) error {
	b.b.Put(key, value)
	b.size += len(value)
	return nil
}

//这里才真正写入db
func (b *ldbBatch) Write() error {
	return b.db.Write(b.b, nil)
}

func (b *ldbBatch) ValueSize() int {
	return b.size
}

func (b *ldbBatch) Reset() {
	b.b.Reset()
	b.size = 0
}
```
和`memory_database.go`中的定义一样，一目了然，不用小编解释了吧？

### 通用的db操作封装
剩下的代码，定义了`table`和`tableBatch`的规则，这进一步对数据库做了通用的处理，通过这一套规则，底层可以使用别的各种数据库，不一定要选择levelDB。本不打算再列这块的代码的，算了，这模块的内容不多，就把这代码也都贴出来吧：
```go
//只要传入一个满足Database接口的db，均可正常操作本数据库，通用性更强
func NewTable(db Database, prefix string) Database {
	return &table{
		db:     db,
		prefix: prefix,
	}
}

func (dt *table) Put(key []byte, value []byte) error {
	return dt.db.Put(append([]byte(dt.prefix), key...), value)
}

func (dt *table) Has(key []byte) (bool, error) {
	return dt.db.Has(append([]byte(dt.prefix), key...))
}

func (dt *table) Get(key []byte) ([]byte, error) {
	return dt.db.Get(append([]byte(dt.prefix), key...))
}

func (dt *table) Delete(key []byte) error {
	return dt.db.Delete(append([]byte(dt.prefix), key...))
}

func (dt *table) Close() {
	// Do nothing; don't close the underlying DB.
}

type tableBatch struct {
	batch  Batch
	prefix string
}

// NewTableBatch returns a Batch object which prefixes all keys with a given string.
func NewTableBatch(db Database, prefix string) Batch {
	return &tableBatch{db.NewBatch(), prefix}
}

func (dt *table) NewBatch() Batch {
	return &tableBatch{dt.db.NewBatch(), dt.prefix}
}

func (tb *tableBatch) Put(key, value []byte) error {
	return tb.batch.Put(append([]byte(tb.prefix), key...), value)
}

func (tb *tableBatch) Write() error {
	return tb.batch.Write()
}

func (tb *tableBatch) ValueSize() int {
	return tb.batch.ValueSize()
}

func (tb *tableBatch) Reset() {
	tb.batch.Reset()
}
```
具体代码就不讲了，自己领悟吧。

## 全文总结
本文主要介绍了以太坊对db接口的定义，对levelDB的封装，另外也给出一套通用的规范，来让人们可以更自由的选择使用别的数据库。
其中db中均涉及到了普通操作和批处理操作。另外对于levelDB,还加入了性能检测（计数）相关内容。







