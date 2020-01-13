---
title: 剖析Libra的Network组件
date: 2020-01-13
description: "2020年1月04日，Westar实验室组织了第二次技术Meetup，我们围绕Libra主题，探讨了Libra架构、共识以及Move语言"
author: 邓启明
draft: true
tags:
- libra
- blockchain
keywords:
- libra
- blockchain
categories:
- blog
---

如果想学习或者使用Libra，我们需要先启动一个节点，并将它加入到网络中。这里，我们了解一下Node的启动以及Network的设计与实现。



### Node启动流程

我们先看一下Node大概的启动流程，主要包含两部分：

1. 生成config

   Libra的Config的模块中，能构建3种类型的配置文件，分别是validator、faucet、fullnode的配置文件。其中faucet配置是水龙头服务相关的一些配置，通常只有测试网络中第一个validator节点才需要。

   ![conf-build](./images/libra-start-1.png)

2. 启动node

![node-start](./images/libra-start-2.png)

上图中Libra-node用于启动单节点，Libra-swarm用于批量启动多节点。接下来，我们分别看一下这两步的一些实现细节，以及之前的准备工作。



### 准备工作

在一切继续之前，我们先准备需要依赖的环境

​	1). 获取Libra代码

​	git clone https://github.com/libra/libra.git

​	2). 编译和运行环境

​		a. 建议使用Libra自带的脚本script/dev_setup.sh安装环境依赖

​		b. 或者自己手动安装rust、cargo、git、pb、go、CMake等工具

​	

### 生成config

​	从前面的Node启动流程我们了解到，启动node首先需要生成配置。Libra包含的配置文件比较多，我们来整体看一下配置文件：

![config](./images/libra-start-3.png)

​	不过没有特殊需求的话，需要我们特别注意和关注的配置其实也不算多（见上图蓝色部分），主要有：

​		a. Node的角色分为Validator和FullNode

​		b. 生成3个秘钥，2个ed25519算法生成，分别用于打包block签名、网络的消息签名，Libra提供了一个generate_keypair工具生成ed25519秘钥(cargo run -p generate_keypair -- -o mint.key)，1个是x25519算法生成，用于标识节点身份

​		c. 数据存储路径，默认会生成临时路径

​		d. network_peers：存放网络中Node的公钥等信息，主要包含网络消息签名的公钥和节点身份的公钥

​		e. seed_peers：当前节点加入网络主动去连接的node的信息

​		f. consensus_peers：所有Validator节点的信息，Libra网络是一个许可形网络

​		g. 各服务的端口以及其他配置，没有特殊要求的话，默认就好


### 启动Node

1. 连接Libra的测试网络

   sh scripts/cli/start_cli_testnet.sh

2. 自建节点

   cargo run -p libra-node 
   
   或者
   
   cargo run -p libra-swarm -- -s

当前node启动起来之后，会根据seed_peers的配置，去连接相应的node节点，加入到网络中去，如果没有seed_peers则会启动一个单独的网络。接下来，我们深入了解一下Node的Network的一些设计与核心实现。

### Network

##### 1. Network核心模块

我们整体看一下Network包含哪些模块：

![network-mod](./images/libar-network-1.jpg)

上面中，从下往上看：

​	a. MemSocket实现了UNIX domain socket的功能，一般用于测试

​	b. TcpSocket网络连接

​	c. Transport可以理解为MemSocket和TcpSocket的一层抽象，封装了socket的操作

​	d. Noise是一种加密协议，前面提到的用于网络消息签名的ed25519私钥，就是作用在这里

​	e. Rpc是Libra自己实现的远程过程调用协议，调用方会等待被调用方返回结果

​	f.  DirectSend从字面理解是直接发送，调用方发送完立即返回，不等待被调用方返回结果

​	g. Negotiate可以理解为对Rpc和DirectSend的抽象

​	h. MultiStream用于多路复用，使用了yamux协议。通俗的理解就是在同一个Tcp连接上，从逻辑上将每种上层协议封装成一个单独SubStream，以实现多个上层协议共用一个Tcp连接的情况。这一点后面我们还会提到。

以上是Libra的Network组件的一个整体实现，接下来我们介绍一下Libra的协议。

##### 2. Libra的主要协议

上面我们对Network组件有了一个宏观的认识，这里我们介绍一下Libra包含的协议：

![network-protocol](./images/libra-network-2.jpg)

上图中，从下往上看：

​	a. PeerManager封装了网络连接以及多路复用的操作

​	b. Identity协议：前面提到的x25519私钥，就是Identity协议用于标识当前节点的身份，协议会根据节点的Role将Validator网络与Fullnode网络进行隔离

​	c. Health协议：定期随机选择一个节点发送探活消息

​	d. Discovery协议：每个round从相邻的节点同步节点信息，以发现新节点，可以理解为gossip协议

​	e. AdmissionControl协议：只有RPC的实现，Fullnode节点在收到用户提交的Transaction之后，通过AC协议将Transaction转发给Validator节点

​	f. Mempool协议：只有DirectSend实现，用于不同的Mempool之间同步Transaction

​	g. Consensus协议：包含RPC和DirectSend，用于Validator之间达成共识

​	h. StateSynchronizer协议：只有DirectSend实现，不同node之间寻找Block

前面我们提到了多路复用，上面的协议都是通过MultiStream分别开了SubStream，逻辑上把消息协议区分出来。其中Identity、Health、Discovery是所有node都会包含的基本协议，而Consensus是只有Validator节点才会包含的协议。

### 总结

   最开始我们讲了Node启动流程，讲述了config配置需要注意的地方以及node启动的方式和流程。然后我们深入到Network组件，讲了Network的组成模块以及提供的协议能力。我们以单节点为例，将整个启动以及加入网络的过程总结如下图：

![network](./images/libra-start-4.png)

其中黄色部分表示在Network的端口是开启了SubStream，添加了相应的协议和协议处理过程；绿色部分部分表示服务或者组件实例化，可以看出Storage和Executor不依赖Network；初始化Discovery协议的时候，节点会去连接seed节点，并且seed节点会验证Identity。以上是节点启动以及加入到网络的大概流程。











