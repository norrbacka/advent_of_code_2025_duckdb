CREATE OR REPLACE MACRO get_range(input_file) AS TABLE
WITH lines AS (
  SELECT string_split(content, chr(10)) AS r
  FROM read_text(input_file)
),
split_data AS (
  SELECT 
    list_slice(r, 1, list_position(r, '') - 1) AS fresh,
    r[list_position(r, '') + 1:] AS available
  FROM lines
)
SELECT * FROM split_data;

CREATE OR REPLACE MACRO part1(input_file) AS TABLE
WITH fresh AS (
  SELECT 
    string_split(unnest(fresh),'-')[1]::BIGINT as from_range,
    string_split(unnest(fresh),'-')[2]::BIGINT as to_range
  FROM get_range(input_file)
),
available AS (
  SELECT unnest(available)::BIGINT as id 
  FROM get_range(input_file)
)
SELECT count(*) as part1 
FROM available a 
WHERE exists (SELECT 1 FROM fresh f WHERE a.id BETWEEN f.from_range AND f.to_range);

/*
First solution was extremely slow since so many numbers.
So decided to merge the overlaping ranges to new ranges.
Visualization:

From this:
1  2  3  4  5  6  7  8  9 10 11 12 13 14 15 16 17 18 19 20 21 22
        ├──────┤                                                   [3-5]
                        ├────────────────┤                       [10-14]
                                    ├────────────────────────┤   [12-18]
                                                ├────────────────┤[16-20]

To This:
1  2  3  4  5  6  7  8  9 10 11 12 13 14 15 16 17 18 19 20 21 22
        ├──────┤
                        ├────────────────────────────────────┤

Then simple subrtaction and sumation of to_range+1, from_range.
*/
CREATE OR REPLACE MACRO part2(input_file) AS TABLE
WITH fresh AS (
  SELECT 
    string_split(unnest(fresh),'-')[1]::BIGINT as from_range,
    string_split(unnest(fresh),'-')[2]::BIGINT as to_range
  FROM get_range(input_file)
),
sorted AS (
  SELECT from_range, to_range
  FROM fresh
  ORDER BY from_range
),
with_max AS (
  SELECT 
    from_range,
    to_range,
    MAX(to_range) OVER (ORDER BY from_range ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING) AS prev_max_end
  FROM sorted
),
new_group AS (
  SELECT 
    from_range,
    to_range,
    CASE WHEN prev_max_end IS NULL OR from_range > prev_max_end + 1 THEN 1 ELSE 0 END AS is_new_group
  FROM with_max
),
with_group_id AS (
  SELECT 
    from_range,
    to_range,
    SUM(is_new_group) OVER (ORDER BY from_range) AS group_id
  FROM new_group
),
merged AS (
  SELECT 
    MIN(from_range) AS merged_from,
    MAX(to_range) AS merged_to
  FROM with_group_id
  GROUP BY group_id
)
SELECT SUM(merged_to - merged_from + 1) AS part2 FROM merged;

SELECT 
  'test.input' AS file,
  (SELECT part1 FROM part1('test.input'))::VARCHAR AS part1,
  (SELECT part2 FROM part2('test.input'))::VARCHAR AS part2
UNION ALL
SELECT 
  'my.input' AS file,
  (SELECT part1 FROM part1('my.input'))::VARCHAR AS part1,
  (SELECT part2 FROM part2('my.input'))::VARCHAR AS part2;