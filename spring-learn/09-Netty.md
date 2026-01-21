# Netty 网络编程详解

## 一、网络基础

### 1.1 OSI七层模型与TCP/IP四层模型

```
OSI七层模型              TCP/IP四层模型
┌─────────────┐         ┌─────────────┐
│   应用层    │         │             │
├─────────────┤         │   应用层    │
│   表示层    │         │             │
├─────────────┤         ├─────────────┤
│   会话层    │         │             │
├─────────────┤         │   传输层    │
│   传输层    │         │  (TCP/UDP)  │
├─────────────┤         ├─────────────┤
│   网络层    │         │   网络层    │
├─────────────┤         │    (IP)     │
│ 数据链路层  │         ├─────────────┤
├─────────────┤         │ 网络接口层  │
│   物理层    │         │             │
└─────────────┘         └─────────────┘
```

### 1.2 TCP与UDP对比

| 特性 | TCP | UDP |
|------|-----|-----|
| 连接 | 面向连接 | 无连接 |
| 可靠性 | 可靠传输 | 不可靠传输 |
| 顺序 | 保证顺序 | 不保证顺序 |
| 速度 | 较慢 | 较快 |
| 头部开销 | 20字节 | 8字节 |
| 应用场景 | HTTP、FTP、SMTP | DNS、视频流、游戏 |

### 1.3 TCP三次握手与四次挥手

```
三次握手：
Client                          Server
  │                               │
  │─────── SYN(seq=x) ──────────>│
  │                               │
  │<──── SYN+ACK(seq=y,ack=x+1) ──│
  │                               │
  │─────── ACK(ack=y+1) ────────>│
  │                               │
  │         连接建立              │

四次挥手：
Client                          Server
  │                               │
  │─────── FIN(seq=u) ──────────>│
  │                               │
  │<──── ACK(ack=u+1) ────────────│
  │                               │
  │<──── FIN(seq=v) ──────────────│
  │                               │
  │─────── ACK(ack=v+1) ────────>│
  │                               │
  │         连接关闭              │
```

---

## 二、IO模型演进

### 2.1 BIO（Blocking I/O）

同步阻塞IO，每个连接需要一个独立线程处理。

```java
public class BIOServer {
    public static void main(String[] args) throws IOException {
        ServerSocket serverSocket = new ServerSocket(8080);
        System.out.println("BIO Server started on port 8080");
        
        while (true) {
            // 阻塞等待客户端连接
            Socket socket = serverSocket.accept();
            System.out.println("Client connected: " + socket.getRemoteSocketAddress());
            
            // 每个连接启动一个线程处理
            new Thread(() -> {
                try {
                    handleClient(socket);
                } catch (IOException e) {
                    e.printStackTrace();
                }
            }).start();
        }
    }
    
    private static void handleClient(Socket socket) throws IOException {
        try (BufferedReader reader = new BufferedReader(
                new InputStreamReader(socket.getInputStream()));
             PrintWriter writer = new PrintWriter(socket.getOutputStream(), true)) {
            
            String line;
            while ((line = reader.readLine()) != null) {
                System.out.println("Received: " + line);
                writer.println("Echo: " + line);
            }
        } finally {
            socket.close();
        }
    }
}
```

**BIO的问题**：
- 每个连接占用一个线程，线程资源有限
- 线程上下文切换开销大
- 无法支持高并发场景

### 2.2 NIO（Non-blocking I/O）

同步非阻塞IO，基于Channel、Buffer、Selector实现多路复用。

