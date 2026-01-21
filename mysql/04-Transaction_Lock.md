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
