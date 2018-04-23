---
title: 以太坊源码解读-第3讲-trie模块源码解读（2）
mathjax: true
copyright: true
original: true
date: 2018-04-19 15:40:25
categories: [原创,以太坊,源码解读]
tags: [ethereum]
---
## 前言
这一部分，我们主要是讲trie源码的实现，要理解代码的实现过程，是需要先了解一下理论内容的，建议大家先看看我的上一篇文章：[以太坊源码解读-第3讲-trie模块源码解读（1）](/articles/original/ethereum/src_analysis/以太坊源码解读-第3讲-trie模块源码解读（1）.html)
<!-- more -->

## encoding.go源码解读
trie模块中，这个文件是我们首先要掌握的，这个主要是讲三种编码（`KEYBYTES encoding`、`HEX encoding`、`COMPACT encoding`）的实现与转换，trie中全程都需要用到这些，该文件中主要实现了如下功能：
1. hex编码转换为Compact编码：`hexToCompact()`
2. Compact编码转换为hex编码：`compactToHex()`
3. keybytes编码转换为Hex编码：`keybytesToHex()`
4. hex编码转换为keybytes编码：`hexToKeybytes()`
5. 获取两个字节数组的公共前缀的长度：`prefixLen()`

但是，小编不会去讲这块的源码内容了，因为[以太坊源码解读-第3讲-trie模块源码解读（1）](/articles/original/ethereum/src_analysis/以太坊源码解读-第3讲-trie模块源码解读（1）.html)这篇文章里已经穿插了很多相关的源码，重点都已经在其中解释的很详细了。
如果还有哪些地方不了解，大家可以留言或者微信与小编联系。

## node.go源码解读
大家得先看懂[以太坊源码解读-第3讲-trie模块源码解读（1）](/articles/original/ethereum/src_analysis/以太坊源码解读-第3讲-trie模块源码解读（1）.html)关于节点方面的内容，否则很难理解小编下面要讲的源码。

### node的结构与定义
以太坊为MPT中的node定义了一套基本接口规则：
```go
type node interface {
	fstring(string) string //用来打印节点信息，没别的作用
	cache() (hashNode, bool)  //保存缓存
	canUnload(cachegen, cachelimit uint16) bool  //除去缓存，cache次数的计数器
}
```
以太坊依据上面的规则为MTP定义了四种类型的节点，代码如下：
```go
type (
	fullNode struct {
		Children [17]node  //对应了黄皮书里面的分支节点
		flags    nodeFlag
	}
	shortNode struct {  //对应了黄皮书里面的扩展节点
		Key   []byte
		Val   node  //可能指向叶子节点，也可能指向分支节点。
		flags nodeFlag
	}
	hashNode  []byte
	valueNode []byte  //叶子节点值，但是该叶子节点最终还是会包装在shortNode中
)
```
分为这四种节点：
* fullNode
这就是传说中的分支节点，会发现它里面定义了17个node，其中16个对应的16进制的0~9a~f，第17个还没搞清楚，后面清楚了再来讲。nodeFlag稍后再说。
* shortNode
它本身若是扩展节点，则它的属性Val可能指向分支节点或者叶子节点，但要知道，叶子节点本身同样是用shortNode表示的；
它本身若是叶子节点，则Val的值为rlp编码的数据，而key则是该数据的完整hash(经过hex编码的)
* valueNode：这是给叶子节点用的，但是要知道它不能单独使用，而是要放在shortNode中使用的，用于存放rlp编码的原始数据
* hashNode：这个同样不能单独使用，我们在上面节点定义中发现了，会涉及到`nodeFlag`，先来看看定义：
```go
type nodeFlag struct {
	hash  hashNode // cached hash of the node (may be nil)
	gen   uint16   // cache generation counter
	dirty bool     // whether the node has changes that must be written to the database
}
```
在其中发现了hashNode，这个属性是用来标记nodeFlag所属的node对象本身经过rlp编码后的hash值（该hash在hashNode中同样是经过hex编码的），若node有任何变化，则该hash就会发生变化。
nodeFlag中的gen，只要对应的node发生一次变化，计数就加一
nodeFlage中的bool，只要对应的node发生变化，它就变成true，表示要把数据重新刷新到DB中(以太坊用levelDB存储MTP信息)
小编认为，对node理解到此处就可以了，对node的具体操作，要结合MPT的具体操作来掌握，这就引出了我们的下一部分需要掌握的文件：trie.go