```java
public class NIOServer {
    public static void main(String[] args) throws IOException {
        // 创建ServerSocketChannel
        ServerSocketChannel serverChannel = ServerSocketChannel.open();
        serverChannel.configureBlocking(false);
        serverChannel.bind(new InetSocketAddress(8080));
        
        // 创建Selector
        Selector selector = Selector.open();
        serverChannel.register(selector, SelectionKey.OP_ACCEPT);
        
        System.out.println("NIO Server started on port 8080");
        
        while (true) {
            // 阻塞等待事件
            selector.select();
            
            Iterator<SelectionKey> iterator = selector.selectedKeys().iterator();
            while (iterator.hasNext()) {
                SelectionKey key = iterator.next();
                iterator.remove();
                
                if (key.isAcceptable()) {
                    handleAccept(key, selector);
                } else if (key.isReadable()) {
                    handleRead(key);
                }
            }
        }
    }
    
    private static void handleAccept(SelectionKey key, Selector selector) throws IOException {
        ServerSocketChannel serverChannel = (ServerSocketChannel) key.channel();
        SocketChannel clientChannel = serverChannel.accept();
        clientChannel.configureBlocking(false);
        clientChannel.register(selector, SelectionKey.OP_READ);
        System.out.println("Client connected: " + clientChannel.getRemoteAddress());
    }
    
    private static void handleRead(SelectionKey key) throws IOException {
        SocketChannel clientChannel = (SocketChannel) key.channel();
        ByteBuffer buffer = ByteBuffer.allocate(1024);
        
        int bytesRead = clientChannel.read(buffer);
        if (bytesRead > 0) {
            buffer.flip();
            String message = new String(buffer.array(), 0, bytesRead);
            System.out.println("Received: " + message);
            
            // 写回响应
            buffer.clear();
            buffer.put(("Echo: " + message).getBytes());
            buffer.flip();
            clientChannel.write(buffer);
        } else if (bytesRead == -1) {
            clientChannel.close();
        }
    }
}
```

### 2.3 NIO核心组件

#### Channel（通道）

```java
// 常用Channel类型
ServerSocketChannel  // 服务端TCP
SocketChannel        // 客户端TCP
DatagramChannel      // UDP
FileChannel          // 文件IO
```

#### Buffer（缓冲区）

```java
// Buffer核心属性
// position: 当前读写位置
// limit: 读写上限
// capacity: 容量

ByteBuffer buffer = ByteBuffer.allocate(1024);

// 写模式
buffer.put("Hello".getBytes());

// 切换到读模式
buffer.flip();  // position=0, limit=之前的position

// 读取数据
byte[] data = new byte[buffer.remaining()];
buffer.get(data);

// 清空缓冲区
buffer.clear();  // position=0, limit=capacity
```

#### Selector（选择器）

```java
// 创建Selector
Selector selector = Selector.open();

// 注册Channel到Selector
channel.register(selector, SelectionKey.OP_READ);

// SelectionKey事件类型
SelectionKey.OP_ACCEPT   // 接受连接
SelectionKey.OP_CONNECT  // 连接就绪
SelectionKey.OP_READ     // 读就绪
SelectionKey.OP_WRITE    // 写就绪
```

### 2.4 AIO（Asynchronous I/O）

异步非阻塞IO，基于回调机制。

```java
public class AIOServer {
    public static void main(String[] args) throws Exception {
        AsynchronousServerSocketChannel serverChannel = 
            AsynchronousServerSocketChannel.open();
        serverChannel.bind(new InetSocketAddress(8080));
        
        System.out.println("AIO Server started on port 8080");
        
        serverChannel.accept(null, new CompletionHandler<AsynchronousSocketChannel, Object>() {
            @Override
            public void completed(AsynchronousSocketChannel clientChannel, Object attachment) {
                // 继续接受下一个连接
                serverChannel.accept(null, this);
                
                // 处理当前连接
                ByteBuffer buffer = ByteBuffer.allocate(1024);
                clientChannel.read(buffer, buffer, new CompletionHandler<Integer, ByteBuffer>() {
                    @Override
                    public void completed(Integer result, ByteBuffer buffer) {
                        buffer.flip();
                        String message = new String(buffer.array(), 0, result);
                        System.out.println("Received: " + message);
                    }
                    
                    @Override
                    public void failed(Throwable exc, ByteBuffer attachment) {
                        exc.printStackTrace();
                    }
                });
            }
            
            @Override
            public void failed(Throwable exc, Object attachment) {
                exc.printStackTrace();
            }
        });
        
        // 防止主线程退出
        Thread.sleep(Long.MAX_VALUE);
    }
}
```

