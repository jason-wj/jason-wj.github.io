---
title: hexo的next分享设置
categories:
  - 原创
  - Hexo
  - 界面优化
tags:
  - Hexo
  - NexT
copyright: true
original: true
abbrlink: 9eebfb44
date: 2018-03-22 14:07:24
---
## 2018-05-02 更新
jiathis官方在2018.04.30宣布分享业务关闭，因此小编原先写的内容无法再使用。小编现在提供新的解决方案：
<!-- more --> 
同样是在`/theme/next/`中的`_config.yml`配置文件中，找到如下内容：
```
baidushare:
  type: button
```
若有注释，则去掉，只如此配置即可，切记`type`前面有两个空格,`button`前有一个空格。
重新发布即可。

## 历史内容
next官方介绍的那个`baidushare: true`方式的分享，一直无效。网上找了半天，也没发现个合适的分享设置方式，也一个比一个复杂，更何况小编也不是搞前端开发的。。。。
在此，小编提供一个自己最终的解决方式： 
* 进入`themes/next`目录，打开`_config.yml`，找到`jiathis:`这一项
* 取消`jiathis:`注释，并将其设置为`jiathis: true`，注意，` true`前面有一个空格
* ok，此时重新发布自己的网站，博客最底部分享按钮出现了吧？但是里面各种分享都在，小编自己只需要几个常用的分享就行，好吧，只好改源码了（放心不复杂）  
    * 进入`themes/next/layout/_partials/share/`，打开`jiathis.swig`文件
    * 将自己不需要的分享注释掉 
    * 但是会发现，里面没有自己想要的微博分享和贴吧分享，好吧，继续
    * 抓包或者直接进入`jiathis.swig`里出现的这个网址：`http://www.jiathis.com/share?uid=2140465`（具体分析过程就不讲了，直接看结果），呵呵，发现微博叫做`tsina`，贴吧就是`tieba`，按这规则，把以下内容放在`jiathis.swig`中微信分享的那个地方附近：
    ```html
    <a class="jiathis_button_tsina">微博</a>
    <a class="jiathis_button_tieba">贴吧</a>
    <a class="jiathis_button_yixin">易信</a>
    ```
    * 搞定，保存，重新发布，期待已久的分享功能就出来了
    {% asset_img 1.png 分享功能 %}
    * 在此贴出小编最终的`jiathis.swig`配置（里面没怎么改）：
```html
<!-- JiaThis Button BEGIN -->
<div class="jiathis_style">
<span class="jiathis_txt">分享到：</span>
<a class="jiathis_button_weixin">微信</a>
<a class="jiathis_button_tsina">微博</a>
<a class="jiathis_button_tieba">贴吧</a>
<a class="jiathis_button_yixin">易信</a>
<!--此处请参考一键分享按钮对应的地址信息-->
<!--<a class="jiathis_button_qzone">QQ空间</a>
<a class="jiathis_button_fav">收藏夹</a>
<a class="jiathis_button_copy">复制网址</a>
<a class="jiathis_button_email">邮件</a>
<a class="jiathis_button_tqq">腾讯微博</a>
<a class="jiathis_button_douban">豆瓣</a>
<a class="jiathis_button_share">一键分享</a>

<a href="http://www.jiathis.com/share?uid=2140465" class="jiathis jiathis_txt jiathis_separator jtico jtico_jiathis" target="_blank">更多</a>
<a class="jiathis_counter_style"></a>-->
</div>
<script type="text/javascript" >
var jiathis_config={
  data_track_clickback:true,
  summary:"",
  shortUrl:false,
  hideMore:false
}
</script>
<script type="text/javascript" src="http://v3.jiathis.com/code/jia.js?uid={{ theme.jiathis.uid }}" charset="utf-8"></script>
<!-- JiaThis Button END -->
```