CREATE OR REPLACE MACRO find_next(input_row, input_version) AS TABLE
WITH found AS (
  SELECT row, col FROM day7grid WHERE row = input_row AND version = input_version AND char IN ('S', '|')
),
below AS (
  SELECT g.row, g.col, g.char
  FROM day7grid g, found
  WHERE g.row = found.row + 1 AND g.col = found.col AND g.version = input_version
)
SELECT row, col FROM below WHERE char = '.'
UNION ALL
SELECT row, col - 1 FROM below WHERE char = '^'
UNION ALL
SELECT row, col + 1 FROM below WHERE char = '^';