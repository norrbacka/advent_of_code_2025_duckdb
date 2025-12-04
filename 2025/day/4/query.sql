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
        COALESCE((SELECT x.v FROM grid x WHERE x.r = g.r AND (x.c = g.c-1)), '') ||
        g.v ||
        COALESCE((SELECT x.v FROM grid x WHERE x.r = g.r AND (x.c = g.c+1)), '') ||
        COALESCE((SELECT x.v FROM grid x WHERE x.r = (g.r+1) AND (x.c = g.c-1)), '') ||
        COALESCE((SELECT x.v FROM grid x WHERE x.r = (g.r+1) AND (x.c = g.c)), '') ||
        COALESCE((SELECT x.v FROM grid x WHERE x.r = (g.r+1) AND (x.c = g.c+1)), '')
    ), '') AS area
FROM create_grid(input_file) g
WHERE g.v = '@' AND len(list_filter(area, x -> x = '@')) <= 4;
