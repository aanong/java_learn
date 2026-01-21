# Spring IOC 与 DI 详解

## 一、IOC 概述

### 1.1 什么是 IOC

IOC（Inversion of Control，控制反转）是一种设计思想，将程序中创建对象的控制权交给 Spring 容器，由容器负责对象的创建、初始化、装配和管理。

### 1.2 什么是 DI

DI（Dependency Injection，依赖注入）是 IOC 的一种实现方式，通过注入的方式将依赖对象传递给需要它的对象。

### 1.3 IOC 容器结构

```
┌─────────────────────────────────────────────────────────────┐
│                     BeanFactory                              │
│                   (IOC 容器根接口)                            │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                 HierarchicalBeanFactory                      │
│                    (支持父子容器)                             │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│              ConfigurableBeanFactory                         │
│                  (可配置的容器)                               │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│           ConfigurableListableBeanFactory                    │
│                (完整功能的容器)                               │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│              DefaultListableBeanFactory                      │
│                   (默认实现)                                  │
└─────────────────────────────────────────────────────────────┘
```

### 1.4 ApplicationContext vs BeanFactory

| 特性 | BeanFactory | ApplicationContext |
|------|------------|-------------------|
| Bean 加载时机 | 延迟加载 | 预加载（启动时） |
| 国际化支持 | 不支持 | 支持 |
| 事件发布 | 不支持 | 支持 |
| 资源加载 | 不支持 | 支持 |
| AOP 支持 | 手动配置 | 自动支持 |
| Web 支持 | 不支持 | 支持 |

## 二、IOC 容器初始化流程

### 2.1 整体流程图

```
┌────────────────────────────────────────────────────────────────┐
│                    ApplicationContext 初始化                    │
├────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. prepareRefresh()                                           │
│     └─ 初始化环境，验证必需属性                                  │
│                                                                 │
│  2. obtainFreshBeanFactory()                                   │
│     └─ 创建 BeanFactory，加载 BeanDefinition                    │
│                                                                 │
│  3. prepareBeanFactory()                                       │
│     └─ 配置 BeanFactory（类加载器、表达式解析器等）               │
│                                                                 │
│  4. postProcessBeanFactory()                                   │
│     └─ 子类扩展点                                               │
│                                                                 │
│  5. invokeBeanFactoryPostProcessors()                          │
│     └─ 调用 BeanFactoryPostProcessor                           │
│                                                                 │
│  6. registerBeanPostProcessors()                               │
│     └─ 注册 BeanPostProcessor                                  │
│                                                                 │
│  7. initMessageSource()                                        │
│     └─ 初始化国际化资源                                         │
│                                                                 │
│  8. initApplicationEventMulticaster()                          │
│     └─ 初始化事件广播器                                         │
│                                                                 │
│  9. onRefresh()                                                │
│     └─ 子类扩展点（如创建 Web 服务器）                           │
│                                                                 │
│  10. registerListeners()                                       │
│      └─ 注册事件监听器                                          │
│                                                                 │
│  11. finishBeanFactoryInitialization()                         │
│      └─ 实例化所有非懒加载单例 Bean                              │
│                                                                 │
│  12. finishRefresh()                                           │
│      └─ 发布容器刷新完成事件                                     │
│                                                                 │
└────────────────────────────────────────────────────────────────┘
```

### 2.2 源码分析 - refresh()

```java
public abstract class AbstractApplicationContext {
    
    @Override
    public void refresh() throws BeansException, IllegalStateException {
        synchronized (this.startupShutdownMonitor) {
            
            // 1. 准备刷新
            prepareRefresh();
            
            // 2. 获取 BeanFactory（核心：加载 BeanDefinition）
            ConfigurableListableBeanFactory beanFactory = obtainFreshBeanFactory();
            
            // 3. 准备 BeanFactory
            prepareBeanFactory(beanFactory);
            
            try {
                // 4. 后处理 BeanFactory（子类扩展）
                postProcessBeanFactory(beanFactory);
                
                // 5. 调用 BeanFactoryPostProcessor
                invokeBeanFactoryPostProcessors(beanFactory);
                
                // 6. 注册 BeanPostProcessor
                registerBeanPostProcessors(beanFactory);
                
                // 7. 初始化消息源
                initMessageSource();
                
                // 8. 初始化事件广播器
                initApplicationEventMulticaster();
                
                // 9. 子类扩展（如启动 Web 服务器）
                onRefresh();
                
                // 10. 注册监听器
                registerListeners();
                
                // 11. 实例化所有非懒加载单例 Bean（核心）
                finishBeanFactoryInitialization(beanFactory);
                
                // 12. 完成刷新
                finishRefresh();
                
            } catch (BeansException ex) {
                // 销毁已创建的 Bean
                destroyBeans();
                // 重置 active 标志
                cancelRefresh(ex);
                throw ex;
            }
        }
    }
}
```

