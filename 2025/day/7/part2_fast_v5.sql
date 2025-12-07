SET threads TO 8;

CREATE TABLE splits AS
WITH lines AS (
  SELECT unnest(string_split(content, chr(10))) AS line
  FROM read_text('INPUT_FILE_PLACEHOLDER')
),
numbered AS (
  SELECT row_number() OVER () AS row, line
  FROM lines WHERE line != ''
),
cells AS (
  SELECT row,
         generate_subscripts(string_split(line, ''), 1) AS col,
         unnest(string_split(line, '')) AS char
  FROM numbered
)
SELECT row, col, char FROM cells WHERE char IN ('S', '^');

CREATE TABLE meta AS
SELECT COUNT(*) AS max_row FROM (
  SELECT unnest(string_split(content, chr(10))) AS line
  FROM read_text('INPUT_FILE_PLACEHOLDER')
) WHERE line != '';

CREATE INDEX idx_splits ON splits(row, col);

WITH RECURSIVE
paths AS (
  SELECT row, col, 1::BIGINT AS cnt
  FROM splits WHERE char = 'S'

  UNION ALL

  SELECT new_row, new_col, SUM(cnt) AS cnt
  FROM (
    SELECT
      p.row + 1 AS new_row,
      CASE
        WHEN s.char = '^' AND b.d = 0 THEN s.col - 1
        WHEN s.char = '^' AND b.d = 1 THEN s.col + 1
        ELSE p.col
      END AS new_col,
      p.cnt
    FROM paths p
    LEFT JOIN splits s ON s.row = p.row + 1 AND s.col = p.col
    CROSS JOIN (SELECT 0 AS d UNION ALL SELECT 1) b
    WHERE p.row < (SELECT max_row FROM meta)
      AND (s.char IS NULL AND b.d = 0 OR s.char = '^')
  ) sub
  GROUP BY new_row, new_col
)
SELECT SUM(cnt) AS total_paths FROM paths
WHERE row = (SELECT max_row FROM meta);
