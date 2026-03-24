# Spring
## Ioc/DI
### 注入方式

#### 构造器注入

##### 特点

- 依赖声明为 final，对象不可变
- 构造即完备，不存在 null 风险
- 单元测试直接 new 传入 mock
- 依赖过多时构造器参数变长，反向提示重构

- 依赖多时构造器参数列表较长

````java
@Service
public class OrderService {

    private final PaymentService paymentService;

    // 单构造器时 @Autowired 可省略（Spring 4.3+）
    @Autowired
    public OrderService(PaymentService ps) {
        this.paymentService = ps;
    }

    public void createOrder() {
        paymentService.pay();
    }
}
````



#### Setter 注入

##### 特点

- 适合可选依赖（不一定注入）
- 允许对象创建后再设置或重置依赖

- 依赖可变，存在 null 指针风险
- 调用 setter 之前对象处于不完整状态
- 不能声明 final

````java
@Service
public class OrderService {

    private PaymentService paymentService;

    @Autowired
    public void setPaymentService(
            PaymentService ps) {
        this.paymentService = ps;
    }

    public void createOrder() {
        paymentService.pay();
    }
}
````



#### 字段注入

##### 特点

- 写法最简洁，上手快

- 无法声明 final，非线程安全
- 单测需要反射才能注入 mock
- 隐藏真实依赖，违反显式设计
- 依赖再多也无感知，不利于重构

````java
@Service
public class OrderService {

    @Autowired
    private PaymentService paymentService;

    // 无构造器，Spring 通过反射注入
    public void createOrder() {
        paymentService.pay();
    }
}
````

### Bean 作用域

#### singleton
 整个 IoC 容器中只创建一个 Bean 实例，所有注入和 getBean() 获取的都是同一个对象。适合无状态的 Service、Repository 等。

#### prototype

每次从容器获取 Bean 时都会创建一个新实例，Spring 不管理其销毁。适合有状态的对象，如命令对象、DTO 等。

#### request

每次 HTTP 请求创建一个新实例，请求结束后销毁。

#### session

绑定到 HTTP Session 生命周期，同一个 Session 内共享同一个实例。

#### application

绑定到 `ServletContext`，相当于 Web 应用级别的单例（比 `singleton` 范围更大，跨容器共享）。

#### websocket

绑定到一次 WebSocket 连接的生命周期。 

#### 配置方式

````java
// 注解方式
@Component
@Scope("prototype")
public class MyBean { ... }

// 或使用常量
@Scope(ConfigurableBeanFactory.SCOPE_PROTOTYPE)

// Web 专属作用域
@Scope(value = WebApplicationContext.SCOPE_REQUEST, proxyMode = ScopedProxyMode.TARGET_CLASS)
````

## Spring事务

### Spring 事务失效机制

#### AOP 代理未生效

##### 自调用（Self-invocation）

同类内部方法调用不经过代理@Transactional 无法被 AOP 拦截

##### 非 Spring 管理的 Bean

new 出来的对象没有代理包装需通过 @Autowired 注入使用

#### 方法可见性问题

##### 方法非 public

private / protected 方法Spring AOP 无法代理，直接忽略注解

#####  final 或 static 方法

CGLIB 代理无法重写 final 方法static 方法不属于实例方法

#### 异常处理问题

##### 异常被 try-catch 吃掉

吃掉事务管理器感知不到异常需 throw 或手动标记 rollbackOnly

##### 异常类型不匹配

默认只回滚 RuntimeException需指定 rollbackFor = Exception.class

#### 事务传播行为配置错误

##### Propagation.NOT_SUPPORTED

显式挂起当前事务方法体内操作在无事务状态执行等同于主动关闭事务

##### REQUIRES_NEW 误用

误用开启独立事务，外层异常内层已提交无法跟随回滚数据不一致风险

#### 基础设施问题

##### 数据库引擎不支持事务

MySQL MyISAM 无事务支持需使用 InnoDB 引擎

##### 多线程跨线程调用

事务绑定在 ThreadLocal 上子线程获取不到父线程的事务

### Spring 事务传播机制

#### REQUIRED（默认）

````java
@Transactional(propagation = Propagation.REQUIRED)
````

👉 **有事务就加入，没有就创建**

- 外层有事务 → 加入外层事务
- 外层没有事务 → 自己创建事务

✔ 最常用（默认

####  REQUIRES_NEW

````java
@Transactional(propagation = Propagation.REQUIRES_NEW)
````

 **必须新建事务，挂起当前事务**

- 无论外层有没有事务 → 都新建
- 外层事务会被**挂起（suspend）**

✔ 常用于：

- 日志记录
- 审计
- 不希望被主事务影响的操作

#### SUPPORTS

````java
@Transactional(propagation = Propagation.SUPPORTS)
````

👉 **有事务就用，没有就不用**

- 有事务 → 加入
- 没有事务 → 非事务执行

✔ 适用于：

- 查询操作（不强制事务

####  NOT_SUPPORTED

````java
@Transactional(propagation = Propagation.NOT_SUPPORTED)
````

👉 **不支持事务，强制非事务执行**

- 如果有事务 → 挂起
- 自己以非事务方式执行

✔ 适用于：

- 不希望被事务影响的操作（如调用外部接口）

#### MANDATORY

````java
@Transactional(propagation = Propagation.MANDATORY)
````

👉 **必须在事务中执行，否则报错**

- 有事务 → 加入
- 没有事务 → 抛异常

✔ 适用于：

- 强依赖事务的逻辑

#### NEVER

````java
@Transactional(propagation = Propagation.NEVER)
````

👉 **必须无事务执行，否则报错**

- 有事务 → 抛异常
- 没有事务 → 正常执行

✔ 很少使用

#### NESTED

````java
@Transactional(propagation = Propagation.NESTED)
````

👉 **嵌套事务（基于 savepoint）**

- 外层有事务 → 创建子事务（保存点）
- 外层没有 → 类似 REQUIRED

✔ 特点：

- 子事务回滚 → 不影响外层
- 外层回滚 → 子事务一起回滚

⚠️ 依赖数据库支持（如 MySQL InnoDB）






# 微服务

## Nacos注册中心



# Java基础

###  多线程

##### 线程基本概念

###### 进程与线程的区别



| 特性     | 进程                   | 线程                                                       |
| -------- | ---------------------- | ---------------------------------------------------------- |
| 定义     | 资源分配的最小单位     | CPU调度的最小单位                                          |
| 内存空间 | 独立的地址空间         | 共享进程的地址空间                                         |
| 资源拥有 | 拥有独立的系统资源     | 共享进程的资源，仅拥有一点必不可少的资源（PC、栈、寄存器） |
| 开销     | 创建/切换开销大        | 创建/切换开销小                                            |
| 通信     | 进程间通信（IPC）复杂  | 线程间通信简单（共享内存）                                 |
| 健壮性   | 进程间互不影响，更健壮 | 一个线程崩溃可能导致整个进程崩溃                           |

###### 并行与并发

- **并发（Concurrency）**：指两个或多个事件在**同一个时间段内**发生。在单核CPU中，通过时间片轮转实现。
- **并行（Parallelism）**：指两个或多个事件在**同一时刻**发生。需要多核CPU支持。

#### 创建线程的四种方式

##### 继承 Thread 类

```java
public class MyThread extends Thread {
    @Override
    public void run() {
        System.out.println("继承Thread类创建线程: " + Thread.currentThread().getName());
    }

    public static void main(String[] args) {
        new MyThread().start();
    }
}
```

**特点**：

- 简单直接
- 无法继承其他类（Java单继承限制）
- 每个任务需要一个对象，不适合资源共享

##### 实现 Runnable 接口

```java
public class MyRunnable implements Runnable {
    @Override
    public void run() {
        System.out.println("实现Runnable接口创建线程: " + Thread.currentThread().getName());
    }

    public static void main(String[] args) {
        // 可以被多个线程共享
        MyRunnable task = new MyRunnable();
        new Thread(task).start();
        new Thread(task).start();
    }
}
```

**特点**：

- 避免了单继承限制
- 适合资源共享（多个线程处理同一个任务）
- 代码与线程控制解耦

##### 实现 Callable 接口

```java
public class MyCallable implements Callable<String> {
    @Override
    public String call() throws Exception {
        System.out.println("实现Callable接口创建线程: " + Thread.currentThread().getName());
        return "Success";
    }

    public static void main(String[] args) throws ExecutionException, InterruptedException {
        FutureTask<String> futureTask = new FutureTask<>(new MyCallable());
        new Thread(futureTask).start();
        
        // 获取返回值（会阻塞直到完成）
        String result = futureTask.get();
        System.out.println("返回值: " + result);
    }
}
```

**特点**：

- 可以有返回值
- 可以抛出检查异常
- 需要配合 FutureTask 使用

##### 使用线程池

```java
public class ThreadPoolDemo {
    public static void main(String[] args) {
        ExecutorService executor = Executors.newFixedThreadPool(2);
        
        executor.execute(() -> {
            System.out.println("线程池创建线程: " + Thread.currentThread().getName());
        });
        
        executor.shutdown();
    }
}
```

**特点**：

- 复用线程，降低资源消耗
- 提高响应速度
- 统一管理线程



#### 线程生命周期

##### 六种状态（Java）

````java
public enum State {
    NEW,            // 新建
    RUNNABLE,       // 可运行（包括运行中和就绪）
    BLOCKED,        // 阻塞（等待锁）
    WAITING,        // 无限等待（wait/join/park）
    TIMED_WAITING,  // 限时等待（sleep/wait(t)/join(t)）
    TERMINATED      // 终止
}
````

##### 状态转换图

````
      new Thread()           start()
[NEW] ───────────────> [RUNNABLE] <──────────────────┐
                          │  │                       │
           获取到锁        │  │ yield() / CPU时间片耗尽 │
       ┌──────────────────┘  │                       │
       │                     │ notify() / notifyAll()│
       │        synchronized │                       │
       ▼                     ▼                       │
   [BLOCKED] <───────── [WAITING] ───────────────────┘
       │     wait()          │
       │                     │ sleep(t) / wait(t)
       │                     ▼
       └─────────── [TIMED_WAITING] 
                     RUNNABLE 执行完毕 / 异常
[TERMINATED] <────────────────┘
````

#### 线程常用方法

##### sleep() vs wait()

| 特性     | sleep()              | wait()                        |
| -------- | -------------------- | ----------------------------- |
| 所属类   | Thread               | Object                        |
| 锁释放   | **不释放锁**         | **释放锁**                    |
| 使用场景 | 任何地方             | 同步代码块/同步方法           |
| 唤醒方式 | 时间到自动唤醒       | notify()/notifyAll() 或时间到 |
| 异常     | InterruptedException | InterruptedException          |

##### start() vs run()

- **start()**：启动新线程，JVM 调用该线程的 run() 方法。
- **run()**：普通方法调用，不会启动新线程，在当前线程执行。

#####  join()



等待该线程终止。

```java
Thread t1 = new Thread(() -> System.out.println("t1 done"));
t1.start();
t1.join(); // 主线程等待t1执行完才继续
System.out.println("main done");
```

**原理**：内部调用 wait() 方法等待。

##### yield()

提示调度器当前线程愿意放弃 CPU 使用权，但调度器可以忽略。
状态从 Running 变为 Runnable（就绪）。

##### interrupt()

中断线程。

- 如果线程阻塞（sleep/wait/join），会抛出 `InterruptedException` 并清除中断状态。
- 如果线程正常运行，只设置中断标志位，线程需手动检查 `isInterrupted()`。

#### 线程安全与通信

##### 线程通信方式

1. **volatile**：保证内存可见性
2. **synchronized + wait/notify**：等待通知机制
3. **Lock + Condition**：更灵活的等待通知
4. **CountDownLatch / CyclicBarrier**：并发工具类
5. **BlockingQueue**：阻塞队列
6. **Pipe**：管道流

##### 守护线程 (Daemon Thread)

- **用户线程**：主要的工作线程。
- **守护线程**：服务于用户线程（如 GC 线程）。
- **特点**：当所有用户线程结束，JVM 退出，不管守护线程是否结束。

```java
Thread t = new Thread();
t.setDaemon(true); // 必须在 start() 之前设置
t.start();
```

## 

#### 常见面试题

##### 为什么不建议使用 stop() 方法停止线程？

