# synchronized 与 volatile 详解

## 一、synchronized 关键字

### 1.1 基本用法

synchronized 是 Java 中的关键字，是一种同步锁。

1. **修饰实例方法**：作用于当前对象实例（this），进入同步代码前要获得当前对象实例的锁。
   ```java
   public synchronized void method() {
       // ...
   }
   ```
2. **修饰静态方法**：作用于当前类对象（Class对象），进入同步代码前要获得当前类对象的锁。
   ```java
   public static synchronized void method() {
       // ...
   }
   ```
3. **修饰代码块**：指定加锁对象，对给定对象加锁。
   ```java
   public void method() {
       synchronized(this) { // 或其他对象
           // ...
       }
   }
   ```

### 1.2 原理分析

synchronized 在 JVM 层面实现，基于 Monitor 对象。

#### 字节码层面
- **代码块**：使用 `monitorenter` 和 `monitorexit` 指令。
- **方法**：使用 `ACC_SYNCHRONIZED` 标识符。

#### Monitor 对象
每个对象都与一个 Monitor 关联。Monitor 内部维护了：
- `_owner`：当前持有锁的线程
- `_WaitSet`：调用 wait() 后等待的线程集合
- `_EntryList`：等待获取锁的线程集合
- `_count`：重入计数器

### 1.3 锁升级过程 (Java 6+)

为了减少获得锁和释放锁带来的性能消耗，引入了偏向锁和轻量级锁。
锁状态存储在对象头（Mark Word）中。

**升级路线**：无锁 → 偏向锁 → 轻量级锁 → 重量级锁

| 锁状态 | 存储内容 | 适用场景 |
|--------|----------|----------|
| **偏向锁** | 线程ID | 只有一个线程访问同步块 |
| **轻量级锁** | 指向栈中Lock Record的指针 | 多个线程交替执行，无竞争 |
| **重量级锁** | 指向Monitor的指针 | 多个线程同时竞争锁 |

**注意**：锁只能升级，不能降级（GC时除外）。

---

## 二、volatile 关键字

### 2.1 作用
1. **保证内存可见性**：当一个线程修改了 volatile 变量的值，新值对于其他线程来说是立即可见的。
2. **禁止指令重排序**：通过内存屏障（Memory Barrier）防止编译器和处理器对指令进行重排序优化。

### 2.2 内存可见性原理

Java 内存模型（JMM）规定：
- 所有变量存在主内存（Main Memory）。
- 每个线程有自己的工作内存（Working Memory），保存了变量的副本。
- 线程操作变量必须在工作内存中进行，不能直接读写主内存。

**volatile 的实现**：
- **写操作**：立即刷新到主内存。
- **读操作**：强制从主内存读取。

### 2.3 禁止指令重排序

指令重排序是为了优化性能，但在多线程下会导致问题。
volatile 通过插入**内存屏障**来实现：
- 在每个 volatile 写操作前插入 StoreStore 屏障。
- 在每个 volatile 写操作后插入 StoreLoad 屏障。
- 在每个 volatile 读操作后插入 LoadLoad 屏障。
- 在每个 volatile 读操作后插入 LoadStore 屏障。

### 2.4 volatile 不保证原子性

```java
public class VolatileTest {
    public volatile int inc = 0;
    
    public void increase() {
        inc++; // 非原子操作：read -> load -> use -> assign -> store -> write
    }
}
```
**解决方案**：
- 使用 `synchronized` 或 `Lock`。
- 使用 `AtomicInteger`。

---

## 三、synchronized vs volatile

| 特性 | volatile | synchronized |
|------|----------|--------------|
| **原子性** | 不保证 | **保证** |
| **可见性** | **保证** | **保证** |
| **有序性** | **保证** | **保证** |
| **阻塞** | 不阻塞 | 可能阻塞 |
| **性能** | 高 | 低（锁升级优化后还可以） |
| **适用范围** | 变量 | 方法、代码块 |

---

## 四、单例模式中的应用 (DCL)

双重检查锁定（Double-Checked Locking）必须使用 volatile。

```java
public class Singleton {
    // 必须加 volatile，防止指令重排序
    private static volatile Singleton instance;
    
    private Singleton() {}
    
    public static Singleton getInstance() {
        if (instance == null) {
            synchronized (Singleton.class) {
                if (instance == null) {
                    // new Singleton() 非原子操作：
                    // 1. 分配内存
                    // 2. 初始化对象
                    // 3. instance指向内存
                    // 若发生重排序(1->3->2)，其他线程可能拿到未初始化的对象
                    instance = new Singleton();
                }
            }
        }
        return instance;
    }
}
```

---

## 五、常见面试题

### 1. synchronized 和 ReentrantLock 的区别？
**答**：
| 特性 | synchronized | ReentrantLock |
|------|--------------|---------------|
| 实现 | JVM 层面 | JDK API 层面 |
| 锁释放 | 自动释放 | 必须手动 unlock() |
| 灵活性 | 不灵活 | 支持尝试获取、超时获取、中断 |
| 公平性 | 非公平 | 支持公平/非公平 |
| 条件变量 | wait/notify | Condition (支持多个) |

### 2. 什么是 Java 内存模型 (JMM)？
**答**：
JMM 是一种抽象概念，定义了程序中各个变量的访问规则。
- 核心：原子性、可见性、有序性。
- 解决：缓存一致性问题、指令重排序问题。
- 实现：volatile、synchronized、final、Happens-Before 原则。

### 3. Happens-Before 原则有哪些？
**答**：
1. **程序次序规则**：单线程内，代码顺序执行。
2. **管程锁定规则**：unlock 操作先行发生于后面对同一个锁的 lock 操作。
3. **volatile 变量规则**：写操作先行发生于读操作。
4. **线程启动规则**：start() 先行发生于线程的所有动作。
5. **线程终止规则**：线程的所有动作先行发生于 join() 返回。
6. **传递性**：A happens-before B，B happens-before C，则 A happens-before C。

### 4. 为什么 synchronized 无法禁止指令重排序？
**答**：
synchronized **可以**保证有序性，但仅限于"同步块内部看似串行"。它不能禁止指令重排序，只是保证了单线程执行的语义（as-if-serial）。
但在 DCL 单例中，instance 变量逸出到同步块外部，因此必须加 volatile。
