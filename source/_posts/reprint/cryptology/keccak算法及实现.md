---
title: keccak算法及实现
mathjax: false
copyright: true
original: false
top: false
notice: false
explain: 文中可能会根据需要做部分调整
categories:
  - 精品转载
  - 密码学
tags:
  - cryptology
authorship: CSDN-浮云若飞
srcpath: 'https://blog.csdn.net/qq_34911465/article/details/78635027'
abbrlink: d7792efc
date: 2018-07-31 17:14:32
---
## 前言
SHA3采用Keccak算法，在很多场合下Keccak和SHA3是同义词，但在2015年8月SHA3最终完成标准化时，NIST调整了填充算法，标准的SHA3和原先的Keccak算法就有所区别了。在早期的Ethereum相关代码中，普遍使用SHA3代指Keccak256，为了避免和NIST标准的SHA3混淆，现在的代码直接使用Keccak256作为函数名。
总结为一句话：Ethereum和Solidity智能合约代码中的SHA3是指Keccak256，而不是标准的NIST-SHA3，为了避免混淆，直接在合约代码中写成Keccak256是最清晰的。

现在社会中hash算法的应用越来越广泛，因为hash 算法可以用于保证文件不被篡改，可以保证消息正确有效，同时还可以做数字签名，在http协议的开发中，还可以验证某个文件是否被修改过以做到断点续传。而传统的hash函数受到的攻击也越来越多，攻击方法也越来越有效，旧的算法变得不安全，那么就要推行新的标准，而keccak作为SHA- 3算法中的最终的优胜者，当然是有他的优势所在的，所以这里将讨论keccak算法的原理，同时封装一个计算文件hash值的函数。
<!-- more -->

## keccak算法介绍
完整的描述keccak算法是比较复杂的，这里只讨论这个算法的特征。首先他是采用了海绵结构， 
什么是海绵结构呢，首先海绵是可以吸水的，吸了水以后呢又可以挤压将水给挤压出来，保持整个海绵的结构不变。所以海绵结构的工作原理是先输入我们要计算的串，然后对串进行一个填充，将输入串用一个可逆的填充规则填充并且分块，分块后就进行吸水的阶段，当处理完所有的输入消息结构以后，海绵结构切换到挤压状态，挤压后输出的块数可由用户任意选择。 
然后在海绵结构的过程中，总共有五个计算步骤，分别是θ, ρ, π, χ, ι, 下面贴出伪代码：
```python
Keccak-f[b](A) {
  for i in 0…n-1
    A = Round[b](A, RC[i])
  return A
}

Round[b](A,RC) {
  # θ step
  C[x] = A[x,0] xor A[x,1] xor A[x,2] xor A[x,3] xor A[x,4],   for x in 0…4
  D[x] = C[x-1] xor rot(C[x+1],1),                             for x in 0…4
  A[x,y] = A[x,y] xor D[x],                           for (x,y) in (0…4,0…4)

  # ρ and π steps
  B[y,2*x+3*y] = rot(A[x,y], r[x,y]),                 for (x,y) in (0…4,0…4)

  # χ step
  A[x,y] = B[x,y] xor ((not B[x+1,y]) and B[x+2,y]),  for (x,y) in (0…4,0…4)

  # ι step
  A[0,0] = A[0,0] xor RC

  return A
}
```
上面的是轮函数，总共要计算24轮，下面是调用及输出:
```python
    Keccak[r,c](Mbytes || Mbits) {
    # Padding
    d = 2^|Mbits| + sum for i=0..|Mbits|-1 of 2^i*Mbits[i]
    P = Mbytes || d || 0x00 || … || 0x00
    P = P xor (0x00 || … || 0x00 || 0x80)

    # Initialization
    S[x,y] = 0,                               for (x,y) in (0…4,0…4)

    # Absorbing phase
    for each block Pi in P
      S[x,y] = S[x,y] xor Pi[x+5*y],          for (x,y) such that x+5*y < r/w
      S = Keccak-f[r+c](S)

    # Squeezing phase
    Z = empty string
    while output is requested
      Z = Z || S[x,y],                        for (x,y) such that x+5*y < r/w
      S = Keccak-f[r+c](S)

    return Z
    }
```
有了伪代码以后就可以完成整个函数的构建了，这里是github的代码：[keccak](https://github.com/zjtone/keccak-python)

下面是选择计算hash的文件并计算输出hash值：
```python
import Keccak

print("请输入文件路径：")
path = input()
keccak = Keccak.Keccak(1600)
mIn = ''
array = []
try:
    # 这部分是做了KeccakF的结果
    with open(path,"rb") as input:
        j = 0
        while True:
            j += 1
            second_array = []
            i = 0
            while True:
                tB = input.read(1)
                mIn += str(int("%X"%ord(tB),16))
                i += 8
                if len(tB) == 0 or i >= 64:
                    break
                else:
                    second_array.append(int("%X"%ord(tB),16))
            array.append(second_array)
            if j == 5:
                break
    keccak.KeccakF(array, True)
    # keccak.printState(array,'Final result')
    # 这部分是进行Keccak的结果
    mArray = []
    mArray.append(len(mIn))
    mArray.append(mIn)
    print("计算的hash值为: \n"+keccak.Keccak(mArray))
except IOError as err:
    print("错误：" + str(err))
```
以上部分就是hash函数，基于python的