**答**：`stop()` 方法是废弃的（Deprecated）。它会强制终止线程，导致：

- 立即释放所有锁，可能导致数据不一致（数据破坏）。
- 无法完成清理工作（如关闭资源）。
  **正确做法**：使用中断机制 `interrupt()` 配合标志位停止线程。

##### run() 方法可以抛出异常吗？

**答**：`run()` 方法不支持 `throws` 检查异常，必须在方法内部 `try-catch` 处理。
但可以抛出运行时异常（RuntimeException），这会导致线程终止。
可以使用 `UncaughtExceptionHandler` 捕获未处理异常。

##### wait() 为什么要放在循环中？

**答**：防止**虚假唤醒**（Spurious Wakeup）。
在多线程环境下，线程可能在没有收到 notify 的情况下醒来，或者条件在唤醒后被其他线程改变。使用 while 循环可以再次检查条件。

```java
synchronized (obj) {
    while (condition) {
        obj.wait();
    }
    // do logic
}
```

##### Java 中 notify() 和 notifyAll() 有什么区别？

**答**：

- `notify()`：随机唤醒一个等待该锁的线程。
- `notifyAll()`：唤醒所有等待该锁的线程。
  通常建议使用 `notifyAll()` 防止信号丢失（即唤醒了错误的线程，而正确的线程还在等待）。

##### Thread.sleep(0) 有什么用？

**答**：触发操作系统重新进行一次 CPU 竞争。可以让优先级较低的线程有机会执行，或者作为一种让出 CPU 的手段（类似 yield）。

#### synchronized

##### 基本用法

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

##### 原理分析 

synchronized 在 JVM 层面实现，基于 Monitor 对象。

###### 字节码层面

- **代码块**：使用 `monitorenter` 和 `monitorexit` 指令。
- **方法**：使用 `ACC_SYNCHRONIZED` 标识符。

###### Monitor 对象

每个对象都与一个 Monitor 关联。Monitor 内部维护了：

- `_owner`：当前持有锁的线程
- `_WaitSet`：调用 wait() 后等待的线程集合
- `_EntryList`：等待获取锁的线程集合
- `_count`：重入计数器

##### 锁升级过程 (Java 6+)

为了减少获得锁和释放锁带来的性能消耗，引入了偏向锁和轻量级锁。
锁状态存储在对象头（Mark Word）中。

**升级路线**：无锁 → 偏向锁 → 轻量级锁 → 重量级锁

| 锁状态       | 存储内容                  | 适用场景                 |
| ------------ | ------------------------- | ------------------------ |
| **偏向锁**   | 线程ID                    | 只有一个线程访问同步块   |
| **轻量级锁** | 指向栈中Lock Record的指针 | 多个线程交替执行，无竞争 |
| **重量级锁** | 指向Monitor的指针         | 多个线程同时竞争锁       |

**注意**：锁只能升级，不能降级（GC时除外）。

---

#### volatile

##### 作用

1. **保证内存可见性**：当一个线程修改了 volatile 变量的值，新值对于其他线程来说是立即可见的。
2. **禁止指令重排序**：通过内存屏障（Memory Barrier）防止编译器和处理器对指令进行重排序优化。

##### 内存可见性原理

Java 内存模型（JMM）规定：

- 所有变量存在主内存（Main Memory）。
- 每个线程有自己的工作内存（Working Memory），保存了变量的副本。
- 线程操作变量必须在工作内存中进行，不能直接读写主内存。

**volatile 的实现**：

- **写操作**：立即刷新到主内存。
- **读操作**：强制从主内存读取。

##### 禁止指令重排序

指令重排序是为了优化性能，但在多线程下会导致问题。
volatile 通过插入**内存屏障**来实现：

- 在每个 volatile 写操作前插入 StoreStore 屏障。
- 在每个 volatile 写操作后插入 StoreLoad 屏障。
- 在每个 volatile 读操作后插入 LoadLoad 屏障。
- 在每个 volatile 读操作后插入 LoadStore 屏障。

##### volatile 不保证原子性

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

####  synchronized vs volatile

| 特性         | volatile |             synchronized |
| ------------ | -------- | -----------------------: |
| **原子性**   | 不保证   |                 **保证** |
| **可见性**   | **保证** |                 **保证** |
| **有序性**   | **保证** |                 **保证** |
| **阻塞**     | 不阻塞   |                 可能阻塞 |
| **性能**     | 高       | 低（锁升级优化后还可以） |
| **适用范围** | 变量     |             方法、代码块 |

#### 常见面试题

##### 1. synchronized 和 ReentrantLock 的区别？
**答**：

| 特性     | synchronized | ReentrantLock                |
| -------- | ------------ | ---------------------------- |
| 实现     | JVM 层面     | JDK API 层面                 |
| 锁释放   | 自动释放     | 必须手动 unlock()            |
| 灵活性   | 不灵活       | 支持尝试获取、超时获取、中断 |
| 公平性   | 非公平       | 支持公平/非公平              |
| 条件变量 | wait/notify  | Condition (支持多个)         |

##### 2. 什么是 Java 内存模型 (JMM)？
**答**：
JMM 是一种抽象概念，定义了程序中各个变量的访问规则。
- 核心：原子性、可见性、有序性。
- 解决：缓存一致性问题、指令重排序问题。
- 实现：volatile、synchronized、final、Happens-Before 原则。

##### 3. Happens-Before 原则有哪些？
**答**：
1. **程序次序规则**：单线程内，代码顺序执行。
2. **管程锁定规则**：unlock 操作先行发生于后面对同一个锁的 lock 操作。
3. **volatile 变量规则**：写操作先行发生于读操作。
4. **线程启动规则**：start() 先行发生于线程的所有动作。
5. **线程终止规则**：线程的所有动作先行发生于 join() 返回。
6. **传递性**：A happens-before B，B happens-before C，则 A happens-before C。

##### 4. 为什么 synchronized 无法禁止指令重排序？
**答**：
synchronized **可以**保证有序性，但仅限于"同步块内部看似串行"。它不能禁止指令重排序，只是保证了单线程执行的语义（as-if-serial）。
但在 DCL 单例中，instance 变量逸出到同步块外部，因此必须加 volatile。

---

#### Happens-Before 原则详解

##### 6.1 什么是 Happens-Before

Happens-Before 是 JMM（Java 内存模型）中的核心概念，用于描述两个操作之间的可见性关系。
如果操作 A happens-before 操作 B，那么 A 的结果对 B 可见，且 A 的执行顺序排在 B 之前。

**注意**：这是 JMM 的承诺，不代表物理上的执行顺序。

##### 6.2 八大 Happens-Before 规则

```
┌─────────────────────────────────────────────────────────────────┐
│                    Happens-Before 规则                          │
├─────────────────────────────────────────────────────────────────┤
│ 1. 程序次序规则（单线程内）                                      │
│ 2. 管程锁定规则（unlock → lock）                                │
│ 3. volatile 变量规则（写 → 读）                                 │
│ 4. 传递性规则（A→B, B→C ⇒ A→C）                                │
│ 5. 线程启动规则（start() → run()）                              │
│ 6. 线程终止规则（run() → join()返回）                           │
│ 7. 线程中断规则（interrupt() → 检测到中断）                     │
│ 8. 对象终结规则（构造函数 → finalize()）                        │
└─────────────────────────────────────────────────────────────────┘
```

###### 1. 程序次序规则 (Program Order Rule)

```java
// 在单线程中，代码按照程序顺序执行
int a = 1;      // 操作A
int b = 2;      // 操作B
int c = a + b;  // 操作C
// A happens-before B, B happens-before C
```

###### 2. 管程锁定规则 (Monitor Lock Rule)

```java
synchronized (lock) {
    count++; // 操作A
} // unlock happens-before 后续的 lock

synchronized (lock) {
    int x = count; // 操作B - 能看到操作A的结果
}
```

###### 3. volatile 变量规则 (Volatile Variable Rule)

```java
volatile boolean flag = false;
int data = 0;

// 线程1
data = 42;        // 操作A
flag = true;      // 操作B（volatile写）

// 线程2
if (flag) {       // 操作C（volatile读）
    int x = data; // 操作D - x一定是42
}
// B happens-before C，结合传递性，A happens-before D
```

###### 4. 传递性 (Transitivity)

```java
// 如果 A happens-before B，B happens-before C
// 那么 A happens-before C
```

###### 5. 线程启动规则 (Thread Start Rule)

```java
int x = 10;
Thread t = new Thread(() -> {
    int y = x; // y一定是10，因为主线程的x=10 happens-before run()
});
t.start();
```

###### 6. 线程终止规则 (Thread Termination Rule)

```java
Thread t = new Thread(() -> {
    data = 100; // 操作A
});
t.start();
t.join(); // 操作A happens-before join()返回
int x = data; // x一定是100
```

###### 7. 线程中断规则 (Thread Interruption Rule)

```java
Thread t = new Thread(() -> {
    while (!Thread.currentThread().isInterrupted()) {
        // 工作
    }
});
t.start();
t.interrupt(); // interrupt() happens-before 线程检测到中断
```

###### 8. 对象终结规则 (Finalizer Rule)

```java
// 构造函数的最后一行 happens-before finalize() 的第一行
```

##### 6.3 Happens-Before 的实际应用

```java
public class HappensBeforeDemo {
    private int a = 0;
    private volatile boolean flag = false;
    
    public void writer() {
        a = 1;          // 1
        flag = true;    // 2 volatile写
    }
    
    public void reader() {
        if (flag) {     // 3 volatile读
            int i = a;  // 4 一定能看到 a = 1
        }
    }
}
```

**分析**：

- 1 happens-before 2（程序次序规则）
- 2 happens-before 3（volatile规则）
- 3 happens-before 4（程序次序规则）
- 根据传递性：1 happens-before 4

因此，当读到 `flag = true` 时，一定能读到 `a = 1`。

#### ThreadLocal

##### 核心原理

###### 1.1 内存模型

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

###### 1.2 弱引用与内存泄漏 (Memory Leak)

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

##### 高并发场景下的进阶 ThreadLocal

###### 2.1 FastThreadLocal (Netty)

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

###### 2.2 TransmittableThreadLocal (Alibaba)

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

##### ThreadLocal 源码深度解析

######  3.1 ThreadLocalMap 的 Hash 算法

```java
// ThreadLocal.java
private final int threadLocalHashCode = nextHashCode();

// 神奇的哈希增量：0x61c88647
private static final int HASH_INCREMENT = 0x61c88647;

private static int nextHashCode() {
    return nextHashCode.getAndAdd(HASH_INCREMENT);
}
```

**为什么是 0x61c88647？**

- 这是一个黄金分割数，能让哈希码均匀分布
- 与 2^n 取模后，能尽量避免冲突

######  3.2 线性探测法解决冲突

```java
// ThreadLocalMap.set()
private void set(ThreadLocal<?> key, Object value) {
    Entry[] tab = table;
    int len = tab.length;
    int i = key.threadLocalHashCode & (len-1);

    // 线性探测：如果当前槽位被占用，向后找
    for (Entry e = tab[i]; e != null; e = tab[i = nextIndex(i, len)]) {
        ThreadLocal<?> k = e.get();
        
        // key 相同，更新值
        if (k == key) {
            e.value = value;
            return;
        }
        
        // key 为 null（被 GC 回收），替换 stale entry
        if (k == null) {
            replaceStaleEntry(key, value, i);
            return;
        }
    }
    
    // 找到空槽位，插入新 Entry
    tab[i] = new Entry(key, value);
    // ...
}
```

######  3.3 过期 Entry 清理机制

ThreadLocalMap 在以下时机清理过期 Entry（key=null）：

1. `set()` 时遇到 stale entry
2. `get()` 时遇到 stale entry
3. `remove()` 时
4. `rehash()` 时

```java
// 探测式清理
private int expungeStaleEntry(int staleSlot) {
    Entry[] tab = table;
    int len = tab.length;

    // 清理 staleSlot 位置
    tab[staleSlot].value = null;
    tab[staleSlot] = null;
    size--;

    // 向后遍历，清理所有连续的 stale entry
    // ...
}
```

##### ThreadLocal 使用场景总结

