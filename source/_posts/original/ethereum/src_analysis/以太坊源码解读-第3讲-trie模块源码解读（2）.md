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
大家得先看懂[以太坊源码解读-第3讲-trie模块源码解读（1）](/articles/original/ethereum/src_analysis/以太坊源码解读-第3讲-trie模块源码解读（1）.html)关于节点方面的内容，否则很难理解小编下面要讲的源码





