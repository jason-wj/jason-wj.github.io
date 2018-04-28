---
title: 以太坊源码解读-第4讲-ethdb模块源码解读
mathjax: true
copyright: true
original: true
explain: 文中可能会根据需要做部分调整
date: 2018-04-26 15:02:38
categories: [原创,以太坊,源码解读]
tags: [ethereum]
---
看了trie模块的源码，我们知道了其中的节点数据是通过ethdb来进行磁盘db的读写操作的。其实ethdb是依赖google的一个开源kv数据库levelDB实现的。最终所有的数据都是存储在levelDB中。
我们会很好奇，什么是levelDB？在ethdb中是如何处理levelDB的？下面小编一步步来揭开它的面纱

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
|____database_test.go  测试案例
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

### database.go源码解读
本来小编是想通过database_test.go中的测试用例来解读database.go源码的，但综合前面已经介绍的数据库相关内容，直接解释database.go源码应该更好一些。
这个文件真正的封装了google的levelDB,





