---
title: ipfs集群客户端操作
mathjax: false
copyright: true
original: true
top: false
notice: false
categories:
  - 原创
  - ipfs
  - ipfs应用
tags:
  - ipfs
  - storate
abbrlink: ccf3d056
date: 2018-11-01 09:39:17
---
## 前言
本文主要讲的是ipfs集群客户端的操作，这种操作分为两类，一类是通过命令行来控制，另一类是通过restful api来操作，后者对于开发者来说，会有很大帮助。
操作本文内容前，需要先完成前两篇文章中的内容：
[ipfs私有环境搭建](/articles/7987f3ac)
[ipfs集群搭建](/articles/ba940e6d)
<!-- more -->

## 说明
1. `ipfs-cluster-ctl`的使用，请参考：https://cluster.ipfs.io/documentation/ipfs-cluster-ctl/
2. 默认情况下`ipfs-cluster-ctl`的使用，需要保证`service.json`中的设置为：`api.restapi.http_listen_multiaddress: /ip4/127.0.0.1/tcp/9094`
3. 可以选择其中一台安装有ipfs-cluster-server的机器来安装ipfs-cluster-cli

## 主要命令
1. 查看集群当前节点中的节点信息：
  ```bash
  ipfs-cluster-ctl peers ls 
  ```
  {% asset_img 1.png  当前节点信息 %}
2. 查看集群节点关系图
  ```bash
  ipfs-cluster-ctl health graph
  ```
  {% asset_img 1.png  集群拓扑信息 %}

3. （补充）删除节点中的某个节点（集群节点）
  ```bash
  ipfs-cluster-ctl peers rm 集群节点
  ```

## IPFS集群数据同步
正常情况下，有被搜索过的数据才会被ipfs节点保存，要想让数据同步，需要集群的干预。
以上传一个`test.txt`文件为例，里面内容为:
```txt
HelloWorld!
```

### 1. ipfs节点node1上传文件test.txt
```bash
sudo docker exec ipfs ipfs add -r /export/test.txt
```
获得该文件的hash：QmcxC7pxf96yiUyxzkUPoewMMtJst2cFAKQq8CMKXuCSdc

### 2. 根据文件hash将数据同步到集群
```bash
# 全网的ipfs节点repo 都存在该hash.
ipfs-cluster-ctl pin add QmcxC7pxf96yiUyxzkUPoewMMtJst2cFAKQq8CMKXuCSdc
```
返回结果：
```bash
QmcxC7pxf96yiUyxzkUPoewMMtJst2cFAKQq8CMKXuCSdc :
    > iZt4ne720rsobv353yq8kzZ : PINNED | 2018-10-25T16:24:04Z
    > iZt4ne720rsobv353yq8kyZ : PINNED | 2018-10-25T16:24:04Z
```

### 3. 通过pin检测ipfs节点是否有某hash对应的文件
前面步骤中，得到了上传文件的hash。
在另一个节点，使用：
```bash
sudo docker exec ipfs ipfs pin ls QmcxC7pxf96yiUyxzkUPoewMMtJst2cFAKQq8CMKXuCSdc
```
若返回：
```bash
QmcxC7pxf96yiUyxzkUPoewMMtJst2cFAKQq8CMKXuCSdc recursive
```
则说明，该数据在该节点上

### 4. 检测集群同步数据状态
可查看集群中文件的同步状态，此命令在某一节点删除文件后有延迟，延迟时间尚不确定
```bash
ipfs-cluster-ctl status
```
返回结果：
```bash
QmcxC7pxf96yiUyxzkUPoewMMtJst2cFAKQq8CMKXuCSdc :
    > iZt4ne720rsobv353yq8kzZ : PINNED | 2018-10-25T16:24:04Z
    > iZt4ne720rsobv353yq8kyZ : PINNED | 2018-10-25T16:24:04Z
```

### 5. 跟踪集群中文件的同步状态
和上面的命令`ipfs-cluster-ctl status`稍微有所不同
```bash
ipfs-cluster-ctl sync
```

### 6. 集群取消同步某个hash文件
```bash
ipfs-cluster-ctl pin rm QmcxC7pxf96yiUyxzkUPoewMMtJst2cFAKQq8CMKXuCSdc
```

## http rest api说明以及测试
### rest api
参考官方提供的说明：https://cluster.ipfs.io/developer/api/
通过它，可以很方便的使用开发操作
### 测试
```bash
http://192.168.3.100:9094/id
http://192.168.3.100:9094/version
```·