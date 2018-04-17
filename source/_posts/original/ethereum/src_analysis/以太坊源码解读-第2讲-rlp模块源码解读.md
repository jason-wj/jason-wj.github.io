---
title: 以太坊源码解读-第2讲-rlp模块源码解读
mathjax: true
copyright: true
original: true
date: 2018-04-09 23:28:57
categories: [原创,以太坊,源码解读]
tags: [ethereum]
---
## 前言
在正式解读源码前，小编想先解释下为什么使用选择这一模块作为以太坊源码解读的开端：
1. 该模块可以独立于其余模块，且内容少，便于理解整体编码风格，找找感觉。
2. 不懂go语言的，读完这么模块，基本就没什么语言障碍了，话说，go语言是有点怪。。

<!-- more -->

## 什么是rlp
* rlp(递归长度前缀，Recursive Length Prefix)，是不是看的一脸懵逼？
* 序列化听说过不？java开发的同学们应该更了解吧？`rlp`就是以太坊中的序列化工具，它可以将其中涉及到的任何类型的数据都转化为字节序列，方便网络传输。
* 待序列化的数据需要`大端`化处理
* 以太坊的rlp主要分为：`对树形结构的数据序列化`以及`字节数组的序列化`。
* rlp适用于任意二进制数据数组的编码。

## 以太坊中rlp规则
黄皮书中，介绍到了以太坊的rlp规则，公式比较多，小编一个个来解释一下。
公式是从整体到细节的，希望大家能按顺序看，这样看更容易理解

### 公式中可能涉及到的符号解释
* ||x||表示公式的长度
* `这个点号符号$\cdot$表示的是字符串衔接，不是相乘`
* BE(x)表示x的`大端模式`,啥是大端模式小编不解释，基础概念，上百度谷歌一下～
* $\equiv$，恒等于，理解成等于姑且也可以。。。
* 剩下的符号，小编看了看，都是初中高中的，不要说不知道。。。

### 公式1：待序列化数据定义
要被序列化的数据类型，用数学定义如下：

$$
\begin{split}
&\mathbb{T} \equiv \mathbb{L} \cup \mathbb{B} \\\
&\mathbb{L} \equiv \\{t: t = (t[0], t[1], ...) \cap \forall_{n<||t||}\ t[n] \in \mathbb{T} \\} \\\
&\mathbb{B} \equiv \\{b: b = (b[0], b[1], ...) \cap \forall_{n<||b||}\ b[n] \in \mathbb{O} \\}
\end{split}
$$

解释的不一定合理，但大体是这么个意思:
* $\mathbb{T}$表示：待序列化数据中，*字节数组*以及*树形结构（树、结构体）*的数据。
* $\mathbb{L}$表示：$\mathbb{T}$之一的，不止一个节点的树形结构。
* $\mathbb{B}$表示：$\mathbb{T}$之一的，字节数组。
* $\mathbb{O}$表示：小编的理解是，包括待序列化数据以外的，任何字节数组。要知道最终序列化时，待序列化的数据是需要大端处理的。

### 公式2：序列化过程
以太坊序列化是如何执行的：

$$
RLP(x) \equiv
\begin{cases}
R_b(x), &\ if\ \ x \in \mathbb{B} \\\
R_l(x), &\ otherwise \\\
\end{cases}
$$

这个公式就好理解了吧，对于这两大类数据，执行不同的函数来处理序列化

### 公式3：$R_b(x)$字节数组的序列化规则

$$
R_b(x) \equiv
\begin{cases}
x, &if\ \ ||x||=1 \cap x[0]<128 \\\
(128+||x||) \cdot x, &else\ if\ \ ||x||<56 \\\
(183+||BE(||x||)||) \cdot BE(||x||)\cdot x, &otherwise
\end{cases}
$$