---

## 三、Netty核心概念

### 3.1 什么是Netty

Netty是一个异步事件驱动的网络应用框架，用于快速开发可维护的高性能协议服务器和客户端。

**核心优势**：
- 统一的API，支持多种传输类型
- 高性能、高吞吐量
- 零拷贝技术
- 完善的编解码支持
- 灵活的线程模型

### 3.2 Netty核心组件

```
┌─────────────────────────────────────────────────────────────┐
│                        Netty架构                            │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │   Channel   │  │  EventLoop  │  │  Pipeline   │         │
│  └─────────────┘  └─────────────┘  └─────────────┘         │
│         │                │                │                 │
│         ▼                ▼                ▼                 │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │ ChannelFuture│ │EventLoopGroup│ │ChannelHandler│        │
│  └─────────────┘  └─────────────┘  └─────────────┘         │
│                                                             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │  Bootstrap  │  │   ByteBuf   │  │   Codec     │         │
│  └─────────────┘  └─────────────┘  └─────────────┘         │
└─────────────────────────────────────────────────────────────┘
```

#### Channel

Channel是Netty网络通信的组件，代表一个连接。

```java
// 常用Channel类型
NioServerSocketChannel  // NIO服务端TCP
NioSocketChannel        // NIO客户端TCP
NioDatagramChannel      // NIO UDP
EpollServerSocketChannel // Linux Epoll
```

#### EventLoop与EventLoopGroup

EventLoop是事件循环，负责处理Channel上的所有I/O操作。

```java
// 线程模型
EventLoopGroup bossGroup = new NioEventLoopGroup(1);    // 接受连接
EventLoopGroup workerGroup = new NioEventLoopGroup();    // 处理IO

// 一个EventLoop可以处理多个Channel
// 一个Channel只绑定一个EventLoop
```

#### ChannelPipeline与ChannelHandler

Pipeline是责任链模式，Handler是处理器。

```java
// Handler类型
ChannelInboundHandler   // 入站处理（读取数据）
ChannelOutboundHandler  // 出站处理（写入数据）

// Pipeline结构
┌──────────────────────────────────────────────────┐
│                  ChannelPipeline                  │
├──────────────────────────────────────────────────┤
│ Head ←→ Handler1 ←→ Handler2 ←→ Handler3 ←→ Tail │
│                                                   │
│ Inbound:  Head → Handler1 → Handler2 → Handler3  │
│ Outbound: Handler3 → Handler2 → Handler1 → Head  │
└──────────────────────────────────────────────────┘
```

---

## 四、Netty实战案例

### 4.1 Echo服务器

```java
public class EchoServer {
    private final int port;
    
    public EchoServer(int port) {
        this.port = port;
    }
    
    public void start() throws InterruptedException {
        EventLoopGroup bossGroup = new NioEventLoopGroup(1);
        EventLoopGroup workerGroup = new NioEventLoopGroup();
        
        try {
            ServerBootstrap bootstrap = new ServerBootstrap();
            bootstrap.group(bossGroup, workerGroup)
                    .channel(NioServerSocketChannel.class)
                    .option(ChannelOption.SO_BACKLOG, 128)
                    .childOption(ChannelOption.SO_KEEPALIVE, true)
                    .childHandler(new ChannelInitializer<SocketChannel>() {
                        @Override
                        protected void initChannel(SocketChannel ch) {
                            ChannelPipeline pipeline = ch.pipeline();
                            // 添加编解码器
                            pipeline.addLast(new StringDecoder());
                            pipeline.addLast(new StringEncoder());
                            // 添加业务处理器
                            pipeline.addLast(new EchoServerHandler());
                        }
                    });
            
            // 绑定端口，同步等待成功
            ChannelFuture future = bootstrap.bind(port).sync();
            System.out.println("Echo Server started on port " + port);
            
            // 等待服务端监听端口关闭
            future.channel().closeFuture().sync();
        } finally {
            bossGroup.shutdownGracefully();
            workerGroup.shutdownGracefully();
        }
    }
    
    public static void main(String[] args) throws InterruptedException {
        new EchoServer(8080).start();
    }
}

public class EchoServerHandler extends SimpleChannelInboundHandler<String> {
    
    @Override
    public void channelActive(ChannelHandlerContext ctx) {
        System.out.println("Client connected: " + ctx.channel().remoteAddress());
    }
    
    @Override
    protected void channelRead0(ChannelHandlerContext ctx, String msg) {
        System.out.println("Received: " + msg);
        ctx.writeAndFlush("Echo: " + msg);
    }
    
    @Override
    public void channelInactive(ChannelHandlerContext ctx) {
        System.out.println("Client disconnected: " + ctx.channel().remoteAddress());
    }
    
    @Override
    public void exceptionCaught(ChannelHandlerContext ctx, Throwable cause) {
        cause.printStackTrace();
        ctx.close();
    }
}
```

