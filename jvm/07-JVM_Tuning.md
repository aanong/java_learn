# JVM Tuning (JVM 调优)

JVM 调优是一个复杂的过程，通常遵循 "发现问题 -> 分析问题 -> 解决问题 -> 验证问题" 的循环。

## 一、调优的一般步骤

1.  **监控与报警**
    - 建立完善的监控体系（Prometheus + Grafana, Zabbix 等）。
    - 关注核心指标：CPU 使用率、内存使用率、GC 频率、GC 停顿时间、接口响应时间。

2.  **发现问题**
    - **频繁 Full GC**：导致系统停顿时间过长，响应慢。
    - **内存溢出 (OOM)**：堆溢出、元空间溢出、栈溢出。
    - **CPU 飙高**：死循环、频繁 GC。
    - **内存泄漏**：内存占用持续上升，无法回收。

3.  **分析问题 (定位原因)**
    - **使用工具**：jstat, jmap, jstack, MAT (Memory Analyzer Tool), VisualVM。
    - **分析 GC 日志**：查看 GC 原因、频率、耗时。
    - **分析 Dump 文件**：查找大对象、内存泄漏点。

4.  **解决问题 (调优手段)**
    - **优化代码**：修复内存泄漏、减少不必要的对象创建、优化算法。
    - **调整 JVM 参数**：
        - 调整堆大小 (`-Xms`, `-Xmx`)。
        - 调整新生代/老年代比例 (`-XX:NewRatio`, `-XX:SurvivorRatio`)。
        - 选择合适的垃圾收集器。
        - 调整大对象阈值 (`-XX:PretenureSizeThreshold`)。
        - 调整晋升老年代阈值 (`-XX:MaxTenuringThreshold`)。
    - **升级硬件**：增加内存、CPU。

5.  **验证问题**
    - 观察调整后的指标是否改善。
    - 进行压力测试。

## 二、常见生产案例

### 案例 1：CPU 占用过高 (100%)
**排查步骤**：
1.  `top` 命令找出 CPU 占用最高的进程 PID。
2.  `top -Hp <pid>` 找出该进程下 CPU 占用最高的线程 TID。
3.  将 TID 转换为 16 进制：`printf "%x\n" <tid>` -> `nid`。
4.  `jstack <pid> | grep <nid> -A 20` 查看该线程的堆栈信息。
5.  **分析**：
    - 如果是 `VM Thread`，可能是频繁 GC。
    - 如果是业务线程，查看代码是否有死循环或复杂计算。

### 案例 2：内存泄漏 (OOM)
**现象**：程序运行一段时间后抛出 `java.lang.OutOfMemoryError: Java heap space`，重启后暂时恢复，一段时间后复现。
**排查步骤**：
1.  `jmap -dump:format=b,file=heap.hprof <pid>` 导出堆转储文件 (建议开启 `-XX:+HeapDumpOnOutOfMemoryError`)。
2.  使用 **MAT** 或 **VisualVM** 打开 hprof 文件。
3.  查看 **Histogram** (直方图)，按 Retained Heap (深堆) 排序，找出占用内存最大的对象。
4.  查看 **Dominator Tree** (支配树)。
5.  分析对象的 **GC Roots** 引用链，找到是谁在引用它导致无法回收。
6.  **常见原因**：
    - 静态集合类 (Map, List) 只增不减。
    - 未关闭的资源 (Connection, IO)。
    - ThreadLocal 未 remove。

### 案例 3：频繁 Full GC
**原因分析**：
1.  **元空间不足**：类加载过多。 -> 调大 `-XX:MetaspaceSize`。
2.  **老年代空间不足**：
    - 大对象直接进入老年代。 -> 调大 `-XX:PretenureSizeThreshold` 或优化代码。
    - 长期存活的对象进入老年代。
    - 动态对象年龄判定机制导致。 -> 调整 Survivor 区大小。
3.  **System.gc() 被显式调用**。 -> 使用 `-XX:+DisableExplicitGC` 禁用。

## 三、调优建议

1.  **优先优化代码**：代码逻辑问题是性能问题的根本。
2.  **不要过度调优**：JVM 默认配置通常已经足够好，除非有明确的性能瓶颈。
3.  **测试环境验证**：任何参数调整必须在测试环境经过充分压测。
4.  **保持简单**：参数越少越好，越通用越好。
