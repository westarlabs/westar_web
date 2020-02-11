---
title: Libra技术与实现
date: 2020-02-11
description: "2020年1月04日，Westar实验室组织了第二次技术Meetup，我们围绕Libra主题，探讨了Libra架构、共识以及Move语言"
author: 邓启明
draft: false
tags:
- libra
- blockchain
keywords:
- libra
- blockchain
categories:
- blog
---
6 月 18 日，Facebook 发布了 Libra 白皮书及源码，引起了业界的广泛关注与讨论。

这里我们通过分析Libra的源码，探索Libra的各个组件，来了解一下Libra的整体设计与实现。




### Libra核心组件

在进入主题之前，我们先对Libra有一个整体的认识：

![libra-1](./images/libra-1.png)

看过Libra技术白皮书的朋友，应该都记得这张图，下面简单介绍一下这些核心的组件（后面还会有更详细的讨论）：

​	a. AdmissionControl服务：简称AC，翻译过来叫准入控制，可以理解为Libra的网关，将跟用户打交道的接口暴露给用户，例如提交Transaction、获取用户状态等等

​	b. Mempool服务：存储未上链交易

​	c. Consensus组件：LibraBFT共识组件

​	d. VirtualMachine组件：简称VM，运行Move合约的虚拟机

​	e. Execution组件：VM的入口，已换成Executor组件

​	f. Storage服务：存储所有链上数据

​	g. Network组件：上图中隐含了一个Network组件，不论是Node启动还是跟其他节点通信，都需要Network组件。在第一条主线中，我们重点介绍Network组件。

注意，上面介绍各个核心组件的时候，我们区分了组件和服务，两者的区别是：组件没有额外监听端口，与node共用同一个端口，而服务会单独监听一个端口，通常是GRPC服务。



### Libra设计与实现

Libra涉及的东西比较多，我们从三条线介绍Libra的设计与实现：

1. 通过分析Node启动并加入到Libra网络的过程，介绍[Network组件的设计与实现](http://westar.io/blog/libra_network/)；
2. 围绕[Transaction的生命周期](http://westar.io/blog/libra_tx/)，分析其接收交易、打包区块、运行上链的过程，介绍Libra的Mempool、Executor以及Storage、VM等核心组件；
3. 围绕LibraBFT，介绍[Consensus组件](http://westar.io/blog/libra_consensus/)以及区块达成共识的过程

Libra目前还处于测试网阶段，仍在不断的迭代，对此，我们充满了期待，但愿Libra能给区块链带来美好的春天。