# JVM Memory Structure (内存结构)

## 一、运行时数据区域

Java 虚拟机在执行 Java 程序的过程中会把它所管理的内存划分为若干个不同的数据区域。

![JVM Runtime Data Areas](https://img-blog.csdnimg.cn/20210508160530752.png)

### 1. 程序计数器 (Program Counter Register)
- **作用**：当前线程所执行的字节码的行号指示器。
- **特点**：
    - **线程私有**：每个线程都有独立的程序计数器。
    - **唯一不会 OOM**：Java 虚拟机规范中唯一没有规定 `OutOfMemoryError` 情况的区域。
    - 如果执行的是 Native 方法，计数器值为空 (Undefined)。

### 2. Java 虚拟机栈 (Java Virtual Machine Stacks)
- **作用**：描述 Java 方法执行的内存模型。每个方法在执行的同时都会创建一个 **栈帧 (Stack Frame)**。
- **栈帧包含**：
    - **局部变量表**：存放编译期可知的各种基本数据类型、对象引用。
    - **操作数栈**：用于计算过程中的临时存储。
    - **动态链接**：指向运行时常量池的方法引用。
    - **方法出口**：方法返回地址。
- **异常**：
    - `StackOverflowError`：线程请求的栈深度大于虚拟机允许的深度（如无限递归）。
    - `OutOfMemoryError`：如果栈可以动态扩展，扩展时无法申请到足够的内存。

### 3. 本地方法栈 (Native Method Stack)
- **作用**：与虚拟机栈类似，不过它是为虚拟机使用到的 **Native** 方法服务。
- **异常**：同样会抛出 `StackOverflowError` 和 `OutOfMemoryError`。

### 4. Java 堆 (Java Heap)
- **作用**：存放对象实例。是垃圾收集器管理的主要区域 ("GC 堆")。
- **特点**：
    - **线程共享**：所有线程共享同一块堆内存。
    - **最大的一块内存**：虚拟机启动时创建。
- **结构**（分代收集算法）：
    - **新生代 (Young Generation)**：
        - Eden 区
        - Survivor 区 (S0, S1)
    - **老年代 (Old Generation)**
- **异常**：`OutOfMemoryError: Java heap space` (堆内存不足)。

### 5. 方法区 (Method Area)
- **作用**：存储已被虚拟机加载的 **类信息、常量、静态变量、即时编译器编译后的代码** 等数据。
- **演变**：
    - **JDK 1.7 及之前**：实现为 **永久代 (PermGen)**。
    - **JDK 1.8 及之后**：实现为 **元空间 (Metaspace)**，使用本地内存。
- **异常**：`OutOfMemoryError: Metaspace` (元空间溢出) 或 `PermGen space` (永久代溢出)。

### 6. 运行时常量池 (Runtime Constant Pool)
- 是方法区的一部分。
- 用于存放编译期生成的各种字面量和符号引用。
- 具备动态性，运行期间也可以将新的常量放入池中（如 `String.intern()`）。

### 7. 直接内存 (Direct Memory)
- 不是虚拟机运行时数据区的一部分，也不是 Java 虚拟机规范中定义的内存区域。
- NIO (New Input/Output) 类引入了一种基于通道 (Channel) 和缓冲区 (Buffer) 的 I/O 方式，可以使用 Native 函数库直接分配堆外内存。
- 避免了在 Java 堆和 Native 堆中来回复制数据，提高性能。
- **异常**：`OutOfMemoryError: Direct buffer memory`。

## 二、常用字节码指令简介

- **加载与存储指令**：`iload`, `istore`, `ldc`, `bipush`
- **运算指令**：`iadd`, `isub`, `imul`, `idiv`
- **类型转换指令**：`i2l`, `i2f`, `d2i`
- **对象创建与访问指令**：`new`, `getfield`, `putfield`, `invokevirtual`
- **操作数栈管理指令**：`pop`, `dup`, `swap`
- **控制转移指令**：`ifeq`, `goto`, `tableswitch`
- **方法调用和返回指令**：`invokevirtual`, `invokespecial`, `invokestatic`, `return`
