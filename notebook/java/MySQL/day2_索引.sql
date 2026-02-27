-- 数据库索引
select count(*) from gupao_user;

select * from gupao_user where name='天明';

-- 

-- calc 算一算3层数存多少

-- 联合索引
ALTER TABLE gupao_user add  INDEX ` comidx_name_phone ` ('name' , 'phone');
explain SELECT * FROM gupao_user WHERE NAME= '天明' AND phone = '13003666508'; 
explain SELECT * FROM gupao_user WHERE phone = '13003666508' AND NAME= '天明';
explain SELECT * FROM gupao_user WHERE NAME= '天明'; 
explain SELECT * FROM gupao_user WHERE phone = '13003666508';

-- sql 改成这样 能不能走索引  速度会不会快    还可以深入
SELECT name FROM gupao_user WHERE phone = '1588888888';  



-- 哪些语句要回表操作？

explain  SELECT  name ,phone FROM gupao_user WHERE name='天明';
explain SELECT name FROM gupao_user WHERE phone = '18566668888' AND name= '天明';
explain SELECT name  FROM gupao_user WHERE phone= ' 18566668888 ';
explain SELECT * FROM gupao_user WHERE name ='天明';

-- 索引下推
explain SELECT *  FROM gupao_user WHERE  name= '天明' and phone = '18566668888';
explain SELECT *  FROM order_detail WHERE  payno like '1%' and orderType = '1';


-- 哪一个最慢  ？   为什么？
show index from order_detail;
-- 索引数据 知道
 -- 为什么不是 xxx ？
	-- 特点  优势
--索引失效	模型数空运最快。 
explain SELECT * FROM gupao_user WHERE name  like '天%';
explain SELECT * FROM gupao_user WHERE name  like '%明';


explain SELECT * FROM gupao_user WHERE name = "666";
explain SELECT * FROM gupao_user WHERE name = 666;


explain SELECT * FROM order_detail WHERE createDate > CURRENT_DATE;
explain SELECT * FROM order_detail WHERE createDate >TO_DAYS(CURRENT_DATE);


explain SELECT * FROM order_detail WHERE payno='2' or payno is  null;
explain SELECT * FROM order_detail WHERE   payno is null;

explain SELECT * FROM order_detail WHERE   userid =2 ;
explain SELECT * FROM order_detail WHERE   userid/2 > 1;
	
explain SELECT * FROM gupao_user WHERE  name="张小三" and phone ='13003812736' ;
explain SELECT * FROM gupao_user WHERE  phone ='13003812736' and  name="张小三" ;
explain SELECT * FROM gupao_user WHERE  name="张小三" or phone ='13003812736' ;


explain SELECT * FROM order_detail WHERE   createdate >='2021-10-15 13:40:49' ;
explain SELECT * FROM order_detail WHERE   createdate >='2021-11-16 19:30:04' ;    
-- 索引定位的记录很多且需要回表 ，默认超出33% 可以测试5.7的临界值 删一条就能走索引




