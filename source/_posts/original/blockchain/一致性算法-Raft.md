---
title: 一致性算法-Raft
mathjax: false
copyright: true
original: false
top: false
notice: false
explain: 文中可能会根据需要做部分调整
categories:
  - 原创
  - 区块链
tags:
  - 区块链
  - 共识机制
authorship: 黎跃春区块链博客
srcpath: 'http://liyuechun.org/2018/05/18/Consistency-algorithm-Raft/'
abbrlink: abf4a6b7
date: 2018-07-17 16:28:02
---
## wj前言
小编之所以要转载这篇文章，是因为Raft也是很重要的一个共识算法。小编看了很多白皮书，做公链的基本没有人提到Raft算法，但不能说它就不重要。
<!--more-->
共识机制不是什么新鲜东西，在大数据领域中，已经用的很成熟了，其中的Raft就是Zookeeper的核心。
并且，在区块链的联盟链领域中，Raft也是举足轻重，目前比较火的`超级账本`项目，用的就是这一共识。

## Raft 状态
一个 Raft 集群包含若干个服务器节点；通常是 5 个，这允许整个系统容忍 2 个节点的失效，每个节点处于以下三种状态之一：
* `follower` ：所有结点都以`follower`的状态开始。如果没收到`leader`消息则会变成`candidate`状态。
* `candidate`：会向其他结点“拉选票”，如果得到大部分的票则成为`leader`。这个过程就叫做Leader选举(Leader Election)。
* `leader`：所有对系统的修改都会先经过`leader`。

## Raft 一致性算法
Raft通过选出一个leader来简化日志副本的管理，例如，日志项(log entry)只允许从leader流向follower。
基于leader的方法，Raft算法可以分解成三个子问题：
1. `Leader election`(领导选举)：原来的leader挂掉后，必须选出一个新的leader
2. `Log replication`(日志复制)：leader从客户端接收日志，并复制到整个集群中
3. `Safety`(安全性)

### Leader election (领导选举)
Raft 使用一种心跳机制来触发领导人选举。当服务器程序启动时，他们都是`follower`(跟随者)身份。如果一个跟随者在一段时间里没有接收到任何消息，也就是选举超时，然后他就会认为系统中没有可用的领导者然后开始进行选举以选出新的领导者。要开始一次选举过程，`follower`会给当前term加1并且转换成`candidate`状态。
然后他会并行的向集群中的其他服务器节点发送请求投票的 RPCs 来给自己投票。候选人的状态维持直到发生以下任何一个条件发生的时候:

* 他自己赢得了这次的选举
	* 如果这个节点赢得了半数以上的vote就会成为leader，每个节点会按照first-come-first-served的原则进行投票，并且一个term中只能投给一个节点， 这样就保证了一个term最多有一个节点赢得半数以上的vote。
	* 当一个节点赢得选举， 他会成为leader， 并且给所有节点发送这个信息， 这样所有节点都会回退成follower。

* 其他的服务器成为领导者
	* 如果在等待选举期间，candidate接收到其他server要成为leader的RPC，分两种情况处理：
	* 如果leader的term大于或等于自身的term，那么改candidate 会转成follower 状态
	* 如果leader的term小于自身的term，那么会拒绝该 leader，并继续保持candidate 状态

* 一段时间之后没有任何一个获胜的人
	* 有可能，很多follower同时变成candidate，导致没有candidate能获得大多数的选举，从而导致无法选出主。当这个情况发生时，每个candidate会超时，然后重新发增加term，发起新一轮选举RPC。需要注意的是，如果没有特别处理，可能出导致无限地重复选主的情况。
	* Raft采用随机定时器的方法来避免上述情况，每个candidate选择一个时间间隔内的随机值，例如150-300ms，采用这种机制，一般只有一个server会进入candidate状态，然后获得大多数server的选举，最后成为主。每个candidate在收到leader的心跳信息后会重启定时器，从而避免在leader正常工作时，会发生选举的情况。

### Log replication (日志复制)
当选出`leader`后，它会开始接受客户端请求，每个请求会带有一个指令，可以被回放到状态机中。`leader`把指令追加成一个`log entry`，然后通过AppendEntries RPC并行的发送给其他的server，当该entry被多数派server复制后，`leader`会把该entry回放到状态机中，然后把结果返回给客户端。
当`follower`宕机或者运行较慢时，`leader`会无限地重发AppendEntries给这些follower，直到所有的follower都复制了该log entry。
raft的log replication保证以下性质(Log Matching Property)：
* 如果两个log entry有相同的index和term，那么它们存储相同的指令
* 如果两个log entry在两份不同的日志中，并且有相同的index和term，那么它们之前的log entry是完全相同的

其中特性一通过以下保证：
* leader在一个特定的term和index下，只会创建一个log entry
* log entry不会改变它们在日志中的位置
特性二通过以下保证：
* AppendEntries会做log entry的一致性检查，当发送一个AppendEntriesRPC时，leader会带上需要复制的log entry前一个log entry的(index, iterm)

如果follower没有发现与它一样的log entry，那么它会拒绝接受新的log entry 

## 动画演示 Raft
http://thesecretlivesofdata.com/raft

## Raft作为公链应用的不足之处
* 选举共识节点未参考节点的区块高度，不能跟区块链有效结合；
* 选举一个共识节点并由此节点持续记账，容错性较差；
* 目前很多方案对共识节点的监管不够，不能实现共识节点的动态加入退出。

