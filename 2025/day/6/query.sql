CREATE OR REPLACE MACRO part1(input_file) AS TABLE
WITH lines AS (
  SELECT 
    row_number() OVER () AS row_num,
    unnest(string_split(content, chr(10))) AS r
  FROM read_text(input_file)
),
split_to_cols AS (
  SELECT 
    row_num,
    regexp_split_to_array(trim(r), '\s+') AS cols
  FROM lines
),
exploded AS (
  SELECT 
    row_num,
    unnest(cols) AS value,
    generate_subscripts(cols, 1) AS col_idx
  FROM split_to_cols
),
ordered AS (
SELECT 
  col_idx,
  list(value ORDER BY row_num) AS values
FROM exploded
GROUP BY col_idx
ORDER BY col_idx
),
computed AS (
select 
  (case 
    when values[-1] = '*' then
      values.list_filter(x -> x <> '*' and x <> '+')
            .list_reduce((x, y) -> x::BIGINT * y::BIGINT)
    else
     values.list_filter(x -> x <> '*' and x <> '+')
           .list_reduce((x, y) -> x::BIGINT + y::BIGINT)
  end)::BIGINT as computes
from ordered
)
select sum(computes) from computed;


SELECT * FROM part1('my.input');