---
title: hexo常用属性设置
date: 2018-03-21 13:33:34
categories: [Hexo,界面优化]
tags: [Hexo,NexT]
---
##  
* 进入`themes/next`,打开`_config.yml`  
* 修改如下： 
```yml
# Automatically Excerpt. Not recommand.
# Please use <!-- more --> in the post to control excerpt accurately.
auto_excerpt:
  enable: true  //此处将false改为true,设置首页显示文章概述（即取消默认全文）
  length: 150
 
# Declare license on posts
post_copyright:
  enable: true  //改为true，文章设置结束语，默认false
  license: CC BY-NC-SA 3.0
  license_url: https://creativecommons.org/licenses/by-nc-sa/3.0/
  
# Sidebar Avatar
# in theme directory(source/images): /images/avatar.gif
# in site  directory(source/uploads): /uploads/avatar.gif
avatar: /images/my_head.jpg  //设置头像图片，在sources/images下添加头像图片，默认不显示
```