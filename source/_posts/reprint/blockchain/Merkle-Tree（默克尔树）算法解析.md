---
title: Merkle Tree（默克尔树）算法解析
mathjax: false
copyright: true
original: true
explain: 文中可能会根据需要做部分调整
date: 2018-04-17 15:33:16
categories: [精品转载,区块链]
tags: [区块链,数据结构]
authorship: 博客园
srcpath: http://www.cnblogs.com/fengzhiwu/p/5524324.html
---

## Merkle Tree概念
Merkle Tree，通常也被称作Hash Tree，顾名思义，就是存储hash值的一棵树。Merkle树的叶子是数据块(例如，文件或者文件的集合)的hash值。非叶节点是其对应子节点串联字符串的hash。
<!-- more -->
{% asset_img 1.png  Merkle Tree结构示意图 %}

### Hash
Hash是一个把任意长度的数据映射成固定长度数据的函数。例如，对于数据完整性校验，最简单的方法是对整个数据做Hash运算得到固定长度的Hash值，然后把得到的Hash值公布在网上，这样用户下载到数据之后，对数据再次进行Hash运算，比较运算结果和网上公布的Hash值进行比较，如果两个Hash值相等，说明下载的数据没有损坏。可以这样做是因为输入数据的稍微改变就会引起Hash运算结果的面目全非，而且根据Hash值反推原始输入数据的特征是困难的。
{% asset_img 2.png  hash生成 %}
如果从一个稳定的服务器进行下载，采用单一Hash是可取的。但如果数据源不稳定，一旦数据损坏，就需要重新下载，这种下载的效率是很低的。
`wj备注：因此引出了下文的Hash List`

### Hash List
在点对点网络中作数据传输的时候，会同时从多个机器上下载数据，而且很多机器可以认为是不稳定或者不可信的。为了校验数据的完整性，更好的办法是把大的文件分割成小的数据块（例如，把分割成2K为单位的数据块）。这样的好处是，如果小块数据在传输过程中损坏了，那么只要重新下载这一快数据就行了，不用重新下载整个文件。

怎么确定小的数据块没有损坏哪？只需要为每个数据块做Hash。BT下载的时候，在下载到真正数据之前，我们会先下载一个Hash列表。那么问题又来了，怎么确定这个Hash列表本事是正确的哪？答案是把每个小块数据的Hash值拼到一起，然后对这个长字符串在作一次Hash运算，这样就得到Hash列表的根Hash(Top Hash or Root Hash)。下载数据的时候，首先从可信的数据源得到正确的根Hash，就可以用它来校验Hash列表了，然后通过校验后的Hash列表校验数据块。 
{% asset_img 3.png  Hash List %}

### Merkle Tree
Merkle Tree可以看做Hash List的泛化（Hash List可以看作一种特殊的Merkle Tree，即树高为2的多叉Merkle Tree）。

在最底层，和哈希列表一样，我们把数据分成小的数据块，有相应地哈希和它对应。但是往上走，并不是直接去运算根哈希，而是把相邻的两个哈希合并成一个字符串，然后运算这个字符串的哈希，这样每两个哈希就结婚生子，得到了一个”子哈希“。如果最底层的哈希总数是单数，那到最后必然出现一个单身哈希，这种情况就直接对它进行哈希运算，所以也能得到它的子哈希。于是往上推，依然是一样的方式，可以得到数目更少的新一级哈希，最终必然形成一棵倒挂的树，到了树根的这个位置，这一代就剩下一个根哈希了，我们把它叫做 Merkle Root。

在p2p网络下载网络之前，先从可信的源获得文件的Merkle Tree树根。一旦获得了树根，就可以从其他从不可信的源获取Merkle tree。通过可信的树根来检查接受到的Merkle Tree。如果Merkle Tree是损坏的或者虚假的，就从其他源获得另一个Merkle Tree，直到获得一个与可信树根匹配的Merkle Tree。

Merkle Tree和Hash List的主要区别是，可以直接下载并立即验证Merkle Tree的一个分支。因为可以将文件切分成小的数据块，这样如果有一块数据损坏，仅仅重新下载这个数据块就行了。如果文件非常大，那么Merkle tree和Hash list都会很大，但是Merkle tree可以一次下载一个分支，然后立即验证这个分支，如果分支验证通过，就可以下载数据了。而Hash list只有下载整个hash list才能验证。
{% asset_img 4.png  Merkle Tree %}

## Merkle Tree的特点
1. MT是一种树，大多数是二叉树，也可以多叉树，无论是几叉树，它都具有树结构的所有特点；
2. Merkle Tree的叶子节点的value是数据集合的单元数据或者单元数据HASH。
3. 非叶子节点的value是根据它下面所有的叶子节点值，然后按照Hash算法计算而得出的。

