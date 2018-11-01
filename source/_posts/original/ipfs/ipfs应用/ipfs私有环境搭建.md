---
title: ipfs私有环境搭建
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
abbrlink: 7987f3ac
date: 2018-11-01 09:01:50
---
## 前言
本文主要讲的是ipfs私有环境的配置，使用两个节点。
<!-- more -->

## ubuntu相关
### 服务器信息
1. 服务器1（节点1）:root@192.168.3.100
    1. ipfs第一节点
    2. 密码已修改******
2. 服务器2（节点2）:root@192.168.3.101
    1. ipfs第二节点
    2. 密码已修改******
3. hosts文件：
虽然hosts中配置如下内容，但经测试发现，还是得用ip，用域名会产生异常
```
192.168.3.100 node1
192.168.3.101 node2
```

### 目录结构说明
1. `~/app/` ：为方便管理，手动安装的软件统一放在此处
    1. `~/app/golang/go`：go安装目录
    2. `~/app/golang/gopath`：gopath位置
2. docker镜像相关映射目录，均放在`~/docker`中
    1. `~/docker/ipfs`：ipfs相关
3. `/usr/local/bin`：部分执行文件直接放于此处
    1. `/usr/local/bindocker-compose`:不解释
    
### 其余
其余基本配置和安装，此处略

## docker相关
其余基本的依赖安装、服务启动相关，此处不描述

### docker安装
1. 更新apt
```bash
sudo apt-get  update
```
2. 安装docker
```bash
sudo apt-get install  docker
```
3. 安装docker.io
```bash
sudo apt-get install docker.io
```
4. 安装docker-registry
```bash
sudo apt-get install  docker-registry
```
5. 此时docker已经启动，若未启动，执行：
```bash
sudo systemctl start docker
```

### docker-compose安装
```bash
sudo curl -L "https://github.com/docker/compose/releases/download/1.22.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
```

### ipfs启动
此时会同时初始化
```bash
docker run -d --name ipfs -v ~/docker/ipfs/export:/export -v ~/docker/ipfs/data:/data/ipfs -p 4001:4001 -p 8080:8080 -p 5001:5001 ipfs/go-ipfs:latest
```

## ipfs私有环境配置

### 每个节点均执行以下步骤

#### 生成共享key
私有网络，需要拥有相同key的节点在一起
1. 下载go相关依赖包：
```bash
go get -u github.com/Kubuxu/go-ipfs-swarm-key-gen
```
2. 生成key
`ipfs/data`中
```bash
~/docker/ipfs/data/swarm.key
```
3. 复制到另一个节点
需要保证每个节点都有相同的swarm.key，类似于网络许可证
```bash
scp ~/docker/ipfs/data/swarm.key 192.168.3.101:~/docker/ipfs/data/
```

#### 删掉默认的ipfs可以发现的网络
```bash
sudo docker exec ipfs  ipfs bootstrap rm --all
```

#### 重新启动发现
docker镜像启动后，默认就会启动该服务
```bash
sudo docker exec ipfs ipfs daemon
```

#### 配置http head
为了方便外部访问，比如5001的webui访问，需要修改配置文件
```bash
vim /home/wj/docker/ipfs/data/config
补全如下内容：
  "API": {
    "HTTPHeaders": {
      "Server": [
        "go-ipfs/0.4.17"
      ]
      "Access-Control-Allow-Methods": [
        "GET","POST","PUT","OPTIONS"
      ],
      "Access-Control-Allow-Origin": [
        "*"
      ]
    }
  },
```
重启：
```bash
sudo docker restart ipfs
```

#### 总结
如此，就有一个节点生成了，此时已经是启动可发现状态
1. node1节点id：`QmNdi6ExJ9Rcpggf41uB7TYuHhPUBExg2fbV8V7TCXFj8Z`
2. node2节点id：
`QmSBQvCgomiMCdGULVdehLZFKXLpNRNyo67ZRk43g8mQpC`

### 将其中一个节点加入到另一个节点
1. 若有多个节点，则选择其中一个节点做标准，然后加入到其它每个节点中，也就是说，若有A、B、C、D、E、F五个节点，选择节点A为标准，将节点A加入到B、C、D、E、F中。
2. `ps`：因目前docker-compose还未使用，暂时直接添加ip，后面再用hosts文件来设置域名。
3. 比如将节点2加入到节点1中
```bash
sudo docker exec ipfs ipfs bootstrap add /ip4/192.168.3.100/tcp/4001/ipfs/QmNdi6ExJ9Rcpggf41uB7TYuHhPUBExg2fbV8V7TCXFj8Z
```
检查是否加入
```bash
sudo docker exec ipfs ipfs swarm peers
```

### 测试
目的：将一张图片加入到ipfs节点
1. 因为使用的是docker，从外部映射的文件夹到ipfs中，也就是说，要将待上传图片test.jpg放在`/home/wj/docker/ipfs/export`
2. 然后执行：
```bash
sudo docker exec ipfs ipfs add -r /export/test.jpg
```·