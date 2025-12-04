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
