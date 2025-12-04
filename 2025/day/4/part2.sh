#!/bin/bash
set -e

INPUT_FILE="${1:-test.input}"
DB_FILE="/tmp/aoc_day4_$$.duckdb"
trap "rm -f $DB_FILE" EXIT

total=0

duckdb "$DB_FILE" <<EOF
.read create_grid.sql
CREATE OR REPLACE TABLE grid AS SELECT * FROM create_grid('$INPUT_FILE');
.read get_updates.sql
EOF

while true; do
  count=$(duckdb "$DB_FILE" -csv -noheader -c "SELECT count(*) FROM get_updates();")
  if [ "$count" -eq 0 ]; then break; fi
  total=$((total + count))
  duckdb "$DB_FILE" -c "UPDATE grid SET v = '.' WHERE [r, c] IN (SELECT [r, c] FROM get_updates());"
done

echo "$total"