### 4.2 Echo客户端

```java
public class EchoClient {
    private final String host;
    private final int port;
    
    public EchoClient(String host, int port) {
        this.host = host;
        this.port = port;
    }
    
    public void start() throws InterruptedException {
        EventLoopGroup group = new NioEventLoopGroup();
        
        try {
            Bootstrap bootstrap = new Bootstrap();
            bootstrap.group(group)
                    .channel(NioSocketChannel.class)
                    .option(ChannelOption.TCP_NODELAY, true)
                    .handler(new ChannelInitializer<SocketChannel>() {
                        @Override
                        protected void initChannel(SocketChannel ch) {
                            ChannelPipeline pipeline = ch.pipeline();
                            pipeline.addLast(new StringDecoder());
                            pipeline.addLast(new StringEncoder());
                            pipeline.addLast(new EchoClientHandler());
                        }
                    });
            
            // 连接服务器
            ChannelFuture future = bootstrap.connect(host, port).sync();
            System.out.println("Connected to server: " + host + ":" + port);
            
            // 发送消息
            Channel channel = future.channel();
            channel.writeAndFlush("Hello Netty!");
            
            // 等待连接关闭
            channel.closeFuture().sync();
        } finally {
            group.shutdownGracefully();
        }
    }
    
    public static void main(String[] args) throws InterruptedException {
        new EchoClient("localhost", 8080).start();
    }
}

public class EchoClientHandler extends SimpleChannelInboundHandler<String> {
    
    @Override
    protected void channelRead0(ChannelHandlerContext ctx, String msg) {
        System.out.println("Server response: " + msg);
    }
    
    @Override
    public void exceptionCaught(ChannelHandlerContext ctx, Throwable cause) {
        cause.printStackTrace();
        ctx.close();
    }
}
```

### 4.3 自定义协议

```java
/**
 * 自定义协议格式
 * +--------+--------+--------+
 * | Length |  Type  |  Body  |
 * | 4 bytes| 1 byte | N bytes|
 * +--------+--------+--------+
 */
public class CustomMessage {
    private int length;      // 消息长度
    private byte type;       // 消息类型
    private String body;     // 消息体
    
    // 消息类型常量
    public static final byte TYPE_REQUEST = 1;
    public static final byte TYPE_RESPONSE = 2;
    public static final byte TYPE_HEARTBEAT = 3;
    
    // getters and setters...
}

// 编码器
public class CustomMessageEncoder extends MessageToByteEncoder<CustomMessage> {
    
    @Override
    protected void encode(ChannelHandlerContext ctx, CustomMessage msg, ByteBuf out) {
        byte[] bodyBytes = msg.getBody().getBytes(StandardCharsets.UTF_8);
        
        out.writeInt(bodyBytes.length + 1);  // Length (body + type)
        out.writeByte(msg.getType());         // Type
        out.writeBytes(bodyBytes);            // Body
    }
}

// 解码器
public class CustomMessageDecoder extends ByteToMessageDecoder {
    
    @Override
    protected void decode(ChannelHandlerContext ctx, ByteBuf in, List<Object> out) {
        // 检查是否有足够的数据读取长度字段
        if (in.readableBytes() < 4) {
            return;
        }
        
        in.markReaderIndex();
        int length = in.readInt();
        
        // 检查是否有足够的数据读取完整消息
        if (in.readableBytes() < length) {
            in.resetReaderIndex();
            return;
        }
        
        byte type = in.readByte();
        byte[] bodyBytes = new byte[length - 1];
        in.readBytes(bodyBytes);
        
        CustomMessage message = new CustomMessage();
        message.setLength(length);
        message.setType(type);
        message.setBody(new String(bodyBytes, StandardCharsets.UTF_8));
        
        out.add(message);
    }
}
```

