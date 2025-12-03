CREATE OR REPLACE MACRO joltage(input_file) AS TABLE
WITH ranges AS (
  SELECT unnest(string_split(content, chr(10))) AS batteries
  FROM read_text(input_file)
),
parsed AS (
  SELECT 
    row_number() OVER () AS i, 
    * 
  FROM ranges
),
cells AS (
  SELECT 
    i,
    t.j,
    batteries,
    CAST(substr(batteries, t.j, 1) AS INTEGER) AS joltage
  FROM parsed, 
    unnest(generate_series(1, length(batteries))) AS t(j)
),
max_joltage AS (
  SELECT 
    c.i,
    MAX(c.joltage) AS max_joltage,
    (select max(c2.joltage) from cells c2 where c2.i = c.i and c2.j > c.j) as next_joltage
  FROM cells c
  WHERE c.j < length(c.batteries)
  GROUP BY c.i, c.j
),
computed AS (
  SELECT 
    *, 
    CAST(concat(max_joltage, next_joltage) AS INTEGER) as total_joltage 
  FROM max_joltage order by i
),
max_computed AS (
  SELECT i, max(total_joltage) as total_max_joltage from computed
  group by i
)
SELECT sum(total_max_joltage) as part1 from max_computed;
-- part 1
SELECT 'test.input' AS file, * FROM joltage('test.input')
UNION ALL
SELECT 'my.input' AS file, * FROM joltage('my.input');

---------
---------

-- part 2
CREATE OR REPLACE MACRO valid_range_end(batteries_len, step) AS 
  batteries_len - (11 - step);

CREATE OR REPLACE MACRO max_digit_in_range(batteries, start_pos, end_pos) AS (
  SELECT MAX(substr(batteries, k, 1)) 
  FROM unnest(generate_series(start_pos, end_pos)) AS t(k)
);

CREATE OR REPLACE MACRO first_pos_of_max(batteries, start_pos, end_pos) AS (
  SELECT MIN(j) 
  FROM unnest(generate_series(start_pos, end_pos)) AS t(j)
  WHERE substr(batteries, j, 1) = max_digit_in_range(batteries, start_pos, end_pos)
);

CREATE OR REPLACE MACRO large_joltage(input_file) AS TABLE
WITH RECURSIVE ranges AS (
  SELECT unnest(string_split(content, chr(10))) AS batteries
  FROM read_text(input_file)
),
parsed AS (
  SELECT 
    row_number() OVER () AS i, 
    batteries
  FROM ranges
),
pick AS (
  -- initial state
  SELECT 
    i,
    batteries,
    0 AS step,
    0 AS last_pos,
    CAST('' AS VARCHAR) AS result
  FROM parsed
  UNION ALL
  -- recursive state
  SELECT
    p.i,
    p.batteries,
    p.step + 1,
    first_pos_of_max(p.batteries, p.last_pos + 1, valid_range_end(length(p.batteries), p.step)),
    concat(p.result, max_digit_in_range(p.batteries, p.last_pos + 1, valid_range_end(length(p.batteries), p.step)))
  FROM pick p
  WHERE p.step < 12
)

SELECT SUM(result::BIGINT) AS part2 FROM pick WHERE step = 12;
SELECT 'test.input' AS file, * FROM large_joltage('test.input')
UNION ALL
SELECT 'my.input' AS file, * FROM large_joltage('my.input');