## trie.go源码解读
我们先来了解下以太坊给trie定义的结构：
```go
type Trie struct {
	db           *Database  //trei在levelDB中
	root         node  //根结点
	originalRoot common.Hash  //32位byte[],从db中恢复出完整的trie

	//cachegen表示当前trie树的版本，trie每次commit，则增加1
	//cachelimit如果当前的cache时代 - cachelimit参数 大于node的cache时代，那么node会从cache里面卸载，以便节约内存。
	cachegen, cachelimit uint16
}
```
具体我们来解读一下其中的每部分：
* db
* root 可以理解为当前root指向哪个节点，初始时候，没有内容，则root=nil，表示指向nil
* originalRoot
* cachegen
* cachelimit

按小编的理解，trie中存入db本身的是各种类型的node，也就是从root指向的那个node开始存储，root本身并不存储。

想要真正掌握以太坊中的trie，小编建议还是从它的测试文件node_test.go作为入口来读取源码，这里面涉及到内容如果都看懂，那相信你对MPT了解已经非常深刻了。好，那咱们一个个来看：
### 一颗空树
当为一颗空树时候，也就是trie只有一个节点，且trie.root=nil。
此时使用trie.Hash()可以返回当前整个trie树的hash值。而emptyRoot是trie预先定义的一个空节点时候的hash常量，将当前trie的hash和它比较，可以校验当前trie是否为空树。具体代码如下：
注意，这些hash是真实值，从进一步的代码中，我们是可以得知，这些hash是使用hex转换回来的hash。
```go
func TestEmptyTrie(t *testing.T) {
	var trie Trie
	res := trie.Hash() //获取当前trie的hash
	exp := emptyRoot
	if res != common.Hash(exp) {
		t.Errorf("expected %x got %x", exp, res)
	}
}
```
###  从空树中添加一个节点
添加一个节点，也就是添加叶子结点，先来看代码：
```go
func TestNull(t *testing.T) {
	var trie Trie
	value := []byte("test")  //value为字节数组
	key := make([]byte, 32) //一个32位的hash，但是其中每一位都是0
	trie.Update(key, value)
	if !bytes.Equal(trie.Get(key), value) {
		t.Fatal("wrong value")
	}
}
```
初始时，tril.root指向的是nil。
value：要把一个字符串内容为"test"的数据存入trie中
key：应该是value对应的rlp编码后的hash值
从trie.Update()进入到trie.go的insert方法中：会发现，key和value被组成一个shortNode，表示一个叶子节点，插入到trie空树中。
然后trie.root指向这个叶子节点。
可以这么理解，此时这棵树有一个根结点和一个叶子结点。
为更好说明，上个图，大体如下：
{% asset_img 1.png  空树中添加到一个节点 %}

### 数据库中检测一个不存在的trie根节点
小编曾说个，以太坊的MPT中，是有google的levelDB参与的，而从trie定义的结构中，我们可知通过trie中的originalRoot可以恢复出一棵levelDB中存在的MPT树。
这个案例中，我们尝试使用一个不存在的hash来判断level中的确不存在该对应的MTP树。代码如下：
`ps：小编需要说明，其中涉及的levelDB以及代码中的db操作相关，属于以太坊的ethdb模块中的内容，这个将在后续的文章中讲解，本文只一笔概述不会深入去讲db内容。`
```go
func TestMissingRoot(t *testing.T) {
	diskdb, _ := ethdb.NewMemDatabase()
	//New()中，第一个参数是将hex编码转为原始的hash 32位byte[]
	trie, err := New(common.HexToHash("0beec7b5ea3f0fdbc95d0dd47f3c5bc275da8a33"), NewDatabase(diskdb))
	if trie != nil {
		t.Error("New returned non-nil trie for invalid root")
	}
	if _, ok := err.(*MissingNodeError); !ok {
		t.Errorf("New returned wrong error: %v", err)
	}
}
```
代码中我们可知，我们是要从一个新建的db中去找某hash对应的trie树。呵呵，当然会找不到。但程序具体是怎么执行查找的？需要我们进入New()方法去进一步了解过程：
传入的root是一个hash，根据该hash最后是在db中查找对应的trie根的。
其中`originalRoot: root, `，若最终查找出了该trie，则该root就是整个trie的hash。
```go
func New(root common.Hash, db *Database) (*Trie, error) {
	if db == nil {
		panic("trie.New called without a database")
	}
	trie := &Trie{
		db:           db,
		originalRoot: root,  //把传入的hash保存在此处，只要能恢复了整个trie
	}
	if (root != common.Hash{}) && root != emptyRoot {
		rootnode, err := trie.resolveHash(root[:], nil) //检查是否有对应的trie
		if err != nil {
			return nil, err
		}
		trie.root = rootnode  //返回了找到的trie，按小编理解，这个rootnode应该是分支节点或叶子节点
	}
	return trie, nil
}
```
其中，真正进行node查找的方法是resolveHash()该方法也需要大家了解一下：
```go
func (t *Trie) resolveHash(n hashNode, prefix []byte) (node, error) {
	cacheMissCounter.Inc(1)  //每执行一次resolveHash()方法，计数器+1

	hash := common.BytesToHash(n)
	enc, err := t.db.Node(hash)
	if err != nil || enc == nil {
		return nil, &MissingNodeError{NodeHash: hash, Path: prefix}
	}
	return mustDecodeNode(n, enc, t.cachegen), nil
}
```
主要的是那个计数器，`cacheMissCounter.Inc(1)`，不论从db中还原trie成功还是失败，计数器都会累加1

