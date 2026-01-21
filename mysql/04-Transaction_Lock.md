# Transaction & Locks (事务与锁机制)

## 一、事务 (Transaction)

### 1. ACID 特性
- **原子性 (Atomicity)**：事务包含的所有操作要么全部成功，要么全部失败回滚。由 **Undo Log** 保证。
- **一致性 (Consistency)**：事务执行前后，数据保持一致。是事务的目的。
- **隔离性 (Isolation)**：多个并发事务之间互不干扰。由 **MVCC** 和 **锁** 保证。
- **持久性 (Durability)**：事务提交后，修改是永久的。由 **Redo Log** 保证。

### 2. 并发问题
- **脏读 (Dirty Read)**：读到了其他事务未提交的数据。
- **不可重复读 (Non-Repeatable Read)**：同一个事务中，两次读取同一行数据不一致（被其他事务 Update/Delete）。
- **幻读 (Phantom Read)**：同一个事务中，两次读取的记录数不一致（被其他事务 Insert）。

### 3. 隔离级别 (Isolation Levels)
| 隔离级别 | 脏读 | 不可重复读 | 幻读 | 备注 |
| :--- | :--- | :--- | :--- | :--- |
| **Read Uncommitted** (读未提交) | √ | √ | √ | 几乎不用 |
| **Read Committed** (读已提交) | × | √ | √ | Oracle/SQL Server 默认 |
| **Repeatable Read** (可重复读) | × | × | × (MySQL 解决) | **MySQL 默认** |
| **Serializable** (串行化) | × | × | × | 效率最低 |

## 二、MVCC (多版本并发控制)

**MVCC (Multi-Version Concurrent Control)** 是一种无锁的并发控制机制，用于实现 Read Committed 和 Repeatable Read 隔离级别。

### 1. 核心组件
- **隐藏字段**：
    - `DB_TRX_ID`：最近修改该行的事务 ID。
    - `DB_ROLL_PTR`：回滚指针，指向 Undo Log 中的旧版本。
    - `DB_ROW_ID`：隐藏主键。
- **Undo Log**：保存历史版本链。
- **Read View (读视图)**：事务进行快照读时产生的读视图。包含：
    - `m_ids`：当前活跃的事务 ID 列表。
    - `min_trx_id`：最小活跃事务 ID。
    - `max_trx_id`：下一个分配的事务 ID。

### 2. 可见性规则
通过比较数据的 `DB_TRX_ID` 和 Read View 的属性，判断数据对当前事务是否可见。
- 如果 `trx_id` < `min_trx_id`：可见（已提交）。
- 如果 `trx_id` > `max_trx_id`：不可见（将来事务）。
- 如果 `trx_id` 在 `m_ids` 中：不可见（未提交）。

### 3. RC vs RR
- **Read Committed**：**每次查询** 都会生成一个新的 Read View。
- **Repeatable Read**：**第一次查询** 生成 Read View，之后复用，保证多次读取一致。

## 三、锁机制 (Lock)

### 1. 锁分类
- **粒度**：
    - **全局锁**：锁整个库 (FTWRL)，用于全库备份。
    - **表级锁**：开销小，并发低。
    - **行级锁**：InnoDB 支持，开销大，并发高。

- **模式**：
    - **读锁 (S锁 / Shared Lock)**：共享锁。`select ... lock in share mode`
    - **写锁 (X锁 / Exclusive Lock)**：排他锁。`select ... for update`, `update`, `delete`, `insert`

### 2. InnoDB 行锁算法
- **Record Lock**：**记录锁**。锁住索引记录本身。
- **Gap Lock**：**间隙锁**。锁住索引记录之间的间隙，防止幻读。
- **Next-Key Lock**：**临键锁**。Record Lock + Gap Lock。锁住记录本身和前面的间隙。

### 3. 幻读解决
- **快照读 (Snapshot Read)**：普通 select。由 **MVCC** 解决。
- **当前读 (Current Read)**：select for update / update / delete。由 **Next-Key Lock** 解决。

## 四、LBCC (Lock-Based Concurrent Control) 详解

**LBCC（基于锁的并发控制）** 通过对数据加锁来保证并发安全，是解决"当前读"场景下并发问题的核心机制。

### 1. 锁的兼容矩阵

|  | S锁 (共享锁) | X锁 (排他锁) |
|:---:|:---:|:---:|
| **S锁** | ✅ 兼容 | ❌ 冲突 |
| **X锁** | ❌ 冲突 | ❌ 冲突 |

### 2. 表级锁详解

#### 2.1 表锁
```sql
-- 加读锁
LOCK TABLES table_name READ;

-- 加写锁
LOCK TABLES table_name WRITE;

-- 释放锁
UNLOCK TABLES;
```

#### 2.2 意向锁 (Intention Lock)
- **IS (Intention Shared)**：事务打算给某些行加 S 锁。
- **IX (Intention Exclusive)**：事务打算给某些行加 X 锁。
- **作用**：快速判断表中是否有行被锁定，避免逐行检查。

