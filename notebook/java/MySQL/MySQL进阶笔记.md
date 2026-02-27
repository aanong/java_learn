# 咕泡教育-天明MySQL进阶

## 	课程内容：Day1-MySQL架构与SQL执行流程

## 内容提要：



##### 1.MySQL全揽

​			历史：1996.内部1.0   10月发布3.11

​						2000 开源  ISAM 升级 MyISAM 

​						2003 4.0集成 InnoDB ，   

​						2010  5.5 InnoDB 成为默认存储

​						2016  8.0release 版本   2018   8.0正式版



##### 2.MySQL架构

​				![image-20220216204256339](C:\Users\LX\AppData\Roaming\Typora\typora-user-images\image-20220216204256339.png)





##### 3.SQL执行流程

​			参数：status   variables

​			Thread   连了多少

show GLOBAL variables like '%wait_time%'     -- 交互式JDBC     连接超时 8小时

interactive_timeout   -- 客户端工具

​	max_connections



​	

​		client  >  query_cache(8.0 remove  ) 

​				字符串去匹配  数据变更也不行

​			>  parser  此法语法

​		>pre processor 预处理   语义

​		>optimizer 优化器    子查询优化，条件优化，外连接 嵌套连接消除

​				基于cost_info

​				show GLOBAL variables like "%optimizer_trace%" 

set @@session.optimizer_trace='enabled=on,one_line=on'

​		>explain  执行计划

​		>executor 执行器

​		>InnoDB >Buffer Pool> DB.file



​		三大特性

​				adaptive hash index   自适应hash索引。

​						show variables like '%adaptive_hash_index%';    

​						show engine innodb status;

​						如果用二级索引，频繁（3次==查询。 >=不行）等值查询 ，自动创建hash 结构索引 



​				Buffer Pool 缓存区

​						传统的OS Cache的缓存区  LRU 先进后出   （1秒内还保持热度 再次访问）  

​								问题：可能会把热点数据刷掉  ， MySQL  Page页（innodb_page_size） 16KB  ,操作系统块4K 预读3块

​					innodb_old_blocks_pct  5/8   3/8



##### update 语句

​				三大日志：

​								Redo log  重做    %innodb_log%      48M  2个 环

​								Bin-log  备份恢复  
​								Undo log 回滚     

​			

​					刷盘策略（刷脏）：	page页可能出现 部分成功 部分失败的数据没有到redo log 

​							解决方案：doublewrite   第一次在写redolog(prepare)的时候 ，第二次是在真实修改数据库文件的时候

​					二阶段提交     写完bin-log之后 发起标记 redo-log 为commit状态



​				DoubleWrite Pool 双写缓存  ：目的 是解决刷脏 部分页失败的情况。   

​						doublewrite 2M 8.0之前共享表空间。之后系统表空间。第一次是在写redo的时候(prepare)  ，第二次是更新db file 数据的时候

​			

​			刷盘默认策略1 ：每次事务

​				0 ，每秒刷

​				2，每次事务刷到 OS cache，再通过操作 每秒刷



​			为什么要二阶段提交  Redo 。

​			bin-log  和 redo-log 的区别。

​					 redo 可能覆盖历史   ，bin（DDL DML）是追加  ，

​					bin没法确定是否落库     







##### 			update语句串起来

​					id =1  age=18         >     update  age =19

​					先查数据

​					看有没有cache    语法解析器  预处理器  优化器  执行计划  执行器

​					buffer pool  ,

​					DB file(18)   > buffer pool   (age =18)

​					undo-log  (age=18)

​					 > buffer pool   (age =19)

​					redo-log （prepare） 

​							> doublewrite 2M 

​					bin-log （发起线程去标记redo 为commit）

​					修改DB file 

​							>doublewrite 

​					![image-20220216223541458](C:\Users\LX\AppData\Roaming\Typora\typora-user-images\image-20220216223541458.png)

​					



# 咕泡教育-天明MySQL进阶

## 	课程内容：Day2-从数据结构深入与MySQL索引到优化实战应用

## 内容提要：

##### 1.MySQL索引的底层数据结构

​			链表    查询效率o(n)  插入快

​			二叉树   递增递减 斜树 

​			平衡二叉查找树 (AVL)  通过左右旋达到平衡       page页浪费  16K

​			多路平衡查找树B-Tree     顺序查询效率不高， 遍历表效率低，树的高太高>IO次数还是太多

​			 B+Tree      特点：1,非叶子节点只存 key(索引的字段) + point（指针）

​											2,叶子节点有一个双向的链表

​											3.所有行数据都放在 叶子节点   （聚集索引）

​								优势：就是B-Tree的劣势的改进



​			谁做为聚集索引。

