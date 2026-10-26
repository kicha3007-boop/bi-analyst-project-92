#!/bin/sh
# Перезаливает данные в работающий контейнер db: основная база из дампа,
# копии Google-таблиц и выгрузки (схема reports). make load
set -eu

PSQL="psql -X -q -v ON_ERROR_STOP=1 -U $POSTGRES_USER -d $POSTGRES_DB"

$PSQL -c "DROP SCHEMA IF EXISTS public CASCADE; CREATE SCHEMA public;"
gunzip -c /docker-entrypoint-initdb.d/10_salesdb.sql.gz | $PSQL
$PSQL -f /docker-entrypoint-initdb.d/20_sheets.sql
$PSQL -f /docker-entrypoint-initdb.d/30_reports.sql
$PSQL -c "SELECT 'customers' AS table_name, COUNT(*) FROM public.customers
          UNION ALL SELECT 'employees', COUNT(*) FROM public.employees
          UNION ALL SELECT 'products', COUNT(*) FROM public.products
          UNION ALL SELECT 'sales', COUNT(*) FROM public.sales;"
