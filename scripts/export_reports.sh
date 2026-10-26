#!/bin/sh
# Выполняет каждый запрос из queries.sql и сохраняет результат в csv,
# имя которого указано строкой «-- output: <файл>.csv» перед запросом.
# Запускается внутри контейнера db: make reports
set -eu

PROJECT_DIR="${PROJECT_DIR:-/project}"
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

awk -v dir="$WORK_DIR" '
    /^-- output: / { name = $3; next }
    /^--/ { next }
    name != "" {
        print >> (dir "/" name ".sql")
        if ($0 ~ /;[[:space:]]*$/) { close(dir "/" name ".sql"); name = "" }
    }
' "$PROJECT_DIR/queries.sql"

for query_file in "$WORK_DIR"/*.sql; do
    csv_name="$(basename "$query_file" .sql)"
    psql -X -q -v ON_ERROR_STOP=1 --csv \
        -U "$POSTGRES_USER" -d "$POSTGRES_DB" \
        -f "$query_file" -o "$PROJECT_DIR/$csv_name"
    echo "$csv_name: $(($(wc -l < "$PROJECT_DIR/$csv_name") - 1)) строк"
done