- When you define a `PRIMARY KEY` on a table, `InnoDB` uses it as the clustered index. A primary key should be defined for each table. If there is no logical unique and non-null column or set of columns to use a the primary key, add an auto-increment column. Auto-increment column values are unique and are added automatically as new rows are inserted.
  - 如果有主键就是主键作为聚集索引
- If you do not define a `PRIMARY KEY` for a table, `InnoDB` uses the first `UNIQUE` index with all key columns defined as `NOT NULL` as the clustered index.
  - 若没有主键 找第一个唯一非空的索引作为聚集索引
- If a table has no `PRIMARY KEY` or suitable `UNIQUE` index, `InnoDB` generates a hidden clustered index named `GEN_CLUST_INDEX` on a synthetic column that contains row ID values. The rows are ordered by the row ID that `InnoDB` assigns. The row ID is a 6-byte field that increases monotonically as new rows are inserted. Thus, the rows ordered by the row ID are physically in order of insertion.
  - 若上面两种都没有  用row_id 这个隐藏字段 

​	

​		Hash 结构索引：查询o(1),      无序，Hash碰撞

​		

​		 B-Tree  ， B+Tree  ，Hash

##### 2.索引的结构设计能带来哪些优势



###### 		二级索引  ：

 二级索引的叶子节点不放data 放  聚集索引的 值

​					那怎么找到 row data  ？   

###### 					回表： 

​			 假如  在名字 字段创建了索引  。  通过name 来查询 他电话号码 ？

​								过程 需要先走二级索引 找到改名字的ID ，再走聚集索引找到row data

###### 					覆盖索引： 

通过二级索引 能找到所有需要的信息  （where  条件    select 值  order  group）

​								标志： extra     里面 Using index

​								尽量避免多次回表，用覆盖索引

​				最左匹配原则：  name  like '%名'       可以右  '天%'   

###### 				索引下推：（ICP）   