1.  **数据库连接/Session 管理**: `DataSourceTransactionManager`, `Hibernate Session`.
2.  **Web 上下文**: Spring MVC `RequestContextHolder` (存储 `HttpServletRequest`).
3.  **日志追踪**: MDC (Log4j/Logback) 存储 TraceID。
4.  **SimpleDateFormat**: 避免每次 new，且保证线程安全。
5.  **用户上下文传递**: 登录用户信息在调用链中传递。

##### 常见面试题

###### Q1: ThreadLocal 会造成内存泄漏吗？如何避免？

**答**：会。

- Entry 的 Key 是弱引用，GC 后变成 null
- 但 Value 是强引用，如果线程不结束，Value 不会被回收
- 解决方案：使用完毕后调用 `remove()` 方法

###### Q2: 为什么 Entry 的 Key 是弱引用？

**答**：

- 如果是强引用，即使 ThreadLocal 不再使用，也无法被 GC
- 使用弱引用可以让 ThreadLocal 在没有外部引用时被回收
- 但这只解决了 Key 的内存问题，Value 仍需手动 remove

###### Q3: ThreadLocal 如何保证线程安全？

**答**：

- 每个线程有自己的 ThreadLocalMap
- 读写操作只在当前线程的 Map 中进行
- 不存在并发访问，天然线程安全

###### Q4: InheritableThreadLocal 在线程池中的问题？

**答**：

- InheritableThreadLocal 只在创建子线程时复制父线程的值
- 线程池中线程是复用的，不会重复复制
- 解决方案：使用阿里的 TransmittableThreadLocal

###### Q5: FastThreadLocal 为什么比 ThreadLocal 快？

**答**：

- ThreadLocal 使用哈希表 + 线性探测，有冲突处理开销
- FastThreadLocal 使用数组，每个实例有唯一 index，直接定位
- FastThreadLocal 需要配合 FastThreadLocalThread 使用

#### ReentrantLock

##### 一、ReentrantLock 简介

`ReentrantLock`（可重入锁）是 JDK 5 引入的，位于 `java.util.concurrent.locks` 包下。
它是一种互斥锁，功能类似于 `synchronized`，但提供了更高级的功能。

**主要特性**：
1. **可重入**：线程可以重复获取已持有的锁。
2. **可中断**：支持 `lockInterruptibly()`，在等待锁时可被中断。
3. **超时获取**：支持 `tryLock(time, unit)`，超时放弃。
4. **公平锁**：支持公平锁（FairSync）和非公平锁（NonFairSync）。
5. **多条件变量**：支持多个 `Condition`，实现精确唤醒。

---

##### 二、使用示例

###### 2.1 基本用法

```java
public class LockDemo {
    private final Lock lock = new ReentrantLock();

    public void method() {
        lock.lock(); // 获取锁
        try {
            // 业务逻辑
        } finally {
            lock.unlock(); // 必须在 finally 块中释放锁
        }
    }
}
```

###### 2.2 公平锁 vs 非公平锁

```java
// 默认是非公平锁 (性能更高)
Lock nonFairLock = new ReentrantLock();

// 创建公平锁 (按请求顺序获取锁)
Lock fairLock = new ReentrantLock(true);
```

###### 2.3 Condition 实现等待/通知

```java
public class ConditionDemo {
    private final Lock lock = new ReentrantLock();
    private final Condition condition = lock.newCondition();

    public void await() throws InterruptedException {
        lock.lock();
        try {
            condition.await(); // 释放锁并等待，类似 Object.wait()
        } finally {
            lock.unlock();
        }
    }

    public void signal() {
        lock.lock();
        try {
            condition.signal(); // 唤醒等待线程，类似 Object.notify()
        } finally {
            lock.unlock();
        }
    }
}
```

---

##### 三、AQS (AbstractQueuedSynchronizer) 原理

`AQS` 是 Java 并发包的核心基础框架，`ReentrantLock`、`Semaphore`、`CountDownLatch` 都基于它实现。

###### 3.1 核心结构

AQS 内部维护了：
1. **state**：volatile int 类型的同步状态。
   - 0 表示无锁
   - >0 表示有锁（重入次数）
2. **CLH 队列**：双向链表，存储等待锁的线程。
   - Head：当前持有锁的节点（或虚节点）
   - Tail：等待队列的尾节点

```java
// AQS 伪代码结构
public abstract class AbstractQueuedSynchronizer {
    private volatile int state;
    private transient volatile Node head;
    private transient volatile Node tail;
    
    // 内部类 Node
    static final class Node {
        volatile Thread thread;
        volatile Node prev;
        volatile Node next;
        volatile int waitStatus; // 节点状态
    }
}
```

###### 3.2 ReentrantLock 加锁过程（非公平锁）

1. **CAS 尝试**：尝试将 `state` 从 0 改为 1。
   - 成功：设置当前线程为 ExclusiveOwnerThread。
   - 失败：进入 `acquire(1)`。
2. **acquire(1) 流程**：
   - `tryAcquire(1)`：再次尝试获取锁（包括重入判断）。
   - `addWaiter(Node.EXCLUSIVE)`：封装成 Node 加入队列尾部。
   - `acquireQueued(node, 1)`：自旋等待。
     - 检查前驱节点是否为 Head。
     - 如果是 Head，再次 `tryAcquire`。
     - 如果失败，挂起当前线程 (`LockSupport.park()`)。

###### 3.3 释放锁过程

1. `tryRelease(1)`：`state` 减 1。
   - 如果 `state` 变为 0，清空 ExclusiveOwnerThread，返回 true。
2. `unparkSuccessor(h)`：唤醒后继节点。
   - 找到 Head 的下一个有效节点。
   - 调用 `LockSupport.unpark(s.thread)` 唤醒线程。

---

##### 四、ReentrantReadWriteLock

`ReentrantReadWriteLock` 维护了一对锁：
- **读锁**（共享锁）：多个线程可以同时获取，适合读多写少。
- **写锁**（独占锁）：同一时刻只能有一个线程获取。

**互斥规则**：
- 读-读：不互斥
- 读-写：互斥
- 写-写：互斥

**锁降级**：
- 写锁可以降级为读锁（持有写锁时获取读锁，然后释放写锁）。
- 读锁**不能**升级为写锁（必须先释放读锁，存在死锁风险）。

```java
public class Cache {
    private final Map<String, Object> map = new HashMap<>();
    private final ReentrantReadWriteLock rwl = new ReentrantReadWriteLock();
    private final Lock r = rwl.readLock();
    private final Lock w = rwl.writeLock();

    public Object get(String key) {
        r.lock();
        try {
            return map.get(key);
        } finally {
            r.unlock();
        }
    }

    public void put(String key, Object value) {
        w.lock();
        try {
            map.put(key, value);
        } finally {
            w.unlock();
        }
    }
}
```

---

##### 五、常见面试题

###### 1. ReentrantLock 与 synchronized 的区别？
**答**：
- **实现**：synchronized 是 JVM 层面（Monitor），ReentrantLock 是 JDK API 层面（AQS）。
- **功能**：ReentrantLock 功能更丰富（超时、中断、公平锁、Condition）。
- **性能**：JDK 6 以后，synchronized 做了大量优化（偏向/轻量级），两者性能差别不大。
- **释放**：synchronized 自动释放，ReentrantLock 必须手动释放。

###### 2. 什么是 AQS？
**答**：
AQS（AbstractQueuedSynchronizer）是一个构建锁和同步器的框架。
它使用一个 volatile int 变量 `state` 表示同步状态，通过 CAS 操作修改 state。
内部维护一个 FIFO 的双向链表（CLH 队列）来管理等待线程。
核心方法是 `acquire`（获取资源）和 `release`（释放资源）。

###### 3. 公平锁是如何实现的？
**答**：
在 `tryAcquire` 时，公平锁会先判断队列中是否有前驱节点 (`hasQueuedPredecessors()`)。
如果有线程在排队，当前线程必须加入队列尾部，不能插队。
非公平锁则不检查，直接尝试 CAS 获取锁。

###### 4. 读写锁适用什么场景？
**答**：
适用于**读多写少**的并发场景，如缓存系统。
读写锁通过分离读锁和写锁，提高了并发性。
注意：如果写操作过于频繁，可能导致读线程饥饿。

#### ConcurrentHashMap 源码与原理深度解析

##### 一、JDK 1.7 与 1.8 架构对比

###### 1.1 JDK 1.7：分段锁 (Segment)

*   **结构**: `Segment` 数组 + `HashEntry` 数组 + 链表。
*   **锁机制**: `Segment` 继承自 `ReentrantLock`。每个 `Segment` 守护一个 `HashEntry` 数组。
*   **并发度**: 等于 `Segment` 数组长度 (默认 16)。即最多支持 16 个线程同时写。
*   **put 操作**: 
    1.  Hash(key) 定位到 Segment。
    2.  `segment.lock()` 加锁。
    3.  Hash(key) 定位到 HashEntry，插入链表。
    4.  `segment.unlock()`。

###### 1.2 JDK 1.8：Node + CAS + Synchronized

*   **结构**: `Node` 数组 + 链表/红黑树 (类似 HashMap)。
*   **锁机制**: 抛弃 `Segment`，直接锁住 **链表/红黑树的头节点**。
*   **并发度**: 理论上等于数组长度 (默认 16，扩容后更大)，并发度远高于 1.7。
*   **put 操作**:
    1.  如果没有初始化，CAS 初始化数组。
    2.  Hash(key) 定位到 Node 数组下标 `i`。
    3.  如果 `table[i]` 为空，**CAS** 尝试插入。
    4.  如果 `table[i]` 不为空，`synchronized(table[i])` 加锁，插入链表或红黑树。

##### 二、JDK 1.8 核心源码分析

###### 2.1 核心属性

```java
// 默认为 null，懒加载
transient volatile Node<K,V>[] table;

// 扩容时的临时表
private transient volatile Node<K,V>[] nextTable;

// 默认为 0
// -1: 正在初始化
// -N: 正在扩容 (N-1 个线程参与)
// >0: 下一次扩容的阈值 (0.75 * capacity)
private transient volatile int sizeCtl;
```

###### 2.2 put 方法解析

```java
final V putVal(K key, V value, boolean onlyIfAbsent) {
    if (key == null || value == null) throw new NullPointerException();
    int hash = spread(key.hashCode()); // 计算 hash，保证正数
    int binCount = 0;
    
    for (Node<K,V>[] tab = table;;) {
        Node<K,V> f; int n, i, fh;
        
        // 1. 懒加载初始化
        if (tab == null || (n = tab.length) == 0)
            tab = initTable();
            
        // 2. 槽位为空，CAS 插入
        else if ((f = tabAt(tab, i = (n - 1) & hash)) == null) {
            if (casTabAt(tab, i, null, new Node<K,V>(hash, key, value, null)))
                break; 
        }
        
        // 3. 正在扩容 (MOVED = -1)，帮忙扩容
        else if ((fh = f.hash) == MOVED)
            tab = helpTransfer(tab, f);
            
        // 4. 发生哈希冲突，加锁
        else {
            V oldVal = null;
            synchronized (f) { // 锁住头节点
                if (tabAt(tab, i) == f) { // 双重检查
                    if (fh >= 0) { // 链表
                        // ... 遍历链表插入 ...
                    }
                    else if (f instanceof TreeBin) { // 红黑树
                        // ... 树操作 ...
                    }
                }
            }
            // 5. 链表转红黑树 (阈值 8)
            if (binCount != 0) {
                if (binCount >= TREEIFY_THRESHOLD)
                    treeifyBin(tab, i);
                if (oldVal != null)
                    return oldVal;
                break;
            }
        }
    }
    // 6. 增加计数 (LongAdder 思想)
    addCount(1L, binCount);
    return null;
}
```

###### 2.3 扩容 (Transfer) 源码精髓

CHM 的扩容是 **多线程协同** 的。

1.  **触发条件**: `size >= sizeCtl` (0.75 * n)。
2.  **创建新表**: `nextTable` 大小翻倍。
3.  **分段迁移**: 
    *   将数组按 `stride` (步长) 分成多个段。
    *   每个线程领取一段区间 (例如 16 个槽位)，负责将这部分的 Node 迁移到 `nextTable`。
    *   迁移完的槽位放置 `ForwardingNode` (hash = -1)，表示该位置已迁移。
4.  **并发扩容**: 如果线程 B 在 put 时发现当前槽位是 `ForwardingNode`，它不会阻塞，而是去协助线程 A 进行扩容。

