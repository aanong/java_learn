# 《记得喊我录播》

# Mybatis源码分析

# 初始化

1.解析我们的配置文件（mybatis-config.xml）

- setting,cacheenable标签
- 解析我们的插件

2.得到我们config里面的mappers的配置，解析mapper文件

3.解析mapper文件里面的增删改查

4.把我们的增上改查封装成一个mapperstatement,并且放入到Map

key:namespace+sqlid 

value:statement



namespace能不能重复，sql id能不能重复？

namespace充不重复没关系，id也没关系

再一个namespace中，id不能重复

如果namespace相同，则id重复



# 创建会话

1.确认我们的执行器SIMPLE, REUSE, BATCH

什么叫预编译处理？mysql对于sql的处理

2.判断一个缓存的开关（config中的setting cacheEnable）默认

3.如果开启的话，返回的就不是基本执行器，而是缓存执行器CachingExcutor

3.执行插入逻辑



# 语句执行

1.根据我们的接口的class对象拿到MapperProxyFactory

2.再拿到一个代理对象

3.所有的接口访问方法都会去调用MapperProxy的invok方法

4.查询mapperstatement,里面有很多信息，包括sql语句

5.如果你开启了缓存，走到CachingExecutor,否则走BaseExcutor

​	二级缓存默认开启，config中可以关闭，就算开启，也要通过mapper控制

   二级缓存config和mapper有关系       二级缓存跟着namespace

6.一级缓存呢？一级缓存是跟sqlsession有关，默认开启

# mybatis有一个插件

1.Excutor:我要查看mybatis的sql执行过程

2.ParameterHandler我要修改他的参数

3.ResultSetHandler我要拦截返回值

4.StatementHandler我要进行分页





