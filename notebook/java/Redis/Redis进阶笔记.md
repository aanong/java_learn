# 咕泡教育-天明Redis进阶Day1

## 	课程内容：Redis数据类型及底层数据结构与应用场景

## 内容提要：

#### 1:  Redis概览及数据类型

​			特性：非关系型数据库基于内存    支持很多数据8种 常用 5种   ，集群  ，分片 ，主从 ，过期淘汰策略

​			为什么快？

​				基于内存 ，单线程，多路复用 ，key-value数据结构 底层 hash  quicklist 跳表等结构 ，

			命令：127.0.0.1:6379> keys *
			1) "keyA"
	2) "gupao"
	   127.0.0.1:6379> flushall
	   OK
	   127.0.0.1:6379> keys *
	   (empty list or set)
	   127.0.0.1:6379> set keyA  val 
	   OK
	   127.0.0.1:6379> expire keyA 2
	   (integer) 1
	   127.0.0.1:6379> exists keyA 
	   (integer) 0
	   127.0.0.1:6379> set keyA  val 
	   OK
	   127.0.0.1:6379> exists keyA 
	   (integer) 1
	   127.0.0.1:6379> type keyA
	   string
	   127.0.0.1:6379> object encoding keyA
	   "embstr"
	   127.0.0.1:6379> append keyA  aaa
	   (integer) 6
	   127.0.0.1:6379> get keyA
	   "valaaa"
	   127.0.0.1:6379> 


常用的数据类型 ： String ，List ，Set  ，ZSet(SortSet) ，Hash,   Hyperlog （基数统计） ，Geo（地理位置），Stream(流)

##### 			String

​					get  set    场景缓存

​					incr  递增  场景分布式ID   incrby  intKey  2  递增2

​					setnx    无则成功 有返回0    应用 新增

​					setxx  只有存在key才设置     应用修改

​			能干什么：缓存，场景分布式ID，新增，修改，分布式锁（setnx 会死锁  互斥，必须释放 expire   借助LUA脚本），限流

#### 2：使用场景及底层编码

​		object encoding keyA

​					String 数据编码 ：  

​							 int   存储8个字节长整型 long   2^64-1

​							embstr 动态字符串   SDS 存储(SDS 5    8   16  32  64)   44个字节（4.0之后，之前39） 但是append 之后 变成

​							raw  存储 大于44字节   最多能存 512M

​						

##### 			List : 有序能重复

​					lpush   rpush    lpop  rpop   lrange  blpop

​				  brpop  queue  10

​			应用场景：有序集合   抢红包 ，消息队列，

​			object encoding queue 

​					ziplist  压缩列表  entry   +  QuickList 里面是有node结构  指向 zipList  .最后一个节点柔性的数据

​					list存会有磁盘碎片 所以用上面的。



##### 		Hash：

​				hset  hget  hincrby  单独对key 加多少   hexists  

​					应用场景：统计(PV)浏览量  (UV)自然人数 购物车

​								id 1  orderNO       订单商品商品+1的时候   hincrby  1  orderNO  1

​			object encoding h

​					第一种情况  ziplist     Hash键值对 <512 个 ，元素大小 <64byte 时候

​					第二种情况  dict字典

​							dict   dicth   table   entry   



##### 		Set  无序 不能重复

​				sadd   smembers   sdiff   sinter  sunion

​				应用场景：抽奖  浏览 点赞 评论 互关     交集  并集   差集

​		

​		object encoding 

​				inset  元素是整型  且长度 不超过512  

​				hashTable

​			

##### 		ZSet  有序的集合

 					zadd  zrange     zrevrange   [withscores]    zincrby    zrank   zscore 

​					如果 score 相同 按ASI码判断

​			应用 ：绩效排行  

​				object   

​						zipList   默认  

```
            # 元素个数 大于128
            zset-max-ziplist-entries 128
            # ziplist 长度大于 64个字节
            zset-max-ziplist-value 64
            		就会转跳表
```

​							skipList   HashTable

​					



​		

#### 3：底层数据结构解读

​			String     SDS   512M  

​			List   zipList   +  quickList     

​			Hash  dict字典   >  dictht 哈希表   > dicEntry[]* > dictEntry   > obj > redisObject

​		

















# 咕泡教育-天明Redis进阶Day2