### 操作存储在内存或磁盘的trie
db中只会存放最终真正确认有效的数据块，因此trie会被分为存在db磁盘中的以及留在内存中的两大类，具体可以看测试代码，（期间会涉及到部分非重点代码，小编就不列出了）：
```go

func testMissingNode(t *testing.T, memonly bool) {
	diskdb, _ := ethdb.NewMemDatabase()  //磁盘空间
	triedb := NewDatabase(diskdb)  //生成db

	trie, _ := New(common.Hash{}, triedb) //空节点创建
	updateString(trie, "120000", "qwerqwerqwerqwerqwerqwerqwerqwer")  //插入第一个结点数据
	updateString(trie, "123456", "asdfasdfasdfasdfasdfasdfasdfasdf")  //插入第二个结点数据
	root, _ := trie.Commit(nil)  //trie.Commit需要了解
	if !memonly {  //根据此处来判断是否提交到db
		triedb.Commit(root, true)  //这个就是将trie提交到db了
	}

	//根据key查找某个trie是否存在
	var bts []byte
	trie, _ = New(root, triedb)
	bts, err := trie.TryGet([]byte("120000"))
	fmt.Println(bts)
	
	//添加一个node
	trie, _ = New(root, triedb)
	err = trie.TryUpdate([]byte("120099"), []byte("zxcvzxcvzxcvzxcvzxcvzxcvzxcvzxcv"))

	//删除一个node
	trie, _ = New(root, triedb)
	err = trie.TryDelete([]byte("123456"))
	
	hash := common.HexToHash("0xe1d943cc8f061a0c0b98162830b970395ac9315654824bf21b73b891365262f9")
	if memonly { //为true，则在内存中删除该trie
		delete(triedb.nodes, hash)
	} else {  //为false，则在磁盘中删除该trie
		diskdb.Delete(hash[:])
	}
}
```

### 缓存清除
```go
func TestCacheUnload(t *testing.T) {
	trie := newEmpty() //创建新的trie，root空节点
	key1 := "---------------------------------"
	key2 := "---some other branch"
	updateString(trie, key1, "this is the branch of key1.")
	updateString(trie, key2, "this is the branch of key2.")

	root, _ := trie.Commit(nil) //提交到内存
	trie.db.Commit(root, true)  //提交到磁盘

	db := &countingDB{Database: trie.db.diskdb, gets: make(map[string]int)}
	trie, _ = New(root, NewDatabase(db))
	trie.SetCacheLimit(5)  //设置缓存队列长度为5
	for i := 0; i < 12; i++ {
		trie.Get([]byte(key1)) //在trie中找到key1所对应的原始数据，key1是各节点拼出的完整hash
		trie.Commit(nil) 
	}

	for dbkey, count := range db.gets {
		if count != 2 {
			t.Errorf("db key %x loaded %d times, want %d times", []byte(dbkey), count, 2)
		}
	}
}
```

