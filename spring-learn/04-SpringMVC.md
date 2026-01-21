# Spring MVC 详解

## 一、Spring MVC 概述

Spring MVC 是 Spring 框架的 Web 模块，基于 MVC 设计模式，提供了一套完整的 Web 应用开发解决方案。

### 1.1 MVC 架构

```
┌───────────┐    请求     ┌─────────────────┐
│  Browser  │───────────>│  DispatcherServlet │
└───────────┘            └─────────────────┘
      ▲                          │
      │                          │ 1. 查找 Handler
      │                          ▼
      │                  ┌─────────────────┐
      │                  │  HandlerMapping  │
      │                  └─────────────────┘
      │                          │
      │                          │ 2. 返回 HandlerExecutionChain
      │                          ▼
      │                  ┌─────────────────┐
      │                  │  HandlerAdapter  │
      │                  └─────────────────┘
      │                          │
      │                          │ 3. 调用 Handler
      │                          ▼
      │                  ┌─────────────────┐
      │                  │    Controller    │
      │                  └─────────────────┘
      │                          │
      │                          │ 4. 返回 ModelAndView
      │                          ▼
      │                  ┌─────────────────┐
      │                  │   ViewResolver   │
      │                  └─────────────────┘
      │                          │
      │                          │ 5. 解析视图
      │                          ▼
      │                  ┌─────────────────┐
      │    响应           │      View        │
      └──────────────────└─────────────────┘
```

## 二、Spring MVC 核心流程

### 2.1 DispatcherServlet 处理流程

```
1. 用户发送请求 -> DispatcherServlet
2. DispatcherServlet -> HandlerMapping (查找 Handler)
3. HandlerMapping -> DispatcherServlet (返回 HandlerExecutionChain)
4. DispatcherServlet -> HandlerAdapter (调用 Handler)
5. HandlerAdapter -> Handler/Controller (执行业务逻辑)
6. Handler/Controller -> HandlerAdapter (返回 ModelAndView)
7. HandlerAdapter -> DispatcherServlet (返回 ModelAndView)
8. DispatcherServlet -> ViewResolver (解析视图)
9. ViewResolver -> DispatcherServlet (返回 View)
10. DispatcherServlet -> View (渲染视图)
11. View -> DispatcherServlet (返回响应)
12. DispatcherServlet -> 用户 (响应结果)
```

### 2.2 核心组件

| 组件 | 说明 |
|------|------|
| **DispatcherServlet** | 前端控制器，接收所有请求 |
| **HandlerMapping** | 处理器映射，找到对应的 Handler |
| **HandlerAdapter** | 处理器适配器，调用 Handler |
| **Handler/Controller** | 处理器，处理业务逻辑 |
| **ViewResolver** | 视图解析器，解析视图名称 |
| **View** | 视图，渲染页面 |

## 三、Spring MVC 常用注解

### 3.1 控制器注解

```java
/**
 * @Controller - 定义控制器
 */
@Controller
@RequestMapping("/users")
public class UserController {
    
    /**
     * @RequestMapping - 请求映射
     */
    @RequestMapping(value = "/list", method = RequestMethod.GET)
    public String list(Model model) {
        model.addAttribute("users", userService.findAll());
        return "user/list"; // 视图名
    }
    
    /**
     * @GetMapping - GET 请求
     */
    @GetMapping("/{id}")
    public String detail(@PathVariable Long id, Model model) {
        model.addAttribute("user", userService.findById(id));
        return "user/detail";
    }
    
    /**
     * @PostMapping - POST 请求
     */
    @PostMapping
    public String create(@ModelAttribute User user) {
        userService.save(user);
        return "redirect:/users";
    }
    
    /**
     * @PutMapping - PUT 请求
     */
    @PutMapping("/{id}")
    @ResponseBody
    public Result update(@PathVariable Long id, @RequestBody User user) {
        user.setId(id);
        userService.update(user);
        return Result.success();
    }
    
    /**
     * @DeleteMapping - DELETE 请求
     */
    @DeleteMapping("/{id}")
    @ResponseBody
    public Result delete(@PathVariable Long id) {
        userService.delete(id);
        return Result.success();
    }
}

/**
 * @RestController = @Controller + @ResponseBody
 */
@RestController
@RequestMapping("/api/users")
public class UserApiController {
    
    @GetMapping
    public List<User> list() {
        return userService.findAll();
    }
    
    @GetMapping("/{id}")
    public User detail(@PathVariable Long id) {
        return userService.findById(id);
    }
}
```