##### 三、常见面试问题

###### 3.1 为什么 1.8 放弃了 Segment？

1.  **粒度更细**: 1.7 锁一段，1.8 锁一个槽位 (Node)。
2.  **内存占用**: Segment 对象本身有内存开销。
3.  **JVM 优化**: synchronized 在 JDK 1.6 后优化了 (偏向锁、轻量级锁)，性能不输 ReentrantLock。

###### 3.2 什么时候转红黑树？

同时满足两个条件：

1.  链表长度 >= 8。
2.  数组长度 >= 64。

*   如果链表长但数组短，优先扩容 (`tryPresize`) 而不是转树。

###### 3.3 get 方法需要加锁吗？

不需要。

*   `Node` 的 `val` 和 `next` 指针都是 `volatile` 的，保证可见性。
*   如果遇到扩容 (`ForwardingNode`)，会调用 `find` 方法去 `nextTable` 查找。

#### Java 线程池详解

##### 一、为什么使用线程池

1. **降低资源消耗**：通过重复利用已创建的线程，降低线程创建和销毁造成的消耗。
2. **提高响应速度**：当任务到达时，任务可以不需要等待线程创建就能立即执行。
3. **提高线程的可管理性**：线程是稀缺资源，如果无限制地创建，不仅会消耗系统资源，还会降低系统的稳定性，使用线程池可以进行统一分配、调优和监控。

---

##### 二、ThreadPoolExecutor 核心参数

```java
public ThreadPoolExecutor(int corePoolSize,
                          int maximumPoolSize,
                          long keepAliveTime,
                          TimeUnit unit,
                          BlockingQueue<Runnable> workQueue,
                          ThreadFactory threadFactory,
                          RejectedExecutionHandler handler)
```

| 参数名              | 含义                                                 |
| ------------------- | ---------------------------------------------------- |
| **corePoolSize**    | 核心线程数（即使空闲也不会被销毁）                   |
| **maximumPoolSize** | 最大线程数（核心线程 + 非核心线程）                  |
| **keepAliveTime**   | 非核心线程空闲存活时间                               |
| **unit**            | 时间单位                                             |
| **workQueue**       | 任务队列（当核心线程满了，新任务放入队列）           |
| **threadFactory**   | 线程工厂（用于创建线程，设置线程名等）               |
| **handler**         | 拒绝策略（当队列和最大线程数都满了，如何处理新任务） |

---

##### 三、线程池工作流程

1. **提交任务**：执行 `execute()`。
2. **核心线程判断**：
   - 如果当前运行的线程数 < `corePoolSize`，则创建新线程执行任务。
   - 否则，进入下一步。
3. **队列判断**：
   - 如果队列未满，将任务加入 `workQueue`。
   - 否则，进入下一步。
4. **最大线程判断**：
   - 如果当前运行的线程数 < `maximumPoolSize`，则创建非核心线程执行任务。
   - 否则，执行拒绝策略。

```
     Submit Task
          │
          ▼
   Running < CoreSize? ──YES──> Create Thread
          │
          NO
          ▼
    Queue Full? ──────NO──────> Add to Queue
          │
          YES
          ▼
   Running < MaxSize? ──YES──> Create Thread
          │
          NO
          ▼
    Reject Strategy
```

---

##### 四、常见阻塞队列

| 队列名称                  | 特性                                                         |
| ------------------------- | ------------------------------------------------------------ |
| **ArrayBlockingQueue**    | 基于数组的有界阻塞队列，FIFO。                               |
| **LinkedBlockingQueue**   | 基于链表的阻塞队列，默认无界（Integer.MAX_VALUE），FIFO。    |
| **SynchronousQueue**      | 不存储元素的阻塞队列，每个插入操作必须等待另一个线程的移除操作。 |
| **PriorityBlockingQueue** | 支持优先级的无界阻塞队列。                                   |
| **DelayQueue**            | 使用优先级队列实现的无界阻塞队列，只有在延迟期满时才能从中提取元素。 |

---

##### 五、四种拒绝策略

1. **AbortPolicy** (默认)：直接抛出 `RejectedExecutionException` 异常。
2. **CallerRunsPolicy**：用调用者所在的线程来执行任务。
3. **DiscardOldestPolicy**：丢弃队列中最老的一个任务，并执行当前任务。
4. **DiscardPolicy**：不处理，直接丢弃任务。

---

##### 六、Executors 工具类（不推荐生产使用）

虽然 `Executors` 提供了便捷的方法创建线程池，但《阿里巴巴Java开发手册》**禁止**在生产环境使用，原因如下：

1. **FixedThreadPool** 和 **SingleThreadPool**：
   - 允许的请求队列长度为 `Integer.MAX_VALUE`，可能会堆积大量请求，导致 OOM。
2. **CachedThreadPool**：
   - 允许的创建线程数量为 `Integer.MAX_VALUE`，可能会创建大量线程，导致 OOM。

**推荐方式**：手动创建 `ThreadPoolExecutor`。

```java
// 生产环境推荐写法
ThreadPoolExecutor executor = new ThreadPoolExecutor(
    5, // corePoolSize
    10, // maximumPoolSize
    60L, TimeUnit.SECONDS, // keepAliveTime
    new ArrayBlockingQueue<>(100), // workQueue
    new ThreadFactoryBuilder().setNameFormat("demo-pool-%d").build(), // threadFactory (Guava)
    new ThreadPoolExecutor.CallerRunsPolicy() // handler
);
```

---

##### 七、线程池状态

1. **RUNNING**：能接受新任务，也能处理队列中的任务。
2. **SHUTDOWN**：不接受新任务，但处理队列中的任务（调用 `shutdown()`）。
3. **STOP**：不接受新任务，也不处理队列中的任务，中断正在执行的任务（调用 `shutdownNow()`）。
4. **TIDYING**：所有任务都已终止，workerCount 为 0。
5. **TERMINATED**：`terminated()` 方法执行完。

---

##### 八、常见面试题

###### 1. 线程池参数如何设置？

**答**：

- **CPU 密集型任务**（加密、计算）：
  - 线程数 = CPU 核数 + 1
- **IO 密集型任务**（数据库、网络请求）：
  - 线程数 = CPU 核数 * 2
  - 或者：线程数 = CPU 核数 / (1 - 阻塞系数)  (阻塞系数通常 0.8~0.9)

###### 2. 线程池是如何复用线程的？

**答**：
线程执行完任务后，不会销毁，而是去队列中获取下一个任务 (`task = workQueue.take()`)。
如果队列为空，核心线程会阻塞等待，非核心线程等待超时后销毁。
核心逻辑在 `runWorker()` 方法的 `while` 循环中。

###### 3. submit() 和 execute() 的区别？

**答**：

- **execute()**：提交 Runnable 任务，无返回值。
- **submit()**：提交 Callable 或 Runnable 任务，返回 Future 对象，可以获取执行结果或捕获异常。

###### 4. 线程池中线程发生异常怎么处理？

**答**：

- 如果使用 `execute()`，异常会打印到控制台，线程终止，线程池会创建一个新线程代替它。
- 如果使用 `submit()`，异常会被封装在 Future 中，调用 `future.get()` 时才会抛出。
- 建议在任务内部 try-catch 处理异常。

### Mysql

#### 一条 SQL 语句是如何执行的

MySQL 的架构大体分为 **Server 层** 和 **存储引擎层**。

1.  **连接器 (Connector)**
    - 负责跟客户端建立连接、获取权限、维持和管理连接。
    - 命令：`mysql -h <host> -P <port> -u <user> -p`

2.  **查询缓存 (Query Cache)** (MySQL 8.0 已移除)
    - 之前的查询结果以 Key-Value 对的形式存储。Key 是 SQL 语句，Value 是结果。
    - 弊大于利：表数据更新，相关缓存全部失效。

3.  **分析器 (Analyzer)**
    - **词法分析**：识别关键字 (select, from) 和标识符 (表名, 列名)。
    - **语法分析**：判断 SQL 语句是否满足 MySQL 语法。

4.  **优化器 (Optimizer)**
    - 决定使用哪个索引。
    - 决定 Join 表的连接顺序。
    - 生成执行计划。

5.  **执行器 (Executor)**
    - 判断是否有权限。
    - 根据执行计划调用存储引擎接口。

6.  **存储引擎 (Storage Engine)**
    - 负责数据的存储和提取。
    - 插件式架构，常用 InnoDB, MyISAM, Memory。
    - **InnoDB**：支持事务、行级锁、外键，是默认引擎。

#### InnoDB 关键特性与日志

##### 1. Buffer Pool (缓冲池)

- **作用**：缓存磁盘上的数据页，减少磁盘 IO。
- **机制**：
  - 读取数据时，先看 Buffer Pool 中有没有，有则直接读取，无则从磁盘加载。
  - 修改数据时，先修改 Buffer Pool 中的页（标记为 **脏页**），后台线程定期刷脏到磁盘。
- **LRU 算法**：MySQL 对标准 LRU 做了改进（分代 LRU），防止全表扫描导致热数据被淘汰。
  * LRU被拆分成两个部分 old区（37%） 和new区（63%）
  * 当数据第一次被加载到Buffer Pool不会直接进入 Young，防止一次性大查询污染缓存
  * 二次访问才进入 Young（关键），这是“真正的热点数据”
  * 优先从 Old 区尾部淘汰（冷数据优先被清理，热点数据（Young）不容易被挤掉）

##### 2. Redo Log (重做日志) - 物理日志

- **作用**：保证事务的 **持久性 (Durability)**，实现 **Crash-safe** 能力。
- **内容**：记录的是"在某个数据页上做了什么修改"。
- **机制**：**WAL (Write-Ahead Logging)** 技术，先写日志，再写磁盘。
- **结构**：循环写。write pos 是写入点，checkpoint 是擦除点。

##### 3. Bin Log (归档日志) - 逻辑日志

- **作用**：用于主从复制 (Replication) 和数据恢复。
- **属于**：Server 层，所有引擎通用。
- **内容**：记录语句的原始逻辑 (如 "给 ID=2 这一行的 c 字段加 1")。
- **模式**：
  - `Statement`：记录 SQL 语句。
  - `Row`：记录行内容的变化（推荐）。
  - `Mixed`：混合模式。
- **写入机制**：追加写。

##### 4. 两阶段提交 (Two-Phase Commit)

为了保证 Redo Log 和 Bin Log 的数据一致性。

1.  **Prepare 阶段**：引擎将更新记录写入 Redo Log，状态设为 prepare。
2.  **Commit 阶段**：Server 写 Bin Log，然后通知引擎将 Redo Log 状态设为 commit。

##### 5. Undo Log (回滚日志) - 逻辑日志

- **作用**：保证事务的 **原子性 (Atomicity)** 和实现 **MVCC**。
- **内容**：记录数据的逻辑变化。
  - Insert -> 记录 Delete
  - Delete -> 记录 Insert
  - Update -> 记录反向 Update
- **回滚**：执行 Undo Log 中的逆操作。

##### 6. Double Write (双写机制)

- **解决问题**：**页断裂 (Partial Page Write)**。
  - 数据库页大小 (16KB) 与 操作系统页大小 (4KB) 不一致。若写一半断电，页损坏，Redo Log 无法恢复。
- **机制**：
  1. 脏页先拷贝到内存中的 Double Write Buffer。
  2. 顺序写入系统表空间的 Double Write 区 (磁盘)。
  3. 离散写入数据文件。
- **恢复**：如果页损坏，先从 Double Write 区找到副本恢复，再应用 Redo Log。

#### MySQL Index (索引剖析)

索引 (Index) 是帮助 MySQL 高效获取数据的数据结构。

##### 一、索引的数据结构

MySQL 主要使用 **B+树** 作为索引结构。

###### 1. 为什么是 B+树？

- **哈希表**：适合等值查询，不适合范围查询。
- **二叉树/平衡二叉树 (AVL) / 红黑树**：树高过高，磁盘 IO 次数多。
- **B树**：每个节点都存 Key 和 Value。
- **B+树**：
  - **非叶子节点只存 Key**：同样大小的页可以存更多的索引，树更矮胖，IO 更少。
  - **叶子节点存 Key 和 Value**：所有数据都在叶子节点。
  - **叶子节点形成双向链表**：便于范围查询和排序。

###### 2. Page 页

