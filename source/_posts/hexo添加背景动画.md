---
title: hexo添加背景动画
date: 2018-03-21 09:44:05
categories: [Hexo,界面优化]
tags: [Hexo,NexT]
---
项目中，在文件：\themes\next\layout\_layout.swig的`</body>`上面添加  
```html
{% if theme.canvas_nest %}
  <script type="text/javascript" src="//cdn.bootcss.com/canvas-nest.js/1.0.0/canvas-nest.min.js"></script>
{% endif %}
```
同时在`\themes\next\_config.yml`中添加如下内容：    
```yml
# background settings
# add canvas-nest effect
# see detail from https://github.com/hustcc/canvas-nest.js
canvas_nest: true
```
添加完了，发现博客背景是白色，会遮住动画，只留下两边一点点的位置看到动画效果，这时候可以去设置一下背景颜色，在`\themes\next\source\css\_schemes\Pisces\_layout.styl`中，把`.content-wrap`中的background修改为none。  

此时电脑端展示正常，但是手机端展示缺很异常，此时同样可以在`.content-wrap`中把+mobile()中的background修改为white，这样手机端的体验就好很多，却又不影响电脑端的炫酷动画。    
