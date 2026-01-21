# 工厂模式 (Factory Pattern)

## 一、工厂模式概述

工厂模式是一种创建型设计模式，它提供了一种创建对象的方式，使得创建对象的过程与使用对象的过程分离。

### 工厂模式的三种类型
1. **简单工厂模式**（Simple Factory）- 静态工厂方法
2. **工厂方法模式**（Factory Method）- 定义创建对象的接口
3. **抽象工厂模式**（Abstract Factory）- 创建相关对象家族

## 二、简单工厂模式

### 2.1 定义
简单工厂模式由一个工厂类根据传入的参数，动态决定创建哪一个产品类的实例。

### 2.2 结构图

```
┌─────────────────┐
│  SimpleFactory  │
│  +createProduct │─────────────┐
└─────────────────┘             │
         │                      │
         │ creates              │
         ▼                      ▼
┌─────────────┐         ┌─────────────┐
│  ProductA   │         │  ProductB   │
└─────────────┘         └─────────────┘
```

### 2.3 代码实现

```java
/**
 * 产品接口
 */
public interface Product {
    void use();
}

/**
 * 具体产品A
 */
public class ProductA implements Product {
    @Override
    public void use() {
        System.out.println("使用产品A");
    }
}

/**
 * 具体产品B
 */
public class ProductB implements Product {
    @Override
    public void use() {
        System.out.println("使用产品B");
    }
}

/**
 * 简单工厂
 */
public class SimpleFactory {
    
    /**
     * 根据类型创建产品
     */
    public static Product createProduct(String type) {
        switch (type) {
            case "A":
                return new ProductA();
            case "B":
                return new ProductB();
            default:
                throw new IllegalArgumentException("未知产品类型: " + type);
        }
    }
    
    /**
     * 使用 Class 反射创建（更灵活）
     */
    public static <T extends Product> T createProduct(Class<T> clazz) {
        try {
            return clazz.getDeclaredConstructor().newInstance();
        } catch (Exception e) {
            throw new RuntimeException("创建产品失败", e);
        }
    }
}

// 使用示例
public class Client {
    public static void main(String[] args) {
        Product productA = SimpleFactory.createProduct("A");
        productA.use(); // 输出：使用产品A
        
        Product productB = SimpleFactory.createProduct(ProductB.class);
        productB.use(); // 输出：使用产品B
    }
}
```

### 2.4 实际应用案例 - 日志工厂

```java
/**
 * 日志接口
 */
public interface Logger {
    void info(String message);
    void error(String message);
}

/**
 * 控制台日志
 */
public class ConsoleLogger implements Logger {
    @Override
    public void info(String message) {
        System.out.println("[INFO] " + message);
    }
    
    @Override
    public void error(String message) {
        System.err.println("[ERROR] " + message);
    }
}

/**
 * 文件日志
 */
public class FileLogger implements Logger {
    private String filePath;
    
    public FileLogger(String filePath) {
        this.filePath = filePath;
    }
    
    @Override
    public void info(String message) {
        writeToFile("[INFO] " + message);
    }
    
    @Override
    public void error(String message) {
        writeToFile("[ERROR] " + message);
    }
    
    private void writeToFile(String content) {
        // 写入文件的逻辑
    }
}

/**
 * 日志工厂
 */
public class LoggerFactory {
    
    public static Logger getLogger(String type) {
        switch (type.toLowerCase()) {
            case "console":
                return new ConsoleLogger();
            case "file":
                return new FileLogger("/var/log/app.log");
            default:
                return new ConsoleLogger();
        }
    }
    
    public static Logger getLogger(Class<?> clazz) {
        // 可以根据类名创建带类名前缀的日志
        return new ConsoleLogger();
    }
}
```

## 三、工厂方法模式

### 3.1 定义
工厂方法模式定义一个创建对象的接口，但让实现这个接口的子类来决定实例化哪个类。

### 3.2 结构图

```
┌───────────────────┐         ┌───────────────────┐
│  Creator          │         │  Product          │
│  +factoryMethod() │         │                   │
└───────────────────┘         └───────────────────┘
         △                             △
         │                             │
    ┌────┴────┐                   ┌────┴────┐
    │         │                   │         │
┌───┴───┐ ┌───┴───┐         ┌───┴───┐ ┌───┴───┐
│CreatorA│ │CreatorB│         │ProductA│ │ProductB│
└───────┘ └───────┘         └───────┘ └───────┘
```

### 3.3 代码实现