### 4.4 心跳机制

```java
public class HeartbeatServerHandler extends ChannelInboundHandlerAdapter {
    
    @Override
    public void userEventTriggered(ChannelHandlerContext ctx, Object evt) throws Exception {
        if (evt instanceof IdleStateEvent) {
            IdleStateEvent event = (IdleStateEvent) evt;
            
            switch (event.state()) {
                case READER_IDLE:
                    System.out.println("读空闲，客户端可能已断开");
                    ctx.close();
                    break;
                case WRITER_IDLE:
                    System.out.println("写空闲");
                    break;
                case ALL_IDLE:
                    System.out.println("读写空闲");
                    break;
            }
        } else {
            super.userEventTriggered(ctx, evt);
        }
    }
}

// 在Pipeline中添加IdleStateHandler
pipeline.addLast(new IdleStateHandler(60, 30, 0, TimeUnit.SECONDS));
pipeline.addLast(new HeartbeatServerHandler());
```

---

## 五、ByteBuf详解

### 5.1 ByteBuf vs ByteBuffer

| 特性 | ByteBuffer | ByteBuf |
|------|------------|---------|
| 读写切换 | 需要flip() | 独立的读写指针 |
| 扩容 | 不支持 | 自动扩容 |
| 内存类型 | 堆内存 | 堆内存/直接内存/池化 |
| 引用计数 | 无 | 有，支持池化 |

### 5.2 ByteBuf类型

```java
// 堆内存（默认）
ByteBuf heapBuf = Unpooled.buffer(256);

// 直接内存（零拷贝）
ByteBuf directBuf = Unpooled.directBuffer(256);

// 复合缓冲区
CompositeByteBuf compositeBuf = Unpooled.compositeBuffer();
compositeBuf.addComponents(true, heapBuf, directBuf);

// 池化ByteBuf（性能优化）
ByteBuf pooledBuf = PooledByteBufAllocator.DEFAULT.buffer(256);
```

### 5.3 ByteBuf操作

```java
ByteBuf buf = Unpooled.buffer(256);

// 写操作
buf.writeInt(100);
buf.writeLong(200L);
buf.writeBytes("Hello".getBytes());

// 读操作
int i = buf.readInt();
long l = buf.readLong();
byte[] bytes = new byte[5];
buf.readBytes(bytes);

// 随机访问
int value = buf.getInt(0);
buf.setInt(0, 999);

// 引用计数
buf.retain();   // 增加引用
buf.release();  // 减少引用
```

---

## 六、Netty高级特性

### 6.1 零拷贝

```java
// 1. 使用CompositeByteBuf合并多个缓冲区
CompositeByteBuf compositeBuf = Unpooled.compositeBuffer();
compositeBuf.addComponents(true, buf1, buf2);

// 2. 使用slice()分割缓冲区
ByteBuf slice = buf.slice(0, 10);

// 3. 使用FileRegion发送文件
FileChannel fileChannel = new FileInputStream(file).getChannel();
DefaultFileRegion region = new DefaultFileRegion(fileChannel, 0, fileChannel.size());
ctx.writeAndFlush(region);

// 4. 使用wrap()包装数组
byte[] data = "Hello".getBytes();
ByteBuf wrapped = Unpooled.wrappedBuffer(data);
```

### 6.2 粘包拆包处理