## 三、BeanDefinition 加载

### 3.1 BeanDefinition 结构

```java
/**
 * BeanDefinition 包含 Bean 的所有配置信息
 */
public interface BeanDefinition {
    
    // Bean 的类名
    String getBeanClassName();
    
    // 作用域（singleton, prototype）
    String getScope();
    
    // 是否懒加载
    boolean isLazyInit();
    
    // 依赖的 Bean
    String[] getDependsOn();
    
    // 是否自动装配候选
    boolean isAutowireCandidate();
    
    // 是否主要候选
    boolean isPrimary();
    
    // 工厂 Bean 名称
    String getFactoryBeanName();
    
    // 工厂方法名
    String getFactoryMethodName();
    
    // 构造参数
    ConstructorArgumentValues getConstructorArgumentValues();
    
    // 属性值
    MutablePropertyValues getPropertyValues();
    
    // 初始化方法
    String getInitMethodName();
    
    // 销毁方法
    String getDestroyMethodName();
}
```

### 3.2 BeanDefinition 注册流程

```java
/**
 * 注解方式注册 BeanDefinition
 */
public class AnnotatedBeanDefinitionReader {
    
    public void register(Class<?>... componentClasses) {
        for (Class<?> componentClass : componentClasses) {
            registerBean(componentClass);
        }
    }
    
    public void registerBean(Class<?> beanClass) {
        // 1. 创建 BeanDefinition
        AnnotatedGenericBeanDefinition abd = new AnnotatedGenericBeanDefinition(beanClass);
        
        // 2. 解析 @Conditional
        if (this.conditionEvaluator.shouldSkip(abd.getMetadata())) {
            return;
        }
        
        // 3. 解析 @Scope
        ScopeMetadata scopeMetadata = this.scopeMetadataResolver.resolveScopeMetadata(abd);
        abd.setScope(scopeMetadata.getScopeName());
        
        // 4. 生成 Bean 名称
        String beanName = this.beanNameGenerator.generateBeanName(abd, this.registry);
        
        // 5. 处理通用注解（@Lazy, @Primary, @DependsOn 等）
        AnnotationConfigUtils.processCommonDefinitionAnnotations(abd);
        
        // 6. 注册到 BeanDefinitionRegistry
        BeanDefinitionHolder definitionHolder = new BeanDefinitionHolder(abd, beanName);
        BeanDefinitionReaderUtils.registerBeanDefinition(definitionHolder, this.registry);
    }
}
```

## 四、依赖注入

### 4.1 注入方式

```java
@Service
public class UserService {
    
    // 1. 字段注入（不推荐）
    @Autowired
    private UserRepository userRepository;
    
    // 2. Setter 注入
    private OrderService orderService;
    
    @Autowired
    public void setOrderService(OrderService orderService) {
        this.orderService = orderService;
    }
    
    // 3. 构造器注入（推荐）
    private final ProductService productService;
    
    @Autowired // Spring 4.3+ 单构造器可省略
    public UserService(ProductService productService) {
        this.productService = productService;
    }
}
```

### 4.2 @Autowired 注入流程

```java
/**
 * AutowiredAnnotationBeanPostProcessor 处理 @Autowired
 */
public class AutowiredAnnotationBeanPostProcessor {
    
    @Override
    public PropertyValues postProcessProperties(PropertyValues pvs, 
            Object bean, String beanName) {
        
        // 1. 查找注入元数据（@Autowired 标注的字段和方法）
        InjectionMetadata metadata = findAutowiringMetadata(beanName, 
            bean.getClass(), pvs);
        
        // 2. 执行注入
        metadata.inject(bean, beanName, pvs);
        
        return pvs;
    }
}

/**
 * InjectionMetadata.inject() 执行注入
 */
public class InjectionMetadata {
    
    public void inject(Object target, String beanName, PropertyValues pvs) {
        for (InjectedElement element : this.injectedElements) {
            element.inject(target, beanName, pvs);
        }
    }
}

/**
 * AutowiredFieldElement 字段注入
 */
private class AutowiredFieldElement extends InjectionMetadata.InjectedElement {
    
    @Override
    protected void inject(Object bean, String beanName, PropertyValues pvs) {
        Field field = (Field) this.member;
        Object value;
        
        // 解析依赖
        DependencyDescriptor desc = new DependencyDescriptor(field, this.required);
        value = beanFactory.resolveDependency(desc, beanName, autowiredBeans, typeConverter);
        
        // 通过反射设置值
        if (value != null) {
            ReflectionUtils.makeAccessible(field);
            field.set(bean, value);
        }
    }
}
```

