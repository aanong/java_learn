# Redis 集群部署

## 一、主从复制 (Master-Slave)

### 1.1 原理
- Master 处理写，异步同步给 Slave。
- Slave 处理读，分担压力。
- **全量复制**: Slave 第一次连 Master，Master 执行 bgsave 发送 RDB，之后发送缓冲区的写命令。
- **增量复制**: 断线重连，根据 offset 继续同步。

### 1.2 问题
- 故障无法自动恢复，需要人工介入。

## 二、哨兵模式 (Sentinel)

### 2.1 作用
- **监控**: 检查 Master/Slave 是否在线。
- **自动故障恢复**: Master 挂了，选举新 Master。
- **通知**: 将新 Master 地址通知客户端。

### 2.2 工作流程
1. **主观下线 (SDOWN)**: 单个哨兵认为 Master 挂了。
2. **客观下线 (ODOWN)**: 多数哨兵认为 Master 挂了。
3. **选举 Leader**: 哨兵集群选举出一个 Leader 负责故障转移。
4. **故障转移**: 选一个 Slave 升级为 Master，通知其他 Slave 和客户端。

## 三、Redis Cluster (切片集群)

### 3.1 架构
- 无中心结构，多个 Master 节点。
- 数据分片 (Sharding)。
- 共有 16384 个 **Slot (槽)**。
- 也就是每个 Key 通过 `CRC16(key) % 16384` 决定放在哪个节点。

### 3.2 特点
- **高性能**: 线性扩展。
- **高可用**: 每个 Master 可以挂载 Slave，Master 挂了 Slave 顶上。
- **客户端路由**: 客户端连接任意节点，如果 Key 不在该节点，返回 `MOVED` 转向错误，客户端重定向。

### 3.3 部署关键
- 至少 3 Master (防止脑裂，过半机制)。
- 建议 3 Master 3 Slave。
- 配置 `cluster-enabled yes`。

### 3.4 常见问题
- **数据倾斜**: BigKey 导致某个节点内存/CPU 压力大。
- **多 Key 操作限制**: 只有 Key 在同一个 Slot 才能使用 MGET/Lua 脚本 (可以使用 HashTag `{user}:1`, `{user}:2` 强制在同 Slot)。
