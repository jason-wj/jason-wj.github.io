---
title: '''hexo d''后github需重新绑定域名问题'
categories:
  - 原创
  - Hexo
  - 项目编译部署
tags:
  - NexT
  - Hexo
  - github
copyright: true
original: true
abbrlink: 2c7cd733
date: 2018-03-22 11:21:37
---
小编每次`hexo d`发布的时候，github都需要重新绑定域名，并且还得该域名解析，很麻烦。为了避免这种麻烦，可以进行如下操作：  
<!-- more -->
1. 从项目根目录进入`/source`文件夹，创建一个名为`CNAME`的文本文件，没有后缀
2. 进入该文件，输入你的域名地址，比如小编的是：`www.wjblog.top`,然后保存并退出
3. `hexo d`重新发布到github  
4. 大功告成