## Merkle Tree的操作
一些常见操作
###  创建Merckle Tree
加入最底层有9个数据块。
1. （红色线）对数据块做hash运算，Node0i = hash(Data0i), i=1,2,…,9
2. （橙色线）相邻两个hash块串联，然后做hash运算，Node1((i+1)/2) = hash(Node0i+Node0(i+1)), i=1,3,5,7;对于i=9, Node1((i+1)/2) = hash(Node0i)
3. （黄色线）重复step2
4. （绿色线）重复step2
5. （蓝色线）重复step2，生成Merkle Tree Root
{% asset_img 5.png  创建Merckle Tree %} 
易得，创建Merkle Tree是O(n)复杂度(这里指O(n)次hash运算)（`wj小编备注：这里没看懂，为什么是O(n)次`），n是数据块的大小。得到Merkle Tree的树高是log(n)+1。

### 检索数据块
为了更好理解，我们假设有A和B两台机器，A需要与B有相同的结构体：相同目录下有8个文件，文件分别是f1 f2 f3 ….f8。这个时候我们就可以通过Merkle Tree来进行快速比较。假设我们在文件创建的时候每个机器都构建了一个Merkle Tree。具体如下图: 
{% asset_img 6.png  检索 %}
从上图可得知，叶子节点node7的value = hash(f1),是f1文件的HASH;而其父亲节点node3的value = hash(v7, v8)，也就是其子节点node7 node8的值得HASH。就是这样表示一个层级运算关系。root节点的value其实是所有叶子节点的value的唯一特征。

假如A上的文件5与B上的不一样。我们怎么通过两个机器的merkle treee信息找到不相同的文件? 这个比较检索过程如下:
1. 首先比较v0是否相同,如果不同，检索其孩子node1和node2.
2. v1 相同，v2不同。检索node2的孩子node5 node6;
3. v5不同，v6相同，检索比较node5的孩子node 11 和node 12
4. v11不同，v12相同。node 11为叶子节点，获取其目录信息。
5. 检索比较完毕。

以上过程的理论复杂度是Log(N)。过程描述图如下:
{% asset_img 7.png  检索 %}
从上图可以得知真个过程可以很快的找到对应的不相同的文件。

### 更新，插入和删除
虽然网上有很多关于Merkle Tree的资料，但大部分没有涉及Merkle Tree的更新、插入和删除操作，讨论Merkle Tree的检索和遍历的比较多。我也是非常困惑，一种树结构的操作肯定不仅包括查找，也包括更新、插入和删除的啊。后来查到stackexchange上的一个问题，才稍微有点明白，原文见[6]。

对于Merkle Tree数据块的更新操作其实是很简单的，更新完数据块，然后接着更新其到树根路径上的Hash值就可以了，这样不会改变Merkle Tree的结构。但是，插入和删除操作肯定会改变Merkle Tree的结构，如下图，一种插入操作是这样的，插入前数据如下状态：
{% asset_img 8.png  插入前数据状态 %}
插入数据块0后(考虑数据块的位置)，Merkle Tree的结构是这样的：
{% asset_img 9.png  插入后数据状态 %}
[6]中说明，实际上Merkle Tree的结构(是否平衡，树高限制多少)在大多数应用中并不重要，而且保持数据块的顺序也在大多数应用中也不需要。因此，可以根据具体应用的情况，设计自己的插入和删除操作。一个通用的Merkle Tree插入删除操作是没有意义的。

##  Merkle Tree的应用
`wj小编这里就不整理了`，区块链里，这个结构是离不开的，具体怎么实现，就需要大家根据需要去具体了解了。


>[1]  https://en.wikipedia.org/wiki/Merkle_tree
>[2]  https://en.wikipedia.org/wiki/Hash_function#Hash_function_algorithms
>[3]  http://www.jianshu.com/p/458e5890662f
>[4]  http://blog.csdn.net/xtu_xiaoxin/article/details/8148237
>[5]  http://blog.csdn.net/yuanrxdu/article/details/22474697?utm_source=tuicool&utm_medium=referral
>[6]  http://crypto.stackexchange.com/questions/22669/merkle-hash-tree-updates
>[7]  https://en.wikipedia.org/wiki/BitTorrent
>[8]  梁成仁, 李健勇, 黄道颖, 等. 基于 Merkle 树的 BT 系统 torrent 文件优化策略[J]. 计算机工程, 2008, 34(3): 85-87.
>[9]  http://bittorrent.org/beps/bep_0030.html
>[10] 徐梓耀, 贺也平, 邓灵莉. 一种保护隐私的高效远程验证机制[J]. Journal of Software, 2011, 22(2).
>[11] http://whatdoesthequantsay.com/2015/09/13/ipfs-introduction-by-example/
>[12] https://www.weusecoins.com/what-is-a-merkle-tree/
>[13] http://www.8btc.com/merkling-in-ethereum
