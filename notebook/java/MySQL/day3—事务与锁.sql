-- 内容定位
select veseion();
SHOW VARIABLES like '%engine%';		-- 存储引擎
SHOW GLOBAL VARIABLES LIKE '%_isolation%';      -- 隔离级别


-- 事务定义
show variables like 'autocommit';  
-- begin / start transaction .   commit / rollback;  
set session autocommit =off/on   --0/1 JDBC  conn.setAutoCommit(false);
-- ACID  Atomicity  Consistency Isolation Durability

-- 事务隔离级别

select @@transaction_isolation	-- 查看session级别（Repeatable  /rɪˈpiːtəbl/ Read默认RR） 
SHOW  VARIABLES LIKE '%_isolation%';   --READ-COMMITTED
set session transaction isolation level read committed; -- 修改
--最好改回来：需要全局session 改成 global
set session transaction isolation level REPEATABLE READ;


-- TRX_ID 14.16.2.1 Using InnoDB Transaction and Locking Information  Identifying Blocking Transactions
CREATE TABLE `transaction_locking` (
  `a` int(11) NOT NULL AUTO_INCREMENT,
  `b` varchar(20) CHARACTER SET latin1 DEFAULT NULL,
  `c` varchar(20) CHARACTER SET latin1 DEFAULT NULL,
  PRIMARY KEY (`a`)
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8;
INSERT INTO transaction_locking VALUES (NULL,'Ti','Mi');

-- row_id 存在 与可见性问题   12可见  3不可见  https://dev.mysql.com/doc/refman/5.7/en/create-index.html
select _rowid from course;
select _rowid from order_detail;


-- Session A:  
BEGIN; 
SELECT a FROM transaction_locking FOR UPDATE;
 SELECT SLEEP(100);   

-- Session B:
SELECT b FROM transaction_locking FOR UPDATE;

-- Session C:
SELECT c FROM transaction_locking FOR UPDATE;
-- In this scenario, use the following query to see which transactions are waiting and which transactions are blocking them:
-- 5.7
SELECT
  r.trx_id waiting_trx_id,
  r.trx_mysql_thread_id waiting_thread,
  r.trx_query waiting_query,
  b.trx_id blocking_trx_id,
  b.trx_mysql_thread_id blocking_thread,
  b.trx_query blocking_query
FROM       information_schema.innodb_lock_waits w
INNER JOIN information_schema.innodb_trx b
  ON b.trx_id = w.blocking_trx_id
INNER JOIN information_schema.innodb_trx r
  ON r.trx_id = w.requesting_trx_id;
  
-- Or, more simply, use the sys schema innodb_lock_waits view: 

SELECT
  waiting_trx_id,
  waiting_pid,
  waiting_query,
  blocking_trx_id,
  blocking_pid,
  blocking_query
FROM sys.innodb_lock_waits;

-- 事务与锁的 实例 
-- 注意 begin ；
-- T1:初始两条数据 TianMing   James



begin;
SELECT * from   transaction_locking ;
INSERT INTO transaction_locking VALUES (NULL,'Jam','es');
SELECT * from   transaction_locking ;

-- T2:一个事务中查询多次
BEGIN;
SELECT * FROM   transaction_locking ;
-- T3:插入一条   自动事务 开始提交的 当然也可 begin; commit;确保效果
BEGIN;
INSERT INTO transaction_locking VALUES (NULL,'Tian','Ming');
COMMIT;
-- 这个时候到表数据看看，肯定是能查到刚增加的，但是先前T2的能不能查到呢？

-- T4: 删除一条
BEGIN;
DELETE FROM transaction_locking where a=1;
COMMIT;

--T5: 更新一条
BEGIN;
update transaction_locking set b='up' where a=1;
COMMIT;
-- 思考下 这里删除和修改的数据在哪个地方？ undo
-- 同一条数据多次改 会undo链表存这些多个版本的数据 具体怎么达到这个效果的呢？



-- Read View  一致性视图 存储内容

update transaction_locking set c ='ttt' where a=1;
begin; -- start transaction;
update transaction_locking set c ='ttt' where a=1;
rollback;




-- low-lever locking     ；Table-level locking 


-- Shared Locks ；Exclusive Locks；Record Locks；Intention Locks； Insert Intention Locks; Auto-inc locks  ;Predicate Locks for Spatial Indexs
-- 加锁方式
--  自动 insert update delete 默认加X锁   
--  select .... for update;        commit; rollback;

-- S锁
--加锁方式 select ... lock in share mode;
--  T1
begin; -- start transaction;
select * from transaction_locking where b="Ti" lock in share mode;

rollback;
--  T2
begin;  
select * from transaction_locking where b="Ti" lock in share mode;
delete from transaction_locking where b="Ti";
rollback;

-- X 锁   DML和for update
--  T1
begin; -- start transaction;
update transaction_locking set b="Tian"where b="Ti";

rollback;
commit;
--  T2
begin;  
select * from transaction_locking where b="Ti" lock in share mode;
select * from transaction_locking where b="Ti" for update;
delete from transaction_locking where b="Ti";
rollback;

SHOW VARIABLES LIKE 'innodb_lock_wait_timeout';

--  Intention Locks
--  T1
begin; -- start transaction;
select * from transaction_locking where b="Ti" for update;

rollback;
commit;

--  T2
begin; -- start transaction;
lock tables transaction_locking write;
unlock tables;


-- T3
CREATE TABLE child (id int(11) NOT NULL, PRIMARY KEY(id)) ENGINE=InnoDB;
INSERT INTO child (id) values (90),(102);

START TRANSACTION;
SELECT * FROM child WHERE id > 100 FOR UPDATE;
-- T4
START TRANSACTION;
INSERT INTO child (id) VALUES (101);
/*
SHOW ENGINE INNODB STATUS;
RECORD LOCKS space id 31 page no 3 n bits 72 index `PRIMARY` of table `test`.`child`
trx id 8731 lock_mode X locks gap before rec insert intention waiting
Record lock, heap no 3 PHYSICAL RECORD: n_fields 3; compact format; info bits 0
 0: len 4; hex 80000066; asc    f;;
 1: len 6; hex 000000002215; asc     " ;;
 2: len 7; hex 9000000172011c; asc     r  ;;...*/

-- Insert Intention Locks
insert into transaction_locking VALUES(7, '77', '777');
insert into transaction_locking VALUES(9, '99', '9999');

--  T1
START TRANSACTION;
select * From transaction_locking where a  > 7  for update;

rollback;
commit;

--  T2
START TRANSACTION;
insert into transaction_locking VALUES(8, '88', '888');

update transaction_locking set b = 88   where a = 8;



-- Auto-inc locks
SHOW VARIABLES LIKE 'innodb_autoinc_lock_mode%';


-- 意向锁 实例
begin; -- start transaction;
select * from transaction_locking where b="Ti" for update;
rollback;
commit;
--  T2
begin; -- start transaction;
lock tables transaction_locking write;
unlock tables;

-- 行锁实例  注意测试需要先关闭自动提交  set autocommit=0;     当然 你也可以每次begin一下
select * from transaction_locking -- 可见4条记录  1 3 6 9 
-- 测试Record锁   事务一

show variables like 'autocommit'; 
  set autocommit=0;   -- 默认自动提交   测试完最好改回去
select * from transaction_locking where a =1 for update;
-- 事务二 修改此行记录会等待锁
select * from transaction_locking where a =1 for update;
update transaction_locking set c='mi'  where a =1 ;

-- 测试 Gap锁  事务一  没有命中 则锁定 (4,6) 区间   阻塞插入的
select * from transaction_locking where a =4 for update;
-- 或者
select * from transaction_locking where a >3 and a<6  for update;
-- 事务二 想在此区间新增行 需等待锁
insert into transaction_locking values(4,3,4);

-- 测试 next-key 锁 事务一 (3,6] 和 (6,9]
select * from transaction_locking where a >3 and a<7  for update;
-- 事务二 修改此行记录会等待锁
select * from transaction_locking where a =1 for update;
update transaction_locking set c='mi'  where a =1 ;


-- 线上死锁问题如何定位和解决！怎么处理？
--避免方式：
--    顺序访问，数据排序避免环路，申请足够的级别锁（比如修改就别先加个读锁），避免没有where或者不命中索引（能等值最好）的操作，大事务分解小的，
--第一种情况 锁一行：start transaction;  -- 索引  X锁行

    		select * from TRANSACTION_locking where id=2 LOCK IN SHARE MODE; 
-- 下一个事务 无法去修改 这一行。 但可以修改其他行。
-- 第二种情况 where 过滤不用id有索引的字段    S锁表
    		select * from TRANSACTION_locking where b=2 LOCK IN SHARE MODE; 
-- 下一个事务 无法修改所有行
-- 第三种情况 for update 直接S锁表
-- 注意如果此表已有锁行也会加锁失败。

--解决方案5.6&5.7 设置可以看到此SQL持有锁信息 需开启super权限：
-- 能定位到id 看看逻辑是否可按避免方式处理，不能就只能kill trxid
-- The following table shows some sample contents of INFORMATION_SCHEMA.INNODB_TRX.
-- The following table shows some sample contents of INFORMATION_SCHEMA.INNODB_LOCKS.
-- The following table shows some sample contents of INFORMATION_SCHEMA.INNODB_LOCK_WAITS
SELECT * from INFORMATION_SCHEMA.INNODB_TRX;
SELECT * from INFORMATION_SCHEMA.INNODB_LOCKS;
SELECT * from INFORMATION_SCHEMA.INNODB_LOCK_WAITS;

-- 解决方案8
select @@pseudo_thread_id; 
select connection_id();
select * from INFORMATION_SCHEMA.INNODB_TRX;
SELECT * from PERFORMANCE_SCHEMA.data_locks;
SELECT * from PERFORMANCE_SCHEMA.data_lock_waits;
SELECT * from SYS.innodb_lock_waits