## 	课程内容：数据结构源码，过期策略，淘汰策略

## 内容提要：

#### 1：数据结构源码解析：

​			快：内存 key-value 单线程  多路复用   hash桶 quicklist 跳表 

​			数据类型： 5  + 3    

​					String   缓存 分布式锁/ID     int 长整型     embstr  编码>数据结构sds   44字节 》    raw   512MB

​					Hash  重入锁 购物车    ziplist      512    64字节   >   hashTable (dict > dictch > table > entry )

​					List  消息队列  ziplist  +  quickList

​					Set  抽奖 交集并集差集   intSet 长整型    512 >   hashTable

​					ZSet 排行榜   ziplist  如果元素个数128 或者 长度64字节   跳表

#### 2：过期策略：

​			maxmemory  

​			redis最大内存 ？    默认 32位系统  3G   。64 直到满

​			超出怎么办？      默认不淘汰 直接OOM   可以查不能插



​			expire    key   seconds

​					set key  value  ex  seconds

​					expireat key  seconds 	

​					pexpireat key seconds  内部最终都会转换成       presist key(移除)

​				

假如 你的冰箱满了？

​			怎么知道过期  丢掉哪些？

​			轮循 只看有过期特性的

​			 看生产时间 哪些快过期

​			 吃的频率   

​			 随机



​				1:惰性（被动）过期：访问数据的时候看是否过期

​				2:定期过期 ：每隔一段时间去检查快过期的（设置了过期时间） 

​						默认100MS 一次   配置 redis.conf  hz 10

​		

​			1:惰性过期 

​						



#### 3：淘汰策略：

​			![Redis流程图（过期策略，淘汰策略，缓存机制，分布式锁） (1)](D:\soft\Redis流程图（过期策略，淘汰策略，缓存机制，分布式锁） (1).png)







# 咕泡教育-天明Redis进阶Day3

## 	课程内容：持久化原理&哨兵&集群&分布式锁等面试题

## 内容提要：

​	过期策略： 主动 被动  

​						  hz  每秒每秒10     根据 hash桶 20 / 400桶  然后做删除  10%  16次  25ms  

​				淘汰策略：

​						novication  不会淘汰

​						LRU  （allkeys / volatite ）  24bit     if service.lru > obj.lru       -      !    service.lru + 24.bit - obj.lru

​						LFU（allkeys / volatite ）    16bit时间 + 8bit 次数     加： 255   5  必然+1  factory  

​																								减： lfu-decay-time默认1分钟一次

​						Random（allkeys / volatite ）

​						ttl



#### 1: 持久化机制

##### 			RDB   类似于 bin-log

​						主动： shutdown   . flushall (备份是一个空rdb文件)

​								save命令 （会阻塞）

​							bgsave  会后台开启RDB进程

​						被动：

```
save 900 1   //900s 有一个key更改
save 300 10
save 60 10000
//多个 配置项 ，任意一个满足都会触发
```

​			优势：快 主从同步RDB

​			劣势：可能丢失 

##### AOF     

手动触发：bgrewriteaof       / rewriteaof



自动触发：

```
appendonly no    //yes就开启    如果开启 默认AOF了 但是 RDB也会进行备份
appendfilename "appendonly.aof"

# appendfsync always   //每一条记录修改 传输
appendfsync everysec  //默认(折中方案) 每秒记录aof文件做备份 
# appendfsync no	//由操作系统决定 30s

```

毕竟redis ，强一致性不是最重要的   

​		问题：文件太大怎么办？

​		解决方案：重写机制  rewrite   

​					4.0之前     lpush  t  a     ;  lpush  t  b c s ;  lpop ;       重写  lpush  a  b c ;   效率低 ，需要判断

​					4.0之后     启用 RDB + AOF 混合模式  。文件前面部分RDB二进制 后面 AOF命令形式

​				

```
aof-use-rdb-preamble yes   //默认 启用 RDB + AOF 混合模式 
auto-aof-rewrite-percentage 100 // 重写的百分比必须比上次重写文件大 100%
auto-aof-rewrite-min-size 64mb  //最开始 文件必须大于64MB
//假如  第一次   64MB   触发重写   文件可能变成20MB   ，下次重写 40MB

```

​			优点 ：安全性更好  （1s  或者 1条）