这公式的意思如下：
* 如果字节数组长度为1，且这个字节的值小于128，则不处理
* 如果不满足上一条要求，但是满足字节数组的长度小于56，那么就在原始数据前面加上`128与该字节数组长度之和`，该过程类似字符串衔接。
* 如果不满足以上两种条件，那么就先在原始数据前面加上`原始数据长度的大端表示的数据`，再在其前面加上`183与原始数据大端表示的长度之和`

### 公式4: $R_l(x)$树型结构数据的序列化规则

$$
\begin{split}
s(x) &\equiv RLP(x_0) \cdot RLP(x_1)...\\\
R_l(x) &\equiv
\begin{cases}
(192+||s(x)||) \cdot s(x), &if\ \ ||s(x)||<56 \\\
(247+||BE(||s(x)||)||) \cdot BE(||s(x)||) \cdot s(x), &otherwise \\\
\end{cases}
\end{split}
$$


第1个公式的意思如下：
* 将树形结构中的每个元素分别使用RLP进行处理，然后将处理结果依次连接起来（字符串连接），生成新的字节，表示为`s`。

第2个公式的意思如下：
* 如果公式1连接后的`s`字节长度小于56，那结果就是在`s`前面连接上`192与 *s的长度* 之和`
* 如果不满足上面的要求，也就是`s`字节长度大于等于56，则在s的前面连接上`s长度的大端表示`，再在其前面加上`247与*连接后长度的大端模式的长度*`

看懂上面的两个公式了不？看懂的话，你就会明白，这公式会是一个`递归过程`，因为结构体里还有结构体，一层又一层。。。

### 公式5: 标量数据处理(特殊数据)

$$
RLP(i:i \in \mathbb{P} ) \equiv RLP(BE(i))
$$
标量数据，可以理解为我们通常所说的基本的数据。
此时RLP只能用来处理正整数。这块理解貌似有点费劲，后面可以看看源码来进一步了解。这些数据需要先大端处理。

### 总结：
抛离公式，小编在此总结一下，RLP是如下处理数据的：
1. 如果是一个单字节(长度为1)并且其值在`[0x00,0x7f]`范围内（即0～127），RLP编码就是自身。
2. 如果一个数据串的字节长度是0-55字节，那么它的RLP编码是在数据串开头增加一个字节，这个字节的值是0x80加上数据串的字节长度。因此增加的该字节的取值范围为[0x80, 0xb7]。
3. 如果一个数据串的字节长度大于55，那么它的RLP编码是在开头增加一个字节，这个字节的值等于0xb7加上数据串字节长度的二进制编码的字节长度，然后依次跟着数据串字节长度部分和内容部分。比如：一个长度为1024字节的数据串，其字节长度用16进制表示为0x0400，长度为2个字节，因此RLP编码头字节的值为0xb9（0xb7 + 0x02），然后跟着两字节为0x0400，后面再加上数据串的具体内容。因此增加的首字节的取值范围为[0xb8, 0xbf]，因此其能编码的最大数据长度为$2^56$
4. 如果是一个嵌套的列表数据，则需要先将列表中的数据按照单元素的编码规则进行RLP编码后串联得到列表数据的s。如果一个列表数据的s的字节长度为0-55，那么列表的RLP编码在其s前加上一个字节，这个字节的值是0xc0加上s的字节长度。因此首字节的取值范围为[0xc0, 0xf7]。
5. 如果一个列表数据的s的长度大于55，那么它的RLP编码是在开头增加一个字节，这个字节的值等于0xf7加上列表s字节长度的二进制编码的字节长度，然后依次跟着s字节长度部分和s部分。因此首字节的取值范围为[0xf8, 0xff]，因此一个列表中存储的所有元素的字节长度不能超过$2^56$。

## RLP源码解析
讲了一堆天书，终于到了关键地方了。
rlp分为`编码`和`解码`两个部分，当然，小编只会讲`编码`过程。
`解码`过程的实现和`编码`过程都差不多。
另外一个原因是小编没那么多精力去那么细看啦，知道有那么一回事就行。

