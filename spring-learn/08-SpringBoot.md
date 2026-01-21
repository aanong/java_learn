# Spring Boot 详解

## 一、Spring Boot 概述

Spring Boot 是 Spring 的一套快速开发脚手架，简化了 Spring 应用的初始搭建和开发过程。

### 1.1 核心特性
- **自动配置**：根据类路径自动配置 Spring 应用
- **起步依赖**：简化依赖管理
- **内嵌服务器**：无需部署 WAR 包
- **生产就绪**：健康检查、指标监控

## 二、启动流程

### 2.1 启动流程图

```
┌────────────────────────────────────────────────────────────────┐
│                  SpringApplication.run()                        │
├────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. new SpringApplication(primarySources)                      │
│     ├─ 推断应用类型（Servlet/Reactive/None）                    │
│     ├─ 加载 ApplicationContextInitializer                      │
│     └─ 加载 ApplicationListener                                │
│                                                                 │
│  2. run(args)                                                  │
│     │                                                          │
│     ├─ 2.1 创建 SpringApplicationRunListeners                  │
│     │       └─ 发布 ApplicationStartingEvent                   │
│     │                                                          │
│     ├─ 2.2 准备环境 prepareEnvironment                         │
│     │       ├─ 创建 ConfigurableEnvironment                   │
│     │       ├─ 加载配置文件（application.yml/properties）       │
│     │       └─ 发布 ApplicationEnvironmentPreparedEvent        │
│     │                                                          │
│     ├─ 2.3 打印 Banner                                         │
│     │                                                          │
│     ├─ 2.4 创建 ApplicationContext                             │
│     │       └─ 根据应用类型创建对应上下文                        │
│     │                                                          │
│     ├─ 2.5 准备上下文 prepareContext                           │
│     │       ├─ 设置 Environment                                │
│     │       ├─ 调用 ApplicationContextInitializer              │
│     │       ├─ 发布 ApplicationContextInitializedEvent         │
│     │       └─ 加载启动类                                      │
│     │                                                          │
│     ├─ 2.6 刷新上下文 refreshContext                           │
│     │       └─ 调用 AbstractApplicationContext.refresh()       │
│     │           ├─ 实例化所有单例 Bean                          │
│     │           └─ 启动 Web 服务器                              │
│     │                                                          │
│     ├─ 2.7 afterRefresh（空方法，留给子类扩展）                  │
│     │                                                          │
│     ├─ 2.8 发布 ApplicationStartedEvent                        │
│     │                                                          │
│     ├─ 2.9 调用 Runner                                         │
│     │       ├─ ApplicationRunner                               │
│     │       └─ CommandLineRunner                               │
│     │                                                          │
│     └─ 2.10 发布 ApplicationReadyEvent                         │
│                                                                 │
└────────────────────────────────────────────────────────────────┘
```

### 2.2 源码分析

```java
public class SpringApplication {
    
    /**
     * 构造函数
     */
    public SpringApplication(Class<?>... primarySources) {
        // 1. 推断应用类型
        this.webApplicationType = WebApplicationType.deduceFromClasspath();
        
        // 2. 加载 ApplicationContextInitializer
        this.initializers = getSpringFactoriesInstances(
            ApplicationContextInitializer.class);
        
        // 3. 加载 ApplicationListener
        this.listeners = getSpringFactoriesInstances(ApplicationListener.class);
        
        // 4. 推断主类
        this.mainApplicationClass = deduceMainApplicationClass();
    }
    
    /**
     * 运行方法
     */
    public ConfigurableApplicationContext run(String... args) {
        StopWatch stopWatch = new StopWatch();
        stopWatch.start();
        
        ConfigurableApplicationContext context = null;
        
        // 1. 获取 SpringApplicationRunListeners
        SpringApplicationRunListeners listeners = getRunListeners(args);
        
        // 2. 发布 starting 事件
        listeners.starting();
        
        try {
            ApplicationArguments applicationArguments = 
                new DefaultApplicationArguments(args);
            
            // 3. 准备环境
            ConfigurableEnvironment environment = prepareEnvironment(
                listeners, applicationArguments);
            
            // 4. 打印 Banner
            Banner printedBanner = printBanner(environment);
            
            // 5. 创建 ApplicationContext
            context = createApplicationContext();
            
            // 6. 准备上下文
            prepareContext(context, environment, listeners, 
                applicationArguments, printedBanner);
            
            // 7. 刷新上下文（核心）
            refreshContext(context);
            
            // 8. 刷新后处理
            afterRefresh(context, applicationArguments);
            
            stopWatch.stop();
            
            // 9. 发布 started 事件
            listeners.started(context);
            
            // 10. 调用 Runner
            callRunners(context, applicationArguments);
            
        } catch (Throwable ex) {
            handleRunFailure(context, ex, listeners);
            throw new IllegalStateException(ex);
        }
        
        // 11. 发布 ready 事件
        listeners.running(context);
        
        return context;
    }
}
```