```java
// 1. 固定长度解码器
pipeline.addLast(new FixedLengthFrameDecoder(20));

// 2. 行分隔符解码器
pipeline.addLast(new LineBasedFrameDecoder(1024));

// 3. 分隔符解码器
ByteBuf delimiter = Unpooled.copiedBuffer("$_".getBytes());
pipeline.addLast(new DelimiterBasedFrameDecoder(1024, delimiter));

// 4. 长度字段解码器（最常用）
pipeline.addLast(new LengthFieldBasedFrameDecoder(
    65535,      // maxFrameLength
    0,          // lengthFieldOffset
    4,          // lengthFieldLength
    0,          // lengthAdjustment
    4           // initialBytesToStrip
));
```

### 6.3 内存泄漏检测

```java
// 启动参数设置检测级别
// -Dio.netty.leakDetection.level=PARANOID

// 级别说明
// DISABLED: 禁用
// SIMPLE: 默认，采样检测
// ADVANCED: 详细堆栈
// PARANOID: 每个ByteBuf都检测（性能影响大）
```

---

## 七、Netty源码分析

### 7.1 服务端启动流程

```java
// 1. 创建EventLoopGroup
NioEventLoopGroup bossGroup = new NioEventLoopGroup(1);
// → 创建NioEventLoop数组
// → 每个NioEventLoop关联一个Selector

// 2. 配置ServerBootstrap
bootstrap.group(bossGroup, workerGroup)
         .channel(NioServerSocketChannel.class)
// → 通过反射创建Channel工厂

// 3. 绑定端口
bootstrap.bind(port).sync();
// → 创建NioServerSocketChannel
// → 初始化Channel（添加ChannelInitializer）
// → 注册到Selector
// → 绑定端口

// 核心源码
public ChannelFuture bind(SocketAddress localAddress) {
    // 创建Channel
    Channel channel = channelFactory.newChannel();
    // 初始化Channel
    init(channel);
    // 注册到EventLoop
    ChannelFuture regFuture = group().register(channel);
    // 绑定端口
    doBind0(regFuture, channel, localAddress);
}
```

### 7.2 NioEventLoop核心

```java
// NioEventLoop.run() 核心逻辑
@Override
protected void run() {
    for (;;) {
        // 1. 轮询IO事件
        select(wakenUp.getAndSet(false));
        
        // 2. 处理IO事件
        processSelectedKeys();
        
        // 3. 处理任务队列
        runAllTasks();
    }
}

// processSelectedKeys处理逻辑
private void processSelectedKey(SelectionKey k, AbstractNioChannel ch) {
    NioUnsafe unsafe = ch.unsafe();
    
    if ((readyOps & SelectionKey.OP_CONNECT) != 0) {
        unsafe.finishConnect();
    }
    if ((readyOps & SelectionKey.OP_WRITE) != 0) {
        unsafe.forceFlush();
    }
    if ((readyOps & (SelectionKey.OP_READ | SelectionKey.OP_ACCEPT)) != 0) {
        unsafe.read();
    }
}
```

### 7.3 Pipeline责任链

```java
// ChannelPipeline默认结构
// HeadContext ←→ [用户Handler] ←→ TailContext

// 入站事件传播
public ChannelHandlerContext fireChannelRead(Object msg) {
    invokeChannelRead(findContextInbound(), msg);
    return this;
}

// 出站事件传播
public ChannelFuture write(Object msg) {
    return write(msg, newPromise());
}

// 查找下一个Handler
private AbstractChannelHandlerContext findContextInbound() {
    AbstractChannelHandlerContext ctx = this;
    do {
        ctx = ctx.next;
    } while (!ctx.inbound);
    return ctx;
}
```

---

## 八、Netty最佳实践

### 8.1 线程模型配置

```java
// 生产环境推荐配置
// Boss线程数：1（只需要处理连接）
// Worker线程数：CPU核心数 * 2

EventLoopGroup bossGroup = new NioEventLoopGroup(1);
EventLoopGroup workerGroup = new NioEventLoopGroup(
    Runtime.getRuntime().availableProcessors() * 2
);

// 如果有耗时业务，使用业务线程池
EventExecutorGroup businessGroup = new DefaultEventExecutorGroup(16);
pipeline.addLast(businessGroup, new BusinessHandler());
```