### 3.2 参数绑定注解

```java
@RestController
@RequestMapping("/api")
public class ParamController {
    
    /**
     * @PathVariable - 路径变量
     */
    @GetMapping("/users/{id}")
    public User getUser(@PathVariable("id") Long userId) {
        return userService.findById(userId);
    }
    
    /**
     * @RequestParam - 请求参数
     */
    @GetMapping("/search")
    public List<User> search(
        @RequestParam String keyword,
        @RequestParam(defaultValue = "1") int page,
        @RequestParam(defaultValue = "10") int size,
        @RequestParam(required = false) String status
    ) {
        return userService.search(keyword, page, size, status);
    }
    
    /**
     * @RequestBody - 请求体（JSON）
     */
    @PostMapping("/users")
    public User createUser(@RequestBody @Valid UserDTO userDTO) {
        return userService.create(userDTO);
    }
    
    /**
     * @RequestHeader - 请求头
     */
    @GetMapping("/info")
    public Map<String, Object> getInfo(
        @RequestHeader("Authorization") String token,
        @RequestHeader(value = "X-Request-Id", required = false) String requestId
    ) {
        // ...
    }
    
    /**
     * @CookieValue - Cookie 值
     */
    @GetMapping("/session")
    public String getSession(@CookieValue("JSESSIONID") String sessionId) {
        return sessionId;
    }
    
    /**
     * @ModelAttribute - 模型属性
     */
    @PostMapping("/form")
    public String handleForm(@ModelAttribute UserForm form) {
        // 表单提交
        return "success";
    }
    
    /**
     * @RequestPart - 文件上传
     */
    @PostMapping("/upload")
    public String upload(@RequestPart("file") MultipartFile file) {
        // 处理文件
        return "uploaded";
    }
}
```

### 3.3 响应处理注解

```java
@RestController
public class ResponseController {
    
    /**
     * @ResponseBody - 返回 JSON
     */
    @GetMapping("/json")
    @ResponseBody
    public User getJson() {
        return new User(1L, "张三");
    }
    
    /**
     * @ResponseStatus - 设置响应状态码
     */
    @PostMapping("/created")
    @ResponseStatus(HttpStatus.CREATED)
    public User createUser(@RequestBody User user) {
        return userService.save(user);
    }
    
    /**
     * ResponseEntity - 完整控制响应
     */
    @GetMapping("/entity/{id}")
    public ResponseEntity<User> getEntity(@PathVariable Long id) {
        User user = userService.findById(id);
        if (user == null) {
            return ResponseEntity.notFound().build();
        }
        return ResponseEntity.ok()
            .header("X-Custom-Header", "value")
            .body(user);
    }
}
```

## 四、拦截器

### 4.1 HandlerInterceptor

```java
/**
 * 自定义拦截器
 */
@Component
public class AuthInterceptor implements HandlerInterceptor {
    
    /**
     * 在 Controller 方法执行前调用
     * 返回 true 继续执行，返回 false 中断
     */
    @Override
    public boolean preHandle(HttpServletRequest request, 
            HttpServletResponse response, Object handler) throws Exception {
        
        // 检查登录状态
        String token = request.getHeader("Authorization");
        if (StringUtils.isEmpty(token)) {
            response.setStatus(401);
            response.getWriter().write("未授权");
            return false;
        }
        
        // 验证 token
        User user = tokenService.validate(token);
        if (user == null) {
            response.setStatus(401);
            return false;
        }
        
        // 将用户信息放入请求
        request.setAttribute("currentUser", user);
        return true;
    }
    
    /**
     * 在 Controller 方法执行后，视图渲染前调用
     */
    @Override
    public void postHandle(HttpServletRequest request, 
            HttpServletResponse response, Object handler, 
            ModelAndView modelAndView) throws Exception {
        // 可以修改 ModelAndView
    }
    
    /**
     * 在整个请求完成后调用（视图渲染完成）
     */
    @Override
    public void afterCompletion(HttpServletRequest request, 
            HttpServletResponse response, Object handler, 
            Exception ex) throws Exception {
        // 清理资源
        // 记录日志
    }
}

/**
 * 注册拦截器
 */
@Configuration
public class WebConfig implements WebMvcConfigurer {
    
    @Autowired
    private AuthInterceptor authInterceptor;
    
    @Override
    public void addInterceptors(InterceptorRegistry registry) {
        registry.addInterceptor(authInterceptor)
            .addPathPatterns("/api/**")
            .excludePathPatterns("/api/login", "/api/register");
    }
}
```