```java
/**
 * 产品接口
 */
public interface Product {
    void use();
}

/**
 * 具体产品
 */
public class ConcreteProductA implements Product {
    @Override
    public void use() {
        System.out.println("使用具体产品A");
    }
}

public class ConcreteProductB implements Product {
    @Override
    public void use() {
        System.out.println("使用具体产品B");
    }
}

/**
 * 抽象工厂（创建者）
 */
public abstract class Creator {
    
    // 工厂方法 - 子类实现
    public abstract Product factoryMethod();
    
    // 业务逻辑 - 使用工厂方法
    public void operation() {
        Product product = factoryMethod();
        product.use();
    }
}

/**
 * 具体工厂A
 */
public class ConcreteCreatorA extends Creator {
    @Override
    public Product factoryMethod() {
        return new ConcreteProductA();
    }
}

/**
 * 具体工厂B
 */
public class ConcreteCreatorB extends Creator {
    @Override
    public Product factoryMethod() {
        return new ConcreteProductB();
    }
}

// 使用示例
public class Client {
    public static void main(String[] args) {
        Creator creatorA = new ConcreteCreatorA();
        creatorA.operation(); // 输出：使用具体产品A
        
        Creator creatorB = new ConcreteCreatorB();
        creatorB.operation(); // 输出：使用具体产品B
    }
}
```

### 3.4 实际应用案例 - 支付工厂

```java
/**
 * 支付接口
 */
public interface Payment {
    void pay(BigDecimal amount);
    PaymentResult queryStatus(String orderId);
}

/**
 * 支付宝支付
 */
public class AlipayPayment implements Payment {
    @Override
    public void pay(BigDecimal amount) {
        System.out.println("使用支付宝支付: " + amount);
        // 调用支付宝 SDK
    }
    
    @Override
    public PaymentResult queryStatus(String orderId) {
        // 查询支付宝订单状态
        return new PaymentResult();
    }
}

/**
 * 微信支付
 */
public class WechatPayment implements Payment {
    @Override
    public void pay(BigDecimal amount) {
        System.out.println("使用微信支付: " + amount);
        // 调用微信支付 SDK
    }
    
    @Override
    public PaymentResult queryStatus(String orderId) {
        // 查询微信订单状态
        return new PaymentResult();
    }
}

/**
 * 支付工厂接口
 */
public interface PaymentFactory {
    Payment createPayment();
}

/**
 * 支付宝工厂
 */
public class AlipayFactory implements PaymentFactory {
    @Override
    public Payment createPayment() {
        return new AlipayPayment();
    }
}

/**
 * 微信支付工厂
 */
public class WechatPayFactory implements PaymentFactory {
    @Override
    public Payment createPayment() {
        return new WechatPayment();
    }
}

/**
 * 支付服务
 */
public class PaymentService {
    private PaymentFactory paymentFactory;
    
    public PaymentService(PaymentFactory paymentFactory) {
        this.paymentFactory = paymentFactory;
    }
    
    public void processPayment(BigDecimal amount) {
        Payment payment = paymentFactory.createPayment();
        payment.pay(amount);
    }
}
```

## 四、抽象工厂模式

### 4.1 定义
抽象工厂模式提供一个创建一系列相关或相互依赖对象的接口，而无需指定它们具体的类。

### 4.2 结构图

```
┌─────────────────────────┐
│    AbstractFactory      │
│  +createProductA()      │
│  +createProductB()      │
└─────────────────────────┘
            △
            │
    ┌───────┴───────┐
    │               │
┌───┴────┐    ┌────┴───┐
│Factory1│    │Factory2│
└────────┘    └────────┘
    │              │
    │ creates      │ creates
    ▼              ▼
┌────────┐    ┌────────┐
│ProductA1│   │ProductA2│
│ProductB1│   │ProductB2│
└────────┘    └────────┘
```

### 4.3 代码实现

```java
/**
 * 抽象产品A
 */
public interface Button {
    void render();
    void onClick();
}

/**
 * 抽象产品B
 */
public interface TextField {
    void render();
    String getValue();
}

/**
 * Windows 风格按钮
 */
public class WindowsButton implements Button {
    @Override
    public void render() {
        System.out.println("渲染 Windows 风格按钮");
    }
    
    @Override
    public void onClick() {
        System.out.println("Windows 按钮点击");
    }
}

/**
 * Mac 风格按钮
 */
public class MacButton implements Button {
    @Override
    public void render() {
        System.out.println("渲染 Mac 风格按钮");
    }
    
    @Override
    public void onClick() {
        System.out.println("Mac 按钮点击");
    }
}

/**
 * Windows 风格文本框
 */
public class WindowsTextField implements TextField {
    @Override
    public void render() {
        System.out.println("渲染 Windows 风格文本框");
    }
    
    @Override
    public String getValue() {
        return "Windows TextField Value";
    }
}

/**
 * Mac 风格文本框
 */
public class MacTextField implements TextField {
    @Override
    public void render() {
        System.out.println("渲染 Mac 风格文本框");
    }
    
    @Override
    public String getValue() {
        return "Mac TextField Value";
    }
}

/**
 * 抽象工厂接口
 */
public interface GUIFactory {
    Button createButton();
    TextField createTextField();
}

/**
 * Windows 工厂
 */
public class WindowsFactory implements GUIFactory {
    @Override
    public Button createButton() {
        return new WindowsButton();
    }
    
    @Override
    public TextField createTextField() {
        return new WindowsTextField();
    }
}

/**
 * Mac 工厂
 */
public class MacFactory implements GUIFactory {
    @Override
    public Button createButton() {
        return new MacButton();
    }
    
    @Override
    public TextField createTextField() {
        return new MacTextField();
    }
}

/**
 * 应用程序
 */
public class Application {
    private Button button;
    private TextField textField;
    
    public Application(GUIFactory factory) {
        button = factory.createButton();
        textField = factory.createTextField();
    }
    
    public void render() {
        button.render();
        textField.render();
    }
}

// 使用示例
public class Client {
    public static void main(String[] args) {
        // 根据操作系统选择工厂
        GUIFactory factory;
        String os = System.getProperty("os.name").toLowerCase();
        
        if (os.contains("mac")) {
            factory = new MacFactory();
        } else {
            factory = new WindowsFactory();
        }
        
        Application app = new Application(factory);
        app.render();
    }
}
```

