# Apache Pulsar 学习资料

## 一、使用手册

### 1.1 什么是 Pulsar
Apache Pulsar 是下一代云原生分布式消息流平台，采用计算与存储分离的架构。

### 1.2 核心架构 (计算存储分离)
- **Broker**: 无状态服务层，负责消息的接收、分发和管理，不存储数据。
- **BookKeeper (Bookie)**: 存储层，负责持久化消息，由 Bookie 节点组成。
- **ZooKeeper**: 元数据存储和协调。

### 1.3 关键特性
- **多租户**: 内置多租户支持 (Tenant -> Namespace -> Topic)。
- **GEO Replication**: 原生跨地域复制。
- **分层存储 (Tiered Storage)**: 自动将冷数据卸载到 S3/HDFS。

## 二、部署方案

### 2.1 组件依赖
- ZooKeeper
- BookKeeper
- Pulsar Broker

### 2.2 独立模式 (Standalone)
```bash
bin/pulsar standalone
```
适合开发测试，所有组件运行在一个 JVM 中。

### 2.3 集群部署
1. 部署 ZooKeeper 集群。
2. 初始化集群元数据 (`bin/pulsar initialize-cluster-metadata`)。
3. 部署 BookKeeper 集群。
4. 部署 Pulsar Broker 集群。

## 三、源码分析

### 3.1 消息存储 (Ledger)
- **Topic**: 逻辑上的消息流。
- **Ledger**: 物理上的存储单元，一个 Topic 由多个 Ledger 组成。
- **Fragment**: Ledger 中的最小分布单元，写入 Bookie。
- **Ensemble Size (E)**: 选取的 Bookie 数量。
- **Write Quorum (W)**: 写入副本数。
- **Ack Quorum (A)**: 确认写入数。

### 3.2 消费模型
Pulsar 支持多种订阅模式：
1. **Exclusive (独占)**: 一个 Subscription 只能有一个 Consumer。
2. **Failover (灾备)**: 主备模式，主 Consumer 挂了备用接管。
3. **Shared (共享)**: 多个 Consumer 竞争消费 (类似 Kafka Group，但不保证顺序)。
4. **Key_Shared**: 按 Key 哈希分发，保证 Key 级别的有序性。

## 四、常见问题

### 4.1 为什么要计算存储分离？
- **扩容灵活**: Broker 和 Bookie 可以独立扩容。Broker 无状态，扩容瞬间完成；Bookie 扩容只需加入新节点，新 Ledger 会自动使用新节点，无需像 Kafka 那样重平衡 (Rebalance) 搬运数据。
- **故障恢复**: Broker 挂了，Topic 瞬间转移到其他 Broker，无需数据恢复。

### 4.2 Pulsar vs Kafka
- **Kafka**: 吞吐量极高，架构简单，适合日志收集、流处理。扩容涉及数据迁移，运维成本较高。
- **Pulsar**: 架构复杂 (组件多)，但云原生特性好，支持多租户，扩容方便，延迟更低且稳定 (尾部延迟低)。适合金融、计费等对一致性和延迟要求高的场景。