​		Using index condition   5.6[ Index Condition Pushdown Optimization](https://dev.mysql.com/doc/refman/5.7/en/index-condition-pushdown-optimization.html)

​						目的：为了减少回表查询的次数  ，提高查询效率

​							 将 Server 层过滤的事情  下推个 Strorage 来过滤

​							





##### 3.索引的使用误区及优化

​			不是越多越好    ，频繁查询的    组合比较多的联合索引   *   ，列的离散度

​				or 条件最好 换成多个 union all 

​				in  换成 between   and  和 exist



​		失效的场景 ：   模型数空运最快。

​				模糊   like   %name

​				数据类型   类型转换

​				函数    TO_DAS(create_date)

​				null 值   （5.7 ref_or_null  ）

​				运算   +-/*

​				最左匹配

​				遍历整个表 比 你走索引还快  。 （5.7  33%    8.0看优化器的cost）



​      

explain select  name,id,phone FROM user_innodb where name like '%AA';
--  走不走索引  key
--  回表  NO 
--  要不要 ICP 

![image-20220218215536700](C:\Users\LX\AppData\Roaming\Typora\typora-user-images\image-20220218215536700.png)





# 咕泡教育-天明MySQL进阶

## 	课程内容：Day3-MySQL事务与锁

## 内容提要：

#### 1.事务并发造成的问题及场景

​			定义：数据管理系统逻辑单位，要么都成功要么都失败

##### 					ACID ：

  原子性 ：原子最小单元  ，可以设置savepoint 回滚点   （通过 undo log）

  一致性 :最终都是为了确保 

​	隔离性  ：不同事务之间相互隔离  （通过事务）

   持久性：数据持久化  （redo +  bin）

##### 			并发的问题：

脏读、在内存里数据 被读到了 ，读未提交     

不可重复读、读取的时候另一个事务修改或删除了 并且已经提交。读已提交

幻读，读取的范围 时候另一个事务插入新的数据 

​	

#### 2.事务隔离级别与解决方案，MVCC的原理

​		

```
_Level__________________			P1______P2_______P3________________________

        | READ UNCOMMITTED     | Possib|e Possib|e Possible                |
        |       |        |                          |
        | READ COMMITTED       | Not   | Possibl| Possible                 |
                                 Possible

        | REPEATABLE READ      | Not   | Not    | Possible                 |
        |                      | Possib|e Possib|e                         |
        |                      |       |        |                          |
        | SERIALIZABLE         | Not   | Not    | Not Possible             |
        |______________________|_Possib|e_Possib|e_________________________|
```

InnoDB  RR 的隔离级别   解决了幻读  

​			MVCC  + LBCC 

​			一个事务 能看到 ：当前事务第一次查询前 已提交的 内容 还有当前事务更改的内容。

​			一个事务 不能看到：当前事务第一次查询之后的事务更改的内容，还在活跃中的事务的更改

​								只有第一次查询创建 ReadView

​		RC 隔离级别 ：每一次查询都会创建一个 ReadView 

​				Oracle   只有两种  默认 RC 

​		

- A 6-byte `DB_TRX_ID` 事务ID 
- A 7-byte `DB_ROLL_PTR` 回滚字段
- A 6-byte `DB_ROW_ID` 行隐藏字段





ReadView 





#### 3.锁的分类及原理 & X锁S锁 & 行锁的区间划分



#### 4.不同情况的查询对应锁的内容及死锁调优实战

​		

undo_log    TRX_IDs[]   

ReadView   TRX_ID   创建的事务ID ,     能看到的事务 ID ，不能看到的事务ID 



![image-20220220210821587](C:\Users\LX\AppData\Roaming\Typora\typora-user-images\image-20220220210821587.png)

  当前事务  ID  20  

​		m_ids{}   当前事务创建的时候 还在活跃的事务ID

​		up_limit_id   当前事务能看到 比这个还小的   (事务ID > = 高水位 （m_low_limit_id）  不可见)

​		low_limit_id  当前事务不能看到 比这个还大的

​		在 up_limit_id   low_limit_id    之间的 ，看是否在 m_ids{} 中 。如果在不可见 ，如果不在 能看到

​				如果上面都不行  undo_log

​			![image-20220220221834418](C:\Users\LX\AppData\Roaming\Typora\typora-user-images\image-20220220221834418.png)



 拓展：

![image-20220220212827730](C:\Users\LX\AppData\Roaming\Typora\typora-user-images\image-20220220212827730.png)



##### 4.锁 

- [Shared and Exclusive Locks](https://dev.mysql.com/doc/refman/5.7/en/innodb-locking.html#innodb-shared-exclusive-locks)
  - 共享锁S(读锁)    排他锁 X(写锁) 互斥
- [Intention Locks](https://dev.mysql.com/doc/refman/5.7/en/innodb-locking.html#innodb-intention-locks)
  - 意向锁     表级别的     锁行的时候加一个 意向锁表的标记  。   目的提高表锁效率
  - [Record Locks](https://dev.mysql.com/doc/refman/5.7/en/innodb-locking.html#innodb-record-locks)  记录锁 。通过索引查询命中记录，锁定这一行记录 ，
    - ​		比如：  1   ，  3  ， 5    查询3     锁定 3     主要解决不可重复读的问题，避免修改此记录
  - [Gap Locks](https://dev.mysql.com/doc/refman/5.7/en/innodb-locking.html#innodb-gap-locks)  间隙锁 。通过索引查询没有命中记录  ，锁定该区间  ，双开
    - ​				比如：  1   ，  3  ， 5    查询2     锁定 (1,3)       主要幻读的问题
  - [Next-Key Locks ](https://dev.mysql.com/doc/refman/5.7/en/innodb-locking.html#innodb-next-key-locks) 临建锁   左开右闭    ，下一key
    - ​	 比如：  1   ，  3  ， 5  ,  8  查询  id< 4   锁定     (1,3]  + (3,5]

- [Insert Intention Locks](https://dev.mysql.com/doc/refman/5.7/en/innodb-locking.html#innodb-insert-intention-locks)
- [AUTO-INC Locks](https://dev.mysql.com/doc/refman/5.7/en/innodb-locking.html#innodb-auto-inc-locks)
  - 自增字段  （5.7 策略1    。8及之后 2）
    - ​	1.每次锁表    2，获取批量的锁，并提前释放     3不会锁表
- [Predicate Locks for Spatial Indexes](https://dev.mysql.com/doc/refman/5.7/en/innodb-locking.html#innodb-predicate-locks)

​			谓语锁   : 在 S 基本  next-key没法正常索引 的有效性 会产生此锁



   InnodDB   row_lev    MyISAM   table_lev





锁的 优化  ：

​			避免： 通过索引 做事务的修改      尽量 缩小锁的范围    大事务改多个事务 避免死环

​			业务场景 锁表    事务死锁。 

​			怎么办？    

​				定位问题：   

					5.7          
	                select * from  information_schema.Innodb_trx ; 
	                  select * from  information_schema.Innodb_locks   ;
	 select * from  information_schema.Innodb_lock_waits;
	 
	 			8.0
	 			select * from  information_schema.Innodb_trx ; 
			select * from  `performance_schema`.data_locks   ;
			select * from  performance_schema.data_lock_waits;
	 
	 
	 查询当前session、    thread
	 		
	 
	 
	 


​					  8

​				尽量解决死锁，或者先记录下死锁的部分 	 最终 kill 线程    再单独的跑