- InnoDB 管理存储空间的基本单位是 **页 (Page)**，默认 16KB。
- B+树的每个节点就是一个页。

##### 二、索引分类 (InnoDB)

###### 1. 主键索引 (聚簇索引 / Clustered Index)

- **定义**：叶子节点存储了 **整行数据**。
- **特点**：一张表只能有一个聚簇索引。
- **选择规则**：
  1. 优先选择主键。
  2. 没有主键，选择第一个非空的唯一索引。
  3. 都没有，InnoDB 生成一个隐藏的 6 字节 row_id。

###### 2. 二级索引 (非聚簇索引 / Secondary Index)

- **定义**：叶子节点存储了 **索引列的值** 和 **主键值**。
- **特点**：包括普通索引、唯一索引、联合索引。
- **回表 (Back Query)**：
  - 如果查询的列在二级索引中找不到，需要拿主键值去聚簇索引中再查一次，称为回表。
  - 例：`select * from user where name = 'Alice';` (name 是索引)
  - 过程：先查 name 索引找到 id，再根据 id 查聚簇索引找到整行数据。

###### 3. 联合索引 (Composite Index)

- **定义**：基于多个列创建的索引。
- **结构**：先按第一列排序，第一列相同按第二列排序...
- **最左前缀原则 (Leftmost Prefix Principle)**：
  - 必须从最左边的列开始匹配。
  - 如果中间跳过某列，后面的列索引失效。
  - 遇到范围查询 (`>`, `<`, `between`, `like`)，右边的列索引失效。

##### 三、索引优化与概念

###### 1. 覆盖索引 (Covering Index)

- 查询的列完全被索引包含，**不需要回表**。
- 例：`select id, name from user where name = 'Alice';` (name 是索引，叶子节点有 name 和 id)

###### 2. 索引下推 (Index Condition Pushdown - ICP)

- MySQL 5.6 引入。
- 在索引遍历过程中，对索引中包含的字段先做判断，直接过滤掉不满足条件的记录，减少回表次数。

###### 3. 怎么判断一条 SQL 走没走索引？

- 使用 `explain` 命令查看执行计划（详见下一章）。

#### SQL Analysis & Optimization (语句分析与优化)

使用 `EXPLAIN` 关键字可以模拟优化器执行 SQL 查询语句，从而知道 MySQL 是如何处理你的 SQL 语句的。

##### 一、Explain 字段详解

命令：`EXPLAIN SELECT ...`

| 字段              | 含义                                                         |
| :---------------- | :----------------------------------------------------------- |
| **id**            | select 查询的序列号，表示查询中执行 select 子句或操作表的顺序。 |
| **select_type**   | 查询的类型 (如 SIMPLE, PRIMARY, SUBQUERY, DERIVED)。         |
| **table**         | 显示这一行的数据是关于哪张表的。                             |
| **partitions**    | 匹配的分区。                                                 |
| **type**          | **访问类型** (重要指标)。                                    |
| **possible_keys** | 显示可能应用在这张表上的索引。                               |
| **key**           | 实际使用的索引。如果为 NULL，则没有使用索引。                |
| **key_len**       | 使用索引的字节数。                                           |
| **ref**           | 显示索引的哪一列被使用了，如果可能的话，是一个常数。         |
| **rows**          | 根据表统计信息及索引选用情况，大致估算出找到所需的记录所需要读取的行数。 |
| **filtered**      | 查询条件过滤的行数百分比。                                   |
| **Extra**         | **额外信息** (重要指标)。                                    |

###### 1. id

- id 相同，执行顺序由上至下。
- id 不同，id 值越大优先级越高，越先被执行。

###### 2. type (访问类型)

从最好到最差依次是：
**system > const > eq_ref > ref > range > index > ALL**

- **system**：表只有一行记录（系统表）。
- **const**：通过索引一次就找到了，用于 **Primary Key** 或 **Unique** 索引。
- **eq_ref**：唯一性索引扫描，对于每个索引键，表中只有一条记录与之匹配。常见于主键或唯一索引扫描。
- **ref**：非唯一性索引扫描，返回匹配某个单独值的所有行。
- **range**：只检索给定范围的行，使用一个索引来选择行。key 显示使用了哪个索引。常见于 `between`, `<`, `>`, `in` 等查询。
- **index**：**Full Index Scan**，遍历索引树。通常比 ALL 快，因为索引文件通常比数据文件小。
- **ALL**：**Full Table Scan**，全表扫描。

###### 3. Extra (额外信息)

- **Using filesort**：说明 MySQL 会对数据使用一个外部的索引排序，而不是按照表内的索引顺序进行读取。**需要优化**。
- **Using temporary**：使用了临时表保存中间结果，MySQL 在对查询结果排序时使用临时表。常见于 `order by` 和 `group by`。**严重，需要优化**。
- **Using index**：表示相应的 select 操作中使用了 **覆盖索引 (Covering Index)**，避免访问了表的数据行，效率不错。
- **Using where**：使用了 where 过滤。
- **Using join buffer**：使用了连接缓存。

##### 二、优化案例

###### 1. 避免 `select *`

- 只查询需要的列，增加使用覆盖索引的可能性。

###### 2. 最左前缀法则

- 联合索引 `(a, b, c)`。
- `where a=1 and b=2 and c=3` -> 用到 a, b, c
- `where a=1 and b=2` -> 用到 a, b
- `where a=1 and c=3` -> 只用到 a (c 失效)
- `where b=2` -> 不走索引 (a 缺失)

###### 3. 不要在索引列上做任何操作

- 计算、函数、类型转换会导致索引失效而转向全表扫描。
- 例：`where left(name, 4) = 'test'` (失效)

###### 4. 范围查询右边的列失效

- `where a=1 and b>2 and c=3` -> a, b 走索引，c 失效。

###### 5. 尽量使用覆盖索引

- 减少 `select *`，查询列尽量和索引列一致。

###### 6. `is null`, `is not null`

- 可能会导致索引失效（取决于数据分布）。

###### 7. `like` 以通配符开头

- `like '%abc'` -> 索引失效。
- `like 'abc%'` -> 索引有效 (range)。
- 解决：使用覆盖索引可以挽救。

###### 8. 字符串不加单引号

- 导致隐式类型转换，索引失效。
- 例：varchar 字段 `where name = 123` (失效)。

###### 9. `or` 连接

- `or` 两边必须都有索引才会走索引，否则全表扫描。

#### MySQL 事务与锁机制深度解析

##### 一、事务隔离级别与实现原理

###### 1.1 隔离级别 (Isolation Level)

| 隔离级别                 | 脏读 | 不可重复读 | 幻读            | 实现方式                                      |
| :----------------------- | :--- | :--------- | :-------------- | :-------------------------------------------- |
| **Read Uncommitted**     | ✅    | ✅          | ✅               | 不加锁，读取最新版本                          |
| **Read Committed (RC)**  | ❌    | ✅          | ✅               | MVCC (每次 Select 生成 ReadView)              |
| **Repeatable Read (RR)** | ❌    | ❌          | ❌ (InnoDB 解决) | MVCC (第一次 Select 生成 ReadView) + Gap Lock |
| **Serializable**         | ❌    | ❌          | ❌               | 所有 Select 转为 Select ... in share mode     |

###### 1.2 MVCC (多版本并发控制) 原理

MVCC 使得 InnoDB 能够在不加锁的情况下实现并发读写。

###### 核心组件

1.  **隐藏字段**:
    *   `DB_TRX_ID`: 最近修改该行数据的事务 ID。
    *   `DB_ROLL_PTR`: 回滚指针，指向 Undo Log 中的旧版本。
    *   `DB_ROW_ID`: 隐藏主键。
2.  **Undo Log (回滚日志)**: 存储历史版本数据，形成版本链。
3.  **ReadView (一致性视图)**:
    *   `m_ids`: 当前活跃的事务 ID 列表。
    *   `min_trx_id`: 活跃事务中最小 ID。
    *   `max_trx_id`: 生成 ReadView 时系统分配的下一个 ID。

###### 可见性判断算法

当事务 A (ID=100) 读取某行数据 (trx_id=50) 时：

1.  如果 `trx_id < min_trx_id`: 说明该版本在事务 A 开启前已提交 -> **可见**。
2.  如果 `trx_id >= max_trx_id`: 说明该版本在事务 A 开启后才创建 -> **不可见**。
3.  如果 `min_trx_id <= trx_id < max_trx_id`:
    *   如果 `trx_id` 在 `m_ids` 中: 说明该版本由尚未提交的事务创建 -> **不可见**。
    *   如果 `trx_id` 不在 `m_ids` 中: 说明该版本由已提交事务创建 -> **可见**。

**结论**: RC 级别下，每次 Select 都重新生成 ReadView，所以能看到别的事务新提交的数据。RR 级别下，只有第一次 Select 生成 ReadView，后续复用，所以看不到。

##### 二、InnoDB 锁机制

###### 2.1 锁的分类

*   **共享锁 (S Lock)**: 读锁。`SELECT ... LOCK IN SHARE MODE`。
*   **排他锁 (X Lock)**: 写锁。`SELECT ... FOR UPDATE`, `UPDATE`, `DELETE`, `INSERT`。

###### 2.2 行锁算法 (Row Locks)

InnoDB 的锁是**加在索引上**的，不是加在数据行上的。

1.  **Record Lock (记录锁)**: 锁住索引记录本身。
    *   `SELECT * FROM user WHERE id = 1 FOR UPDATE` (id 是主键)
2.  **Gap Lock (间隙锁)**: 锁住索引记录之间的间隙，防止插入 (解决幻读)。
    *   `SELECT * FROM user WHERE id > 10 FOR UPDATE`
3.  **Next-Key Lock**: Record Lock + Gap Lock。锁住左开右闭区间 `(5, 10]`。

###### 2.3 间隙锁 (Gap Lock) 案例图解

假设表 `t` (id PK): 5, 10, 15, 20。

**案例 1: 等值查询 (不存在的记录)**

```sql
-- 事务 A
SELECT * FROM t WHERE id = 7 FOR UPDATE;
```

*   **分析**: id=7 不存在，落在 (5, 10) 区间。
*   **结果**: InnoDB 会加 Gap Lock `(5, 10)`。
*   **影响**: 其他事务插入 id=6, 8, 9 会被阻塞，直到 A 提交。

**案例 2: 范围查询**

```sql
-- 事务 A
SELECT * FROM t WHERE id > 10 FOR UPDATE;
```

*   **结果**: 锁住 `(10, 15]`, `(15, 20]`, `(20, +∞)`。
*   **注意**: 即使是 RC 级别，Update 语句也会加锁，但 RC 没有 Gap Lock，只有 Record Lock。这也是为什么 RR 比 RC 更容易死锁的原因。

##### 三、死锁 (Deadlock) 分析

###### 3.1 经典死锁案例 (AB - BA)

*   事务 A: `UPDATE user SET age=10 WHERE id=1;` (持有 id=1 X锁)
*   事务 B: `UPDATE user SET age=20 WHERE id=2;` (持有 id=2 X锁)
*   事务 A: `UPDATE user SET age=11 WHERE id=2;` (等待 id=2 X锁)
*   事务 B: `UPDATE user SET age=21 WHERE id=1;` (等待 id=1 X锁) -> **死锁**

###### 3.2 间隙锁死锁

*   事务 A: `SELECT * FROM t WHERE id = 7 FOR UPDATE;` (持有 (5, 10) Gap Lock)
*   事务 B: `SELECT * FROM t WHERE id = 8 FOR UPDATE;` (Gap Lock 之间兼容，B 也持有 (5, 10) Gap Lock)
*   事务 A: `INSERT INTO t VALUES (7);` (被 B 的 Gap Lock 阻塞)
*   事务 B: `INSERT INTO t VALUES (8);` (被 A 的 Gap Lock 阻塞) -> **死锁**

###### 3.3 如何排查

1.  查看死锁日志: `SHOW ENGINE INNODB STATUS`。
2.  查看 LATEST DETECTED DEADLOCK 部分。

### Redis
#### 数据结构

##### String（字符串）

###### 数据结构

底层实现：

| 数据结构                        | 说明                       |
| ------------------------------- | -------------------------- |
| **SDS (Simple Dynamic String)** | Redis 自己实现的动态字符串 |

SDS 结构：