### 4.2 拦截器执行流程

```
请求 ────────────────────────────────────────────────────────>
       │
       ▼
  preHandle1 (Interceptor1)
       │ true
       ▼
  preHandle2 (Interceptor2)
       │ true
       ▼
  ┌─────────────┐
  │  Controller │
  └─────────────┘
       │
       ▼
  postHandle2 (Interceptor2)
       │
       ▼
  postHandle1 (Interceptor1)
       │
       ▼
  ┌─────────────┐
  │    View     │
  └─────────────┘
       │
       ▼
  afterCompletion2 (Interceptor2)
       │
       ▼
  afterCompletion1 (Interceptor1)
       │
       ▼
<──────────────────────────────────────────────────────── 响应
```

## 五、异常处理

### 5.1 @ExceptionHandler

```java
@RestController
public class UserController {
    
    /**
     * 局部异常处理
     */
    @ExceptionHandler(UserNotFoundException.class)
    @ResponseStatus(HttpStatus.NOT_FOUND)
    public ErrorResponse handleUserNotFound(UserNotFoundException ex) {
        return new ErrorResponse(404, ex.getMessage());
    }
}
```

### 5.2 @ControllerAdvice

```java
/**
 * 全局异常处理
 */
@RestControllerAdvice
public class GlobalExceptionHandler {
    
    private static final Logger log = LoggerFactory.getLogger(GlobalExceptionHandler.class);
    
    /**
     * 处理业务异常
     */
    @ExceptionHandler(BusinessException.class)
    @ResponseStatus(HttpStatus.BAD_REQUEST)
    public Result handleBusinessException(BusinessException ex) {
        log.warn("业务异常: {}", ex.getMessage());
        return Result.fail(ex.getCode(), ex.getMessage());
    }
    
    /**
     * 处理参数校验异常
     */
    @ExceptionHandler(MethodArgumentNotValidException.class)
    @ResponseStatus(HttpStatus.BAD_REQUEST)
    public Result handleValidationException(MethodArgumentNotValidException ex) {
        String message = ex.getBindingResult().getFieldErrors().stream()
            .map(error -> error.getField() + ": " + error.getDefaultMessage())
            .collect(Collectors.joining("; "));
        return Result.fail(400, message);
    }
    
    /**
     * 处理参数绑定异常
     */
    @ExceptionHandler(BindException.class)
    @ResponseStatus(HttpStatus.BAD_REQUEST)
    public Result handleBindException(BindException ex) {
        String message = ex.getBindingResult().getFieldErrors().stream()
            .map(FieldError::getDefaultMessage)
            .collect(Collectors.joining("; "));
        return Result.fail(400, message);
    }
    
    /**
     * 处理所有未捕获异常
     */
    @ExceptionHandler(Exception.class)
    @ResponseStatus(HttpStatus.INTERNAL_SERVER_ERROR)
    public Result handleException(Exception ex) {
        log.error("系统异常", ex);
        return Result.fail(500, "系统繁忙，请稍后重试");
    }
}
```

## 六、数据绑定与转换

### 6.1 类型转换器

```java
/**
 * 自定义类型转换器
 */
@Component
public class StringToDateConverter implements Converter<String, Date> {
    
    private static final String[] PATTERNS = {
        "yyyy-MM-dd HH:mm:ss",
        "yyyy-MM-dd",
        "yyyy/MM/dd"
    };
    
    @Override
    public Date convert(String source) {
        for (String pattern : PATTERNS) {
            try {
                return new SimpleDateFormat(pattern).parse(source);
            } catch (ParseException e) {
                // 继续尝试下一个格式
            }
        }
        throw new IllegalArgumentException("无法解析日期: " + source);
    }
}

/**
 * 注册转换器
 */
@Configuration
public class WebConfig implements WebMvcConfigurer {
    
    @Override
    public void addFormatters(FormatterRegistry registry) {
        registry.addConverter(new StringToDateConverter());
    }
}
```