## 三、自动配置原理

### 3.1 @SpringBootApplication 注解

```java
@Target(ElementType.TYPE)
@Retention(RetentionPolicy.RUNTIME)
@Documented
@Inherited
@SpringBootConfiguration  // 等同于 @Configuration
@EnableAutoConfiguration  // 启用自动配置
@ComponentScan            // 组件扫描
public @interface SpringBootApplication {
}
```

### 3.2 @EnableAutoConfiguration

```java
@Target(ElementType.TYPE)
@Retention(RetentionPolicy.RUNTIME)
@Documented
@Inherited
@AutoConfigurationPackage
@Import(AutoConfigurationImportSelector.class) // 核心
public @interface EnableAutoConfiguration {
}
```

### 3.3 AutoConfigurationImportSelector

```java
public class AutoConfigurationImportSelector implements DeferredImportSelector {
    
    @Override
    public String[] selectImports(AnnotationMetadata annotationMetadata) {
        // 1. 获取自动配置类
        AutoConfigurationEntry autoConfigurationEntry = 
            getAutoConfigurationEntry(annotationMetadata);
        
        return StringUtils.toStringArray(autoConfigurationEntry.getConfigurations());
    }
    
    protected AutoConfigurationEntry getAutoConfigurationEntry(
            AnnotationMetadata annotationMetadata) {
        
        // 1. 从 META-INF/spring.factories 加载候选配置类
        List<String> configurations = getCandidateConfigurations(
            annotationMetadata, getAttributes(annotationMetadata));
        
        // 2. 去重
        configurations = removeDuplicates(configurations);
        
        // 3. 获取排除项
        Set<String> exclusions = getExclusions(annotationMetadata, getAttributes(annotationMetadata));
        
        // 4. 检查排除项
        checkExcludedClasses(configurations, exclusions);
        
        // 5. 移除排除项
        configurations.removeAll(exclusions);
        
        // 6. 过滤（根据 @Conditional 条件）
        configurations = getConfigurationClassFilter()
            .filter(configurations);
        
        // 7. 触发 AutoConfigurationImportEvent
        fireAutoConfigurationImportEvents(configurations, exclusions);
        
        return new AutoConfigurationEntry(configurations, exclusions);
    }
    
    protected List<String> getCandidateConfigurations(
            AnnotationMetadata metadata, AnnotationAttributes attributes) {
        
        // 从 spring.factories 加载
        List<String> configurations = SpringFactoriesLoader.loadFactoryNames(
            EnableAutoConfiguration.class, getBeanClassLoader());
        
        return configurations;
    }
}
```

### 3.4 自动配置类示例

```java
/**
 * Redis 自动配置
 */
@Configuration(proxyBeanMethods = false)
@ConditionalOnClass(RedisOperations.class) // 类路径存在 Redis
@EnableConfigurationProperties(RedisProperties.class) // 绑定配置属性
@Import({LettuceConnectionConfiguration.class, JedisConnectionConfiguration.class})
public class RedisAutoConfiguration {
    
    @Bean
    @ConditionalOnMissingBean(name = "redisTemplate") // 没有自定义时生效
    @ConditionalOnSingleCandidate(RedisConnectionFactory.class)
    public RedisTemplate<Object, Object> redisTemplate(
            RedisConnectionFactory redisConnectionFactory) {
        RedisTemplate<Object, Object> template = new RedisTemplate<>();
        template.setConnectionFactory(redisConnectionFactory);
        return template;
    }
    
    @Bean
    @ConditionalOnMissingBean
    @ConditionalOnSingleCandidate(RedisConnectionFactory.class)
    public StringRedisTemplate stringRedisTemplate(
            RedisConnectionFactory redisConnectionFactory) {
        return new StringRedisTemplate(redisConnectionFactory);
    }
}
```

