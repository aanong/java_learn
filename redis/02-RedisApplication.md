# Redis 应用与进阶

## 一、持久化机制

### 1.1 RDB (Redis DataBase)
- **原理**: 周期性将内存数据快照保存到磁盘 (dump.rdb)。
- **触发**: `save` (阻塞), `bgsave` (fork 子进程，Copy-on-Write)。
- **优点**: 文件小，恢复快。
- **缺点**: 可能会丢失最后一次快照后的数据。

### 1.2 AOF (Append Only File)
- **原理**: 记录每次写操作命令到文件 (appendonly.aof)。
- **同步策略**:
  - `appendfsync always`: 每次写都同步 (慢，安全)。
  - `appendfsync everysec`: 每秒同步 (推荐)。
  - `appendfsync no`: 操作系统决定。
- **优点**: 数据更安全。
- **缺点**: 文件大，恢复慢。
- **Rewrite**: AOF 重写，合并重复命令，减小文件体积。

### 1.3 混合持久化 (4.0+)
- RDB + AOF，AOF 重写时将当前内存数据存为 RDB 格式，增量数据存为 AOF 指令。

## 二、缓存一致性

### 2.1 Cache Aside Pattern (旁路缓存)
- **读**: 先读缓存，命中返回；未命中读库，写入缓存。
- **写**: **先更新数据库，再删除缓存**。
- **为什么删除而不是更新缓存？**
  - 防止并发写导致脏数据。
  - 懒加载，避免不必要的计算。
- **延时双删**: 解决主从延迟导致的脏数据 (更新库 -> 删缓存 -> sleep -> 删缓存)。

## 三、内存淘汰策略 (maxmemory-policy)

当内存达到 maxmemory 时触发：
1. **noeviction**: 报错 (默认)。
2. **allkeys-lru**: 移除最近最少使用的 key (推荐)。
3. **volatile-lru**: 在设置了过期时间的 key 中移除 LRU。
4. **allkeys-random**: 随机移除。
5. **volatile-random**: 在过期 key 中随机移除。
6. **volatile-ttl**: 移除即将过期的 key。
7. **allkeys-lfu**: 移除最不经常使用的 (4.0+)。
8. **volatile-lfu**: 在过期 key 中移除 LFU (4.0+)。

## 四、分布式锁

### 4.1 基础实现
```java
// 加锁: 原子性操作
SET lock_key unique_id NX PX 10000

// 解锁: Lua 脚本保证原子性
if redis.call("get",KEYS[1]) == ARGV[1] then
    return redis.call("del",KEYS[1])
else
    return 0
end
```

### 4.2 Redisson (看门狗机制)
- 解决锁过期但业务没跑完的问题。
- 只要线程持有锁，后台线程会自动续期 (Watch Dog)。

### 4.3 Redlock
- 解决集群下 Master 宕机导致锁丢失的问题。
- 向 N 个节点申请锁，超过 N/2+1 个成功才算成功。
