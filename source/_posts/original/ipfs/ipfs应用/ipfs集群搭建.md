---
title: ipfs集群搭建
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
abbrlink: ba940e6d
date: 2018-11-01 09:19:01
---
## 前言
本文主要是讲ipfs私有集群的搭建，本文是在上一篇文章[ipfs私有环境搭建](/articles/7987f3ac)的基础上进一步搭建的。文中涉及到小编项目隐私的内容，已经做了脱敏处理。
<!-- more -->

## 概述
ipfs集群同步，同时要对集群管理，在已有环境的基础上，还需要再加入如下项目:
`https://github.com/ipfs/ipfs-cluster`
其中分为两个部分
1. `ipfs-cluster-service`：集群服务端
下载地址：`https://dist.ipfs.io/ipfs-cluster-service/v0.6.0/ipfs-cluster-service_v0.6.0_linux-amd64.tar.gz`
2. `ipfs-cluster-ctl`：集群客户端
下载地址：`https://dist.ipfs.io/ipfs-cluster-ctl/v0.6.0/ipfs-cluster-ctl_v0.6.0_linux-amd64.tar.gz`
 
## 集群配置要求
1. 每个ipfs节点都要安装`ipfs-cluster-service`
2. 其中一个或者某几个节点安装`ipfs-cluster-ctl`来和前端交互
3. 该安装过程略，都是可执行程序，加个环境变量就可以

## 配置
分别配置`ipfs-cluster-service`和`ipfs-cluster-ctl`

### ipfs-cluster-service
1. 每个ipfs节点都要执行：
```bash
ipfs-cluster-service init
```
此时会在`/home/wj/`中生成一个新目录：
```
├── peerstore     #  存储当前连接集群节点地址
├── raft          #  是ipfs的协议共识机制
│   ├── raft.db
│   └── snapshots
└── service.json  #  集群service端配置文件
```

2. `service.json`说明
    1. 该文件是集群server端核心配置文件
    2. 在该目录下生成的service.json中的`cluster.id`，表示集群当前节点的id，不是ipfs的节点id，注意区分。
    3. 在centos7中，是在此处生成：`/root/.ipfs-cluster/service.json`
3. 选择一个管理节点
管理节点的作用是，集群中，以该节点作为主节点
还是上面的`service.json`，
在此选择node1节点作为集群的管理节点：`cluster.id: QmXr7xVQmdVW45RPBnor2M3G600000PyktuZz5QLpN59QN`
`"secret": "2437f6e6a0b223e4ae0896efc68271939d000003151c5eeb1bad48d2a666584b"`
4. 修改管理节点ip连接：
`ps`:其余每个节点也要做类似操作，将ip改成自己所在节点的`地址`，不能是`域名`
有的文章中将`service.json`中，下面的地址改成127.0.0.1之外的ip，但是经过测试，后面集群同步会有问题，且效率低下，因此，如无必要或者对这些不熟悉，不建议修改，默认值即可。
```yaml
## ip问题，以下为默认值，不建议修改
# 对外开放api，若有需要，可以修改此处ip
api.restapi.http_listen_multiaddress: /ip4/127.0.0.1/tcp/9094
# 节点连接ipfs
ipfs_connector.ipfshttp.node_multiaddress: /ip4/127.0.0.1/tcp/5001
# 节点监听
ipfs_connector.ipfshttp.proxy_listen_multiaddress: /ip4/127.0.0.1/tcp/9095
```
`2018.10.26补充`：经过多次尝试，以上几个ip设置的都是默认的127.0.0.1,这样可以增加安全性，公网rest api无法直接访问其中的端口。若想要完全开放，只要将ip全改为`0.0.0.0`即可。
`2018.10.27补充`：为了方便开发和测试，将node2节点此处的相关ip都设置成`0.0.0.0`。

### ipfs-cluster-ctl
安装好即可，不用额外处理，具体可看下一个笔记，客户端管理集群

## 启动运行

### 启动管理节点
启动管理节点的ipfs-cluster-serivce
```bash
nohup ipfs-cluster-service daemon &
```
此时日志会有该管理节点地址，记录下，下一步用到：
`/ip4/192.168.3.100/tcp/9096/ipfs/QmXr7xVQmdVW45RPBnor2M3G600000PyktuZz5QLpN59QN`

### 其余节点启动并加入管理节点之中
其余每个节点都执行启动，都要和管理节点连通，注意，只能用ip地址，`不能用域名`，无法识别：
```bash
nohup ipfs-cluster-service daemon --bootstrap /ip4/192.168.3.100/tcp/9096/ipfs/QmXr7xVQmdVW45RPBnor2M3G600000PyktuZz5QLpN59QN &
```

## ipfs节点内容测试
其中`QmbvBDKPhdHMVDthaafapqsis9g4YorjRp3bTLc4v7ZMp2`，为原先上传的一张图片
```
http://192.168.3.101:8080/ipfs/QmbvBDKPhdHMVDthaafapqsis9g4YorjRp3bTLc4v7ZMp2/

http://192.168.3.100:8080/ipfs/QmbvBDKPhdHMVDthaafapqsis9g4YorjRp3bTLc4v7ZMp2/
```·