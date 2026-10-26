-- Копии Google-таблиц шагов 2-4 (продажи и цены товаров) в схеме sheets.
-- Исходные CSV лежат в data/sheets/ репозитория.
SET client_min_messages = warning;
DROP SCHEMA IF EXISTS sheets CASCADE;
CREATE SCHEMA sheets;

CREATE TABLE sheets.sales (
    sales_id bigint PRIMARY KEY,
    sales_person_id bigint NOT NULL,
    customer_id bigint NOT NULL,
    product_id bigint NOT NULL,
    quantity integer NOT NULL
);

CREATE TABLE sheets.products (
    product_id bigint PRIMARY KEY,
    price numeric(19, 4) NOT NULL
);

\copy sheets.sales FROM '/project/data/sheets/sales.csv' WITH (FORMAT csv, HEADER true)
\copy sheets.products FROM '/project/data/sheets/products.csv' WITH (FORMAT csv, HEADER true)
