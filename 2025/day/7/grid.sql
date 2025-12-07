CREATE OR REPLACE TABLE day7grid AS
WITH lines AS (
  SELECT unnest(string_split(content, chr(10))) AS line
  FROM read_text('$INPUT_FILE')
),
rows AS (
  SELECT
    row_number() OVER () AS row,
    line
  FROM lines
  WHERE line != ''
),
chars AS (
  SELECT
    row,
    unnest(string_split(line, '')) AS char,
    generate_subscripts(string_split(line, ''), 1) AS col
  FROM rows
)
SELECT row, col, char, 1 AS version FROM chars;

SELECT * FROM day7grid ORDER BY version, row, col;