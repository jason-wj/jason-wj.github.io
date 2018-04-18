---
title: Merkle Patricia Tree (MPT) 以太坊merkle技术分析
mathjax: false
copyright: true
original: false
explain: 文中可能会根据需要做部分调整
date: 2018-04-17 18:53:52
categories: [精品转载,以太坊]
tags: [ethereum]
authorship: CSDN
srcpath: https://blog.csdn.net/zslomo/article/details/53434883
---

## 传统merkle tree的缺陷
传统merkle树的一个特别的限制是，它们虽然可以证明包含此交易，但无法证明任何当前的状态（例如：数字资产的持有，名称注册，金融合约的状态等）。你现在拥有了多少个比特币？一个比特币轻客户端，可以使用一种涉及查询多个节点的协议，并相信其中至少会有一个节点会通知你关于你的地址中任何特定的交易支出，而这可以让你实现更多的功能。但对于其他更为复杂的应用而言，这些远远是不够的。一笔交易影响的确切性质（precisenature），可以取决于此前的几笔交易，而这些交易本身则依赖于更为前面的交易，所以最终你可以验证整个链上的每一笔交易。为了解决这个问题，以太坊的梅克尔树的概念，会更进一步。
<!-- more -->
## 以太坊的改进

### 先说前缀树
MPT中的Patricia即patricia tree 前缀树，也叫trie或者字典树，刷过oj的同学都体验过这个数据结构的查找速度有多快，甚至超过hash 
传统的前缀树如下：
{% asset_img 1.jpg  传统的（标准）trip示意图 %}
上面这棵trie包含这样一组单词，inn, int, at, age, adv, ant 每个节点存储的是字符串中的谋和字符，每个从根到某个节点的路径（不一定到叶子节点）代表了一个存储的字符串，如果我想查找adv是否存在，只需要走红圈这样的路径即可

上图是一个简略视图，实际上trie每个节点是一个确定长度的数组，数组中每个节点的值是一个指向子节点的指针，最后有个标志域，标识这个位置为止是否是一个完整的字符串，并且有几个这样的字符串

常见的用来存英文单词的trie每个节点是一个长度为27的指针数组，index0-25代表a-z字符，26为标志域，如图：
{% asset_img 2.jpg  传统的（标准）trip完整示意图 %}

### 传统trie的局限
* 高度不可控
	{% asset_img 3.jpg  trie缺点之一：高度不可控 %}
	如上图所示，如果有一个字符串很长，且跟其他字符串没有公共前缀，就会形成这样的一棵极其不平衡的树，整棵树的性能会被少量的这样的字符串拖慢，并且给攻击者提供了可能

* 安全系数不高
传统的trie是由内存指针来连接节点，并且字符串的值就相当于存储在这棵树中，两者完全暴露在外，毫无安全性可言。

### 以太坊漂亮的改进
* 压缩路径
	传统的trie只有一种节点，该节点是一个数组，每个index是指向子节点的指针

	以太坊增加了两个新的节点，称为`叶子节点`和`扩展节点`，两个节点的形式一样，都是一个[key,value]的组合，原来的节点称为`分支节点`

	key、value 有没有感觉很熟悉？是的就是数据库，以太坊的数据存放在google的levelDB关系数据库中

	叶子节点和扩展节点的区别在于：value域，叶子节点的value就是字符串的值，而扩展节点的value是一个指向另一个节点的指针

	详细的增删改查操作原理非常长我不在这里阐述，这篇[Merkle Patricia Tree (MPT) 树详解](http://www.cnblogs.com/fengzhiwu/p/5584809.html) 以及这篇[Understanding the ethereum trie](https://easythereentropy.wordpress.com/2014/06/04/understanding-the-ethereum-trie/)讲的非常好，也非常详细，我只总结一些关键的东西。（`wj小编ps：原文作者在这里提到的两篇文章，讲的很详细，涉及到源码解析，但是建议等读者在区块链有一定的沉淀后再考虑阅读`）

	我们来看看这个两个增加的神奇节点，回想我们上面的图，当一个长长长长的字符串被插入trie很不幸又没有其他字符串与他相匹配时，会形成一个很长的路径

	如今，当我们发现新加入了一个这样的节点，我们直接生成一个value为“understand”的叶子节点，长度从10直接压缩到了1!
	{% asset_img 4.jpg  添加第一个节点 %}
	如果再插入一个“understood”，那么我们会新建一个分支节点，不妨称为node。另外会生成一个key为“underst”，而value为指向node的`扩展节点`（指针），不妨称为extension ，它指向新创建的两个`叶子节点`，leaf1、leaf2这两个叶子的value分别为“understand”和“understood” 
	{% asset_img 5.png  添加添加新的节点，有共同前缀 %}
* 安全性
MPT中的节点是一个key：value的组合，但是并直接存储value，而是经过编码的value，此处value的编码方式为RLP编码，而key是RPL编码的hash值，指针依然不是内存地址，而是hash值 
所有非叶节点存在levelDB数据库中