### 4.3 依赖解析流程

```java
/**
 * DefaultListableBeanFactory.resolveDependency()
 */
public class DefaultListableBeanFactory {
    
    @Override
    public Object resolveDependency(DependencyDescriptor descriptor, 
            String requestingBeanName, Set<String> autowiredBeanNames, 
            TypeConverter typeConverter) {
        
        // 1. 处理 @Lazy
        Object result = getAutowireCandidateResolver()
            .getLazyResolutionProxyIfNecessary(descriptor, requestingBeanName);
        if (result != null) {
            return result;
        }
        
        // 2. 解析依赖
        return doResolveDependency(descriptor, requestingBeanName, 
            autowiredBeanNames, typeConverter);
    }
    
    public Object doResolveDependency(DependencyDescriptor descriptor, 
            String beanName, Set<String> autowiredBeanNames, 
            TypeConverter typeConverter) {
        
        Class<?> type = descriptor.getDependencyType();
        
        // 3. 处理 @Value
        Object value = getAutowireCandidateResolver().getSuggestedValue(descriptor);
        if (value != null) {
            // 解析占位符和 SpEL
            return resolveValue(value, type);
        }
        
        // 4. 处理集合类型（List, Map, Set）
        Object multipleBeans = resolveMultipleBeans(descriptor, beanName, 
            autowiredBeanNames, typeConverter);
        if (multipleBeans != null) {
            return multipleBeans;
        }
        
        // 5. 按类型查找候选 Bean
        Map<String, Object> matchingBeans = findAutowireCandidates(
            beanName, type, descriptor);
        
        if (matchingBeans.isEmpty()) {
            if (descriptor.isRequired()) {
                throw new NoSuchBeanDefinitionException(type);
            }
            return null;
        }
        
        // 6. 确定最终的 Bean
        String autowiredBeanName;
        Object instanceCandidate;
        
        if (matchingBeans.size() > 1) {
            // 多个候选，确定主要候选
            autowiredBeanName = determineAutowireCandidate(matchingBeans, descriptor);
            if (autowiredBeanName == null) {
                throw new NoUniqueBeanDefinitionException(type, matchingBeans.keySet());
            }
            instanceCandidate = matchingBeans.get(autowiredBeanName);
        } else {
            Map.Entry<String, Object> entry = matchingBeans.entrySet().iterator().next();
            autowiredBeanName = entry.getKey();
            instanceCandidate = entry.getValue();
        }
        
        // 7. 获取 Bean 实例
        if (instanceCandidate instanceof Class) {
            instanceCandidate = getBean(autowiredBeanName);
        }
        
        return instanceCandidate;
    }
}
```

## 五、Bean 获取流程

### 5.1 getBean 流程