```
┌────────────────────────────────────────────────────┐
│           意向锁与表锁兼容矩阵                       │
├──────────┬────────┬────────┬────────┬────────────┤
│          │   IS   │   IX   │   S    │     X      │
├──────────┼────────┼────────┼────────┼────────────┤
│    IS    │   ✅   │   ✅   │   ✅   │     ❌     │
│    IX    │   ✅   │   ✅   │   ❌   │     ❌     │
│    S     │   ✅   │   ❌   │   ✅   │     ❌     │
│    X     │   ❌   │   ❌   │   ❌   │     ❌     │
└──────────┴────────┴────────┴────────┴────────────┘
```

### 3. 行级锁详解

InnoDB 行锁是通过**锁住索引记录**来实现的。

#### 3.1 Record Lock (记录锁)
- 锁住 **单条索引记录**。
- 仅在唯一索引（主键/唯一键）上进行等值查询且命中时使用。

```sql
-- id是主键，只锁住id=1这一行
SELECT * FROM users WHERE id = 1 FOR UPDATE;
```

#### 3.2 Gap Lock (间隙锁)
- 锁住 **索引记录之间的间隙**，不包括记录本身。
- 目的：防止其他事务在间隙内插入新记录，解决幻读。

```sql
-- 假设表中有 id = 1, 5, 10
-- 锁住 (1, 5) 间隙，防止插入 id = 2, 3, 4
SELECT * FROM users WHERE id BETWEEN 2 AND 4 FOR UPDATE;
```

**Gap Lock 示意图**：
```
数据：    [1]     [5]     [10]    [15]
间隙：  (-∞,1) (1,5) (5,10) (10,15) (15,+∞)
```

#### 3.3 Next-Key Lock (临键锁)
- **Record Lock + Gap Lock**，锁住记录本身及其前面的间隙。
- InnoDB 默认的行锁算法（RR 隔离级别下）。
- 左开右闭区间：`(前一条记录, 当前记录]`

```sql
-- 假设表中有 id = 1, 5, 10
-- SELECT * FROM users WHERE id = 5 FOR UPDATE
-- 加锁范围：(1, 5] 的 Next-Key Lock
```

### 4. 锁定读 SQL 语法

```sql
-- 共享锁 (S锁)
SELECT ... LOCK IN SHARE MODE;   -- MySQL 8.0 之前
SELECT ... FOR SHARE;            -- MySQL 8.0+

-- 排他锁 (X锁)
SELECT ... FOR UPDATE;
```

### 5. 加锁规则总结 (RR 隔离级别)

| 场景 | 使用的锁 |
|:-----|:--------|
| 唯一索引等值查询，命中 | **Record Lock** |
| 唯一索引等值查询，未命中 | **Gap Lock** |
| 唯一索引范围查询 | **Next-Key Lock** |
| 非唯一索引等值查询，命中 | **Next-Key Lock + Gap Lock** |
| 非唯一索引范围查询 | **Next-Key Lock** |
| 无索引 | **表锁**（锁住所有记录） |

### 6. 死锁

#### 6.1 死锁产生条件
1. **互斥**：资源不能共享。
2. **占有且等待**：持有资源同时等待其他资源。
3. **不可剥夺**：资源不能被强制释放。
4. **循环等待**：存在循环等待链。

#### 6.2 死锁示例
```sql
-- 事务A
START TRANSACTION;
UPDATE users SET name = 'A' WHERE id = 1; -- 锁住id=1
UPDATE users SET name = 'A' WHERE id = 2; -- 等待id=2

-- 事务B
START TRANSACTION;
UPDATE users SET name = 'B' WHERE id = 2; -- 锁住id=2
UPDATE users SET name = 'B' WHERE id = 1; -- 等待id=1 → 死锁!
```

#### 6.3 死锁检测与处理
- **wait-for graph**：InnoDB 通过等待图检测死锁。
- **检测到死锁**：回滚代价较小的事务（`innodb_deadlock_detect=ON`）。
- **超时机制**：`innodb_lock_wait_timeout`（默认 50s）。

#### 6.4 如何避免死锁
1. **固定顺序访问表和行**：所有事务按相同顺序访问数据。
2. **大事务拆小**：减少锁持有时间。
3. **合理使用索引**：避免全表扫描导致锁表。
4. **降低隔离级别**：RC 比 RR 锁更少。

### 7. MVCC vs LBCC 对比

| 特性 | MVCC | LBCC |
|:-----|:-----|:-----|
| **读操作** | 快照读，无锁 | 当前读，需要锁 |
| **写操作** | 需要锁 | 需要锁 |
| **并发性能** | 高（读不阻塞写） | 相对低 |
| **使用场景** | 普通 SELECT | SELECT FOR UPDATE |
| **解决幻读** | 读取历史版本 | Next-Key Lock |

**实际应用中，MVCC 和 LBCC 配合使用**：
- 快照读 → MVCC
- 当前读 → LBCC

