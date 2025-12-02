CREATE OR REPLACE MACRO find_invalid_ids(input_file) AS TABLE
WITH ranges AS (
  SELECT unnest(string_split(content, ',')) AS product_id_range
  FROM read_text(input_file)
),
parsed AS (
  SELECT row_number() OVER () AS i,
         product_id_range,
         split_part(product_id_range, '-', 1) AS product_id_start,
         split_part(product_id_range, '-', 2) AS product_id_end
  FROM ranges
),
expanded AS (
  SELECT p.product_id_range,
         product_id
  FROM parsed p
  CROSS JOIN generate_series(
    CAST(p.product_id_start AS BIGINT),
    CAST(p.product_id_end AS BIGINT)
  ) AS gs(product_id)
),
part1 AS (
  SELECT product_id_range, product_id
  FROM expanded
  WHERE length(product_id::VARCHAR) % 2 = 0
    AND substr(product_id::VARCHAR, 1, (length(product_id::VARCHAR) / 2)::BIGINT) 
      = substr(product_id::VARCHAR, (length(product_id::VARCHAR) / 2 + 1)::BIGINT)
),
part2 AS (
  SELECT product_id_range, product_id
  FROM expanded
  WHERE (
    SELECT bool_or(
      product_id::VARCHAR = repeat(substr(product_id::VARCHAR, 1, len), (length(product_id::VARCHAR) / len)::INTEGER)
      AND length(product_id::VARCHAR) % len = 0
    )
    FROM generate_series(1::BIGINT, (length(product_id::VARCHAR) / 2)::BIGINT) AS gs(len)
  )
)
SELECT 
  (SELECT sum(product_id) FROM part1) AS part1,
  (SELECT sum(product_id) FROM part2) AS part2;

SELECT 'test.input' AS file, * FROM find_invalid_ids('test.input')
UNION ALL
SELECT 'my.input' AS file, * FROM find_invalid_ids('my.input');