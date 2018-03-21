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
### 替换标签符号,将"#"变成一个标签图片  
在`/themes/next/layout/_macro/post.swig`中，找到`rel="tag">#`，将其中的`#`替换成`<i class="fa fa-tag"></i>`  
### 在文章末尾添加结束标示  
* 在路径`\themes\next\layout\_macro`中新建`passage-end-tag.swig`文件,并添加以下内容：  
    ```html
    <div>
        {% if not is_index %}
            <div style="text-align:center;color: #ccc;font-size:14px;">-------------本文结束<i class="fa fa-paw"></i>感谢您的阅读-------------</div>
        {% endif %}
    </div>
    ```  
* 接着进入`\themes\next\layout\_macro\post.swig`文件中，在`post-body`对应标签结束后，输入如下： 
    ```html
    <div>
      {% if not is_index %}
        {% include 'passage-end-tag.swig' %}
      {% endif %}
    </div>
    ```