### 4.4 实际应用案例 - 数据库访问层

```java
/**
 * 连接接口
 */
public interface Connection {
    void connect();
    void close();
}

/**
 * 命令接口
 */
public interface Command {
    void execute(String sql);
}

/**
 * MySQL 连接
 */
public class MySQLConnection implements Connection {
    @Override
    public void connect() {
        System.out.println("连接 MySQL 数据库");
    }
    
    @Override
    public void close() {
        System.out.println("关闭 MySQL 连接");
    }
}

/**
 * Oracle 连接
 */
public class OracleConnection implements Connection {
    @Override
    public void connect() {
        System.out.println("连接 Oracle 数据库");
    }
    
    @Override
    public void close() {
        System.out.println("关闭 Oracle 连接");
    }
}

/**
 * MySQL 命令
 */
public class MySQLCommand implements Command {
    @Override
    public void execute(String sql) {
        System.out.println("MySQL 执行: " + sql);
    }
}

/**
 * Oracle 命令
 */
public class OracleCommand implements Command {
    @Override
    public void execute(String sql) {
        System.out.println("Oracle 执行: " + sql);
    }
}

/**
 * 数据库抽象工厂
 */
public interface DatabaseFactory {
    Connection createConnection();
    Command createCommand();
}

/**
 * MySQL 工厂
 */
public class MySQLFactory implements DatabaseFactory {
    @Override
    public Connection createConnection() {
        return new MySQLConnection();
    }
    
    @Override
    public Command createCommand() {
        return new MySQLCommand();
    }
}

/**
 * Oracle 工厂
 */
public class OracleFactory implements DatabaseFactory {
    @Override
    public Connection createConnection() {
        return new OracleConnection();
    }
    
    @Override
    public Command createCommand() {
        return new OracleCommand();
    }
}
```

## 五、三种工厂模式对比

| 特性 | 简单工厂 | 工厂方法 | 抽象工厂 |
|------|---------|---------|---------|
| 结构复杂度 | 简单 | 中等 | 复杂 |
| 代码复杂度 | 一个工厂类 | 多个工厂类 | 多个工厂类 |
| 扩展性 | 差（需修改工厂） | 好（新增工厂类） | 好（新增工厂类） |
| 产品数量 | 单一产品 | 单一产品 | 产品族 |
| 客户端知识 | 知道产品类型 | 知道具体工厂 | 知道具体工厂 |
| 开闭原则 | 违反 | 遵循 | 遵循 |

## 六、工厂模式在 Spring 中的应用

### 6.1 BeanFactory

```java
// Spring 的核心接口就是工厂模式
public interface BeanFactory {
    Object getBean(String name);
    <T> T getBean(Class<T> requiredType);
    // ...
}
```

### 6.2 FactoryBean

```java
/**
 * Spring 的 FactoryBean 接口
 */
public interface FactoryBean<T> {
    T getObject() throws Exception;
    Class<?> getObjectType();
    boolean isSingleton();
}

/**
 * 自定义 FactoryBean
 */
public class MyBeanFactory implements FactoryBean<MyBean> {
    @Override
    public MyBean getObject() throws Exception {
        // 可以实现复杂的创建逻辑
        return new MyBean();
    }
    
    @Override
    public Class<?> getObjectType() {
        return MyBean.class;
    }
    
    @Override
    public boolean isSingleton() {
        return true;
    }
}
```

## 七、面试常见问题

### Q1: 简单工厂和工厂方法的区别？
> 答：简单工厂将创建逻辑集中在一个类中，违反开闭原则；工厂方法将创建逻辑分散到子类中，符合开闭原则。

### Q2: 什么时候使用抽象工厂？
> 答：当需要创建一系列相关联的产品（产品族）时使用抽象工厂，如创建跨平台 UI 组件。

### Q3: 工厂模式的优点？
> 答：解耦（客户端不需要知道具体类）、扩展性好（新增产品只需新增类）、符合单一职责原则（创建逻辑集中管理）。

### Q4: Spring 中的 BeanFactory 和 FactoryBean 的区别？
> 答：BeanFactory 是 Spring IoC 容器的根接口，负责管理 Bean；FactoryBean 是一个能产生 Bean 的工厂 Bean，用于创建复杂对象。
