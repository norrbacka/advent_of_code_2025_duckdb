CREATE OR REPLACE MACRO joltage(input_file) AS TABLE
WITH ranges AS (
  SELECT unnest(string_split(content, chr(10))) AS batteries
  FROM read_text(input_file)
),
parsed AS (
  SELECT 
    row_number() OVER () AS i, 
    * 
  FROM ranges
),
cells AS (
  SELECT 
    i,
    t.j,
    batteries,
    CAST(substr(batteries, t.j, 1) AS INTEGER) AS joltage
  FROM parsed, 
    unnest(generate_series(1, length(batteries))) AS t(j)
),
max_joltage AS (
  SELECT 
    c.i,
    MAX(c.joltage) AS max_joltage,
    (select max(c2.joltage) from cells c2 where c2.i = c.i and c2.j > c.j) as next_joltage
  FROM cells c
  WHERE c.j < length(c.batteries)
  GROUP BY c.i, c.j
),
computed AS (
  SELECT 
    *, 
    CAST(concat(max_joltage, next_joltage) AS INTEGER) as total_joltage 
  FROM max_joltage order by i
),
max_computed AS (
  SELECT i, max(total_joltage) as total_max_joltage from computed
  group by i
)
SELECT sum(total_max_joltage) as part1 from max_computed;

---------
---------
/* 
Algorithmic explanation for future reference

"Max" is given by max_digit_in_range below
"pos" is the first_pos_of_max which is what we recursvily return as last_pos
The total of picks we need to leave is given by valid_range_end

I intially solved this without the helper functions, but used some AI to refactor
it into helper functions, and after that generating this explanation below.

The solution should work for part 1 as well just a lower step limit, and more picks
to explore, but the recursion is overkill for part 1. So I like to leave it to sort
of show that the problem can be solved without recursion theoretically. I was thinking of 
nesting queries firstly, but man, that would have taken me an hour to write! 
Glad this worked out intstead 8)

batteries: 2 3 4 2 3 4 2 3 4 2  3  4  2  7  8
position:  1 2 3 4 5 6 7 8 9 10 11 12 13 14 15

Step 0: range [1-4], need to leave 11 more picks
        2 3 4 2 3 4 2 3 4 2  3  4  2  7  8
        └───┘
        Max='4' at pos 3 → result: "4"

Step 1: range [4-5], need to leave 10 more picks  
        2 3 4 2 3 4 2 3 4 2  3  4  2  7  8
              └─┘
        Max='3' at pos 5 → result: "43"

Step 2: range [6-6], need to leave 9 more picks
        2 3 4 2 3 4 2 3 4 2  3  4  2  7  8
                  │
        Only='4' at pos 6 → result: "434"

Step 3: range [7-7], no skips left!
        2 3 4 2 3 4 2 3 4 2  3  4  2  7  8
                    │
        Only='2' at pos 7 → result: "4342"

Step 4: range [8-8]
        2 3 4 2 3 4 2 3 4 2  3  4  2  7  8
                      │
        Only='3' at pos 8 → result: "43423"

Step 5: range [9-9]
        2 3 4 2 3 4 2 3 4 2  3  4  2  7  8
                        │
        Only='4' at pos 9 → result: "434234"

Step 6: range [10-10]
        2 3 4 2 3 4 2 3 4 2  3  4  2  7  8
                          │
        Only='2' at pos 10 → result: "4342342"

Step 7: range [11-11]
        2 3 4 2 3 4 2 3 4 2  3  4  2  7  8
                             │
        Only='3' at pos 11 → result: "43423423"

Step 8: range [12-12]
        2 3 4 2 3 4 2 3 4 2  3  4  2  7  8
                                │
        Only='4' at pos 12 → result: "434234234"

Step 9: range [13-13]
        2 3 4 2 3 4 2 3 4 2  3  4  2  7  8
                                   │
        Only='2' at pos 13 → result: "4342342342"

Step 10: range [14-14]
        2 3 4 2 3 4 2 3 4 2  3  4  2  7  8
                                      │
        Only='7' at pos 14 → result: "43423423427"

Step 11: range [15-15]
        2 3 4 2 3 4 2 3 4 2  3  4  2  7  8
                                         │
        Only='8' at pos 15 → result: "434234234278"
*/

-- part 2
CREATE OR REPLACE MACRO valid_range_end(batteries_len, step) AS 
  batteries_len - (11 - step);

CREATE OR REPLACE MACRO max_digit_in_range(batteries, start_pos, end_pos) AS (
  SELECT MAX(substr(batteries, k, 1)) 
  FROM unnest(generate_series(start_pos, end_pos)) AS t(k)
);

CREATE OR REPLACE MACRO first_pos_of_max(batteries, start_pos, end_pos) AS (
  SELECT MIN(j) 
  FROM unnest(generate_series(start_pos, end_pos)) AS t(j)
  WHERE substr(batteries, j, 1) = max_digit_in_range(batteries, start_pos, end_pos)
);

CREATE OR REPLACE MACRO large_joltage(input_file) AS TABLE
WITH RECURSIVE ranges AS (
  SELECT unnest(string_split(content, chr(10))) AS batteries
  FROM read_text(input_file)
),
parsed AS (
  SELECT 
    row_number() OVER () AS i, 
    batteries
  FROM ranges
),
pick AS (
  -- initial state
  SELECT 
    i,
    batteries,
    0 AS step,
    0 AS last_pos,
    CAST('' AS VARCHAR) AS result
  FROM parsed
  UNION ALL
  -- recursive state
  SELECT
    p.i,
    p.batteries,
    p.step + 1,
    first_pos_of_max(p.batteries, p.last_pos + 1, valid_range_end(length(p.batteries), p.step)),
    concat(p.result, max_digit_in_range(p.batteries, p.last_pos + 1, valid_range_end(length(p.batteries), p.step)))
  FROM pick p
  WHERE p.step < 12
)

SELECT SUM(result::BIGINT) AS part2 FROM pick WHERE step = 12;

SELECT 
  'test.input' AS file,
  (SELECT part1 FROM joltage('test.input'))::VARCHAR AS day1,
  (SELECT part2 FROM large_joltage('test.input'))::VARCHAR AS day2
UNION ALL
SELECT 
  'my.input' AS file,
  (SELECT part1 FROM joltage('my.input'))::VARCHAR AS day1,
  (SELECT part2 FROM large_joltage('my.input'))::VARCHAR AS day2