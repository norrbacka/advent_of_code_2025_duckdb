SELECT COUNT(*) AS total_splits
FROM day7grid g
WHERE g.char = '^'
  AND EXISTS (
    SELECT 1 FROM day7grid above
    WHERE above.col = g.col
      AND above.row = g.row - 1
      AND above.char = '|'
  );