### rlp编码后数据格式：
为了便于更好的理解后面的代码，小编现画出如下结构图：
{% asset_img 1.png  序列化后的数据结构%}
除了最后一个编码数据，其余编码后的每个原始数据之后，都对应的标有该数据的起始和截止位置信息。

### rlp模块源文件结构
项目根目录下，找到`rlp`目录，里面如下结构：
.
|____raw.go                  //用于处理编码后的rlp数据，比如计算长度、分离等
|____raw_test.go             //rlp数据测试用例
|____encode.go               //编码器，用于将给定的数据编码为rlp
|____encode_test.go          //编码测试，各种测试用例验证编码器的稳定性
|____encoder_example_test.go //用案例体验测试编码
|____decode.go               //解码器，用于将rlp数据解码为原始数据
|____decode_test.go          //用于测试解码，各种测试用例测试解码器的稳定性
|____decode_tail_test.go     //用案例体验测试解码
|____typecache.go            //类型缓存，用于记录哪些类型数据应该如何处理（如何编码和解码）
|____doc.go                  //没什么，rlp的相关描述

### rlp编码过程解析：第1部分
经过小编分析，从`encoder_example_test.go`这个文件作为入口来分析是最合适不过的。
该example的目的是编码一个结构体。根据前面的描述可知，编码一个结构体，基本就会牵涉到rlp的所有编码逻辑了。
具体来看看该文件的内容，先是定义了一个要进行编码的结构体，名为`MyCoolType`,而紧随其后，定义了属于该结构体的一个函数`EncodeRLP()`。
此处`EncodeRLP()`其实是一个`被实现了的接口函数`，等后面分析了`encode.go`的代码就会明白（具体go语法的接口实现，小编不想解释。。小编突然觉得，`该写个go语言教程了`)。
```go
type MyCoolType struct {  //要编码的的结构体
	Name string  //字符串，名称
	a, b uint    //两个整型数据
}

// 呵呵，(x *MyCoolType)表示，该方法是属于结构体的MyCoolType
// 呵呵，(err error)表示这个方法的返回值
func (x *MyCoolType) EncodeRLP(w io.Writer) (err error) {
	if x == nil {  //若结构体指针本身是空的，则编码{0,0}
		err = Encode(w, []uint{0, 0}) //此处可以发现，真正参与编码的只有结构体中的a,b两个
	}
	} else {  //否则编码指定结果
		err = Encode(w, []uint{x.a, x.b})
	}
	return err
}
```

接着来看看具体该结构体编码的过程
```go
//案例，测试为空和不为空的结构体的编码方式
func ExampleEncoder() {
	var t *MyCoolType // t 是空指针
	bytes, _ := EncodeToBytes(t) //编码成字节数组
	fmt.Printf("%v → %X\n", t, bytes)  //输出编码结果

	t = &MyCoolType{Name: "foobar", a: 5, b: 6} //t有数据
	bytes, _ = EncodeToBytes(t)  
	fmt.Printf("%v → %X\n", t, bytes)  //输出编码结果

	// Output:         //标准测试，必须如此输出，用于校验输出结果        
	// <nil> → C28080
	// &{foobar 5 6} → C20506
}
```
具体怎么运转这个测试，不要问小编，小编是个大忙人。。。

