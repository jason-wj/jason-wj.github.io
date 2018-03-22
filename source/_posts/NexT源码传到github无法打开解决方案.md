---
title: NexT源码传到github无法打开解决方案
date: 2018-03-22 11:30:23
categories: [Hexo,项目编译部署]
tags: [Next,Hexo,github]
---
当Hexo项目发送到github上时，发现`/themes/next`文件夹打不开，小编网上找了下，大体是这么一回事：  
这属于git的子模块功能，当在自己的项目里clone别人的项目的时候，子模块只是一个HEAD指针，指向子模块的commit。  
也就是说，最初我们是通过`git clone`将NexT克隆到Hexo项目里的，这个NexT和Hexo项目一起上传到github的时候，是把NexT当成指向NexT官方地址一个指针传上去的。而实际的NexT文件还是在本地的git缓存中。  

### 具体解决方法：  
* 你可以建立两个分支，一个存储官方指针，一个存储自行大量修改过的NexT.
* 也可以在根目录运行：  
```text
git ls-files --stage | grep 160000
git rm --cached themes/next
```  
然后next文件夹就变成普通文件夹了，就可以按照通常的方式来操作了。


