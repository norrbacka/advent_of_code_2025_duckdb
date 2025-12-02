CREATE OR REPLACE MACRO day1_solution(input_file) AS TABLE
WITH day1 AS (
  SELECT column0 AS rotation 
  FROM read_csv_auto(input_file, delim='', header=false, strict_mode=false)
),
parsed AS (
  SELECT 
    row_number() OVER () AS i,
    SUBSTRING(rotation, 1, 1) AS dir,
    SUBSTRING(rotation, 2) AS dis,
    CASE WHEN dir = 'L' 
      THEN -dis::BIGINT 
      ELSE dis::BIGINT 
    END AS delta
  FROM day1
),
totals AS (
  SELECT 
    ((50 + SUM(delta) 
      OVER (ORDER BY i ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)) 
      % 100 + 100) % 100 AS running_total
  FROM parsed
),
-- Step 1: cumulative raw position (no wrapping) after each move,
-- starting from 50 to match the puzzle's initial state.
raw_calc AS (
  SELECT 
    i,
    delta,
    50 + SUM(delta) OVER (ORDER BY i) AS raw_total
  FROM parsed
),
-- Step 2: pair each raw total with the previous one
-- so we can measure how far we moved in this instruction.
with_prev AS (
  SELECT
    i,
    delta,
    raw_total,
    LAG(raw_total, 1, 50) OVER (ORDER BY i) AS prev_raw_total
  FROM raw_calc
),
-- Step 3: derive helper values for each row.
loop_indices AS (
  SELECT
    i,
    delta,
    raw_total,
    prev_raw_total,
    -- Wrap the raw total into the 0..99 dial.
    (raw_total % 100.0 + 100.0) % 100.0 AS wrapped_position,
    -- Count how many full 100-step loops we have completed so far.
    -- Example: raw_total= 832 → raw_loop_index=8 (passed zero 8 times),
    -- Example: moving -250 from 0 hits wrapped 0 twice:
    --   after 100 steps raw_total = -100 (wrapped 0) → first password hit
    --   after 200 steps raw_total = -200 (wrapped 0) → second password hit
    -- remaining 50 steps land at wrapped 50 with no extra hit (total crossings = 2)        
    FLOOR(raw_total / 100.0) AS raw_loop_index,
    FLOOR(prev_raw_total / 100.0) AS prev_loop_index,
    -- For backward movement, use negative totals so floor behaves consistently.
    FLOOR((-raw_total) / 100.0) AS neg_raw_loop_index,
    FLOOR((-prev_raw_total) / 100.0) AS neg_prev_loop_index
  FROM with_prev
),
-- Step 4: difference in loop indices tells us how many boundaries we crossed.
part2_calc AS (
  SELECT
    i,
    delta,
    raw_total,
    wrapped_position,
    CASE
      WHEN raw_total >= prev_raw_total
        -- Moving forward: count the extra loops compared to the previous row.
        THEN raw_loop_index - prev_loop_index
      ELSE
        -- Moving backward: use the negative loop counts for consistent results.
        neg_raw_loop_index - neg_prev_loop_index
    END AS boundary_crosses
  FROM loop_indices
)
SELECT 
  (SELECT COUNT(*) FROM totals WHERE running_total = 0) AS part1,
  (SELECT SUM(boundary_crosses)::INTEGER FROM part2_calc) AS part2;

SELECT 'test.input' AS file, * FROM day1_solution('test.input')
UNION ALL
SELECT 'my.input' AS file, * FROM day1_solution('my.input');