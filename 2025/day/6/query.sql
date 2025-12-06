LOAD psql;

CREATE OR REPLACE MACRO parse_input_to_numbered_lines(input_file) AS TABLE
SELECT
  row_number() OVER () AS row_num,
  unnest(string_split(content, chr(10))) AS line
FROM read_text(input_file);

CREATE OR REPLACE MACRO split_on_whitespace(line_text) AS
regexp_split_to_array(trim(line_text), '\s+');

CREATE OR REPLACE MACRO parse_lines_to_row_arrays(input_file) AS TABLE
SELECT
  row_num,
  split_on_whitespace(line) AS cols
FROM parse_input_to_numbered_lines(input_file);

CREATE OR REPLACE MACRO explode_arrays_to_indexed_values(input_file) AS TABLE
SELECT
  row_num,
  unnest(cols) AS value,
  generate_subscripts(cols, 1) AS col_idx
FROM parse_lines_to_row_arrays(input_file);

CREATE OR REPLACE MACRO group_by_column_index_into_arrays(input_file) AS TABLE
SELECT
  col_idx,
  list(value ORDER BY row_num) AS values
FROM explode_arrays_to_indexed_values(input_file)
GROUP BY col_idx
ORDER BY col_idx;

CREATE OR REPLACE MACRO remove_operators_from_array(values_array) AS
list_filter(values_array, x -> x NOT IN ('*', '+'));

CREATE OR REPLACE MACRO multiply_array_values(values_array) AS
list_reduce(values_array, (x, y) -> x::BIGINT * y::BIGINT);

CREATE OR REPLACE MACRO sum_array_values(values_array) AS
list_reduce(values_array, (x, y) -> x::BIGINT + y::BIGINT);

CREATE OR REPLACE MACRO get_last_element(arr) AS arr[-1];

CREATE OR REPLACE MACRO calculate_column_result_by_operator(values_array) AS
CASE
  WHEN get_last_element(values_array) = '*' THEN
    multiply_array_values(remove_operators_from_array(values_array))
  ELSE
    sum_array_values(remove_operators_from_array(values_array))
END;

CREATE OR REPLACE MACRO part1(input_file) AS TABLE
WITH column_arrays AS (
  SELECT * FROM group_by_column_index_into_arrays(input_file)
),
column_results AS (
  SELECT calculate_column_result_by_operator(values)::BIGINT AS result
  FROM column_arrays
)
SELECT sum(result) AS total FROM column_results;


SELECT * FROM part1('test.input');

CREATE OR REPLACE MACRO cast_array_to_bigint(arr) AS
list_transform(arr, x -> x::BIGINT);

CREATE OR REPLACE MACRO left_pad_array_with_zeros(arr, target_length) AS
list_transform(
  arr,
  x -> string_split(lpad(x, target_length::INT, ' '), '')
);

CREATE OR REPLACE MACRO part2(input_file) AS TABLE
WITH column_arrays AS (
  SELECT * FROM group_by_column_index_into_arrays(input_file)
),
math_numbers AS (
  select 
     row_number() OVER () AS i,
     get_last_element(values) as operator,    
     remove_operators_from_array(values) as numbers,
  from column_arrays
),
cephalopod_numbers AS (
  select 
    i,
    operator,
    (list_max(numbers.cast_array_to_bigint())::VARCHAR).length() 
      as max_length,
    numbers,
    numbers.list_transform(x -> string_split(x, '')) as arrayed
  from math_numbers
  group by i, operator, numbers
),
expanded_numbers AS (
  select
    *,
    left_pad_array_with_zeros(numbers, max_length) as expanded
  from cephalopod_numbers
),
cephalopod_series AS (
  select
    *,
    generate_series(1, max_length).list_transform(j -> 
      generate_series(1, max_length).list_transform(u -> 
      expanded[u][j]
      )
    ).list_transform(x -> x.list_filter(x -> x <> ' ').array_to_string('')) as c
  from expanded_numbers
  order by i
),
computation AS (
SELECT
    *,
  CASE
    WHEN operator = '*' THEN
      multiply_array_values(c.cast_array_to_bigint())
    ELSE
      sum_array_values(c.cast_array_to_bigint())
  END as result
FROM cephalopod_series
)
select * from computation;

