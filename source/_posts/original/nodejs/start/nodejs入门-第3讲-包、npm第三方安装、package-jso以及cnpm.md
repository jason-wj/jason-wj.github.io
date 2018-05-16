---
title: (nodejs入门)第3讲-包、npm第三方安装、package.jso以及cnpm
copyright: true
original: true
categories:
  - 原创
  - nodejs
  - 入门教程
tags:
  - nodejs
abbrlink: 227a0b07
date: 2018-03-26 19:15:12
---
## 包与npm
### 包 概述
Nodejs中第三方模块由包组成，可以通过包来对一组具有相互依赖关系的模块进行统一管理。
{% asset_img 1.png  包%}
完全符合CommonJs规范的包目录一般包含如下这些文件：
* package.json :包描述文件。
* bin :用于存放可执行二进制文件的目录。
* lib :用于存放JavaScript代码的目录。
* doc :用于存放文档的目录。
通过npm来安装这些包
<!-- more -->
### npm 概述
npm是世界上最大的开放源代码的生态系统。我们可以通过npm下载各种各样的包，这些源代码（包）我们可以在https://www.npmjs.com找到。
npm是随同NodeJS一起安装的包管理工具，能解决NodeJS代码部署上的很多问题，常见的使用场景有以下几种：
* 允许用户从NPM服务器下载别人编写的第三方包到本地使用。(silly-datetime)
* 允许用户从NPM服务器下载并安装别人编写的命令行程序(工具)到本地使用。（supervisor）
* 允许用户将自己编写的包或命令行程序上传到NPM服务器供别人使用。

## npm命令介绍
1. 查看版本
```text
mpm -v
```
2. 使用 npm 命令安装模块
```text
npm install Module Name
```
3. 卸载模块
```text
npm uninstall ModuleName
```
4. 查看当前目录下已安装的node包
```text
npm list
```
5. 查看某模块信息
```text
npm info 模块
```
6. 指定版本安装
```text
npm install jquery@1.8.0
```

## package.json
package.json定义了这个项目所需要的各种模块,以及项目的配置信息(比如名称、版本、许可证等元数据)
1. 创建package.json
```text
npm init 
npm init –yes
```
2. package.json文件
```json
{
　　"name":"test",
　　"version":"1.0.0",
　　"description":"test",
　　"main":"main.js",
　　"keywords":[
　　　　"test"
　　],
　　"author":"wade",
　　"license":"MIT",
　　"dependencies":{
　　　　"express":"^4.10.1"
　　},
　　"devDependencies":{
　　　　"jslint":"^0.6.5"
　　}
}
```
3. 安装模块并把模块写入package.json(依赖)
```text
npm install 模块 --save
npm install 模块 --save-dev
```
4. dependencies与devDependencies之间的区别
    * 使用npm install node_module –save自动更新dependencies字段值; 
    * 使用npm install node_module –save-dev自动更新devDependencies字段值;
    * dependencie 配置当前程序所依赖的其他包。 
    * devDependencie 配置当前程序所依赖的其他包，只会下载模块，而不下载这些模块的测试和文档框架
5. 涉及到的符号解释
```json
"dependencies": { 
    "ejs": "^2.3.4", 
    "express": "^4.13.3", 
    "formidable": "^1.0.17" 
}
```
    * ^ 表示第一位版本号不变，后面两位取最新的 
    * ~ 表示前两位不变，最后一个取最新 
    * \* 表示全部取最新

