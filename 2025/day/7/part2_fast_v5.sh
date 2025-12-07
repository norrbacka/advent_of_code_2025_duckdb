#!/bin/bash

cd "$(dirname "$0")"

INPUT_FILE="${1:-test.input}"

sed "s|INPUT_FILE_PLACEHOLDER|$INPUT_FILE|g" part2_fast_v5.sql | duckdb :memory:
