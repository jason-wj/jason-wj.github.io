---
title: 以太坊dpos共识改造-实现dpos算法
mathjax: true
copyright: true
original: true
top: false
notice: false
date: 2019-01-27 16:09:53
categories:
  - 原创
  - 以太坊
  - 综合
tags:
  - ethereum
---
dpos是什么，为什么要改造成dpos，这些问题小编就不解释了。可参考：[委托股权证明原理(DPOS)--翻译及解读(/articles/bbe43e3f)]
对以太坊做dpos共识改造，从0开始是不可能的，这里小编参考了[美图以太坊dpos改造](https://github.com/meitu/go-ethereum)。美图实验室的改造相比较来说更加直观，网上这方面对信息不多，为此，小编参考该项目重头敲了一遍这个共识。收益颇多，也发现了很多不足的地方。
<!-- more -->
美图官方发布的改造教程解说并不多，讲述的内容也很简洁。为此，小编通过这篇文章详细解释下dpos在以太坊中的改造细节。自我总结的同时，希望能对大家有所帮助。
美图是在ethereum1.7.4上改造dpos的，而小编是在1.8.20上改造的，会有一些差异，但影响不大。
本文最后会介绍这次改造中的不足之处，后续会逐步完善。

## dpos整体框架
小编先前在[以太坊源码解读-第6.1讲-共识模块入口设计](/articles/3673b530)以及[以太坊源码解读-第6.2讲-pow共识算法实现](/articles/231042d1)中解释过，
实现一套共识算法，是需要在以太坊提供的共识引擎之下完成。
美图DPOS的实现方案如下图所示：
{% asset_img 1.png  Dpos算法整体结构 %}
注意区分候选人和验证人，`验证人是候选人之一，但候选人不一定是验证人`
从上图可以看出，分成三大部分，这里简述一下其中每部分的作用：
1. dpos_context和dpos_context_pro：用来存储和操作验证人、投票、候选人等信息，是通过trie来将这些信息存储在leveldb中。这些信息主要分为5部分：
    1. EpochTrie：记录当前周期的验证人列表
    2. DelegateTrie：记录每个候选人对应的投票人，一个候选人有不同的投票人
    3. VoteTrie：记录投票人对应的候选人，每个投票人只能对应一个候选人
    4. MintCntTrie：记录验证人在当前周期内的出块数
2. epoch_context：dpos验证阶段的处理，图中可知，主要完成四部分内容：
    1. CountVotes:获取候选人及其对应投票数（积分）
    2. KickoutValidator：踢除不合格的验证人
    3. LookupValidator：获取当前验证人，就是确定应该由哪个验证人来出块
    4. TryElec：发起新一轮选举，从候选人中选出验证人
3. Dpos：实现共识引擎，dpos的主体


## 

