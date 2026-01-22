# ThreadLocal 原理与高并发陷阱

## 一、ThreadLocal 核心原理

### 1.1 内存模型
*   每个 `Thread` 对象内部有一个 `ThreadLocalMap threadLocals`。
*   `ThreadLocalMap` 是一个定制的 Hash Map。
*   **Key**: `ThreadLocal` 对象本身 (弱引用)。
*   **Value**: 线程存储的具体值 (强引用)。

```java
// Thread.java
ThreadLocal.ThreadLocalMap threadLocals = null;

// ThreadLocal.java
public void set(T value) {
    Thread t = Thread.currentThread();
    ThreadLocalMap map = getMap(t);
    if (map != null)
        map.set(this, value);
    else
        createMap(t, value);
}
```

### 1.2 弱引用与内存泄漏 (Memory Leak)
`Entry extends WeakReference<ThreadLocal<?>>`

*   **Key 泄漏?** 不会。Key 是弱引用，GC 时会被回收。Map 中会出现 Key=null 的 Entry。
*   **Value 泄漏?** **会！**
    *   `CurrentThread` -> `ThreadLocalMap` -> `Entry` -> `Value`。
    *   这是一条强引用链。
    *   如果线程一直存活 (线程池)，且没有手动 remove，Value 永远不会被回收。

**最佳实践**:
```java
try {
    threadLocal.set(val);
    // ...
} finally {
    threadLocal.remove(); // 必须清理
}
```

## 二、高并发场景下的进阶 ThreadLocal

### 2.1 FastThreadLocal (Netty)
JDK 的 `ThreadLocal` 使用线性探测法解决 Hash 冲突，在高并发下性能一般。
Netty 的 `FastThreadLocal` 配合 `FastThreadLocalThread` 使用 **数组下标** 直接定位，无 Hash 冲突，性能极高。

```java
// 使用示例
private static final FastThreadLocal<String> FAST_TL = new FastThreadLocal<>();

public void test() {
    // 必须在 FastThreadLocalThread 中运行才有优化效果
    new FastThreadLocalThread(() -> {
        FAST_TL.set("Hello");
        System.out.println(FAST_TL.get());
    }).start();
}
```

### 2.2 TransmittableThreadLocal (Alibaba)
JDK 的 `InheritableThreadLocal` 只能在 `new Thread()` 时传递父线程上下文。但在线程池中，线程是复用的，不会重复创建，导致上下文丢失。

`TransmittableThreadLocal (TTL)` 解决了这个问题。

```xml
<dependency>
    <groupId>com.alibaba</groupId>
    <artifactId>transmittable-thread-local</artifactId>
    <version>2.14.2</version>
</dependency>
```

```java
// 1. 定义 TTL
TransmittableThreadLocal<String> context = new TransmittableThreadLocal<>();

// 2. 包装线程池 (核心步骤)
ExecutorService executor = Executors.newFixedThreadPool(1);
ExecutorService ttlExecutor = TtlExecutors.getTtlExecutorService(executor);

// 3. 使用
context.set("Trace-ID-001");
ttlExecutor.submit(() -> {
    // 这里能取到父线程的值，即使线程是复用的
    System.out.println(context.get()); 
});
```

## 三、ThreadLocal 使用场景总结

1.  **数据库连接/Session 管理**: `DataSourceTransactionManager`, `Hibernate Session`.
2.  **Web 上下文**: Spring MVC `RequestContextHolder` (存储 `HttpServletRequest`).
3.  **日志追踪**: MDC (Log4j/Logback) 存储 TraceID。
4.  **SimpleDateFormat**: 避免每次 new，且保证线程安全。
