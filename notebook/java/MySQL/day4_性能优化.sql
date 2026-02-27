

-- 查看连接数
 show global status like 'Thread%';
 
-- 非交互式超时 如 jdbc程序
show global variables like 'wait_timeout%'; 
 -- 最多连多少呢？
 SHOW GLOBAL VARIABLES LIKE 'max_connections';
 
-- 交互式超时 如 数据库工具
show global variables like 'interactive_timeout'; 

-- 数据库连接池  c3p0 dpcp  Druid/'dru:id/为监控而生    hikari /hik/   hai，karui 你好卡里 光速的意思

--  查询优化器 慢日志相关
 show variables like 'slow_query%';
-- show VARIABLES like "datadir";
--查看（虚拟机）安装路径   /var/lib/mysql/  
cd /var/lib/mysql/   -- 到安装目录
mysql -uroot -p  --登录

--可以通过 ：   命令去查看my.conf所在路径        /usr/share/mysql 目录
mysql --help | grep my.cnf 
-- 多长时间为慢  正常200 
SHOW VARIABLES LIKE 'long_query_time';
-- 到目录查看慢日志文件
cd /var/lib/mysql/
vi shenz-slow.log


-- 连虚拟机 看下 解析慢查询的工具     perl    在哪里
whereis mysqldumpslow
-- 查看帮助
mysqldumpslow --help

-- 统计查询最慢的十条select 语句  slow-query.log
mysqldumpslow -s t -t 5 -g 'select' /var/lib/mysql/slow-query.log

-- SQL 诊断工具  5.037版本
select * from gupao_user;
show profiles;  for query 11;
-- 延伸DBA性能诊断借助？performance_schema  information_schema
show variables like 'performance_schema';
show tables like '%setup%';
SHOW PROCESSLIST; -- 线程情况。
-- 可以排序过滤结果更加多样化。
SELECT * FROM information_schema.processlist; 

-- 第一个服务状态   
show [global][session] status; 

-- 常用的 比如系统执行了多少select 语句呢？
SHOW GLOBAL STATUS LIKE 'Com_select'
-- 主要查看各种引擎的状态
 show engine innodb status; 

-- 查询mysql课程的老师手机号


DROP TABLE IF EXISTS course;
CREATE TABLE `course` (
 `cid` INT(3) DEFAULT NULL,
 `cname` VARCHAR(20) DEFAULT NULL,
 `tid` INT(3) DEFAULT NULL
) ENGINE=INNODB DEFAULT CHARSET=utf8mb4;

DROP TABLE IF EXISTS teacher;
CREATE TABLE `teacher` (
 `tid` INT(3) DEFAULT NULL,
 `tname` VARCHAR(20) DEFAULT NULL,
 `tcid` INT(3) DEFAULT NULL
) ENGINE=INNODB DEFAULT CHARSET=utf8mb4;

DROP TABLE IF EXISTS teacher_contact;
CREATE TABLE `teacher_contact` (
 `tcid` INT(3) DEFAULT NULL,
 `phone` VARCHAR(200) DEFAULT NULL,
  `tid` INT(3) DEFAULT NULL
) ENGINE=INNODB DEFAULT CHARSET=utf8mb4;

INSERT INTO `course` VALUES ('1', 'mysql', '1');
INSERT INTO `course` VALUES ('2', 'jvm', '1');
INSERT INTO `course` VALUES ('3', 'juc', '2');
INSERT INTO `course` VALUES ('4', 'spring', '3');

INSERT INTO `teacher` VALUES ('1', 'tianming', '1');
INSERT INTO `teacher` VALUES ('2', 'james', '2');
INSERT INTO `teacher` VALUES ('3', 'mic', '3');
INSERT INTO `teacher` VALUES ('4', 'tom', '4');
INSERT INTO `teacher_contact` VALUES ('1', '15966668888','1');
INSERT INTO `teacher_contact` VALUES ('2', '18166669999','2');
INSERT INTO `teacher_contact` VALUES ('3', '17722225555','3');
INSERT INTO `teacher_contact` VALUES ('4', '18166669998','4');
INSERT INTO `teacher_contact` VALUES ('5', '17722225557','1');


-- 查询课程ID为2，或者联系表ID为3的老师  simple
EXPLAIN SELECT t.tname,c.cname,tc.phone
FROM teacher t,course c,teacher_contact tc
WHERE t.tid = c.tid
AND t.tcid = tc.tcid
AND (c.cid=2 OR tc.tcid=3);


-- 查询mysql课程的老师手机号  primary ，subquery 
EXPLAIN SELECT tc.phone FROM teacher_contact tc
	WHERE tcid = (
		SELECT tcid
		FROM teacher t
		WHERE t.tid = (
			SELECT c.tid
			FROM course c
			WHERE c.cname = 'mysql'
		)
	);
