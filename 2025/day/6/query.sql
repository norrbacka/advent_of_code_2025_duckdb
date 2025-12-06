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
