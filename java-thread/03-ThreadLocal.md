# ThreadLocal 详解

## 一、什么是 ThreadLocal

ThreadLocal 提供**线程局部变量**。这些变量不同于普通变量，每个线程都可以通过 get() 或 set() 方法访问自己的独立副本，互不干扰。

**核心作用**：
1. **线程隔离**：每个线程拥有自己的数据副本，避免竞争。
2. **上下文传递**：在同一个线程内，跨类、跨方法传递数据（如数据库连接、Session信息）。

---

## 二、使用示例

### 2.1 基本用法

```java
public class ThreadLocalDemo {
    private static ThreadLocal<String> threadLocal = new ThreadLocal<>();

    public static void main(String[] args) {
        new Thread(() -> {
            threadLocal.set("Thread-A-Value");
            System.out.println("Thread A: " + threadLocal.get());
            threadLocal.remove();
        }).start();

        new Thread(() -> {
            threadLocal.set("Thread-B-Value");
            System.out.println("Thread B: " + threadLocal.get());
            threadLocal.remove();
        }).start();
    }
}
```

### 2.2 实际场景：SimpleDateFormat

`SimpleDateFormat` 是非线程安全的。

```java
public class DateUtils {
    private static final ThreadLocal<SimpleDateFormat> sdfThreadLocal = 
        ThreadLocal.withInitial(() -> new SimpleDateFormat("yyyy-MM-dd HH:mm:ss"));

    public static String format(Date date) {
        return sdfThreadLocal.get().format(date);
    }
    
    public static Date parse(String str) throws ParseException {
        return sdfThreadLocal.get().parse(str);
    }
}
```

---

## 三、ThreadLocal 原理

### 3.1 内存结构

JDK 8 中，`ThreadLocal` 的实现机制：
- 每个 `Thread` 内部维护了一个 `ThreadLocalMap` 成员变量。
- `ThreadLocalMap` 的 Key 是 `ThreadLocal` 对象本身，Value 是线程需要存储的值。

```java
// Thread类源码
public class Thread implements Runnable {
    ThreadLocal.ThreadLocalMap threadLocals = null;
}

// ThreadLocal类源码
public void set(T value) {
    Thread t = Thread.currentThread();
    ThreadLocalMap map = getMap(t);
    if (map != null)
        map.set(this, value);
    else
        createMap(t, value);
}
```

### 3.2 ThreadLocalMap 详解

`ThreadLocalMap` 是一个自定义的哈希表：
1. **Entry**：继承自 `WeakReference<ThreadLocal<?>>`。
   ```java
   static class Entry extends WeakReference<ThreadLocal<?>> {
       Object value;
       Entry(ThreadLocal<?> k, Object v) {
           super(k); // Key是弱引用
           value = v; // Value是强引用
       }
   }
   ```
2. **Hash冲突解决**：采用**线性探测法**（Linear Probing），而不是链表法。

---

## 四、内存泄漏问题

### 4.1 弱引用导致 Key 泄漏？
Key（ThreadLocal对象）是弱引用，当 ThreadLocal 外部没有强引用时，GC 会回收它。
这导致 Map 中出现 Key 为 null 的 Entry，但 Value 还在。

### 4.2 真正的泄漏：Value 无法回收
Key 被回收后，Value 依然存在强引用链：
`Thread -> ThreadLocalMap -> Entry -> Value`

如果线程一直运行（如线程池核心线程），Value 永远不会被回收，导致内存泄漏。

### 4.3 解决方案
1. **手动 remove**：使用完后必须调用 `remove()` 方法。
2. **自动清理**：`set()`、`get()`、`remove()` 方法在调用时，会尝试清理 Key 为 null 的 Entry（探测式清理/启发式清理），但这不是及时的。

**最佳实践**：
```java
try {
    threadLocal.set(value);
    // 业务逻辑
} finally {
    threadLocal.remove(); // 必须防止内存泄漏
}
```

---

## 五、InheritableThreadLocal

ThreadLocal 无法在父子线程间传递数据。`InheritableThreadLocal` 可以解决这个问题。

### 5.1 原理
Thread 类中还有一个 `inheritableThreadLocals` 变量。
创建子线程时，会把父线程的 `inheritableThreadLocals` 拷贝一份给子线程。

```java
// Thread.init() 源码片段
if (parent.inheritableThreadLocals != null)
    this.inheritableThreadLocals =
        ThreadLocal.createInheritedMap(parent.inheritableThreadLocals);
```

### 5.2 局限性
只能在线程创建时复制。如果线程池复用线程，子线程中的数据不会随父线程更新。
可以使用阿里开源的 `TransmittableThreadLocal` 解决线程池上下文传递问题。

---

## 六、常见面试题

### 1. ThreadLocalMap 为什么要用弱引用？
**答**：
如果是强引用，ThreadLocal 对象即使在外部被置为 null，Map 中依然持有引用，导致 ThreadLocal 无法回收。
使用弱引用，ThreadLocal 可以在外部无引用时被 GC 回收。
虽然 Value 依然可能泄漏，但 JDK 在 `get/set` 时会尝试清理 null Key，这是一种权衡。

### 2. ThreadLocal 为什么采用线性探测法解决 Hash 冲突？
**答**：
- ThreadLocalMap 的数据量通常较小。
- 线性探测法在数据量小时，CPU 缓存命中率高。
- 不用链表可以节省内存（无需 Node 对象）。

### 3. FastThreadLocal 是什么？
**答**：
Netty 提供的优化版 ThreadLocal。
- 使用数组（Object[]）替代 Hash 表，通过 index 直接定位，无 Hash 冲突，性能更高。
- 配合 `FastThreadLocalThread` 使用。

### 4. ThreadLocal 在 Spring 中的应用？
**答**：
- **TransactionSynchronizationManager**：管理事务上下文（Connection）。
- **RequestContextHolder**：管理 Web 请求上下文（HttpServletRequest）。
