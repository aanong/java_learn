# Redis 基础学习资料

## 一、Redis 简介
Redis (Remote Dictionary Server) 是一个开源的、基于内存的数据结构存储系统，可以用作数据库、缓存和消息中间件。

## 二、使用手册与常用命令

### 2.1 String (字符串)
最基本类型，二进制安全，最大 512MB。
```bash
SET key value
GET key
INCR counter
SETNX key value  # 分布式锁基础
```

### 2.2 List (列表)
双向链表。
```bash
LPUSH mylist value
RPOP mylist
LRANGE mylist 0 -1
```

### 2.3 Hash (哈希)
键值对集合，适合存储对象。
```bash
HSET user:1 name "Tom"
HGET user:1 name
HGETALL user:1
```

### 2.4 Set (集合)
无序唯一字符串集合。
```bash
SADD myset "a"
SMEMBERS myset
SINTER set1 set2 # 求交集
```

### 2.5 Sorted Set (有序集合/ZSet)
带分数的 Set，有序。
```bash
ZADD myzset 100 "rank1"
ZRANGE myzset 0 -1
```

### 2.6 其他高级结构
- **Bitmap**: 位图，适合签到、活跃统计。
- **HyperLogLog**: 基数统计，统计 UV。
- **Geo**: 地理位置。
- **Stream**: 消息队列 (5.0+)。

## 三、底层原理与数据结构

### 3.1 动态字符串 (SDS)
- C 语言字符串的封装，记录了长度。
- O(1) 获取长度。
- 杜绝缓冲区溢出。
- 减少内存重分配。

### 3.2 字典 (Dict)
- 哈希表实现。
- **渐进式 Rehash**: 扩容时不是一次性搬迁，而是分多次、渐进式地将旧 Hash 表数据迁移到新表，避免阻塞主线程。

### 3.3 跳跃表 (SkipList)
- ZSet 的底层实现之一 (当元素较多时)。
- 链表加多级索引，查找复杂度 O(logN)，实现比红黑树简单。

### 3.4 压缩列表 (ZipList)
- 内存紧凑型结构，用于元素少且小的 List, Hash, ZSet。

## 四、Redis 为什么这么快？

1. **基于内存**: 所有操作都在内存中完成，寻址速度快。
2. **单线程模型 (主线程)**: 
   - 避免了多线程上下文切换的开销。
   - 避免了多线程竞争锁的开销。
   - 注意: 6.0 引入了多线程处理网络 I/O，但命令执行依然是单线程。
3. **IO 多路复用 (Epoll)**: 非阻塞 IO，一个线程管理多个网络连接。
4. **高效的数据结构**: SDS, SkipList 等专门优化。