### rlp编码过程解析：第2部分
从上一部分example中发现，编码的入口函数是：`EncodeToBytes()`，随即我们跟踪到`encode.go`这个文件中，重头戏来了.
1. 先来看看该文件中定义的两个全局内容：
	* 该文件定义了，`空数据（理解成字符串吧）`和`空集合（树形结构）`对应编码后的结果
		```go
		EmptyString = []byte{0x80}  //128，定义了序列化时候的空字符串，空的时候对应的是编码128。
		EmptyList   = []byte{0xC0}  //192，定义了序列化时候的空集合，空的时候对应的编码192
		```
	* 其次，定义了一个接口，用于自定义编码数据（`看到了不，第1部分那个结构体里实现的方法，就是这个接口`）：
		```go
		//可以理解为，任何拥有下面接口中函数的`结构体`，都表示继承并实现了该接口
		type Encoder interface {
			EncodeRLP(io.Writer) error
		}
		```
	* 第1部分的一个待编码的结构体中，有两个uint数据，编码后，两个uint的序列是会衔接在一起的，因此为了便于区分我是需要知道每个uint在编码序列中的哪个位置，因此，有这么一个结构体：
		```go
		type encbuf struct {
			str     []byte      // 被编码后的数据全部在此处，比如第1部分结构体中的两个uint，编码后的结果都紧挨着存在该str中
			lheads  []*listhead // 每个数据在编码序列中存储的位置。比如，还是上面那两个uint，编码后，第一个uint在str中的起始位置是多少，截止位置是多少，都在listhead[0]中记录的
			lhsize  int         // lheads的长度，也就是说，被编码的数据有几个。比如，两个uint参与编码，那lhsize=2
			sizebuf []byte      // 9个字节大小的辅助buffer，专门用来处理uint的编码的
		}
		```
		* 呵呵，`listhead`这个结构体是如下定义的，用来确定被编码的数据，在序列中的哪一部分：
			```go
			type listhead struct {
				offset int // 被编码的某个数据在序列中的起始位置
				size   int // 包含头部在内的所有编码了的数据的总长度
			}
			```
		* 另外，encbuf结构体有如下这些函数（函数比较多，小编在此概述一下这些函数的功能）：
			1. `reset()`：用于将encbuf中的数据初始化，后面对象池中调取时候，会用到。
			2. `Write()`：实现了`io.Writer的接口`，用于连接byte[]编码，可以理解为字符串连接，在结构体若实现了`EncodeRLP`自定义编码，用`Write()`函数会很方便
			3. `encode()`：用于编码数据，同时将先后编码的数据依次衔接起来（`后面详细介绍`）。
			4. `encodeStringHeader()`：将encbuf中的头部是需要序列化，该函数是将头部结构体中的一个`新的编码后的元素`和`先前已编码的所有数据`衔接起来
			5. `encodeString()`：该函数是将当前编码后的一个原始数据衔接到已编码的所有数据之后
			6. `list()`：用于保存每个元素编码后的头部信息，
			7. `listEnd()`：编码衔接结束后的长度统计处理
			8. `size()`：计算编码后的数据和其头部的总长度
			9. `toBytes()`：将每个头部编码，并衔接到对应的编码后的数据之后
			10. `toWriter`：该方法是io流方式，将编码后的头部写在编码数据之后
			11. 看不懂这些方法的同学，最好先好好看看上面画的那个`序列化后的数据结构`图

2. ok，接着来看看我们的`EncodeToBytes()`函数，它就是用来将数据序列化为byte数组的元凶。
该函数中，可以发现，为了减少资源浪费，提高连续编码的效率，以太坊使用了对象池来保存一个`encbuf`实例
`ps`:下面代码有个关键词叫`defer`，表示，这行代码要等return完之后才会执行。
```go
	func EncodeToBytes(val interface{}) ([]byte, error) {
		eb := encbufPool.Get().(*encbuf)  //从对象池中获取一个用于存储完整编码数据的空间
		defer encbufPool.Put(eb)          //return 结束之后才会执行，将实例化的encbuf放入对象池，方便下次使用。
		eb.reset()  //encbuf结构体的函数，初始化该结构体对应实例中的元素
		if err := eb.encode(val); err != nil { //原始数据进行编码，刚编码好的数据是放在字符串中的
			return nil, err
		}
		return eb.toBytes(), nil //将编码后的数据本身和头部衔接起来并放在byte[]中，并返回最终结果
	}
```

