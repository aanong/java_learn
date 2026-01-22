# Kafka 学习资料

## 一、使用手册

### 1.1 什么是 Kafka
Apache Kafka 是一个分布式流处理平台，最初由 LinkedIn 开发，后来贡献给 Apache 基金会。它主要用于构建实时数据管道和流应用。

### 1.2 核心概念
- **Producer (生产者)**: 发送消息到 Kafka 集群的客户端。
- **Consumer (消费者)**: 从 Kafka 集群读取消息的客户端。
- **Broker (代理)**: Kafka 集群中的一个服务器节点。
- **Topic (主题)**: 消息的分类名。
- **Partition (分区)**: 一个 Topic 可以分为多个 Partition，实现并行处理。
- **Offset (偏移量)**: 消息在 Partition 中的唯一标识。
- **Consumer Group (消费者组)**: 一组消费者共同消费一个 Topic，每个 Partition 只能被组内一个消费者消费。

### 1.3 常用命令
```bash
# 创建 Topic
bin/kafka-topics.sh --create --topic my-topic --bootstrap-server localhost:9092 --partitions 3 --replication-factor 1

# 查看 Topic 列表
bin/kafka-topics.sh --list --bootstrap-server localhost:9092

# 生产消息
bin/kafka-console-producer.sh --topic my-topic --bootstrap-server localhost:9092

# 消费消息
bin/kafka-console-consumer.sh --topic my-topic --from-beginning --bootstrap-server localhost:9092
```

## 二、部署方案

### 2.1 单机部署
1. 下载 Kafka 压缩包并解压。
2. 启动 Zookeeper (Kafka 依赖 Zookeeper，新版 Kraft 模式可移除依赖)。
   `bin/zookeeper-server-start.sh config/zookeeper.properties`
3. 启动 Kafka Broker。
   `bin/kafka-server-start.sh config/server.properties`

### 2.2 Docker 部署
```yaml
version: '2'
services:
  zookeeper:
    image: wurstmeister/zookeeper
    ports:
      - "2181:2181"
  kafka:
    image: wurstmeister/kafka
    ports:
      - "9092:9092"
    environment:
      KAFKA_ADVERTISED_HOST_NAME: localhost
      KAFKA_ZOOKEEPER_CONNECT: zookeeper:2181
```

## 三、集群部署

### 3.1 规划
- 至少 3 个 Zookeeper 节点 (或 Kraft Controller 节点)。
- 至少 3 个 Kafka Broker 节点。

### 3.2 配置关键参数 (server.properties)
- `broker.id`: 每个节点必须唯一 (0, 1, 2...)。
- `listeners`: 监听地址。
- `advertised.listeners`: 外部访问地址。
- `zookeeper.connect`: Zookeeper 集群地址列表 (zk1:2181,zk2:2181,zk3:2181)。
- `log.dirs`: 消息存储路径。

### 3.3 高可用配置
- `min.insync.replicas`: 最小同步副本数，建议设为 2 (配合 acks=all)。
- `unclean.leader.election.enable`: 是否允许非 ISR 副本选主，建议 false。

## 四、源码分析

### 4.1 生产者发送流程
1. **拦截器 (Interceptors)**: 对消息进行预处理。
2. **序列化器 (Serializer)**: 将 Key/Value 转为字节数组。
3. **分区器 (Partitioner)**: 决定消息发往哪个分区。
4. **RecordAccumulator**: 消息累加器，将消息按批次缓存。
5. **Sender 线程**: 负责将批次发送到 Broker。

### 4.2 存储机制 (Log Segment)
- Kafka 消息以日志文件形式存储。
- 每个 Partition 对应一个目录。
- 目录下分为多个 Segment ( .log 数据文件, .index 偏移量索引, .timeindex 时间戳索引)。
- 顺序写磁盘，利用 OS Page Cache，性能极高。

### 4.3 零拷贝 (Zero Copy)
Kafka 使用 `sendfile` 系统调用，直接将数据从 Page Cache 传输到网卡，避免了用户态与内核态的多次拷贝。

## 五、常见问题

### 5.1 消息丢失
- **生产者端**: 
  - 设置 `acks=all` (所有 ISR 副本确认)。
  - `retries` 设置重试次数。
- **Broker 端**: 
  - `replication.factor` >= 3。
  - `min.insync.replicas` >= 2。
- **消费者端**: 
  - 关闭自动提交 offset (`enable.auto.commit=false`)，业务处理完成后手动提交。

### 5.2 消息重复
- **原因**: 消费者处理完消息，提交 offset 前宕机，重启后重读。
- **解决**: 保证消费逻辑的**幂等性** (Idempotence)。

### 5.3 消息积压
- **紧急处理**:
  1. 修复消费者逻辑 bug。
  2. 临时新建 Topic，分区数为原来的 N 倍。
  3. 写临时程序将积压数据转发到新 Topic。
  4. 启动 N 倍的消费者消费新 Topic。
- **长期优化**: 增加 Partition 数，同时增加 Consumer 数量。
