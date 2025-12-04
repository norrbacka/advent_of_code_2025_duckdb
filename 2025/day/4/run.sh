#!/bin/bash
set -e

cd "$(dirname "$0")"

run_for_input() {
  local INPUT_FILE="$1"
  local DB_FILE="/tmp/aoc_day4_$$_${INPUT_FILE}.duckdb"
  trap "rm -f $DB_FILE" RETURN

  local part1=$(duckdb -csv -noheader <<EOF
.read query.sql
SELECT count(*) FROM count_rolls('$INPUT_FILE');
EOF
)

  duckdb "$DB_FILE" <<EOF
.read create_grid.sql
CREATE OR REPLACE TABLE grid AS SELECT * FROM create_grid('$INPUT_FILE');
.read get_updates.sql
EOF

  local part2=0
  while true; do
    local count=$(duckdb "$DB_FILE" -csv -noheader -c "SELECT count(*) FROM get_updates();")
    if [ "$count" -eq 0 ]; then break; fi
    part2=$((part2 + count))
    duckdb "$DB_FILE" -c "UPDATE grid SET v = '.' WHERE [r, c] IN (SELECT [r, c] FROM get_updates());"
  done

  rm -f "$DB_FILE"
  echo "$INPUT_FILE|$part1|$part2"
}

results=()
for input in test.input my.input; do
  if [ -f "$input" ]; then
    results+=("$(run_for_input "$input")")
  fi
done

max_file=4
max_p1=5
max_p2=5
for r in "${results[@]}"; do
  IFS='|' read -r f p1 p2 <<< "$r"
  [ ${#f} -gt $max_file ] && max_file=${#f}
  [ ${#p1} -gt $max_p1 ] && max_p1=${#p1}
  [ ${#p2} -gt $max_p2 ] && max_p2=${#p2}
done

printf "┌─%s─┬─%s─┬─%s─┐\n" "$(printf '─%.0s' $(seq 1 $max_file))" "$(printf '─%.0s' $(seq 1 $max_p1))" "$(printf '─%.0s' $(seq 1 $max_p2))"
printf "│ %${max_file}s │ %${max_p1}s │ %${max_p2}s │\n" "file" "part1" "part2"
printf "├─%s─┼─%s─┼─%s─┤\n" "$(printf '─%.0s' $(seq 1 $max_file))" "$(printf '─%.0s' $(seq 1 $max_p1))" "$(printf '─%.0s' $(seq 1 $max_p2))"
for r in "${results[@]}"; do
  IFS='|' read -r f p1 p2 <<< "$r"
  printf "│ %${max_file}s │ %${max_p1}s │ %${max_p2}s │\n" "$f" "$p1" "$p2"
done
printf "└─%s─┴─%s─┴─%s─┘\n" "$(printf '─%.0s' $(seq 1 $max_file))" "$(printf '─%.0s' $(seq 1 $max_p1))" "$(printf '─%.0s' $(seq 1 $max_p2))"
