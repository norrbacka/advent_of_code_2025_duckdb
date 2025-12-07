#!/bin/bash

cd "$(dirname "$0")"

INPUT_FILE="${1:-test.input}"

# Clean slate
rm -f day7.db

INPUT_FILE="$INPUT_FILE" envsubst < grid.sql | duckdb day7.db

duckdb day7.db < find_start.sql
duckdb day7.db < pretty.sql

MAX_ROW=$(duckdb day7.db -noheader -list -c "SELECT MAX(row) FROM day7grid;")

for ((i=1; i<=MAX_ROW; i++)); do
  echo "=== Row $i ==="
  duckdb day7.db -c "
    UPDATE day7grid
    SET char = '|'
    WHERE (row, col) IN (SELECT row, col FROM find_next($i, 1));
  "
  duckdb day7.db -c "SELECT * FROM pretty_print(1);"
done

duckdb day7.db < total_splits.sql
