---
title: 提交hexo源码到项目（网页）子分支
date: 2018-03-21 17:01:36
categorise: [Hexo,项目编译部署]
tags: [Hexo,git,github]
---
通过Hexo发布到name.github.io中到文件是用来网站展示静态页面，并不是编译使用的源文件，若不备份好本地的源文件，当机器丢失由没做好备份的画，就再也不能发表文章了。  
小编建议将项目源文件也同时发布到github的同一个文件下。但是，master分支是一个特殊的分支，用来展示页面用的，会有很多限制，因此，需要将项目源码发在一个子分支。  
用IntelliJ idea折腾了半天，浪费了半天时间也没搞出个啥，最后反而用git命令一下子就搞出来了。。  
```text
git init
git add .  # 把当前目录的文件都加到索引（ignore的除外）
git commit -m "init"  # 消息
git push origin master:src  # 当前索引的代码添加到远程的src分支
```
之后就可以用Intellij idea将项目关联git了，之后发文章的时候，记得分清哪个分支就行