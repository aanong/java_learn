# ConcurrentHashMap 详解

## 一、HashMap 线程不安全原因

1. **JDK 1.7**：
   - 多线程并发 put 时，如果扩容，采用头插法，可能导致环形链表（Infinite Loop），读取时死循环。
   - 数据覆盖问题。
2. **JDK 1.8**：
   - 解决了环形链表问题（改用尾插法）。
   - 依然存在数据覆盖问题（两个线程同时判断 slot 为空，先后写入覆盖）。

---

## 二、ConcurrentHashMap (JDK 1.7)

### 2.1 结构设计
**Segment 数组 + HashEntry 数组 + 链表**
- 采用**分段锁**（Segment Locking）机制。
- `Segment` 继承自 `ReentrantLock`。
- 一个 Segment 包含一个 HashEntry 数组。
- 理论上并发度 = Segment 数组大小（默认 16）。

### 2.2 put 操作
1. 计算 key 的 hash，定位到 Segment。
2. 调用 `Segment.lock()` 获取锁。
3. 插入数据。
4. 解锁。

### 2.3 缺点
- 并发度受限于 Segment 个数。
- 结构复杂，两次 Hash 定位。

---

## 三、ConcurrentHashMap (JDK 1.8)

### 3.1 结构设计
**Node 数组 + 链表 / 红黑树**
- 抛弃 Segment，直接采用数组+链表+红黑树。
- 采用 **CAS + synchronized** 保证并发安全。
- 锁粒度更细，只锁住链表/红黑树的头节点。

### 3.2 核心属性
- `table`：Node 数组，volatile 修饰。
- `nextTable`：扩容时的新数组。
- `sizeCtl`：控制数组初始化和扩容。
  - -1：正在初始化
  - <-1：正在扩容
  - 0：默认状态
  - >0：下一次扩容阈值

### 3.3 put 操作流程

1. 计算 hash 值。
2. 如果数组未初始化，进行 `initTable()`。
3. 根据 hash 定位 Node 数组下标 `i`。
4. 如果 `table[i]` 为空：
   - 使用 **CAS** 尝试写入 `new Node(...)`。
   - 成功则返回，失败则自旋。
5. 如果 `table[i]` 的 hash 为 `MOVED` (-1)：
   - 说明正在扩容，当前线程协助扩容 `helpTransfer()`。
6. 如果 `table[i]` 不为空且非扩容：
   - 使用 **synchronized** 锁住 `table[i]`（头节点）。
   - 遍历链表/红黑树进行插入或更新。
   - 如果链表长度 >= 8 且数组长度 >= 64，转为红黑树。
7. `addCount()` 更新元素数量，检查是否需要扩容。

### 3.4 扩容机制 (Transfer)

1. **多线程并发扩容**：每个线程处理一部分桶（Bucket）的迁移。
2. **ForwardingNode**：迁移完的桶会放置一个 `ForwardingNode`，指向新数组。
3. 读操作遇到 ForwardingNode 会去新数组查找。

---

## 四、ConcurrentHashMap vs Hashtable vs Collections.synchronizedMap

| 特性 | Hashtable | synchronizedMap | ConcurrentHashMap |
|------|-----------|-----------------|-------------------|
| **线程安全** | 是 | 是 | 是 |
| **实现方式** | synchronized 修饰方法 | synchronized(mutex) 代码块 | CAS + synchronized (JDK8) |
| **锁粒度** | 全表锁 | 全表锁 | 桶锁 (Node/Segment) |
| **性能** | 低 | 低 | 高 |
| **null 键值** | 不允许 | 允许 | 不允许 (Key/Value均不可) |
| **迭代器** | 强一致性 (Fail-Fast) | 强一致性 (Fail-Fast) | 弱一致性 (Fail-Safe) |

---

## 五、其他并发容器

### 5.1 CopyOnWriteArrayList
- **写时复制**：写操作时复制新数组，修改后替换旧引用。
- **读写分离**：读操作无锁，写操作加锁（ReentrantLock）。
- **场景**：读多写少，数据量不大（如白名单）。

### 5.2 ThreadLocalRandom
- JDK 7 引入，解决 Random 类在高并发下的 CAS 竞争问题。
- 每个线程维护自己的种子变量，完全无锁。

### 5.3 BlockingQueue (阻塞队列)
- **ArrayBlockingQueue**：有界，一把锁。
- **LinkedBlockingQueue**：有界（默认 Integer.MAX_VALUE），读写分离两把锁。
- **PriorityBlockingQueue**：支持优先级。
- **DelayQueue**：延时队列。
- **SynchronousQueue**：不存储元素，直接传递。

---

## 六、常见面试题

### 1. 为什么 JDK 8 放弃了分段锁？
**答**：
- **锁粒度更细**：JDK 8 锁住的是头节点，并发度只受数组大小限制，远大于 Segment。
- **内存优化**：Segment 继承 ReentrantLock，内部结构臃肿。
- **代码简化**：统一了 HashMap 的结构（数组+链表+红黑树）。

### 2. ConcurrentHashMap 允许 Key 或 Value 为 null 吗？
**答**：
**不允许**。
如果 `get(key)` 返回 null，无法区分是"key不存在"还是"value为null"。
在多线程环境下，无法通过 `containsKey` 再去验证（因为中间可能被其他线程修改），会有二义性问题。
HashMap 允许 null 是因为它是单线程的，可以通过 `containsKey` 确认。

### 3. size() 方法是如何统计元素个数的？
**答**：
- **JDK 1.7**：先尝试无锁统计几次，如果 modCount 变了，再给所有 Segment 加锁统计（低效）。
- **JDK 1.8**：使用 `baseCount` + `CounterCell` 数组。
  - 类似 LongAdder 的思想，分散热点。
  - 最终数量 = baseCount + sum(CounterCell)。

### 4. 扩容时读写操作受影响吗？
**答**：
- **读操作**：不受影响。如果访问的桶已迁移，通过 ForwardingNode 转发到新数组读取。
- **写操作**：
  - 如果写入未迁移的桶：正常写入。
  - 如果写入已迁移的桶：协助扩容，扩容完后再写入。
  - 如果写入正在迁移的桶：等待锁。