-- 查询天明 和 教jvm 老师的联系方式  PRIMARY ，DEPENDENT SUBQUERY  ，DEPENDENT UNION
EXPLAIN SELECT * FROM teacher_contact WHERE tcid IN (
	SELECT tcid FROM teacher WHERE tname = 'tianming' 
	UNION SELECT tcid FROM course WHERE cname = 'jvm'
);
 
-- 查询ID为1或2的老师教授的课程  PRIMARY ，DERIVED ，UNION ，UNION RESULT
EXPLAIN SELECT cr.cname FROM (
	SELECT * FROM course WHERE tid = 1
	UNION
	SELECT * FROM course WHERE tid = 2
) cr;

-- 索引 ALTER TABLE teacher_contact DROP PRIMARY KEY;
ALTER TABLE teacher_contact ADD PRIMARY KEY(tcid); 
-- 索引 ALTER TABLE teacher DROP INDEX idx_tcid;
ALTER TABLE teacher ADD INDEX idx_tcid (tcid);
-- 索引 ALTER TABLE teacher DROP INDEX idx_tid;
ALTER TABLE teacher ADD INDEX idx_tid (tid);
-- Type   通过主键查询的语句。
-- system 一条数据 type是system(5.7MyISAM 8>innodb)
EXPLAIN SELECT * FROM mysql.proxies_priv; 
-- 一条数据 type 是all 
EXPLAIN SELECT * FROM information_schema.INNODB_BUFFER_POOL_STATS;
-- const 主键唯一常量 
EXPLAIN SELECT * FROM teacher_contact WHERE tcid=1
-- eq_ref  作为被驱动表 右表/后面那张表是通过主键或唯一非空索引查询的
EXPLAIN SELECT t.tcid FROM teacher t ,teacher_contact tc WHERE t.tcid=tc.tcid;
-- 换成这样会不会有变化呢？   或者在改成 t.*,tc.*
EXPLAIN SELECT t.tcid FROM teacher_contact tc,teacher t  WHERE tc.tcid=t.tcid;

-- ref  与 rang
-- ref  与 rang
EXPLAIN SELECT * FROM teacher WHERE tcid = 3;
EXPLAIN SELECT * FROM teacher t WHERE t.tid <3;
-- 或 between
EXPLAIN SELECT * FROM teacher t WHERE tid BETWEEN 1 AND 2;
-- 或 in   回忆此处改成 = 是啥？
EXPLAIN SELECT * FROM teacher_contact t WHERE tcid IN (1,2,3);
-- index
EXPLAIN SELECT tid FROM teacher;
EXPLAIN SELECT t.tcid FROM teacher t ,teacher_contact tc WHERE t.tcid=tc.tcid;
-- index +Using index
EXPLAIN SELECT NAME FROM gupao_user WHERE NAME ='天明'; 
-- ref 非唯一的索引，或者你用到的关联查询里面只用到了最左前缀
EXPLAIN SELECT * FROM gupao_user WHERE NAME ='天明'; 

--  覆盖索引  不同引擎
-- name 0.00030625
EXPLAIN  SELECT  NAME ,phone FROM gupao_user WHERE NAME='天明';
-- name Using where
EXPLAIN SELECT NAME FROM gupao_user WHERE phone = '18566668888' AND NAME= '天明';
-- name_phone 优化器 Using index 耗时长
EXPLAIN SELECT NAME  FROM gupao_user WHERE phone= '13003666508'; 
-- name 0.00030625
EXPLAIN SELECT * FROM gupao_user WHERE NAME ='天明';





ALTER TABLE gupao_user DROP INDEX comidx_name_phone;
ALTER TABLE gupao_user ADD INDEX comidx_name_phone (NAME,phone);

EXPLAIN SELECT phone FROM gupao_user WHERE phone='126';

EXPLAIN SELECT * FROM gupao_user WHERE phone ='15966668888';

EXPLAIN SELECT * FROM gupao_user WHERE NAME ='tianming' ORDER BY id; 
-- usint temporary/ˈtempəreri/ 临时的
EXPLAIN SELECT DISTINCT(tid) FROM teacher t
EXPLAIN SELECT tname FROM teacher GROUP BY tname;
EXPLAIN SELECT t.tid FROM teacher t JOIN course c ON t.tid = c.tid GROUP BY t.tid;

-- 索引下推Index Condition Pushdown （ICP）
--    创建了联合索引  name + phone
explain select * from gupao_user where name like '天%' and phone =15908766475; 









