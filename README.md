# ReadMe

### 发布内容

- 发布文章

```
# 新建文稿文件

hugo new news/FileName.md # news目录创建文件
hugo new faq/FileName.md  # faq目录创建文件

# 编辑文件 ./content/news/FileName.md 添加内容

```

- 发布文件头部参数说明示例

```
---
title: "标题"
date: 2017-11-17T12:41:44+08:00
draft: false # 草稿状态否
description: "文章描述，相关应用地方调用该字段"
keywords: # 关键字用于seo优化词
- filecoin
- blockchain
categories: blog # 栏目，组合显示在页面title中
cover: http://xxx.jpg 或 /img/xxx.jpg # 文章引用缩略图处使用，没有使用系统默认1-4张图随机
---
```

### 配置修改

- 目前用到抽离的配置均放在根目录`config.toml`，参照修改即可

- title / keywords / description 配置修改
    - 首页： 修改config.toml对应参数

        ```
        title = "Westar"
        [params]
          keywords="网站关键字"
          description="网站描述信息"
        ```

    - 栏目页修改： content目录下对应栏目目录`_index.md`中配置修改，新创建栏目自行添加文件配置即可
    - 内容页： 对应发布内容md文件首部配置


- 导航菜单配置

- 编辑根目录`config.toml`（修改常用配置），参照现有配置menu配置项即可


### 运行server
- 开发运行
```
hugo server --theme=westar --buildDrafts
```
- 后台运行
```
hugo server -D
```




### 编译发布
- 项目根目录执行`hugo`即可编译静态文件，编译后在根目录生成`public`文件夹，将public部署至指定地点即可直接访问。
- 注：编译前修改`config.toml`中baseURL参数对应当前环境域名。





