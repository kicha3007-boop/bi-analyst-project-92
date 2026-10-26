-- Загрузка выгрузок (csv из корня репозитория) в схему reports.
-- Это аналог шага 8 «загрузите csv-файлы в инструмент визуализации»:
-- дашборд Superset строится по этим таблицам, то есть по тем же данным,
-- что лежат в сдаваемых csv. Перезагрузка: make load-reports.
SET client_min_messages = warning;
DROP SCHEMA IF EXISTS reports CASCADE;
CREATE SCHEMA reports;

CREATE TABLE reports.customers_count (
    customers_count bigint
);

CREATE TABLE reports.top_10_total_income (
    seller text,
    operations bigint,
    income bigint
);

CREATE TABLE reports.lowest_average_income (
    seller text,
    average_income bigint
);

CREATE TABLE reports.day_of_the_week_income (
    seller text,
    day_of_week text,
    income bigint
);

CREATE TABLE reports.age_groups (
    age_category text,
    age_count bigint
);

CREATE TABLE reports.customers_by_month (
    selling_month text,
    total_customers bigint,
    income bigint
);

CREATE TABLE reports.special_offer (
    customer text,
    sale_date date,
    seller text
);

\copy reports.customers_count FROM '/project/customers_count.csv' WITH (FORMAT csv, HEADER true)
\copy reports.top_10_total_income FROM '/project/top_10_total_income.csv' WITH (FORMAT csv, HEADER true)
\copy reports.lowest_average_income FROM '/project/lowest_average_income.csv' WITH (FORMAT csv, HEADER true)
\copy reports.day_of_the_week_income FROM '/project/day_of_the_week_income.csv' WITH (FORMAT csv, HEADER true)
\copy reports.age_groups FROM '/project/age_groups.csv' WITH (FORMAT csv, HEADER true)
\copy reports.customers_by_month FROM '/project/customers_by_month.csv' WITH (FORMAT csv, HEADER true)
\copy reports.special_offer FROM '/project/special_offer.csv' WITH (FORMAT csv, HEADER true)