### 3.5 自动配置流程图

```
┌────────────────────────────────────────────────────────────────┐
│                      自动配置流程                               │
├────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. @SpringBootApplication                                     │
│     └─ @EnableAutoConfiguration                                │
│         └─ @Import(AutoConfigurationImportSelector.class)      │
│                                                                 │
│  2. AutoConfigurationImportSelector                            │
│     └─ selectImports()                                         │
│         └─ getCandidateConfigurations()                        │
│             └─ SpringFactoriesLoader.loadFactoryNames()        │
│                 └─ 读取 META-INF/spring.factories              │
│                                                                 │
│  3. 获取所有自动配置类（100+）                                  │
│     ├─ DataSourceAutoConfiguration                             │
│     ├─ RedisAutoConfiguration                                  │
│     ├─ WebMvcAutoConfiguration                                 │
│     └─ ...                                                     │
│                                                                 │
│  4. 条件过滤（@Conditional）                                    │
│     ├─ @ConditionalOnClass       类路径存在                    │
│     ├─ @ConditionalOnMissingBean 容器不存在某 Bean             │
│     ├─ @ConditionalOnProperty    配置属性满足                   │
│     └─ ...                                                     │
│                                                                 │
│  5. 符合条件的配置类生效                                        │
│     └─ 创建对应的 Bean                                         │
│                                                                 │
└────────────────────────────────────────────────────────────────┘
```

## 四、SPI 机制

### 4.1 Java SPI

```java
// 1. 定义接口
public interface Logger {
    void log(String message);
}

// 2. 实现类
public class ConsoleLogger implements Logger {
    @Override
    public void log(String message) {
        System.out.println(message);
    }
}

// 3. 配置文件 META-INF/services/com.example.Logger
com.example.ConsoleLogger

// 4. 使用
ServiceLoader<Logger> loggers = ServiceLoader.load(Logger.class);
for (Logger logger : loggers) {
    logger.log("Hello");
}
```

### 4.2 Spring SPI (spring.factories)

```properties
# META-INF/spring.factories

# 自动配置类
org.springframework.boot.autoconfigure.EnableAutoConfiguration=\
com.example.MyAutoConfiguration,\
com.example.AnotherAutoConfiguration

# ApplicationContextInitializer
org.springframework.context.ApplicationContextInitializer=\
com.example.MyApplicationContextInitializer

# ApplicationListener
org.springframework.context.ApplicationListener=\
com.example.MyApplicationListener
```

### 4.3 SpringFactoriesLoader

```java
public final class SpringFactoriesLoader {
    
    public static final String FACTORIES_RESOURCE_LOCATION = 
        "META-INF/spring.factories";
    
    public static List<String> loadFactoryNames(Class<?> factoryType, 
            ClassLoader classLoader) {
        
        String factoryTypeName = factoryType.getName();
        
        // 加载所有 spring.factories 文件
        return loadSpringFactories(classLoader)
            .getOrDefault(factoryTypeName, Collections.emptyList());
    }
    
    private static Map<String, List<String>> loadSpringFactories(
            ClassLoader classLoader) {
        
        // 缓存
        Map<String, List<String>> result = cache.get(classLoader);
        if (result != null) {
            return result;
        }
        
        result = new HashMap<>();
        try {
            // 加载所有 META-INF/spring.factories
            Enumeration<URL> urls = classLoader.getResources(
                FACTORIES_RESOURCE_LOCATION);
            
            while (urls.hasMoreElements()) {
                URL url = urls.nextElement();
                Properties properties = PropertiesLoaderUtils
                    .loadProperties(new UrlResource(url));
                
                for (Map.Entry<?, ?> entry : properties.entrySet()) {
                    String factoryTypeName = ((String) entry.getKey()).trim();
                    String[] factoryNames = StringUtils
                        .commaDelimitedListToStringArray((String) entry.getValue());
                    
                    result.computeIfAbsent(factoryTypeName, k -> new ArrayList<>())
                        .addAll(Arrays.asList(factoryNames));
                }
            }
            
            cache.put(classLoader, result);
            return result;
            
        } catch (IOException ex) {
            throw new IllegalArgumentException(ex);
        }
    }
}
```