这里真正重要的一段代码就是：`eb.encode(val)`，不要闷逼，再次强调`eb`是`encbuf结构体的实例`，`encode`是其最重要的函数，看看它的实现：
```go
func (w *encbuf) encode(val interface{}) error {
	rval := reflect.ValueOf(val)  //获取该数据具体的值（包括结构体）
	ti, err := cachedTypeInfo(rval.Type(), tags{}) //根据数据类型来编码数据
	if err != nil {
		return err
	}
	return ti.writer(rval, w)
}
```
先注意一下其中的最后一行代码涉及到的`writer()`，这个在下一节中会具体去讲，简单说就是，writer被定义为了一种数据类型，`只要满足它函数格式的，都属于writer类型`
好的，这块代码，其中的`cachedTypeInfo()`，把我们的节奏引入了高潮，具体如何，且听下一部分分析

### rlp编码过程解析：第3部分
继续上回讲解，`cachedTypeInfo()`函数是在`typecache.go`中实现的，这个文件里，对编码和解码做了详细的规划，让我们更加清晰的了解到了rpl的全局结构。
1. `cachedTypeInfo()`函数具体怎么回事我们先不说，按惯例，先来看看`typecache.go`该文件中主要定义了哪些全局属性：
	* 该文件定义了一个读写锁，多线程、并发读取数据时候的保护措施；还定义了一个映射，不同的数据类型，对应不同的编码或者解码器。
		```go
		var (
			typeCacheMutex sync.RWMutex    //读写锁，用来在多线程的时候保护typeCache这个Map
			//核心数据结构，保存了类型->编解码器函数，*typeinfo指针类型，根据不同的数据类型（reflect.Type），保存不同的解码方式
			typeCache      = make(map[typekey]*typeinfo)
		)
		```
		其中发现有两个重要的结构体：
		* 首先是`typekey`，定义了数据所属类型，以及该数据的特点（是否是集合，是否为空等）
			```go
			type typekey struct {
				reflect.Type   //数据类型不同，则编码解码的数据类型也不同
				tags //某种数据类型中，是否为空，是否为集合，不同情况处理不同
			}
			```
			* 在该结构体其中其中，又有一个`tags`结构体，主要是用来标注数据的特点，如下：
				```go
				type tags struct {
					nilOK bool  //是否为空
					tail bool  //是否为集合（切片）
					ignored bool  //该参数留着，备用
				}
				```
		* 其次定义了一个编码器和解码器的结构体`typeinfo`，注意他们对应的函数
			```go
			type typeinfo struct {
				decoder  //解码，
				writer   //编码
			}
			type decoder func(*Stream, reflect.Value) error //把满足该结构的函数，定义为数据类型decoder
			type writer func(reflect.Value, *encbuf) error  //把满足该结构的函数，定义为数据类型writer
			```