```
struct sdshdr {
    int len;   // 已使用长度
    int free;  // 剩余空间
    char buf[];// 字符数组
}
```

特点：

- O(1) 获取字符串长度
- 自动扩容
- 减少内存拷贝
- 二进制安全

扩容策略：

```
len < 1MB     -> 扩容为2倍
len >= 1MB    -> 每次增加1MB
```

------

## 

###### 使用场景

**缓存**

```
SET user:1001 "{name:tom,age:20}"
```

应用：

- 用户信息缓存
- 商品详情缓存
- Session

**计数器**

```
INCR page_view
```

应用：

- PV/UV统计
- 点赞数
- 阅读量

**分布式锁**

```
SET lock_key value NX PX 30000
```

应用：

- 分布式任务
- 防止重复提交

##### List（列表）

###### 底层数据结构

Redis3.2以后：

```
QuickList
```

QuickList =

```
双向链表 + ziplist
```

结构：

```
quicklist
   │
   ├── ziplist
   ├── ziplist
   └── ziplist
```

优点：

| 结构      | 优点     |
| --------- | -------- |
| 链表      | 插入快   |
| ziplist   | 内存紧凑 |
| quicklist | 结合二者 |

###### 时间复杂度

| 操作   | 复杂度 |
| ------ | ------ |
| LPUSH  | O(1)   |
| RPUSH  | O(1)   |
| LPOP   | O(1)   |
| LRANGE | O(n)   |

###### 使用场景

** 消息队列（简单）**

```
LPUSH queue msg
RPOP queue
```

特点：

- FIFO
- 简单 MQ

缺点：

- 无 ACK
- 无消费确认

** 任务队列**

例如：

```
LPUSH task_queue task1
```

消费者：

```
BRPOP task_queue
```

特点：

- 阻塞消费
- 实时处理

** Feed流**

例如微博：

```
LPUSH feed:user:1001 postId
```

##### Hash（哈希）

###### 底层数据结构

两种实现：

| 条件   | 结构                   |
| ------ | ---------------------- |
| 小对象 | **ziplist / listpack** |
| 大对象 | **hashtable**          |

自动转换条件：

```
hash-max-ziplist-entries 512
hash-max-ziplist-value   64
```

###### 结构示例

```
HSET user:1001 name tom age 20
```

结构：

```
user:1001
   ├── name : tom
   └── age  : 20
```

###### 使用场景

**用户信息**

```
HSET user:1001 name tom age 20
```

优点：

- 局部更新
- 节省空间

**对象存储**

例如：

```
商品
订单
用户
```

------

** 统计数据**

```
HINCRBY article:1 view 1
```

##### Set（集合）

###### 底层数据结构

| 条件   | 结构          |
| ------ | ------------- |
| 整数   | **intset**    |
| 非整数 | **hashtable** |

###### intset结构

```
[1,2,3,4]
```

紧凑存储：

```
连续数组
```

###### 时间复杂度

| 操作      | 复杂度 |
| --------- | ------ |
| SADD      | O(1)   |
| SREM      | O(1)   |
| SISMEMBER | O(1)   |

###### 使用场景

** 1 去重**

```
SADD online_users 1001
```

判断是否存在：

```
SISMEMBER online_users 1001
```

------

** 2 共同好友**

```
SINTER user1 user2
```

------

** 3 抽奖**

```
SRANDMEMBER
```

##### Sorted Set（ZSet）

ZSet 是 **Redis最强数据结构之一**

###### 底层结构

```
SkipList + HashTable
```

结构：

```
       SkipList
           │
score  ->  member
```

HashTable：

```
member -> score
```

这样可以：

| 操作      | 复杂度   |
| --------- | -------- |
| 查询score | O(1)     |
| 范围查询  | O(log n) |

######  跳表（SkipList）

跳表结构：

```
Level3    1 ----------- 8
Level2    1 ---- 4 ---- 8
Level1    1 2 3 4 5 6 7 8
```

特点：

| 特性       | 优势     |
| ---------- | -------- |
| 多层索引   | 快速查找 |
| 平均复杂度 | O(log n) |

###### 使用场景

** 排行榜**

```
ZADD score 100 user1
ZADD score 200 user2
```

获取排行：

```
ZREVRANGE score 0 10
```

应用：

- 游戏排行榜
- 积分榜

** 延迟队列**

```
score = 时间戳
ZADD delay_queue 1710000000 task1
```

扫描：

```
ZRANGEBYSCORE delay_queue -inf now
```

** 热度排名**

例如：

```
文章热度
商品热度
```

##### Bitmap（位图）

本质：

```
String + bit操作
```

示例：

```
SETBIT sign:20260306 1001 1
```

###### 使用场景

** 用户签到**

```
用户ID = offset
SETBIT sign:20260306 1001 1
```

统计：

```
BITCOUNT
```



### JVM

#### Java 编译的四大阶段

1. 词法分析 (Lexical Analysis)   编译器首先读取源文件中的字符流，将其归类为一个个**标记（Token）**。
   * **操作：** 去掉空格、注释，识别出关键字（如 `public`, `class`）、标识符（变量名）、操作符和字面量。
   * **类比：** 就像阅读句子时，先识别出哪些是动词、名词和标点。
2. 语法分析 (Syntactic Analysis) 编译器根据 Java 语言规范，检查 Token 的组合是否符合语法规则，并构建一棵 **抽象语法树 (AST - Abstract Syntax Tree)**。
   *  如果你少写了一个分号 `;` 或括号 `}`，编译器在这个阶段就会报错。
3. 语义分析 (Semantic Analysis) 有了语法树后，编译器需要确认代码逻辑在语义上是否合法。
   * **检查内容：** 变量是否已声明？类型是否匹配（例如能否把 `String` 赋值给 `int`）？方法调用的参数个数是否正确？
   * **符号表：** 编译器会维护一张符号表，记录类、方法和变量的定义及其属性。
4. 代码生成 (Code Generation) 这是最后一步，编译器将经过校验的语法树转换为 **Java 字节码 (Bytecode)**，并写入 `.class` 文件。
   * **产物：** 字节码并不是机器码，而是一种中间指令集，由 **JVM (Java虚拟机)** 来解释执行或编译执行。

````she
ClassFile {
  u4 magic; //魔法数，Class文件的标识。值是固定的，为0xCAFEBABE
  u2 minor_version; //小版本
  u2 major_version; //主版本号 34，52对应java 8 ,也就是我们jdk8生成的class版本
  u2 constant_pool_count; //38 常量池计算器
  cp_info constant_pool[constant_pool_count-1]; //常量池
  u2 access_flags; //访问标志 标志了类或者接口的访问信息，比如是类还是接口还是注解、枚举，是否是abstract,如果是类，是否被声明成final等等
  u2 this_class; //类索引
  u2 super_class; //父类索引
  u2 interfaces_count; //接口计数器 ，这也是之前大家在讨论动态代理的时候最多是65535个接口的时候讨论过的
  u2 interfaces[interfaces_count];
  u2 fields_count; //字段个数
  field_info fields[fields_count]; //字段集合
  u2 methods_count; //方法计数器
  method_info methods[methods_count]; //方法集合
  u2 attributes_count; //附加属性计数器
  attribute_info attributes[attributes_count]; //附加属性集合
}
````



#### Class 类的生命周期

1. 准备阶段 (Loading & Linking) 这是类进入内存并进行检查的过程
   * **加载 (Loading)**：查找并导入 `.class` 文件，在内存中生成一个 `java.lang.Class` 对象。
   * **验证 (Verification)**：确保加载的字节码符合 JVM 规范，没有安全隐患（比如检查“魔数”是否正确）。
   * **准备 (Preparation)**：为类变量（`static` 修饰的变量）分配内存，并设置**默认初始值**（如 `int` 设为 `0`，而不是你代码里写的那个值）。
   * **解析 (Resolution)**：将常量池内的符号引用（比如方法名）替换为直接引用（具体的内存地址）。
2. 初始化与使用阶段 (Initialization & Using)  这是类真正开始“干活”的阶段：
   * **初始化 (Initialization)** 🚩：这是开发者最关心的阶段。JVM 开始执行类构造器 `<clinit>()` 方法，真正给静态变量赋上你在代码里写的初始值，并执行 `static` 代码块。
   * **使用 (Using)**：程序员在代码里 `new` 对象、调用静态方法或访问静态字段。
3.  卸载阶段 (Unloading)
   * **卸载 (Unloading)**：当这个类不再被需要，且满足非常严苛的垃圾回收条件时，它会被从元空间（Metaspace）中清除。

#### 类加载器的层次结构

1. 启动类加载器 (Bootstrap ClassLoader)
   * 它是加载器里的“老祖宗”，由 C++ 编写。
   * 负责加载 Java 的核心类库（如 `rt.jar`，包含 `java.lang.*`、`java.util.*` 等）。
2. 扩展类加载器 (Extension ClassLoader)
   * 负责加载 Java 平台扩展目录中的类库（通常在 `lib/ext` 目录下）。
3. 应用程序类加载器 (Application ClassLoader)
   * 这是我们平时接触最多的加载器，负责加载用户类路径（ClassPath）上所有的类。
4. 自定义类加载器 (Custom ClassLoader)
   * 开发者可以根据需要（比如从网络下载加密过的字节码）自己实现加载逻辑。

#### 双亲委派模型 (Parent Delegation Model)

这是 Java 设计中非常精妙的一个机制。简单来说，当一个类加载器收到加载请求时，它**不会自己先去加载**，而是把这个请求“委派”给它的父类加载器去完成，每一层都是如此。

* **为什么要这么做？** 主要是为了防止核心 API 被随意篡改。例如，如果你自己写了一个 `java.lang.String` 类，由于委派机制，最终会由最顶层的启动类加载器去加载系统自带的 String，从而保证了类型的一致性和安全性。

我们可以针对类加载器的工作细节进一步探索，我将引导你通过以下几个方向来加深理解：

1. **双亲委派的“打破”**：了解在什么特殊场景下（比如 JDBC 或 Tomcat），我们需要打破这个常规委派机制。

2. **代码实战分析**：通过简单的代码看看如何打印出一个类的加载器，直观感受它们的层次。

3. **类加载器的隔离性**：探讨为什么同一个 `.class` 文件被不同的加载器加载后，它们在 JVM 看来是“不同的类”。

#### 内存区域

##### 程序计数器

就是用来记录当前线程执行到哪一行代码了

1. 线程私有的
2. 它是JVM中唯一一个没有OOM（OutofMemory Error的区域）

##### 本地方法栈

就是线程用来调用native方法时的结构特点：

1. 线程私有
2. 调用native方法的结构

###### 为什么是线程私有？

因为 JVM 采用 **线程切换 + 时间片轮转机制**。

* 当前执行到哪条指令
* 下次恢复从哪里继续执行

因此：

````shell
线程A -----> 执行到字节码第100行
线程切换
线程B -----> 执行到字节码第50行
````

如果 PC 是共享的，就会乱套。

所以：

> 每个线程都有自己的程序计数器，用于线程恢复现场。

###### 程序计数器存的是什么？

**执行 Java 方法时**

保存：

````shell
当前字节码指令的地址
````

例如：

````shell
int a = 1;
int b = 2;
int c = a + b;
````

对应字节码类似：

````shell
0: iconst_1
1: istore_1
2: iconst_2
3: istore_2
4: iload_1
5: iload_2
6: iadd
7: istore_3
````

PC 会依次：

````shell
0 → 1 → 2 → 3 → 4 → 5 → 6 → 7
````

**执行 Native 方法时**

PC 的值为：

````shell
undefined（未定义）
````

因为 Native 方法不执行 JVM 字节码。

###### 程序计数器的作用

* 控制字节码执行流程

  JVM 的执行引擎：

  ````shell
  while(true){
      读取PC指向的指令
      执行
      修改PC
  }
  ````

​       PC 是 JVM 指令执行的“指针”。

* 支持分支、循环、跳转

  例如：

  ````shell
  if (a > b) {
      ...
  }
  ````

  字节码会包含：

  ````shell
  if_icmple 20
  ````

  如果条件成立：

  ````shell
  PC = 20
  ````

  否则：

  ````shell
  PC++
  ````

  这本质就是程序计数器控制流程跳转。

* 支持异常处理

  当抛出异常时：

  * JVM 查找异常表
  * 修改 PC 到异常处理块地址