​			缺点：恢复速度慢

```
no-appendfsync-on-rewrite no    //主进程写  子进程不能重写aof    。  不会丢失，但会阻塞   
```



#### 2：主从与哨兵机制，Cluster集群

##### 		主从 配置：

```
# replicaof <masterip> <masterport>
# masterauth <master-password>
```

​			命令 ：  replicaof  ip  6379

​						slaveof  ip  port

​	主从数据同步 ？；一致性问题？     

​				1，连接主机  

​				2，数据同步  (原本有数据 ？ 会先干掉自己的再同步)

​					全量同步： 从发起sync的指令 给 master  ， 主节点bgsave 生产最新 rdb文件 ，然后传输 从 ，从拿到做恢复       

​					增量同步：master 在同步的时候有新的更改，写master缓存区，当恢复之后再追加的形式发送命令给slave节点  client-output-buffer-limit 超出会断开从连接

​			      主节点 有任何修改 都会以命令发送给从节点  server.c 的 propagate  方法 

​				 每秒还会去刷是否同步   源码 ：replication.c  的 replicationCron 方法

​				

为了高可用  ，主节点挂了怎么办？

##### 		哨兵机制 :作为过渡方案

​				脑裂的问题：可能会导致数据丢失   

​					主节点下线： 主观下线 （哨兵认为主节点挂了）     ；  被动下线（其他哨兵大多数认为主挂了）

​			哨兵一定配置奇数 。

​		只能一个主 。  

#####    所以需要 Cluster集群   3.0自带

​			多主多从 

​			解决分片方案 ：  hash取模     存在 分布不均  

​										虚拟hash槽  16384 

​						             	     如果 有三个节点 ，会平均分配到hash槽位上 ， 

​											set  keyA  valA  ； 会根据 keyA 取模 判断值在哪个区间 ，再顺时针找到一个主节点

​			选举机制：

​					1.断开时间

​					2.replica-priority 100    越小优先级越高

​					3.offset 偏移量 越小越有机会

​					4.进程ID(runid)  越小越有机会



​	

#### 3：分布式锁，缓存雪崩，缓存穿透，缓存击穿

##### 		分布式锁：

​	setnx + lua + expire 

​			redission 封装 分布式锁 

​					流程 ：  1.如果有设置过期时间 lua加过期时间     ，

​								2，如果没有设置过期时间  ，用看门狗机制 

​			（默认给你30s，每隔10S查看是否处理完，没有处理完再续时30s）

​					为什么要看门狗，而不是等我处理完自动去释放？

​							业务处理过程中 挂了 。永远得不到释放    判断 线程ID的Key是否存在来判断是否完成



```
if (redis.call('exists', KEYS[1]) == 0) then redis.call('hset', KEYS[1], ARGV[2], 1); redis.call('pexpire', KEYS[1], ARGV[1]); return nil; end; if (redis.call('hexists', KEYS[1], ARGV[2]) == 1) then redis.call('hincrby', KEYS[1], ARGV[2], 1); redis.call('pexpire', KEYS[1], ARGV[1]); return nil; end; return redis.call('pttl', KEYS[1]);
```



##### 缓存雪崩，

​		*大量*的热数据同时失效  。

​		怎么办：热点数据过期时间错开 ，  热的数据不设置过期时间

​	

##### 缓存穿透，

​			大量请求缓存**没查询到**，直接到数据库 。

​		  怎么办：布隆过滤器 （能判断一定不存在，不能判断一定存在），

​					如果不存在查询数据库写入缓存，如果数据库也不存 ， 再设置短暂null对象放到缓存 



##### 缓存击穿,

​				单个热点数据某一个时刻失效，*恰好大量针对此数据请求*来了

​			怎么办：热的数据不设置过期时间   ，预热一下 



redis 特性：  快  ？  数据类型 ？ 应用场景？ 编码  ？  底层数据结构 ？

​		淘汰策略  ？  过期策略？

​		持久化机制 ？  分布式事务锁？

​		主从 ？ 哨兵   ？ 集群 ？



1.判断有没有过期时间    

如果设置了过期时间，在过期时间内提前完成业务会提前释放锁吗？如果在过期时间内没有完成业务会续时长吗

​		理论 上  按设置的过期时间来把控锁

​		所以不设置