2. 接着我们来讲讲期待已久的`cachedTypeInfo()`函数，怎么说吧，它的作用是，根据数据属性的不同，返回一个合适的`编码\解码器`来处理该数据，为了保证读写安全，使用了读写锁；为了提高效率，缓存了`数据类型`和`编码\解码器`的映射（就是说，比如字符串类型的数据，要用到专门处理字符串的编码\解码器）。
```go
func cachedTypeInfo(typ reflect.Type, tags tags) (*typeinfo, error) {
	typeCacheMutex.RLock()  //加读锁来保护
	info := typeCache[typekey{typ, tags}]  //在缓存中查是找是否有typ类型的数据对应的 编码\解码器
	typeCacheMutex.RUnlock()
	if info != nil {   
		return info, nil  //若找到了，则返回结果
	}
	// not in the cache, need to generate info for this type.
	//加写锁 调用cachedTypeInfo1函数创建并返回，
	//这里需要注意的是在多线程环境下有可能多个线程同时调用到这个地方，
	//所以当你进入cachedTypeInfo1方法的时候需要判断一下是否已经被别的线程先创建成功了。
	typeCacheMutex.Lock()

	defer typeCacheMutex.Unlock()  //等return执行完毕后，才会调用该行defer。再次吐槽go..
	return cachedTypeInfo1(typ, tags) //缓存中不存在，则创建对应类型的编码\解码器
}
```
3. 上面代码，真正该注意的是`cachedTypeInfo1(typ,tags)`，它的目的就是根据数据类型去创建并缓存对应的编码\解码器。代码实现如下：
```go
func cachedTypeInfo1(typ reflect.Type, tags tags) (*typeinfo, error) {
	key := typekey{typ, tags}
	info := typeCache[key]
	if info != nil {  //此处再次验证是为了避免并发请求造成影响
		return info, nil
	}
	
	typeCache[key] = new(typeinfo)  //根据数据类型，新建一个它的编码\解码器的缓存空间（此时并不知道具体是哪个编码\解码器）
	info, err := genTypeInfo(typ, tags) //根据数据类型，找到它对应的编码\解码器
	if err != nil {
		delete(typeCache, key)  //创建失败则清除此空间
		return nil, err  //返回空
	}
	*typeCache[key] = *info //创建成功保存该编码器
	return typeCache[key], err //返回当前数据类型的编码/解码器
}
```
	* 上面代码，又有一个重要的函数：`genTypeInfo(typ, tags)`，它用来根据数据类型，找到对应的编码\解码器，具体实现如下：
		```go
		func genTypeInfo(typ reflect.Type, tags tags) (info *typeinfo, err error) {
			info = new(typeinfo)  //新建一个保存编码\解码的空间
			if info.decoder, err = makeDecoder(typ, tags); err != nil { //解码获取失败，则返回空
				return nil, err
			}
			if info.writer, err = makeWriter(typ, tags); err != nil {  //编码获取失败，则返回空
				return nil, err
			}
			//只有成功找到了编码器和解码器，才会返回它们的映射信息。别忘了info的结构体类型
			return info, nil  
		}
		```
清楚了吧，整个编码器和解码器的框架结构其实并不复杂，其中用到的线程安全机制和缓存机制是蛮有意思的。对于上面代码提到的`makeDecoder()`和`makeWriter()`,也就是具体获取编码\解码器是怎样实现的，小编在下一部分来解释，莫心急，心急吃不了豆腐～～～

### rlp编码过程解析：第4部分
1. 紧接上一部分，`makeDecoder()`和`makeWriter()`具体是用来实现获取对应编码\解码器的，这下又跳转回`encode.go`文件中，小编这里只讲编码器`makeWriter()`的获取了，解码器类似，只是相反而已。具体如下：
	```go
	func makeWriter(typ reflect.Type, ts tags) (writer, error) {
		kind := typ.Kind()  //先获取数据类型
		switch {
			case typ == rawValueType:
				return writeRawValue, nil 
			case typ.Implements(encoderInterface):
				return writeEncoder, nil 
			case kind != reflect.Ptr && reflect.PtrTo(typ).Implements(encoderInterface):
				return writeEncoderNoPtr, nil 
			case kind == reflect.Interface:
				return writeInterface, nil    
			case typ.AssignableTo(reflect.PtrTo(bigInt)):
				return writeBigIntPtr, nil  
			case typ.AssignableTo(bigInt):
				return writeBigIntNoPtr, nil 
			case isUint(kind):
				return writeUint, nil  
			case kind == reflect.Bool:
				return writeBool, nil
			case kind == reflect.String:
				return writeString, nil
			case kind == reflect.Slice && isByte(typ.Elem()):
				return writeBytes, nil
			case kind == reflect.Array && isByte(typ.Elem()):
				return writeByteArray, nil
			case kind == reflect.Slice || kind == reflect.Array:
				return makeSliceWriter(typ, ts)
			case kind == reflect.Struct:
				return makeStructWriter(typ)
			case kind == reflect.Ptr:
				return makePtrWriter(typ)
			default:
				return nil, fmt.Errorf("rlp: type %v is not RLP-serializable", typ)
		}
	}
	```
	这个代码应该很好懂吧，根据不同的数据类型，返回对应的具体的编码函数，注意看`makeWriter()`的数据返回类型，返回的是一个编码函数，这就是对应数据类型的编码器。每种数据类型都有各自的编码器被返回。建议大家根据需要去仔细读读每种编码器的具体实现方式，也挺有意思的。
	另外需要知道，对于长度为1的数据，是没有必要做head记录的。因此，关于对head操作，大伙看看不同的编码器中的处理就明白了。