### 6.2 @InitBinder

```java
@Controller
public class UserController {
    
    /**
     * 为当前 Controller 定制数据绑定
     */
    @InitBinder
    public void initBinder(WebDataBinder binder) {
        // 设置日期格式
        SimpleDateFormat dateFormat = new SimpleDateFormat("yyyy-MM-dd");
        binder.registerCustomEditor(Date.class, 
            new CustomDateEditor(dateFormat, true));
        
        // 设置不允许绑定的字段
        binder.setDisallowedFields("id");
        
        // 添加验证器
        binder.addValidators(new UserValidator());
    }
}
```

## 七、源码分析

### 7.1 DispatcherServlet.doDispatch

```java
protected void doDispatch(HttpServletRequest request, 
        HttpServletResponse response) throws Exception {
    
    HttpServletRequest processedRequest = request;
    HandlerExecutionChain mappedHandler = null;
    ModelAndView mv = null;
    Exception dispatchException = null;
    
    try {
        // 1. 检查是否文件上传请求
        processedRequest = checkMultipart(request);
        
        // 2. 获取 Handler
        mappedHandler = getHandler(processedRequest);
        if (mappedHandler == null) {
            noHandlerFound(processedRequest, response);
            return;
        }
        
        // 3. 获取 HandlerAdapter
        HandlerAdapter ha = getHandlerAdapter(mappedHandler.getHandler());
        
        // 4. 执行拦截器 preHandle
        if (!mappedHandler.applyPreHandle(processedRequest, response)) {
            return;
        }
        
        // 5. 调用 Handler，返回 ModelAndView
        mv = ha.handle(processedRequest, response, mappedHandler.getHandler());
        
        // 6. 设置默认视图名
        applyDefaultViewName(processedRequest, mv);
        
        // 7. 执行拦截器 postHandle
        mappedHandler.applyPostHandle(processedRequest, response, mv);
        
    } catch (Exception ex) {
        dispatchException = ex;
    }
    
    // 8. 处理结果（渲染视图）
    processDispatchResult(processedRequest, response, mappedHandler, 
        mv, dispatchException);
}
```

### 7.2 HandlerMapping 原理

```java
/**
 * RequestMappingHandlerMapping 注册映射
 */
public class RequestMappingHandlerMapping extends RequestMappingInfoHandlerMapping {
    
    @Override
    protected boolean isHandler(Class<?> beanType) {
        // 判断是否是 Handler（有 @Controller 或 @RequestMapping）
        return (AnnotatedElementUtils.hasAnnotation(beanType, Controller.class) ||
                AnnotatedElementUtils.hasAnnotation(beanType, RequestMapping.class));
    }
    
    @Override
    protected RequestMappingInfo getMappingForMethod(Method method, 
            Class<?> handlerType) {
        // 获取方法上的 @RequestMapping
        RequestMapping methodAnnotation = AnnotatedElementUtils
            .findMergedAnnotation(method, RequestMapping.class);
            
        if (methodAnnotation != null) {
            // 创建 RequestMappingInfo
            return createRequestMappingInfo(methodAnnotation, method);
        }
        return null;
    }
}
```

## 八、常见面试问题

### Q1: Spring MVC 的工作流程？
> 答：用户请求 → DispatcherServlet → HandlerMapping（查找 Handler）→ HandlerAdapter（调用 Handler）→ Controller（处理业务）→ ModelAndView → ViewResolver（解析视图）→ View（渲染）→ 响应。

### Q2: @Controller 和 @RestController 的区别？
> 答：@RestController = @Controller + @ResponseBody。@RestController 的方法返回值直接写入响应体，@Controller 返回视图名。

### Q3: 拦截器和过滤器的区别？
> 答：1）过滤器是 Servlet 规范，拦截器是 Spring MVC 的；2）过滤器依赖 Servlet 容器，拦截器依赖 Spring 容器；3）拦截器能获取 Spring Bean，过滤器不能；4）拦截器只能拦截 Controller 请求，过滤器能拦截所有请求。

### Q4: @RequestParam 和 @PathVariable 的区别？
> 答：@RequestParam 获取查询参数（?name=value），@PathVariable 获取路径变量（/users/{id}）。

### Q5: 如何处理全局异常？
> 答：使用 @ControllerAdvice + @ExceptionHandler 实现全局异常处理。