* 支持线程切换

  线程挂起时：

  ````shell
  保存 PC
  ````

  线程恢复时：

  ````shell
  恢复 PC
  ````

  实现“从断点继续执行”。

###### 为什么它不会 OOM？

根据 **Java Virtual Machine Specification**：

> 程序计数器是唯一一个 JVM 规范中没有规定 OutOfMemoryError 的区域。

原因：

* 不存对象
* 不做动态扩展
* 只是一个固定长度指针

##### 虚拟机栈

溢出则会抛StackOverflow Error （1：可能是栈的大小设置过小（默认是1M）2:可能方法里面出现了递

归死循环；3：可能是方法里面出现了死循环在不断的创建变量）

1. 线程私有的
2. 内部是一个个的栈帧结构
3. 局部变量表存储在编译期可知的8种基本数据类型以及对象引用

###### 虚拟机栈的整体结构

一个线程对应一个栈。
 栈由多个 **栈帧（Stack Frame）** 组成。

````shell
线程
 └── JVM Stack
      ├── 栈帧（方法A）
      ├── 栈帧（方法B）
      ├── 栈帧（方法C）  ← 当前正在执行
````

每调用一个方法，就会压入一个栈帧；方法执行完毕就出栈。

###### 栈帧（Stack Frame）结构详解

每个栈帧包含以下 5 个核心部分：

**局部变量表（Local Variables）**

用于存储：

* 方法参数
* 方法内部定义的局部变量
* this（非 static 方法）

特点：

* 以 **Slot（槽）** 为单位

* 基本类型按大小占用 Slot

* `long`、`double` 占 2 个 Slot

* 其他类型占 1 个 Slot

示例：

````shell
public void test(int a) {
    int b = 10;
    long c = 100L;
}
````

局部变量表布局可能为：

| Slot | 内容 |
| ---- | ---- |
| 0    | this |
| 1    | a    |
| 2    | b    |
| 3-4  | c    |

**操作数栈（Operand Stack）**

也叫 **表达式栈**。

作用：

* 字节码指令执行时的临时计算区域
* 所有算术运算都在这里完成

示例：

````java
int c = a + b;
````

执行过程：

````shell
1. 将 a 入栈
2. 将 b 入栈
3. 执行 iadd
4. 结果出栈赋值给 c
````

JVM 是 **基于栈的执行引擎**（区别于寄存器架构）

**动态链接（Dynamic Linking）**

每个栈帧持有对 **运行时常量池** 中方法引用的符号引用。

用于支持：

- 方法调用
- 多态
- 动态分派

例如：

````java
obj.method();
````

在运行时根据对象实际类型进行方法解析（虚方法表机制）。

**方法返回地址（Return Address）**

记录当前方法结束后应返回的位置。

* 正常返回
* 异常返回（通过异常表）

**附加信息**

* 调试信息
* 方法监控信息（如 synchronized）

###### 方法调用过程

假设：

````java
main()
  └── methodA()
        └── methodB()
````

执行流程：

1. main 入栈

2. methodA 入栈

3. methodB 入栈

4. methodB 执行完成 → 出栈

5. methodA 执行完成 → 出栈

6. main 执行完成 → 出栈

遵循：

> 先进后出（LIFO）

###### 栈的两种异常

**StackOverflowError**

当递归过深导致栈帧不断压入，超过栈深度限制。

````java
public void test() {
    test();
}
````

默认栈大小：

````bash
-Xss1m
````

可调整：

````bash
-Xss512k
-Xss2m
````

**OutOfMemoryError**

当栈是动态扩展且扩展失败时会发生（较少见）。

##### 堆

1. 线程共享的
2. 存几乎所有的对象 （new出来的对象）
3. 堆分为新生代和老年代（默认比例：1:2）

###### 经典分代堆结构总览

````代码
                              Java Heap
┌──────────────────────────────────────────────────────────────┐
│                                                              │
│                     ┌───────────────┐                        │
│                     │   Young Gen   │                        │
│                     │  (新生代)      │                        │
│                     └───────────────┘                        │
│                              │                                │
│      ┌───────────────────────┼───────────────────────┐        │
│      │                       │                       │        │
│  ┌─────────┐           ┌──────────┐            ┌──────────┐  │
│  │  Eden   │           │ Survivor │            │ Survivor │  │
│  │         │           │   S0     │            │   S1     │  │
│  └─────────┘           └──────────┘            └──────────┘  │
│                                                              │
│                     ┌───────────────┐                        │
│                     │    Old Gen    │                        │
│                     │   (老年代)     │                        │
│                     └───────────────┘                        │
│                                                              │
└──────────────────────────────────────────────────────────────┘
````

###### 对象流转路径图

````代码
对象创建
   │
   ▼
Eden 区
   │  (Eden 满)
   │  触发 Minor GC
   ▼
Survivor S0  <───────┐
   │                  │
   │  复制算法        │  轮换
   ▼                  │
Survivor S1 ──────────┘
   │
   │  年龄达到阈值（默认15）
   ▼
Old Generation
   │
   │  空间不足
   ▼
Full GC
````

###### JVM 堆的整体概念

**JVM 堆（Heap）\**是 Java 虚拟机中\**最大的一块内存区域**，用于存放：

* 对象实例
* 数组
* 运行时生成的对象数据

堆是 **线程共享区域**，几乎所有对象都在这里分配（逃逸分析优化除外）。

在 HotSpot 虚拟机中，堆是 **GC（垃圾回收）的核心区域**。

###### 堆的内存结构划分

在经典的 HotSpot 实现中，堆采用 **分代模型（Generational GC）**，划分为：

````代码
Java Heap
 ├── Young Generation（新生代）
 │     ├── Eden
 │     ├── Survivor 0 (S0)
 │     └── Survivor 1 (S1)
 │
 └── Old Generation（老年代）
````

**新生代（Young Generation）**

特点：

* 存放新创建的对象
* 回收频繁
* 生命周期短

默认比例（可调）：

````代码
新生代 : 老年代 ≈ 1 : 2
````

Eden 区

* 对象默认分配在 Eden
* 发生 Minor GC 时触发回收

Survivor 区（S0 / S1）

* 两块等大小
* 用于对象“晋升前”的缓冲
* 采用复制算法

对象在 Survivor 区会记录 **年龄（Age）**
 达到阈值（默认 15）后进入老年代。

**老年代（Old Generation）**

特点：

- 存活时间长
- 对象体积较大
- GC 次数少，但耗时长

当出现以下情况进入老年代：

- 对象年龄达到阈值
- 大对象直接分配
- Survivor 空间不足

###### 对象分配流程

1. 创建一个对象时的典型流程：
2. 优先分配在 Eden
3. Eden 满 → 触发 Minor GC
4. 存活对象进入 Survivor
5. 年龄增加
6. 达到阈值 → 晋升老年代
7. 老年代满 → 触发 Full GC

##### 方法区（又叫永久代）

1. 线程共享的

2. 用于存储已被虚拟机加载的类信息（classfile里面的东西）、常量、静态变量、符号引用

   JDK1.8之前（不包括1.8）

###### 方法区在不同 JDK 版本中的实现

**JDK 1.7 及之前 —— 永久代（PermGen）**

在 JDK 1.7 及以前，方法区由 **永久代** 实现：

- 位于 **堆内存**
- 受 `-XX:PermSize` 和 `-XX:MaxPermSize` 控制
- 容易出现：

````shell
java.lang.OutOfMemoryError: PermGen space
````

**JDK 1.8 及之后 —— 元空间（Metaspace）**

从 **JDK 1.8** 开始，永久代被移除，改为：

➡ **元空间（Metaspace）**

特点：

- 使用 **本地内存（Native Memory）**
- 不再受堆大小限制
- 默认自动扩展
- 可通过参数限制：

````shell
-XX:MetaspaceSize=128m
-XX:MaxMetaspaceSize=512m
````

常见异常：

````shell
java.lang.OutOfMemoryError: Metaspace
````

###### 方法区存储内容详解

**类元数据（Class Metadata）**

包括：

- 类的全限定名
- 父类信息
- 接口信息
- 方法信息
- 字段信息
- 修饰符
- 注解

例如：

````java
public class User {
    private String name;
}
````

这些结构信息会进入方法区。

**运行时常量池（Runtime Constant Pool）**

类加载后，`.class` 文件中的常量池会被加载到方法区。

包含：

- 字面量（字符串、数字）
- 符号引用（类名、方法名）

例如：

```java
String s = "abc";
```

"abc" 属于常量池内容。

⚠ 注意：
 JDK 1.7 之后字符串常量池移动到了 **堆中**。

**静态变量**

````java
static int count = 10;
````

* 变量引用存储在方法区

* 实际对象仍在堆中

**方法字节码**

方法的：

- 字节码
- 局部变量表结构
- 操作数栈结构

也存储在方法区。

**JIT 编译代码（Code Cache）**

热点代码被 JIT 编译后，会存入代码缓存区。

###### 方法区内存结构示意图

````代码
                 JVM 内存结构
┌─────────────────────────────┐
│           堆 (Heap)          │
│  ┌───────────────┐          │
│  │  新生代        │          │
│  │  老年代        │          │
│  └───────────────┘          │
└─────────────────────────────┘

┌─────────────────────────────┐
│        方法区 (Method Area) │
│                             │
│  类元数据                    │
│  运行时常量池                │
│  静态变量                    │
│  方法字节码                  │
│  JIT Code Cache             │
└─────────────────────────────┘

┌─────────────────────────────┐
│        虚拟机栈              │
└─────────────────────────────┘

┌─────────────────────────────┐
│        本地方法栈            │
└─────────────────────────────┘

┌─────────────────────────────┐
│        程序计数器            │
└─────────────────────────────┘
````

###### 类加载与方法区的关系

类加载流程：

```
加载 -> 验证 -> 准备 -> 解析 -> 初始化
```

在这些阶段中：

- **类元数据进入方法区**
- 静态变量在准备阶段分配默认值
- 初始化阶段执行 `<clinit>`

###### 方法区的 GC 机制

方法区也会发生 GC，但较少。

主要回收：

1. 无用常量
2. 无用类

**类卸载条件（必须同时满足）**

- 该类的所有实例已被回收
- 加载该类的 ClassLoader 已被回收
- 没有任何地方再引用该 Class 对象

典型场景：

- 热部署
- OSGi
- 动态代理框架

##### JVM 如何判断对象是否为垃圾

###### 早期方式：引用计数法（已被淘汰）

原理：

- 对象每被引用一次，计数 +1
- 引用失效，计数 -1
- 计数为 0 → 认为是垃圾

缺点：

- 无法解决循环引用问题

示例：

```
A a = new A();
B b = new B();
a.b = b;
b.a = a;

a = null;
b = null;
```

a 和 b 互相引用，引用计数不为 0，但实际上已经无法访问。

因此现代 JVM 不使用这种方式。

###### 现代方式：可达性分析算法（Reachability Analysis）

当前 JVM（如 HotSpot）使用 **可达性分析算法**。

核心思想：

> 从一组“GC Roots”出发，向下搜索，如果对象不可达，则判定为垃圾。

###### 什么是 GC Roots

GC Roots 是一组“起始引用”，包括：

1. 虚拟机栈中的局部变量
2. 方法区中的静态变量
3. 方法区中的常量引用
4. JNI 引用
5. 活跃线程对象
6. 类加载器

###### 判断过程示意

```代码
GC Root
   │
   ▼
  Object A
     │
     ▼
  Object B

Object C （没有任何引用）
```

- A、B：可达 → 存活
- C：不可达 → 垃圾

###### 对象被判定为垃圾的完整流程

对象不会立刻被回收，会经历两个阶段：

**第一阶段：可达性分析**

不可达 → 标记为“可回收对象”

------

**第二阶段：是否需要执行 finalize()**

如果对象重写了：

```
protected void finalize()
```

JVM 会：

1. 将对象放入 F-Queue
2. 由 Finalizer 线程执行 finalize()
3. 若在 finalize 中重新建立引用 → 对象复活
4. 否则 → 下次 GC 真正回收

注意：

- finalize 只会执行一次
- 已被废弃（Java 9 标记 deprecated）

###### 代码层面如何“间接判断”

Java 代码中无法直接判断对象是否是垃圾，但可以借助以下方式观察：

------

**1️⃣ 使用 WeakReference**

