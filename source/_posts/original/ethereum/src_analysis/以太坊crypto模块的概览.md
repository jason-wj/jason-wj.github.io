---
title: 以太坊crypto模块的概览
mathjax: true
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
abbrlink: 66d6f92e
date: 2018-11-01 18:10:07
---
小编只敢说概览，密码学这片海洋，只是沾了沾脚。。。了解一下这个模块，对以太坊账户以及验证机制心里也就有个底了。了解后，有个好处就是，可以把它用在自己想用的地方。
<!-- more -->

## 综述
以太坊中，对于数据的安全操作，都在以太坊官方的`crypto`代码中（要和golang官方提供的`crypto`区分），大致可以分为2部分：
1. 散列(sha3-Keccak算法)
对块的验证、pow中的hash碰撞、签名等等，都是使用`Keccak算法`来生成hash的，严格意义上讲，Keccak算法和标准的sha3算法并不一样，因此，这个安全散列算法应该称为Keccak算法。
2. 签名（secp256k1算法）
该算法是一种椭圆曲线数字签名算法(ECDSA)，在比特币中已经得以应用，在以太坊中，是通过它来进行密钥生成、签名、验证、公钥账户地址转换）。在整个以太坊生态中，有举足轻重的作用。

## Keccak算法
1. 2015年以前,sha3的标准就是keccak，但后来，sha3标准修改了其中的“海绵算法”，导致之后两者没有太大关系。因此，为了更明确的区分，需要知道以太坊生成hash用的是`keccak安全散列算法`。
2. 需要知道，该算法生成的散列长度是`32字节`，也就是`256位`

### 算法原理
请参考这篇文章，原先转载的，里面很通俗的讲了keccak的原理：http://www.wjblog.top/articles/d7792efc

### 以太坊中Keccak的操作
下面是以太坊提供的一个单元测试用例：
其中：
`abc`为用来生成hash的原文
`4e03657aea45a94fc7d47ba826c8d667c0d1e6e33a64a036ec44f58fa12d6c45`为`abc`生成的hash
程序的大意就是，将`abc`生成hash，然后和预先设置的`abc`的hash做比较，看结果是否一致。
真正调用到`Keccak`的地方，只有这么一处：`Keccak256Hash(in)`，传入原文，返回hash结果
```golang
func TestKeccak256Hash(t *testing.T) {
	//原文转为字节数组
	msg := []byte("abc")
	//将16进制的hash结果，转为2进制。用于稍后和原文生成的hash做比较
	exp, _ := hex.DecodeString("4e03657aea45a94fc7d47ba826c8d667c0d1e6e33a64a036ec44f58fa12d6c45")
	//Keccak256Hash(in)，原文生成hash
	checkhash(t, "Sha3-256-array", func(in []byte) []byte { h := Keccak256Hash(in); return h[:] }, msg, exp)
}

func checkhash(t *testing.T, name string, f func([]byte) []byte, msg, exp []byte) {
	sum := f(msg)
	//判断二者是否一致
	if !bytes.Equal(exp, sum) {
		t.Fatalf("hash %s mismatch: want: %x have: %x", name, exp, sum)
	}
}
```

## secp256k1签名
1. 这个签名算法需要比较深的密码学背景才能吃透，我根据自己掌握的密码学基础讲一下为什么选择椭圆曲线的算法作为以太坊密钥生成算法，
在密码学中，会有一个安全等级的划分。
2. 通常，需要`2^n`次才能破解的算法，我们称为该算法拥有`n位安全等级`，通常分为四个等级：80位、128位、192位和256位四个等级，
这个模块比较复杂,如果要细度源码,需要对密码学有比较深入的理解,但是使用起来其实比较简单.不同算法为了保证某安全等级，所要使用的密钥长度如下：
<table><tr><th>算法家族</th><th>密码体制</th><th colspan="4">安全级别（位）</th></tr><tr><td></td><td></td><td>80</td><td>128</td><td>192</td><td>256</td></tr><tr><td>离散分解<br>离散对数<br>椭圆曲线</td><td>RSA<br>DH、DSA、Elgamal<br>ECDH、ECDSA</td><td>1024位<br>1024位<br>160位</td><td>3072位<br>3072位<br>256位</td><td>7680位<br>7680位<br>384位</td><td>15360位<br>15360位<br>512位</td></tr><tr><td>对称密钥</td><td>AES、3DES</td><td>80位</td><td>128位</td><td>192位</td><td>256位</td></tr></table>
从对称与否、密钥长度和对应安全级别参考，综合考虑下来，椭圆曲线是不二之选。这是我个人的想法，不一定符合以太坊官方的考虑规则。
3. 该算法主要就是密钥生成、签名,验证,以及公钥与以太坊地址转换
4. 密钥长度是`256位`，需要切记。
5. `2018-11-13补充`：常见的非对称加密算法除了椭圆加密算法之外，还有著名的RSA。椭圆加密相比RSA的区别是：
	1. 椭圆加密的密钥更短
	2. 椭圆加密计算更快而安全性相当
	3. RSA的私钥和公钥是何以互换加解密的，但椭圆加密只能私钥加密公钥解密。