### 随机数操作
```go
type randTest []randTestStep

type randTestStep struct {
	op    int
	key   []byte // for opUpdate, opDelete, opGet
	value []byte // for opUpdate
	err   error  // for debugging
}

const (
	opUpdate = iota
	opDelete
	opGet
	opCommit
	opHash
	opReset
	opItercheckhash
	opCheckCacheInvariant
	opMax // boundary value, not an actual op
)

func (randTest) Generate(r *rand.Rand, size int) reflect.Value {
	var allKeys [][]byte
	genKey := func() []byte {
		if len(allKeys) < 2 || r.Intn(100) < 10 {
			// new key
			key := make([]byte, r.Intn(50))
			r.Read(key)
			allKeys = append(allKeys, key)
			return key
		}
		// use existing key
		return allKeys[r.Intn(len(allKeys))]
	}

	var steps randTest
	for i := 0; i < size; i++ {
		step := randTestStep{op: r.Intn(opMax)}
		switch step.op {
		case opUpdate:
			step.key = genKey()
			step.value = make([]byte, 8)
			binary.BigEndian.PutUint64(step.value, uint64(i))
		case opGet, opDelete:
			step.key = genKey()
		}
		steps = append(steps, step)
	}
	return reflect.ValueOf(steps)
}

func runRandTest(rt randTest) bool {
	diskdb, _ := ethdb.NewMemDatabase()
	triedb := NewDatabase(diskdb)

	tr, _ := New(common.Hash{}, triedb)
	values := make(map[string]string) // tracks content of the trie

	for i, step := range rt {
		switch step.op {
		case opUpdate:
			tr.Update(step.key, step.value)
			values[string(step.key)] = string(step.value)
		case opDelete:
			tr.Delete(step.key)
			delete(values, string(step.key))
		case opGet:
			v := tr.Get(step.key)
			want := values[string(step.key)]
			if string(v) != want {
				rt[i].err = fmt.Errorf("mismatch for key 0x%x, got 0x%x want 0x%x", step.key, v, want)
			}
		case opCommit:
			_, rt[i].err = tr.Commit(nil)
		case opHash:
			tr.Hash()
		case opReset:
			hash, err := tr.Commit(nil)
			if err != nil {
				rt[i].err = err
				return false
			}
			newtr, err := New(hash, triedb)
			if err != nil {
				rt[i].err = err
				return false
			}
			tr = newtr
		case opItercheckhash:
			checktr, _ := New(common.Hash{}, triedb)
			it := NewIterator(tr.NodeIterator(nil))
			for it.Next() {
				checktr.Update(it.Key, it.Value)
			}
			if tr.Hash() != checktr.Hash() {
				rt[i].err = fmt.Errorf("hash mismatch in opItercheckhash")
			}
		case opCheckCacheInvariant:
			rt[i].err = checkCacheInvariant(tr.root, nil, tr.cachegen, false, 0)
		}
		// Abort the test on error.
		if rt[i].err != nil {
			return false
		}
	}
	return true
}

func checkCacheInvariant(n, parent node, parentCachegen uint16, parentDirty bool, depth int) error {
	var children []node
	var flag nodeFlag
	switch n := n.(type) {
	case *shortNode:
		flag = n.flags
		children = []node{n.Val}
	case *fullNode:
		flag = n.flags
		children = n.Children[:]
	default:
		return nil
	}

	errorf := func(format string, args ...interface{}) error {
		msg := fmt.Sprintf(format, args...)
		msg += fmt.Sprintf("\nat depth %d node %s", depth, spew.Sdump(n))
		msg += fmt.Sprintf("parent: %s", spew.Sdump(parent))
		return errors.New(msg)
	}
	if flag.gen > parentCachegen {
		return errorf("cache invariant violation: %d > %d\n", flag.gen, parentCachegen)
	}
	if depth > 0 && !parentDirty && flag.dirty {
		return errorf("cache invariant violation: %d > %d\n", flag.gen, parentCachegen)
	}
	for _, child := range children {
		if err := checkCacheInvariant(child, n, flag.gen, flag.dirty, depth+1); err != nil {
			return err
		}
	}
	return nil
}

func TestRandom(t *testing.T) {
	if err := quick.Check(runRandTest, nil); err != nil {
		if cerr, ok := err.(*quick.CheckError); ok {
			t.Fatalf("random test iteration %d failed: %s", cerr.Count, spew.Sdump(cerr.In))
		}
		t.Fatal(err)
	}
}
```






参考：https://blog.csdn.net/ddffr/article/details/78773013