```
Object obj = new Object();
WeakReference<Object> ref = new WeakReference<>(obj);

obj = null;
System.gc();

if (ref.get() == null) {
    System.out.println("对象已被回收");
}
```

原理：

- 弱引用对象只要发生 GC 就会被回收

**使用 PhantomReference（更底层）**

用于资源回收跟踪，常见于框架层面。

###### 不同引用类型与垃圾判断

Java 有四种引用类型：

| 引用类型 | 是否会被回收   |
| -------- | -------------- |
| 强引用   | 不会           |
| 软引用   | 内存不足时回收 |
| 弱引用   | 只要 GC 就回收 |
| 虚引用   | 必然被回收     |

##### 基础垃圾收集算法

###### 标记-清除算法（Mark-Sweep）

**原理**

1. **标记阶段**：从 GC Roots 出发，标记所有可达对象
2. **清除阶段**：回收未被标记的对象

**优点**

- 实现简单
- 不需要移动对象

**缺点**

- 会产生**内存碎片**
- 清除效率不高

**示意**

```代码
[存活][垃圾][存活][垃圾][存活]
清除后：
[存活][   ][存活][   ][存活]  ← 碎片
```

###### 复制算法（Copying）

**原理**

- 将内存划分为两块
- 每次只使用其中一块
- 存活对象复制到另一块
- 一次性清空原区域

**优点**

- 无碎片
- 分配简单（指针碰撞）

**缺点**

- 内存利用率低（50%）

**适用场景**

- 新生代（对象朝生夕死）

###### 标记-整理算法（Mark-Compact）

**原理**

- 先标记
- 再将存活对象向一端移动
- 清理边界外内存

**优点**

- 无碎片
- 不浪费内存

**缺点**

- 需要移动对象（Stop The World 时间更长）

**适用场景**

- 老年代

##### 分代收集思想（Generational GC）

JVM 基于“对象大多朝生夕死”这一经验法则设计。

###### 内存结构

```
        ┌─────────────┐
        │   新生代     │
        │ Eden         │
        │ S0 / S1      │
        ├─────────────┤
        │   老年代     │
        └─────────────┘
```

###### 新生代（Young Generation）

- 采用 **复制算法**
- Minor GC 频繁
- 对象存活率低

流程：

```
Eden 满 → Minor GC
存活对象 → Survivor
多次存活 → 晋升老年代
```

###### 老年代（Old Generation）

* 对象存活率高

* Major GC 次数少但耗时长

* 使用 标记清除 或 标记整理

###### Full GC

触发条件：

- 老年代空间不足
- 元空间不足
- System.gc()
- 大对象分配失败

###### Serial GC

- 单线程
- Stop The World
- 适合小内存场景

```
-XX:+UseSerialGC
```

###### Parallel GC（吞吐量优先）

- 多线程
- 追求高吞吐
- 适合后台计算

```
-XX:+UseParallelGC
```

###### CMS（Concurrent Mark Sweep）

- 低停顿
- 并发标记
- 基于标记清除
- 有碎片问题

已在 JDK 14 移除





###### G1（Garbage First）

JDK 9 以后默认

**特点**

- 基于 Region
- 可预测停顿时间
- 混合回收
- 局部压缩

```
-XX:+UseG1GC
```

适合大内存（8G+）

**Region 分区模型**

G1 将整个堆划分为若干大小相等的 **Region**（1MB ~ 32MB，2 的幂次方）。

堆结构逻辑如下：

```
+------------------------------------------------+
| R | R | R | R | R | R | R | R | R | R | R | R |
+------------------------------------------------+
```

每个 Region 在逻辑上可以是：

- Eden
- Survivor
- Old
- Humongous（大对象专用）

⚠ 不再是物理连续的新生代/老年代，而是逻辑分代。

**Garbage First 原则**

G1 每次回收时，会：

> 优先回收“垃圾最多”的 Region

通过维护每个 Region 的 **回收收益预测模型**，优先选择“性价比最高”的 Region。

这就是 “Garbage First” 的来源。

**G1 的整体回收流程**

G1 回收过程分为：

```代码
Young GC  →  Mixed GC  →  Full GC（极端情况）
```

**Young GC（年轻代回收）**

触发条件：

- Eden 区满

执行流程：

1. STW（Stop-The-World）
2. 多线程复制存活对象到 Survivor 或 Old
3. 清理 Eden

特点：

- 并行执行
- 停顿时间可控
- 不涉及老年代标记

**Mixed GC（混合回收）——G1 的核心**

当老年代占用达到阈值（默认 45%）时：

G1 会启动：

1️⃣ 并发标记（Concurrent Marking）

基于 **三色标记法**：

- 白色：未访问
- 灰色：已访问未扫描
- 黑色：已扫描完成

过程：

```
初始标记（STW）
并发标记（并发执行）
重新标记（STW）
清理阶段（并发）
```

**三色标记 + SATB**

G1 使用的是：

> SATB（Snapshot At The Beginning）算法

核心思想：

- 认为“开始标记时”存活的对象是存活的
- 即使中途引用断开，也当做活对象处理

优点：

- 不会漏标
- 减少重新扫描

缺点：

- 可能产生浮动垃圾（Floating Garbage）

**G1 关键技术点**

1️⃣ Remembered Set（RSet）

解决问题：

> 跨 Region 引用怎么处理？

每个 Region 都维护一个 RSet：

```
记录：谁引用了我
```

这样回收某个 Region 时：

- 只需扫描它的 RSet
- 不必扫描整个堆

代价：

- 维护 RSet 有一定内存和写屏障成本

------

2️⃣ 写屏障（Write Barrier）

G1 使用：

- SATB 写屏障
- RSet 写屏障

用于：

- 记录引用变化
- 保证三色标记正确

------

 3️⃣ Humongous Object

大对象（超过 Region 一半）：

- 直接分配多个连续 Region
- 归入 Humongous 区
- 不参与普通复制

缺点：

- 容易导致 Full GC

优化建议：

- 避免频繁创建大对象
- 合理设置 RegionSize



###### ZGC（低延迟）

- 亚毫秒级停顿
- 并发标记 + 并发整理
- 基于读屏障
- 适合超大内存

```
-XX:+UseZGC
```

适合：

- 金融交易
- 实时系统



**ZGC 内存结构（Region）**

ZGC 采用 **Region 化堆结构**（类似 G1）。

堆被分为多个 **ZPage**（Region）。

```
ZHeap
 ├── ZPage (Small)
 ├── ZPage (Medium)
 └── ZPage (Large)
```

Region 类型：

| 类型   | 大小    |
| ------ | ------- |
| Small  | 2MB     |
| Medium | 32MB    |
| Large  | >=256MB |

对象根据大小进入不同 ZPage。

例如：

```
小对象   → Small Page
中对象   → Medium Page
大对象   → Large Page
```

这样可以：

- 减少碎片
- 提高内存利用率

**Colored Pointer（彩色指针）**

ZGC 最核心技术就是 **Colored Pointer**。

在 **64 位指针的高位存储 GC 状态信息**。

普通 JVM 指针：

```
[ 64bit address ]
```

ZGC 指针：

```
| Mark0 | Mark1 | Remap | Finalizable |  Address |
```

示意：

```
64bit pointer

|4bit metadata|60bit address|
```

指针携带信息：

| 标志位      | 作用           |
| ----------- | -------------- |
| Mark0       | 标记阶段       |
| Mark1       | 第二标记       |
| Remap       | 是否需要重映射 |
| Finalizable | 是否 finalize  |

**意义**

GC 不需要额外存储结构
 **对象状态直接在指针中表示**

**Load Barrier（读屏障）**

ZGC 使用 **读屏障（Load Barrier）**。

每次读取对象引用都会触发：

```
obj = obj.field
```

实际上会变成：

```
obj = load_barrier(obj.field)
```

伪代码：

```
Object loadBarrier(Object ref){
    if(pointerColorInvalid){
        fixPointer(ref)
    }
    return ref
}
```

作用：

1️⃣ 检查对象是否已移动
2️⃣ 修复指针
3️⃣ 保证并发 GC 正确性

**ZGC GC 执行流程**

ZGC 的 GC 周期主要包括 **5 个阶段**：

```
Pause Mark Start (STW)
        ↓
Concurrent Mark
        ↓
Pause Mark End (STW)
        ↓
Concurrent Relocate
        ↓
Concurrent Remap
```

详细流程：

------

 1 初始标记（STW）

暂停时间：

```
< 1ms
```

操作：

- 标记 GC Roots
- 开始对象可达性分析

------

 2 并发标记（Concurrent Mark）

与业务线程 **并发执行**

```
GC Thread
    ↓
扫描对象图
    ↓
标记存活对象
```

此阶段：

- 业务线程仍在运行
- 对象仍在分配

------

 3 重新标记（STW）

暂停时间：

```
< 2ms
```

作用：

修正并发标记期间变化的引用。

------

 4 并发移动（Concurrent Relocate）

ZGC **并发整理内存**。

```
Old Object
   ↓
Copy
   ↓
New Object
```

但关键点是：

**对象移动时应用线程仍在运行**

传统 GC 不敢这么做。

ZGC 依赖：

```
Colored Pointer + Load Barrier
```

自动修复引用。

------

 5 并发重映射（Concurrent Remap）

当对象被移动后：

旧引用：

```
old pointer
```

需要变成：

```
new pointer
```

读屏障会自动修复：

```
old → new
```

#####  吞吐量和最短停顿时间

###### 吞吐量（Throughput）

1. 概念

**吞吐量 = 应用程序运行时间 / （应用程序运行时间 + GC 时间）**

公式：

```
Throughput = Application Time / (Application Time + GC Time)
```

例如：

```
程序运行 100 秒
GC 停顿 1 秒

吞吐量 = 100 / (100 + 1) ≈ 99%
```

含义：

- **吞吐量越高，CPU 越多时间在执行业务代码**
- GC 占用时间越少

2. 吞吐量优先的 GC 特点

特点：

- **GC 可以暂停更久**
- 但 GC 次数更少
- 总体 GC 时间占比更低

典型收集器：

- **Parallel Garbage Collector（Parallel GC）**

JVM 参数示例：

```
-XX:+UseParallelGC
```

特点：

| 特性     | 描述   |
| -------- | ------ |
| GC线程   | 多线程 |
| 停顿时间 | 较长   |
| 吞吐量   | 非常高 |

适合：

- 批处理
- 大数据计算
- 离线任务

例如：

```
Hadoop
Spark
ETL任务
```

###### 最短停顿时间（Pause Time / Latency）

1. 概念

**停顿时间（Pause Time）** 指的是：

```
GC 期间 JVM Stop-The-World 的时间
```

即：

```
所有业务线程暂停
```

例如：

```
一次 GC 暂停 200ms
```

对于用户来说：

```
请求卡顿 200ms
```

如果是实时系统：

```
非常严重
```

2. 低停顿 GC 特点

特点：

- **STW 时间极短**
- GC 与应用线程并发执行
- 但 CPU 开销更高

典型收集器：

- **Z Garbage Collector**
- **Shenandoah Garbage Collector**
- **Garbage-First Garbage Collector**

例如：

ZGC：

```
暂停时间 < 10ms
```

###### 吞吐量 vs 最短停顿时间

二者通常是 **权衡关系（Trade-off）**。

| 指标     | 目标         | 特点        |
| -------- | ------------ | ----------- |
| 吞吐量   | CPU 最大利用 | 允许长停顿  |
| 最短停顿 | 延迟最小     | CPU开销更高 |

示例：

**方案 A（吞吐量优先）**

```
GC 每 10 秒执行一次
停顿 500ms
```

吞吐量高
 但用户会卡顿

------

**方案 B（低延迟）**

```
GC 每 1 秒执行一次
停顿 5ms
```

用户无感知
 但 GC CPU 开销更高

###### 不同 GC 的侧重点

| GC          | 吞吐量   | 停顿时间 | 特点       |
| ----------- | -------- | -------- | ---------- |
| Serial GC   | 低       | 高       | 单线程     |
| Parallel GC | **最高** | 较高     | 吞吐量优先 |
| CMS         | 中       | 较低     | 并发回收   |
| G1          | 高       | 较低     | 平衡型     |
| ZGC         | 中       | **极低** | 毫秒级     |
| Shenandoah  | 中       | **极低** | 并发压缩   |