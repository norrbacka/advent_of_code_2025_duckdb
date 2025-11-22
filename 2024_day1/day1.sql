-- duckdb < day1.sql

CREATE TABLE day1 AS 
  SELECT column0 AS a, column3 AS b 
  FROM read_csv_auto('day1.txt', delim=' ', header=false, strict_mode=false);

Select SUM(t.sum) as day_1_part_1 from (SELECT 
       a_sorted.a,
       b_sorted.b,
       (a-b).abs() as sum
   FROM (
       SELECT a, ROW_NUMBER() OVER (ORDER BY a) AS rn FROM day1
   ) a_sorted
   FULL OUTER JOIN (
       SELECT b, ROW_NUMBER() OVER (ORDER BY b) AS rn FROM day1
   ) b_sorted ON a_sorted.rn = b_sorted.rn
   ORDER BY COALESCE(a_sorted.rn, b_sorted.rn)) as t;