6. 公钥、私钥
	1. 私钥
		以太坊的私钥是一个32字节的数，取值范围从1~0xFFFF FFFF FFFF FFFF FFFF FFFF FFFF FFFE BAAE DCE6 AF48 A03B BFD2 5E8C D036 4140。这个数可以由伪随机算法(PRNG)产生。其实0也是一个合法的私钥，只不过这是一个特殊私钥，以太坊的创世区块就是这个私钥生成的
	2. 公钥
		以太坊的非压缩公钥是一个65字节的数，这个是继承至比特币的。但以太坊只使用了其中64个字节，有一个字节这64个字节中，32字节表示椭圆曲线的X坐标，32字节表示椭圆曲线的Y坐标。这个XY坐标是私钥通过ECDSA-secp256k1推导出来的。所以说，椭圆曲线算法的公钥是通过私钥计算出来的。而反过来，用公钥推导私钥，以现有计算机的计算几乎是不可能的，这也是以太坊和比特币存在的基础。如果哪天计算机技术出现大飞跃，比如量子计算机普及，现有链上所有账户的私钥都会曝光。当然，区块链技术本身也会一定会持续演进的。

### 公钥、私钥生成
crypto提供了随机生成私钥的方法，私钥是可以推导出公钥的：
私钥随机生成的随机数，使用golang自己的 crypto/rand.reader生成的
通过对以太坊中`cmd/geth/accountcmd.go`的源码分析（accountCreate方法中调用的keystore.StoreKey），发现就是通过下面这段代码来生成私钥地址的

`备注：`私钥本质上就是一个 256 个二进制位的随机数字（2^256 ~ 10^77，目前可见宇宙中估计只含有 10^80 个原子）
*这里遗留一个问题是，为什么这样生成不会出现重复的私钥？暂时还不明白。*
```golang
func TestGenerateKey(t *testing.T) {
	privateKey, _ := GenerateKey()
	publicKey := privateKey.Public()
	fmt.Printf("privateKey:%v,\npublicKey:%x\v", privateKey, publicKey)
}
```

### 签名、验证

#### 1. 签名
secp256k1的私钥地址长度是`32字节256位`,公钥地址长度是65字节。
其中，需要注意的是，被签名的必须是32字节的hash；二签名后的数据，长度和公钥一样长。
```golang
//16进制，256位的私钥，这个可以理解为是secp256k1的私钥，为方便测试，预先生成
var testPrivHex = "289c2857d4598e37fb9647507e47a309d6133539bf21a8b9cb6df88fd5232032"

func TestSign(t *testing.T) {
	//根据这个随机数来生成密钥
	key, _ := HexToECDSA(testPrivHex)
	//使用keccak生成原文"foo"的hash
	msg := Keccak256([]byte("foo"))

	//使用密钥对原文对hash进行签名，该msg必须是32位的hash
    //生成的sign
	sig, err := Sign(msg, key)
	if err != nil {
		t.Errorf("Sign error: %s", err)
}
```

#### 2. 验证
为了方便，将上一步骤的代码也加入了下方，形成签名->验证两个环节
该过程主要就是从签名文件中拿到公钥，转换成以太坊地址，然后和测试提供的地址比较，是否一致。
```golang
//这个是测试用的账户地址，验证时候使用
var testAddrHex = "970e8128ab834e8eac17ab8e3812f010678cf791"
//一个256位的随机数，16进制，这个随机数是如何生成的，暂时还没研究，也是密码学里真随机和伪随机的概念
//根据这个随机数来生成密钥
var testPrivHex = "289c2857d4598e37fb9647507e47a309d6133539bf21a8b9cb6df88fd5232032"

func TestVerify(t *testing.T) {
	//根据这个随机数来生成密钥
	key, _ := HexToECDSA(testPrivHex)
	addr := common.HexToAddress(testAddrHex)

	//使用keccak生成原文"foo"的hash
	msg := Keccak256([]byte("foo"))

	//使用密钥对原文对hash进行签名，该msg必须是32位的hash
	sig, err := Sign(msg, key)
	fmt.Printf("签名结果：%v\n", sig)

	if err != nil {
		t.Errorf("Sign error: %s", err)
	}
	//根据签名和原文内容，提取出二进制公钥
	recoveredPub, err := Ecrecover(msg, sig)
	if err != nil {
		t.Errorf("ECRecover error: %s", err)
	}
	//将2机制公钥转换成16进制（65字节）的公钥序列
	pubKey := ToECDSAPub(recoveredPub)
	//将公钥序列转换成账户地址，其实就是取公钥hash处理后的后20位作为地址
	recoveredAddr := PubkeyToAddress(*pubKey)
	//验证生成的公钥地址和测试提供的地址是否一致
	if addr != recoveredAddr {
		t.Errorf("Address mismatch: want: %x have: %x", addr, recoveredAddr)
	}
}
```

### 公钥与地址的转换
上一步骤中已经提到了，我们说的以太坊账户地址并不是公钥地址，而是取的`公钥地址hash运算`后的后20位作为账户。
具体可以深入到代码中去理解。大概位置是：crypto.go中的PubkeyToAddress函数，调用的`common.BytesToAddress(Keccak256(pubBytes[1:])[12:])`