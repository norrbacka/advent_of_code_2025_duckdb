-- duckdb < day1.sql

CREATE TABLE day1 AS 
  SELECT column0 AS rotation 
  FROM read_csv_auto('my.input', delim='', header=false, strict_mode=false);

CREATE TEMP VIEW parsed AS 
Select 
    row_number() OVER () as i,
    SUBSTRING(rotation, 1, 1) as dir,
    SUBSTRING(rotation, 2) as dis,
    case when dir = 'L' 
        then -dis::BIGINT 
        else dis::BIGINT 
    end as delta,
from day1;

CREATE TEMP VIEW totals AS 
select 
    ((50 + SUM(delta) 
    OVER (ORDER BY i ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)) 
    % 100 + 100) % 100 
    as running_total
from parsed;

CREATE TEMP VIEW part2 AS 
WITH raw_calc AS (
    -- Step 1: cumulative raw position (no wrapping) after each move,
    -- starting from 50 to match the puzzle’s initial state.
    SELECT 
        i,
        delta,
        50 + SUM(delta) OVER (ORDER BY i) AS raw_total
    FROM parsed
),
with_prev AS (
    -- Step 2: pair each raw total with the previous one
    -- so we can measure how far we moved in this instruction.
    SELECT
        i,
        delta,
        raw_total,
        LAG(raw_total, 1, 50) OVER (ORDER BY i) AS prev_raw_total
    FROM raw_calc
),
loop_indices AS (
    -- Step 3: derive helper values for each row.
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
)
SELECT
    i,
    delta,
    raw_total,
    wrapped_position,
    -- Step 4: difference in loop indices tells us how many boundaries we crossed.
    CASE
        WHEN raw_total >= prev_raw_total
             -- Moving forward: count the extra loops compared to the previous row.
             THEN raw_loop_index - prev_loop_index
        ELSE
             -- Moving backward: use the negative loop counts for consistent results.
             neg_raw_loop_index - neg_prev_loop_index
    END AS boundary_crosses
FROM loop_indices;

SELECT 
    part1.part1,
    part2.part2
FROM (
    SELECT COUNT(*) AS part1
    FROM totals
    WHERE running_total = 0
) AS part1
CROSS JOIN (
    SELECT SUM(boundary_crosses)::INTEGER AS part2
    FROM part2
) AS part2;