```java
/**
 * AbstractBeanFactory.getBean()
 */
public abstract class AbstractBeanFactory {
    
    @Override
    public Object getBean(String name) throws BeansException {
        return doGetBean(name, null, null, false);
    }
    
    protected <T> T doGetBean(String name, Class<T> requiredType, 
            Object[] args, boolean typeCheckOnly) {
        
        // 1. 转换 Bean 名称（处理 & 前缀和别名）
        String beanName = transformedBeanName(name);
        Object bean;
        
        // 2. 从缓存获取单例 Bean
        Object sharedInstance = getSingleton(beanName);
        if (sharedInstance != null && args == null) {
            // 处理 FactoryBean
            bean = getObjectForBeanInstance(sharedInstance, name, beanName, null);
        } else {
            // 3. 检查是否正在创建（循环依赖检测）
            if (isPrototypeCurrentlyInCreation(beanName)) {
                throw new BeanCurrentlyInCreationException(beanName);
            }
            
            // 4. 检查父容器
            BeanFactory parentBeanFactory = getParentBeanFactory();
            if (parentBeanFactory != null && !containsBeanDefinition(beanName)) {
                return parentBeanFactory.getBean(name, requiredType);
            }
            
            // 5. 获取 BeanDefinition
            RootBeanDefinition mbd = getMergedLocalBeanDefinition(beanName);
            
            // 6. 处理 @DependsOn
            String[] dependsOn = mbd.getDependsOn();
            if (dependsOn != null) {
                for (String dep : dependsOn) {
                    getBean(dep);
                }
            }
            
            // 7. 创建 Bean
            if (mbd.isSingleton()) {
                // 单例 Bean
                sharedInstance = getSingleton(beanName, () -> {
                    return createBean(beanName, mbd, args);
                });
                bean = getObjectForBeanInstance(sharedInstance, name, beanName, mbd);
            } else if (mbd.isPrototype()) {
                // 原型 Bean
                Object prototypeInstance = createBean(beanName, mbd, args);
                bean = getObjectForBeanInstance(prototypeInstance, name, beanName, mbd);
            } else {
                // 其他 Scope
                String scopeName = mbd.getScope();
                Scope scope = this.scopes.get(scopeName);
                Object scopedInstance = scope.get(beanName, () -> {
                    return createBean(beanName, mbd, args);
                });
                bean = getObjectForBeanInstance(scopedInstance, name, beanName, mbd);
            }
        }
        
        // 8. 类型转换
        return adaptBeanInstance(name, bean, requiredType);
    }
}
```

### 5.2 createBean 流程

```java
/**
 * AbstractAutowireCapableBeanFactory.createBean()
 */
protected Object createBean(String beanName, RootBeanDefinition mbd, Object[] args) {
    
    // 1. 解析 Bean 类型
    Class<?> resolvedClass = resolveBeanClass(mbd, beanName);
    
    // 2. 准备方法覆盖
    mbd.prepareMethodOverrides();
    
    // 3. 给 BeanPostProcessor 一个返回代理的机会
    Object bean = resolveBeforeInstantiation(beanName, mbd);
    if (bean != null) {
        return bean;
    }
    
    // 4. 真正创建 Bean
    Object beanInstance = doCreateBean(beanName, mbd, args);
    
    return beanInstance;
}

protected Object doCreateBean(String beanName, RootBeanDefinition mbd, Object[] args) {
    
    // 1. 实例化 Bean
    BeanWrapper instanceWrapper = createBeanInstance(beanName, mbd, args);
    Object bean = instanceWrapper.getWrappedInstance();
    
    // 2. 提前暴露 Bean 引用（解决循环依赖）
    boolean earlySingletonExposure = (mbd.isSingleton() && 
        this.allowCircularReferences && isSingletonCurrentlyInCreation(beanName));
    if (earlySingletonExposure) {
        addSingletonFactory(beanName, () -> getEarlyBeanReference(beanName, mbd, bean));
    }
    
    Object exposedObject = bean;
    try {
        // 3. 填充属性（依赖注入）
        populateBean(beanName, mbd, instanceWrapper);
        
        // 4. 初始化 Bean
        exposedObject = initializeBean(beanName, exposedObject, mbd);
    } catch (Throwable ex) {
        throw new BeanCreationException(beanName, "初始化失败", ex);
    }
    
    // 5. 注册销毁方法
    registerDisposableBeanIfNecessary(beanName, bean, mbd);
    
    return exposedObject;
}
```

## 六、常见面试问题

### Q1: BeanFactory 和 ApplicationContext 的区别？
> 答：BeanFactory 是最基础的容器，提供延迟加载；ApplicationContext 是 BeanFactory 的子接口，提供更多企业级功能（预加载、国际化、事件、AOP 支持等）。

### Q2: Spring IOC 容器初始化的核心步骤？
> 答：1）准备刷新；2）创建 BeanFactory 并加载 BeanDefinition；3）调用 BeanFactoryPostProcessor；4）注册 BeanPostProcessor；5）实例化所有单例 Bean。

### Q3: 构造器注入和字段注入哪个更好？
> 答：构造器注入更好。原因：1）保证依赖不可变；2）保证依赖不为空；3）避免循环依赖；4）便于测试。

### Q4: @Autowired 的工作原理？
> 答：AutowiredAnnotationBeanPostProcessor 处理 @Autowired。在 Bean 属性填充阶段，扫描 @Autowired 标注的字段和方法，通过反射注入依赖。

### Q5: Spring 如何解决依赖类型冲突？
> 答：1）@Primary 标记主要候选；2）@Qualifier 指定 Bean 名称；3）按属性名匹配 Bean 名称。