### 4.4 Dubbo SPI

```java
// Dubbo SPI 比 Java SPI 更强大
// 1. 按需加载（不会加载所有实现）
// 2. 支持扩展点自适应
// 3. 支持 AOP

// 配置文件 META-INF/dubbo/com.example.Logger
console=com.example.ConsoleLogger
file=com.example.FileLogger

// 使用
ExtensionLoader<Logger> loader = ExtensionLoader.getExtensionLoader(Logger.class);
Logger logger = loader.getExtension("console"); // 按名称获取
```

### 4.5 Spring Boot 3.x 变化

```java
// Spring Boot 3.x 使用新的自动配置注册方式
// 文件：META-INF/spring/org.springframework.boot.autoconfigure.AutoConfiguration.imports

com.example.MyAutoConfiguration
com.example.AnotherAutoConfiguration
```

## 五、自定义 Starter

### 5.1 创建 Starter

```xml
<!-- my-spring-boot-starter/pom.xml -->
<project>
    <groupId>com.example</groupId>
    <artifactId>my-spring-boot-starter</artifactId>
    <version>1.0.0</version>
    
    <dependencies>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter</artifactId>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-configuration-processor</artifactId>
            <optional>true</optional>
        </dependency>
    </dependencies>
</project>
```

### 5.2 配置属性类

```java
@ConfigurationProperties(prefix = "my.service")
public class MyServiceProperties {
    
    private boolean enabled = true;
    private String name = "default";
    private int timeout = 5000;
    
    // getters and setters
}
```

### 5.3 服务类

```java
public class MyService {
    
    private final MyServiceProperties properties;
    
    public MyService(MyServiceProperties properties) {
        this.properties = properties;
    }
    
    public String sayHello() {
        return "Hello from " + properties.getName();
    }
}
```

### 5.4 自动配置类

```java
@Configuration
@ConditionalOnClass(MyService.class)
@EnableConfigurationProperties(MyServiceProperties.class)
@ConditionalOnProperty(prefix = "my.service", name = "enabled", 
    havingValue = "true", matchIfMissing = true)
public class MyServiceAutoConfiguration {
    
    @Bean
    @ConditionalOnMissingBean
    public MyService myService(MyServiceProperties properties) {
        return new MyService(properties);
    }
}
```

### 5.5 注册自动配置

```properties
# META-INF/spring.factories
org.springframework.boot.autoconfigure.EnableAutoConfiguration=\
com.example.MyServiceAutoConfiguration
```

## 六、常见面试问题

### Q1: Spring Boot 的启动流程？
> 答：1）创建 SpringApplication 对象；2）准备环境；3）创建 ApplicationContext；4）准备上下文（加载配置类）；5）刷新上下文（实例化 Bean）；6）调用 Runner。

### Q2: 自动配置的原理？
> 答：通过 @EnableAutoConfiguration 导入 AutoConfigurationImportSelector，从 META-INF/spring.factories 加载所有自动配置类，根据 @Conditional 条件筛选生效的配置。

### Q3: 如何自定义 Starter？
> 答：1）创建配置属性类；2）创建自动配置类并添加条件注解；3）在 spring.factories 中注册自动配置类；4）打包发布。

### Q4: spring.factories 的作用？
> 答：Spring Boot 的 SPI 机制，用于加载自动配置类、初始化器、监听器等扩展点，在启动时自动发现并加载。

### Q5: @ConditionalOnClass 和 @ConditionalOnBean 的区别？
> 答：@ConditionalOnClass 判断类路径是否存在某个类；@ConditionalOnBean 判断容器中是否存在某个 Bean。
