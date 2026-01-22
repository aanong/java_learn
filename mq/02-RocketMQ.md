# RocketMQ 学习资料

## 一、使用手册

### 1.1 什么是 RocketMQ
Apache RocketMQ 是阿里巴巴开源的一款低延迟、高并发、高可用、高可靠的分布式消息中间件。

### 1.2 核心概念
- **NameServer**: 路由注册中心，无状态节点。
- **Broker**: 消息存储和转发服务器。
- **Producer**: 消息生产者。
- **Consumer**: 消息消费者，支持 Push 和 Pull 模式。
- **Topic**: 消息主题。
- **Tag**: 消息标签，用于同一 Topic 下的二级过滤。
- **Message Queue**: 相当于 Kafka 的 Partition。

### 1.3 常用命令
```bash
# 启动 NameServer
nohup sh bin/mqnamesrv &

# 启动 Broker
nohup sh bin/mqbroker -n localhost:9876 &

# 查看集群状态
sh bin/mqadmin clusterList -n localhost:9876

# 创建 Topic
sh bin/mqadmin updateTopic -n localhost:9876 -c DefaultCluster -t MyTopic
```

## 二、部署方案

### 2.1 部署架构模式
- **单 Master**: 风险大，单点故障。
- **多 Master**: 无单点故障，但 Master 宕机期间未消费消息不可读。
- **多 Master 多 Slave (异步复制)**: 性能高，Master 宕机 Slave 可读，但 Master 磁盘损坏可能丢少量数据。
- **多 Master 多 Slave (同步双写)**: 数据最安全，性能略低，服务可用性高。

### 2.2 双主双从配置 (2m-2s-async)
需要四台机器 (或四个实例)，配置两对主从。
- **Master1**: `brokerRole=ASYNC_MASTER`, `brokerName=broker-a`
- **Slave1**: `brokerRole=SLAVE`, `brokerName=broker-a`
- **Master2**: `brokerRole=ASYNC_MASTER`, `brokerName=broker-b`
- **Slave2**: `brokerRole=SLAVE`, `brokerName=broker-b`

## 三、源码分析

### 3.1 消息存储结构 (CommitLog)
- **CommitLog**: 消息主体存储文件，所有 Topic 消息顺序写入同一个 CommitLog，极大提升写入性能。
- **ConsumeQueue**: 逻辑消费队列，存储消息在 CommitLog 中的索引 (Offset, Size, TagHashCode)。
- **IndexFile**: 索引文件，支持按 Key 或时间查询消息。

### 3.2 事务消息原理
1. Producer 发送 Half Message (半消息) 到 Broker。
2. Broker 存储消息但不投递 (对消费者不可见)。
3. Producer 执行本地事务。
4. Producer 根据事务结果向 Broker 发送 Commit 或 Rollback。
   - Commit: Broker 将消息投递到真实 Topic，消费者可见。
   - Rollback: Broker 删除/忽略该消息。
5. **回查机制**: 如果 Broker 未收到确认，会定时反查 Producer 的事务状态。

## 四、常见问题

### 4.1 顺序消息
RocketMQ 支持严格的顺序消息。
- **全局顺序**: 一个 Topic 只有一个 Queue。
- **分区顺序**: 发送时指定 Sharding Key，将同一类消息 (如同一订单的操作) 发送到同一个 Queue。

### 4.2 延时消息
RocketMQ 开源版支持特定级别的延时 (1s, 5s, 10s... 2h)。
- 原理: 消息先发到 `SCHEDULE_TOPIC_XXXX`，到了时间后由定时任务转存到真实 Topic。

### 4.3 消息堆积
- 检查 Consumer 是否有瓶颈 (数据库慢、逻辑复杂)。
- 增加 Consumer 实例数 (且不超过 ReadQueueNums)。
- 调整线程池参数 (`consumeThreadMin`, `consumeThreadMax`)。
