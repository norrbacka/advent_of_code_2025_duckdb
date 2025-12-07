# V5: The Magic of Counting Paths Without Tracking Them

## The Problem

Given a grid like this:

```
.......S.......   Row 1: Start at 'S'
...............   Row 2: Empty
.......^.......   Row 3: Split point!
...............   Row 4: Empty
......^.^......   Row 5: Two split points!
...............   Row 6: Empty
```

Count how many unique paths exist from `S` to the bottom row.

**Rules:**
- Move down one row at a time
- `.` = continue straight down
- `^` = split into TWO paths: one goes left, one goes right

## The Naive Approach (Why It Fails)

The obvious solution: track every path individually.

```
Start: 1 path at (row=1, col=8)

After row 3 (first ^):
  Path 1: goes to col 7
  Path 2: goes to col 9

After row 5 (two ^s):
  Path 1 hits ^ at col 7 → splits to col 6 and col 8
  Path 2 hits ^ at col 9 → splits to col 8 and col 10

Now we have 4 paths!
```

**The problem:** With N split points, we get 2^N paths.
- 10 splits = 1,024 paths
- 20 splits = 1,048,576 paths
- 30 splits = 1,073,741,824 paths (OOM crash!)

## The V5 Insight: Count, Don't Track

**Key observation:** We don't need to know WHICH paths exist, just HOW MANY.

Instead of storing:
```
(row=5, col=6, path_id=1)
(row=5, col=6, path_id=2)
(row=5, col=6, path_id=3)
... 1000 more rows ...
```

Store:
```
(row=5, col=6, count=1003)  ← ONE row!
```

If 1000 paths arrive at the same cell, we only need ONE row with a count.

## How V5 Works: Step by Step

### Step 1: Build a Minimal Table

We only store `S` (start) and `^` (split points). Everything else is ignored.

```sql
CREATE TABLE splits AS ...
SELECT row, col, char FROM cells WHERE char IN ('S', '^');
```

Result for our example:
```
row | col | char
----+-----+------
  1 |   8 | S
  3 |   8 | ^
  5 |   7 | ^
  5 |   9 | ^
```

Only 4 rows instead of the entire grid!

### Step 2: Start the Recursion

```sql
SELECT row, col, 1::BIGINT AS cnt
FROM splits WHERE char = 'S'
```

Initial state:
```
row | col | cnt
----+-----+-----
  1 |   8 |   1    ← "1 path is at position (1,8)"
```

### Step 3: The Recursive Magic

For each iteration, we:
1. Look at the cell below each current position
2. If it's a `^`, split left AND right
3. If it's empty (no `^`), continue straight
4. **GROUP BY (row, col) and SUM the counts!**

```sql
SELECT new_row, new_col, SUM(cnt) AS cnt
FROM (
  -- Generate next positions
  SELECT p.row + 1 AS new_row,
    CASE
      WHEN s.char = '^' AND b.d = 0 THEN s.col - 1  -- left
      WHEN s.char = '^' AND b.d = 1 THEN s.col + 1  -- right
      ELSE p.col                                      -- straight
    END AS new_col,
    p.cnt
  FROM paths p
  LEFT JOIN splits s ON s.row = p.row + 1 AND s.col = p.col
  CROSS JOIN (SELECT 0 AS d UNION ALL SELECT 1) b  -- branch multiplier
  WHERE ...
) sub
GROUP BY new_row, new_col  ← THE MAGIC!
```

### Step 4: Watch It Work

Let's trace through our example:

**Iteration 0 (Start):**
```
row=1, col=8, cnt=1
```

**Iteration 1 (row 1→2):** No `^` below, continue straight
```
row=2, col=8, cnt=1
```

**Iteration 2 (row 2→3):** Hit a `^` at (3,8)! Split left and right
```
row=3, col=7, cnt=1   (went left)
row=3, col=9, cnt=1   (went right)
```

**Iteration 3 (row 3→4):** No `^` below either position
```
row=4, col=7, cnt=1
row=4, col=9, cnt=1
```

**Iteration 4 (row 4→5):** Both hit `^`s!
- Position (4,7) hits `^` at (5,7) → splits to col 6 and col 8
- Position (4,9) hits `^` at (5,9) → splits to col 8 and col 10

Before grouping:
```
row=5, col=6, cnt=1   (from col 7, went left)
row=5, col=8, cnt=1   (from col 7, went right)
row=5, col=8, cnt=1   (from col 9, went left)   ← SAME POSITION!
row=5, col=10, cnt=1  (from col 9, went right)
```

**After GROUP BY + SUM:**
```
row=5, col=6, cnt=1
row=5, col=8, cnt=2   ← Two paths merged into one row!
row=5, col=10, cnt=1
```

We now have 3 rows representing 4 paths!

### Step 5: Continue to Bottom

The recursion continues until we reach the max row. At the end:

```sql
SELECT SUM(cnt) AS total_paths FROM paths
WHERE row = (SELECT max_row FROM meta);
```

This sums up all the counts at the bottom row = total number of paths.

## Why This Is Fast

| Approach | Rows in Memory | With 30 splits |
|----------|---------------|----------------|
| Track each path | O(2^N) | 1 billion rows |
| **V5 (aggregate)** | O(grid_width) | ~131 rows |

The trick: paths that arrive at the same cell are **fungible**. We don't care which path is which, only how many there are.

## The LEFT JOIN Trick

```sql
LEFT JOIN splits s ON s.row = p.row + 1 AND s.col = p.col
```

- If `s.char = '^'`: we're at a split point, generate two new positions
- If `s.char IS NULL`: no split point here, continue straight down

This means we only JOIN against split points, not the entire grid.

## The CROSS JOIN Branching

```sql
CROSS JOIN (SELECT 0 AS d UNION ALL SELECT 1) b
WHERE (s.char IS NULL AND b.d = 0 OR s.char = '^')
```

This creates a "branch multiplier":
- For regular cells: only `b.d = 0` passes the filter (1 output row)
- For `^` cells: both `b.d = 0` and `b.d = 1` pass (2 output rows)

## Summary

1. **Store only what matters:** Just `S` and `^` positions
2. **Track counts, not paths:** `(row, col, count)` instead of individual path IDs
3. **Aggregate each step:** `GROUP BY (row, col)` collapses paths at same position
4. **Memory stays constant:** O(grid_width) rows regardless of split count

This transforms an exponential problem into a linear one!
