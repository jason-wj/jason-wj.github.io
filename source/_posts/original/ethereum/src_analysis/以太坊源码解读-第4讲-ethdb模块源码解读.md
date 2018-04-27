---
title: 以太坊源码解读-第4讲-ethdb模块源码解读
mathjax: true
copyright: true
original: true
explain: 文中可能会根据需要做部分调整
date: 2018-04-26 15:02:38
categories: [原创,以太坊,源码解读]
tags: [ethereum]
---
看了trie模块的源码，我们知道了其中的节点数据是通过ethdb来进行磁盘db的读写操作的。其实ethdb是依赖google的一个开源kv数据库levelDB实现的。最终所有的数据都是存储在levelDB中。
我们会很好奇，什么是levelDB？在ethdb中是如何处理levelDB的？下面小编一步步来揭开它的面纱

## 什么是levelDB

### 特点：
* 效率高，支持billion级别的数据量
* key和value都是任意长度的字节数组；
* entry（即一条K-V记录）默认是按照key的字典顺序存储的，当然开发者也可以重载这个排序函数；
* 提供的基本操作接口：Put()、Delete()、Get()、Batch()；
* 支持批量操作以原子操作进行；
* 可以创建数据全景的snapshot(快照)，并允许在快照中查找数据；
* 可以通过前向（或后向）迭代器遍历数据（迭代器会隐含的创建一个snapshot）；
* 自动使用Snappy压缩数据；
* 可移植性；

### 限制：
* 非关系型数据模型（NoSQL），不支持sql语句，也不支持索引；
* 一次只允许一个进程访问一个特定的数据库；
* 没有内置的C/S架构，就是说不包含网络服务架构，但开发者可以使用LevelDB库自己封装一个server；

## ethdb模块概述
这个模块不复杂，直接看里面的文件结构：
.
|____interface.go  数据库接口定义
|____database.go  对levelDB进行封装
|____database_test.go  测试案例
|____memory_database.go  用于db测试，生产中不可使用。在trie模块中的测试案例应该见过很多次这个东西了
一目了然，只有四个文件。下面我们一个个来讲

## 