### 8.2 参数优化

```java
// 服务端参数
bootstrap.option(ChannelOption.SO_BACKLOG, 1024)       // 连接队列大小
         .option(ChannelOption.SO_REUSEADDR, true)      // 地址复用
         .childOption(ChannelOption.SO_KEEPALIVE, true) // 心跳
         .childOption(ChannelOption.TCP_NODELAY, true)  // 禁用Nagle算法
         .childOption(ChannelOption.SO_SNDBUF, 65535)   // 发送缓冲区
         .childOption(ChannelOption.SO_RCVBUF, 65535);  // 接收缓冲区

// 内存分配器
bootstrap.option(ChannelOption.ALLOCATOR, PooledByteBufAllocator.DEFAULT);
bootstrap.childOption(ChannelOption.ALLOCATOR, PooledByteBufAllocator.DEFAULT);
```

### 8.3 优雅关闭

```java
public void shutdown() {
    // 1. 停止接受新连接
    if (serverChannel != null) {
        serverChannel.close().syncUninterruptibly();
    }
    
    // 2. 优雅关闭EventLoopGroup
    Future<?> bossFuture = bossGroup.shutdownGracefully(1, 5, TimeUnit.SECONDS);
    Future<?> workerFuture = workerGroup.shutdownGracefully(1, 5, TimeUnit.SECONDS);
    
    // 3. 等待关闭完成
    bossFuture.syncUninterruptibly();
    workerFuture.syncUninterruptibly();
    
    System.out.println("Server shutdown complete");
}
```

---

## 九、常见面试问题

### 1. Netty的线程模型是怎样的？
**答**：
Netty采用主从Reactor多线程模型：
- **BossGroup**：负责接收客户端连接，一般配置1个线程
- **WorkerGroup**：负责处理连接的IO读写，一般配置CPU核心数*2个线程
- 一个EventLoop可以处理多个Channel，一个Channel只绑定一个EventLoop

### 2. Netty如何解决粘包拆包问题？
**答**：
- **FixedLengthFrameDecoder**：固定长度
- **LineBasedFrameDecoder**：行分隔符
- **DelimiterBasedFrameDecoder**：自定义分隔符
- **LengthFieldBasedFrameDecoder**：长度字段（最常用）

### 3. Netty的零拷贝体现在哪里？
**答**：
- **CompositeByteBuf**：合并多个ByteBuf，不需要内存复制
- **slice()/duplicate()**：共享底层存储
- **Unpooled.wrappedBuffer()**：包装数组，不复制
- **FileRegion**：直接传输文件，不经过用户态

### 4. ByteBuf和ByteBuffer的区别？
**答**：
- ByteBuf有独立的读写指针，无需flip()
- ByteBuf支持自动扩容
- ByteBuf支持池化，减少GC
- ByteBuf支持引用计数

### 5. Netty如何实现高性能？
**答**：
- 基于NIO的非阻塞IO模型
- Reactor线程模型，高效事件驱动
- 零拷贝技术减少内存复制
- 池化ByteBuf减少内存分配
- 无锁化设计（Channel绑定固定EventLoop）
- 高效的序列化框架支持

### 6. Netty中Channel、ChannelHandler、ChannelPipeline的关系？
**答**：
- **Channel**：代表一个网络连接
- **ChannelPipeline**：Channel上的处理器链，每个Channel有一个Pipeline
- **ChannelHandler**：处理器，处理入站/出站事件
- 事件沿着Pipeline传播，经过各个Handler处理

### 7. Netty如何做内存泄漏检测？
**答**：
通过`-Dio.netty.leakDetection.level`设置检测级别：
- DISABLED：禁用
- SIMPLE：采样检测（默认）
- ADVANCED：详细堆栈
- PARANOID：全量检测

### 8. IdleStateHandler的作用？
**答**：
用于检测连接空闲状态，常用于心跳检测：
- `readerIdleTime`：读空闲时间
- `writerIdleTime`：写空闲时间
- `allIdleTime`：读写空闲时间
触发`userEventTriggered`回调