2. 小编根据第1部分提供的待编码数据类型可知，该数据类型是指针，且实现了`EncodeRLP()`接口，它对应的类型是上述代码中的第2个`case`,即`typ.Implements(encoderInterface)`，因此小编详细介绍下`writeEncoder()`，先看它的代码：
```go
func writeEncoder(val reflect.Value, w *encbuf) error {
	return val.Interface().(Encoder).EncodeRLP(w)
}
```
	就两行代码，指向了我们在第1部分的定义的待编码的结构体数据中的`EncodeRLP()`函数，为了方便演示，小编这里再列出来看看：
	```go
	type MyCoolType struct {  
		Name string  
		a, b uint   
	}
	func (x *MyCoolType) EncodeRLP(w io.Writer) (err error) {
		if x == nil 
			err = Encode(w, []uint{0, 0}) 
		else 
			err = Encode(w, []uint{x.a, x.b})
		return err
	}
	```
	呵呵，发现了吧，该接口实现中，调用了`Encode()`函数，其中的参数`w`指的是它是`encbuf`，该函数是在`encode.go`文件中。那就看看它的具体实现吧：
	该函数其实也很有特点：因为有的时候，以太坊中的数据并不是直接通过`EncodeToBytes()`传入具体的数据来编码，很多时候它是通过io流传入待编码数据的，因此，其实这个`Encode()`函数也很重要。
	```go
	func Encode(w io.Writer, val interface{}) error {
		//语法说明，断言w.(*encbuf)的具体类型是否为*encbuf，是，则返回给outer=*encbuf,并且ok为true；否，则返回outer=nil，并且ok为false
		if outer, ok := w.(*encbuf); ok { //EncodeRLP接口提供的参数是`io.Writer`类型，但是，从前面分析我们得知，我们传入的是实现了`io.Writer`的`encbuf`。因此需要判断。
			return outer.encode(val) 
		}
		eb := encbufPool.Get().(*encbuf) //若是直接输入的`io.Writer`流来编码，则通过该处对象池将其转为`encbuf`
		defer encbufPool.Put(eb) //当return后才会执行
		eb.reset()
		if err := eb.encode(val); err != nil { 
			return err
		}
		return eb.toWriter(w)
	}
	```
	若传入的是标准`io.Writer`,则该代码最终返回的是`eb.toWriter(w)`流结果，它和`EncodeToBytes()`函数中返回的byte[]结果还是有区别的。
	此处编码结束，看看下1部分吧，在坚持一下就可以结束了～～

### rlp编码过程解析：第5部分
拿到编码器就可以回到第2部分的`encode()`函数了。返回编码结果，进一步返回到`EncodeToBytes()`函数，最终返回到第1部分的编码结果。

## 解码相关概述
本来小编是不想讲的，想了想，还是大概说两句吧。
解码和编码的方向相反，方式一样。解码时候，先计算好开辟好的结构体、数据类型等的大小和空间，然后就可以在被序列化的编码中，读取到指定位置的值，从而读取到具体数据。
还不懂吗？看代码吧。。。

## 总结
吐出一口老血，终于完成这个浩大的工程了。。。
解码过程就不写了，根据编码过程反推就行。














