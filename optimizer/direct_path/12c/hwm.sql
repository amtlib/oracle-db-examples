set linesize 260
column PLAN_TABLE_OUTPUT format a200
set pagesize 200
set trims on
set tab off
set echo on
spool hwm

DROP TABLE sales_dl;

CREATE TABLE sales_dl (sale_id NUMBER(10), customer_id NUMBER(10));

DECLARE
   i NUMBER(10);
BEGIN
   FOR i IN 1..10
   LOOP
   INSERT INTO sales_dl
      SELECT ROWNUM, MOD(ROWNUM,1000)
      FROM   dual
      CONNECT BY LEVEL <= 100000;
      COMMIT;
   END LOOP;
END;
/

EXEC dbms_stats.gather_table_stats(ownname=>NULL, tabname=>'SALES_DL');

alter table sales_dl parallel 4;

alter session set parallel_force_local = FALSE;
alter session set parallel_degree_policy = 'MANUAL';
alter session enable parallel dml;
alter session enable parallel ddl;

drop table sales_p1;
drop table sales_p2;

--
-- TSM PCTAS
--
create table sales_p1 
partition by range (sale_id) 
subpartition by hash (customer_id)
subpartitions 32
(
partition p0 values less than (50000),
partition p1 values less than (200000))
parallel 4
as select * from sales_dl
/

select * from table(dbms_xplan.display_cursor);

create table sales_p2 
partition by range (sale_id) 
subpartition by hash (customer_id)
subpartitions 64
(
partition p0 values less than (50000),
partition p1 values less than (200000))
parallel 4
as select * from sales_dl where 1=-1
/


--
-- An HWM PIDL 
--
insert /*+ append */
into sales_p2 t1
select * from sales_p1 t2;

select * from table(dbms_xplan.display_cursor);

commit;

