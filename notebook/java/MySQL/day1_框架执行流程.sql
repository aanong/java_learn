-- 情况
select version();
show databases;
use test;
desc gupao_user;
show create table gupao_user;

-- 简单query
SELECT * FROM `gupao_user` WHERE NAME="天明";
-- mysql 多少个连接呢？  5.1.9 Server Status Variables
show global status like 'Thread%';

-- 非交互式超时 如 jdbc程序  5.1.7 Server System Variables
show global variables like 'wait_timeout%'; 
-- 交互式超时 如 数据库工具
show global variables like 'interactive_timeout%';

-- 连接数/并发数
show global variables like "max_connections";
-- 缓存
show  variables like 'query_cache%';

-- Parser 词法 语法
HiTianMing;
-- Pre processor  语法正确但词义不对
SELECT * FROM hitianming;

-- optimizer   数据库查询优化器的艺术原理解析与SQL性能.pdf （100+MB）
-- 如果创建联合索引  sex name   基于成本
SELECT * FROM `gupao_user` WHERE NAME="天明" and sex="男";
-- 性能优化之profiles 5.037 引入sql诊断工具 
show variables like '%prof%'
set profiling=1;
show profiles;
show profile for query 10;
-- 查询次数
show global status like "com_select";
-- 性能优化之explain
EXPLAIN  SELECT * FROM `gupao_user`;
-- 详细json信息  cost成本
EXPLAIN   format=json SELECT * FROM `gupao_user`;

-- 性能优化之 optimizer_trace
show variables like  "optimizer_trace";
set optimizer_trace = 'enabled=on';
select user,host from mysql.user;
-- steps   :  join_preparation   （sql准备阶段） -  join_optimization/,ɑptəmɪ'zeʃən/ （SQL优化阶段）  -join_execution ( SQL 执行阶段)
-- 不知道路径先 show VARIABLES like "datadir";  mysql -uroot -p; 123456 再执行
-- 注意客户端工具哪怕开启steps也是 null
select * from information_schema.OPTIMIZER_TRACE \G
-- 三表不同存储引擎 文件
-- 可设计或alter 修改引擎 alter table table_name engine=innodb; 
-- 为什么这么多种呢？ 区别？Alternative Storage Engines 
SHOW ENGINES\G
-- 面试特性比较 Table 15.1 Storage Engines Feature Summary、
-- innodb 服务状态 再深入就是索引 事务 和缓存池分别可一小时+
show  engine innodb status; \G
-- 磁盘IO log  缓存 最终结果


-- 磁盘IO 块  页大小
SHOW GLOBAL STATUS LIKE '%innodb_page_size%'
-- 缓存区 刷脏

-- redo log 重做
 SHOW VARIABLES LIKE 'innodb_log%'
-- \Data目录下的ib_logfile0 和 1固定大小， 满则触发buffer pool
-- undo log 总体架构图InnoDB Architecture  https://dev.mysql.com/doc/refman/5.7/en/innodb-architecture.html
 show global status like '%undo_%';
show global variables like '%undo%';
-- bin log ; my.cnf中配置 log-bin=mysql-bin  不同版本关闭情况
show variables like "%bin%";  
show variables like "log_bin";
-- 默认存放在mysql/data/目录
show binary logs;

-- show master logs; flush logs; reset master;
-- 可通过 二进制插件 或 mysqlbinlog 全备份与恢复 pdf 详解
show binlog events\G; --show binlog events in 'SHENZ-bin.000011' \G;

-- doUpdate buffer_pool
SHOW VARIABLES LIKE 'innodb_buffer_pool%';
-- redo log
SHOW VARIABLES LIKE 'innodb_log%';
-- where  ib_logfile0 1  
show VARIABLES like "datadir" ;
-- 刷盘策略
 show VARIABLES like "innodb_flush_log_at_trx_commit" ; -- 刷redolog 机制： 默认1，其他0 ，2
 show VARIABLES like "sync_binlog"  -- 刷binlog 机制：默认1每次提交都写 （5.6=0）

-- 自适应hash index 
 show VARIABLES like "%hash_index%" ;
show engine innodb status ;   -- Hash table 大小 ， 使用数   没有命中

















