
CREATE OR REPLACE MACRO create_grid(input_file) AS TABLE
WITH rolls AS (
  SELECT unnest(string_split(content, chr(10))) AS r
  FROM read_text(input_file)
),
grid AS (
  SELECT 
    row_number() OVER () AS r,
    generate_subscripts(string_split(r, ''), 1) AS c,
    UNNEST(string_split(r, '')) AS v
  FROM rolls
)
SELECT * FROM grid;

CREATE OR REPLACE MACRO count_rolls(input_file) AS TABLE
WITH grid AS (
    SELECT * FROM create_grid(input_file)
)
SELECT 
    g.*,

    string_split((
        COALESCE((SELECT x.v FROM grid x WHERE x.r = (g.r-1) AND (x.c = g.c-1)), '') ||
        COALESCE((SELECT x.v FROM grid x WHERE x.r = (g.r-1) AND (x.c = g.c)), '') ||
        COALESCE((SELECT x.v FROM grid x WHERE x.r = (g.r-1) AND (x.c = g.c+1)), '') ||
        --chr(10) ||
        COALESCE((SELECT x.v FROM grid x WHERE x.r = g.r AND (x.c = g.c-1)), '') ||
        g.v ||
        COALESCE((SELECT x.v FROM grid x WHERE x.r = g.r AND (x.c = g.c+1)), '') ||
        --chr(10) ||
        COALESCE((SELECT x.v FROM grid x WHERE x.r = (g.r+1) AND (x.c = g.c-1)), '') ||
        COALESCE((SELECT x.v FROM grid x WHERE x.r = (g.r+1) AND (x.c = g.c)), '') ||
        COALESCE((SELECT x.v FROM grid x WHERE x.r = (g.r+1) AND (x.c = g.c+1)), '')
    ), '') AS area
FROM create_grid(input_file) g
WHERE g.v = '@' and len(list_filter(area, x -> x = '@')) <= 4;

---- PART 2

CREATE OR REPLACE MACRO rec_count_rolls(input_file) AS TABLE
with compute AS (
    select * from count_rolls(input_file)
)
select * from compute;

CREATE OR REPLACE TABLE grid AS 
    SELECT * FROM create_grid('test.input');

CREATE OR REPLACE MACRO get_updates() AS TABLE
SELECT 
    g.*,

    string_split((
        COALESCE((SELECT x.v FROM grid x WHERE x.r = (g.r-1) AND (x.c = g.c-1)), '') ||
        COALESCE((SELECT x.v FROM grid x WHERE x.r = (g.r-1) AND (x.c = g.c)), '') ||
        COALESCE((SELECT x.v FROM grid x WHERE x.r = (g.r-1) AND (x.c = g.c+1)), '') ||
        COALESCE((SELECT x.v FROM grid x WHERE x.r = g.r AND (x.c = g.c-1)), '') ||
        g.v ||
        COALESCE((SELECT x.v FROM grid x WHERE x.r = g.r AND (x.c = g.c+1)), '') ||
        COALESCE((SELECT x.v FROM grid x WHERE x.r = (g.r+1) AND (x.c = g.c-1)), '') ||
        COALESCE((SELECT x.v FROM grid x WHERE x.r = (g.r+1) AND (x.c = g.c)), '') ||
        COALESCE((SELECT x.v FROM grid x WHERE x.r = (g.r+1) AND (x.c = g.c+1)), '')
    ), '') AS area
FROM grid g
WHERE g.v = '@' and len(list_filter(area, x -> x = '@')) <= 4;

select * from grid;

UPDATE grid g SET v = '.' WHERE [g.r, g.c] IN (SELECT [u.r, u.c] FROM get_updates() u);

select * from grid;


--SELECT * FROM rec_count_rolls('test.input');

/*
SELECT 
  'test.input' AS file,
  (SELECT count(*) FROM count_rolls('test.input')) AS part1,
  (SELECT count(*) FROM rec_count_rolls('test.input')) AS part2
UNION ALL
SELECT 
  'my.input' AS file,
  (SELECT count(*) FROM count_rolls('my.input')) AS part1
*/