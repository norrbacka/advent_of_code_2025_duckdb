-- Pretty print: reconstructs the grid as text for a specific version
CREATE OR REPLACE MACRO pretty_print(input_version) AS TABLE
WITH lines AS (
  SELECT row, string_agg(char, '' ORDER BY col) AS line
  FROM day7grid
  WHERE version = input_version
  GROUP BY row
)
SELECT line FROM lines ORDER BY row;
