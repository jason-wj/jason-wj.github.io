---
title: 以太坊源码解读-第3讲-trie模块源码解读
mathjax: true
copyright: true
original: true
explain: 文中可能会根据需要做部分调整
date: 2018-04-17 14:44:59
categories: [原创,以太坊,源码解读]
tags: [ethereum]
---

## 前言
了解以太坊的同学都知道，以太坊中有三大重要的状态：`账户状态`、`交易状态`、`收据状态`（不要问小编它们有什么用\-\_\-）。这三大状态怎么保存，怎样保证这些信息的安全？这就离不开我们这次要讲的以太坊`trie`模块了。
它提供了一种强大的数据结构`Merkle Patricia Tries`，我们亲切的称它为`MPT`。正是它维护着我们的这三种状态，让整个以太坊平稳有序的进行着。
看到这么强大的东西，是不是经不起诱惑了？那我们就快来解刨吧。

## MPT的前世今生
MPT是这三种结构的组合：Trie，Patricia Trie，Merkle tree。每一种都非常经典，为了更好的了解以太坊，小编专门整理了三篇文章，值得一读（依次从上往下读）：
[浅谈标准Trie树（字典树）](/articles/original/ethereum/src_analysis/以太坊源码解读-第3讲-trie模块源码解读.html#more)
[Patricia树介绍](/articles/original/blockchain/Patricia树介绍.html#more)