/*
Beräkningen stämmer, men vi måste behålla "space" från inläsningen och split med det, 
då slipper vi padda ut med ' '. Därmed borde senare delen av koden redan stämma.
*/

SELECT * FROM part2('test.input');

WITH base_lines AS (
  SELECT * FROM parse_input_to_numbered_lines('test.input')
),
split_lines AS (
  SELECT
    row_num,
    line.string_split('') as lines
  FROM base_lines
),
with_size AS (
  SELECT *,
    lines.length() as total_size
  FROM split_lines
),
prettified AS (
  SELECT
    row_number() OVER () AS i,
    total_size,
    generate_series(1, total_size).list_transform(x ->
      CASE WHEN lines[x] = ' ' THEN '_' ELSE lines[x] END
    ) as pretty
  FROM with_size
)
SELECT * FROM prettified;


WITH base_lines AS (
  SELECT * FROM parse_input_to_numbered_lines('my.input')
),
split_lines AS (
  SELECT
    row_num,
    line.string_split('') as lines
  FROM base_lines
),
with_size AS (
  SELECT *,
    lines.length() as total_size
  FROM split_lines
),
prettified AS (
  SELECT
    row_number() OVER () AS i,
    total_size,
    generate_series(1, total_size).list_transform(x ->
      CASE WHEN lines[x] = ' ' THEN '_' ELSE lines[x] END
    ) as pretty
  FROM with_size
),
merged_data AS (
  SELECT 
    total_size, 
    list(pretty) as merged 
  FROM prettified
  GROUP BY total_size
),
with_col_size AS (
  SELECT 
    merged,
    total_size,
    length(merged) as col_size
  FROM merged_data
),
final_result AS (
  SELECT 
    merged, 
    col_size, 
    total_size,
    list_transform(
      list_filter(
        generate_series(1, total_size),
        jdx -> length(
          list_filter(
            generate_series(1, col_size).list_transform(idx -> merged[idx][jdx]),
            x -> x = '_'
          )
        ) = col_size
      ),
      x -> x
    ) as split_indexes
  FROM with_col_size
),
split_result AS (
  SELECT
    list_transform(
      generate_series(1, length(split_indexes) + 1),
      i -> CASE
        WHEN i = 1 THEN
          list_transform(merged, row -> row[1:split_indexes[1]-1])
        WHEN i = length(split_indexes) + 1 THEN
          list_transform(merged, row -> row[split_indexes[-1]+1:total_size])
        ELSE
          list_transform(merged, row -> row[split_indexes[i-1]+1:split_indexes[i]-1])
      END
    ) as split_sections
  FROM final_result
),
transposed_sections AS (
  SELECT
    unnest(split_sections) as section
  FROM split_result
),
calculated AS (
  SELECT
    section[-1][1] as operator,
    list_transform(
      generate_series(1, length(section[1])),
      col_idx -> array_to_string(
        list_filter(
          list_transform(
            generate_series(1, length(section) - 1),
            row_idx -> section[row_idx][col_idx]
          ),
          x -> x != '_'
        ),
        ''
      )
    ).list_filter(x -> x != '') as numbers
  FROM transposed_sections
),
results AS (
  SELECT
    operator,
    numbers,
    CASE
      WHEN operator = '*' THEN
        multiply_array_values(cast_array_to_bigint(numbers))
      ELSE
        sum_array_values(cast_array_to_bigint(numbers))
    END as result
  FROM calculated
),
total AS (
  SELECT sum(result) as total_sum
  FROM results
)
SELECT * FROM results, total;