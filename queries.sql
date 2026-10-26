-- Все запросы проекта «Продажи».
-- Строка «-- output: <файл>.csv» перед запросом говорит, в какой файл
-- выгружается его результат (выгрузку делает `make reports`).
-- Запросы шагов 3 и 4 читают копии Google-таблиц из схемы sheets,
-- остальные — основную базу торговой площадки (схема public).


-- Шаг 3. Десять самых продаваемых товаров по количеству проданных штук
-- (данные Google-таблицы продаж). Десятка — условие задания.
-- output: top_10_popular_products.csv
SELECT
    sales.product_id AS "ProductID",
    SUM(sales.quantity) AS "TotalQuantity"
FROM sheets.sales AS sales
GROUP BY sales.product_id
ORDER BY "TotalQuantity" DESC, "ProductID" ASC
LIMIT 10;


-- Шаг 4. Десять товаров, проданных на наибольшую сумму (цена × количество),
-- сумма округлена до целого в меньшую сторону.
-- Данные Google-таблиц продаж и цен. Десятка — условие задания.
-- output: top_10_profitable_products.csv
SELECT
    sales.product_id AS "ProductID",
    FLOOR(SUM(sales.quantity * products.price)) AS "Amount"
FROM sheets.sales AS sales
INNER JOIN sheets.products AS products
    ON sales.product_id = products.product_id
GROUP BY sales.product_id
ORDER BY "Amount" DESC, "ProductID" ASC
LIMIT 10;


-- Шаг 5. Общее количество покупателей в таблице customers.
-- output: customers_count.csv
SELECT COUNT(customer_id) AS customers_count
FROM public.customers;


-- Шаг 6, отчёт 1. Десять продавцов с наибольшей суммарной выручкой:
-- имя и фамилия, количество сделок и выручка за всё время,
-- выручка округлена в меньшую сторону. Десятка — условие задания.
-- output: top_10_total_income.csv
SELECT
    CONCAT(TRIM(employees.first_name), ' ', TRIM(employees.last_name))
        AS seller,
    COUNT(sales.sales_id) AS operations,
    FLOOR(SUM(sales.quantity * products.price)) AS income
FROM public.sales AS sales
INNER JOIN public.employees AS employees
    ON sales.sales_person_id = employees.employee_id
INNER JOIN public.products AS products
    ON sales.product_id = products.product_id
GROUP BY employees.employee_id, employees.first_name, employees.last_name
ORDER BY income DESC
LIMIT 10;


-- Шаг 6, отчёт 2. Продавцы, чья средняя выручка за сделку меньше средней
-- выручки за сделку по всем продавцам. Средняя выручка округлена
-- в меньшую сторону, сортировка по ней по возрастанию.
-- output: lowest_average_income.csv
WITH deals AS (
    SELECT
        sales.sales_person_id,
        sales.quantity * products.price AS deal_income
    FROM public.sales AS sales
    INNER JOIN public.products AS products
        ON sales.product_id = products.product_id
),

seller_averages AS (
    SELECT
        sales_person_id,
        AVG(deal_income) AS average_deal_income
    FROM deals
    GROUP BY sales_person_id
)

SELECT
    CONCAT(TRIM(employees.first_name), ' ', TRIM(employees.last_name))
        AS seller,
    FLOOR(seller_averages.average_deal_income) AS average_income
FROM seller_averages
INNER JOIN public.employees AS employees
    ON seller_averages.sales_person_id = employees.employee_id
WHERE
    seller_averages.average_deal_income
    < (SELECT AVG(deals.deal_income) FROM deals)
ORDER BY average_income ASC, seller ASC;


-- Шаг 6, отчёт 3. Выручка каждого продавца по дням недели, округлённая
-- в меньшую сторону. День недели — английское название в нижнем регистре
-- (TO_CHAR с модификатором FM убирает пробелы-заполнители). Сортировка по
-- порядковому номеру дня недели по ISO (понедельник — первый), затем
-- по продавцу.
-- output: day_of_the_week_income.csv
SELECT
    CONCAT(TRIM(employees.first_name), ' ', TRIM(employees.last_name))
        AS seller,
    TO_CHAR(sales.sale_date, 'FMday') AS day_of_week,
    FLOOR(SUM(sales.quantity * products.price)) AS income
FROM public.sales AS sales
INNER JOIN public.employees AS employees
    ON sales.sales_person_id = employees.employee_id
INNER JOIN public.products AS products
    ON sales.product_id = products.product_id
GROUP BY
    employees.employee_id,
    employees.first_name,
    employees.last_name,
    EXTRACT(ISODOW FROM sales.sale_date),
    TO_CHAR(sales.sale_date, 'FMday')
ORDER BY EXTRACT(ISODOW FROM sales.sale_date) ASC, seller ASC;


-- Шаг 7, отчёт 1. Количество покупателей в возрастных группах
-- 16-25, 26-40 и 40+. Границы групп заданы в CTE age_limits,
-- группы отсортированы по возрасту.
-- output: age_groups.csv
WITH age_limits AS (
    SELECT
        16 AS youth_min_age,
        25 AS youth_max_age,
        40 AS adult_max_age
),

categorized_customers AS (
    SELECT
        CASE
            WHEN
                customers.age
                BETWEEN age_limits.youth_min_age AND age_limits.youth_max_age
                THEN CONCAT(
                    age_limits.youth_min_age, '-', age_limits.youth_max_age
                )
            WHEN
                customers.age
                BETWEEN age_limits.youth_max_age + 1
                AND age_limits.adult_max_age
                THEN CONCAT(
                    age_limits.youth_max_age + 1, '-', age_limits.adult_max_age
                )
            WHEN customers.age > age_limits.adult_max_age
                THEN CONCAT(age_limits.adult_max_age, '+')
        END AS age_category,
        CASE
            WHEN customers.age <= age_limits.youth_max_age THEN 1
            WHEN customers.age <= age_limits.adult_max_age THEN 2
            ELSE 3
        END AS category_order
    FROM public.customers AS customers
    CROSS JOIN age_limits
    WHERE customers.age >= age_limits.youth_min_age
)

SELECT
    age_category,
    COUNT(*) AS age_count
FROM categorized_customers
GROUP BY age_category, category_order
ORDER BY category_order ASC;


-- Шаг 7, отчёт 2. Количество уникальных покупателей и принесённая ими
-- выручка по месяцам (формат ГОД-МЕСЯЦ), выручка округлена в меньшую
-- сторону, сортировка по месяцу по возрастанию.
-- output: customers_by_month.csv
SELECT
    TO_CHAR(sales.sale_date, 'YYYY-MM') AS selling_month,
    COUNT(DISTINCT sales.customer_id) AS total_customers,
    FLOOR(SUM(sales.quantity * products.price)) AS income
FROM public.sales AS sales
INNER JOIN public.products AS products
    ON sales.product_id = products.product_id
GROUP BY TO_CHAR(sales.sale_date, 'YYYY-MM')
ORDER BY selling_month ASC;


-- Шаг 7, отчёт 3. Покупатели, первая покупка которых пришлась на акцию:
-- акционный товар отпускали по нулевой цене (promo_price в CTE).
-- Первая покупка — самая ранняя по дате, при равных датах — с меньшим
-- sales_id. Сортировка по id покупателя.
-- output: special_offer.csv
WITH promo AS (
    SELECT 0 AS promo_price
),

first_purchases AS (
    SELECT DISTINCT ON (sales.customer_id)
        sales.customer_id,
        sales.sale_date,
        sales.sales_person_id,
        sales.product_id
    FROM public.sales AS sales
    ORDER BY sales.customer_id ASC, sales.sale_date ASC, sales.sales_id ASC
),

promo_first_purchases AS (
    SELECT
        first_purchases.customer_id,
        first_purchases.sale_date,
        CONCAT(TRIM(customers.first_name), ' ', TRIM(customers.last_name))
            AS customer,
        CONCAT(TRIM(employees.first_name), ' ', TRIM(employees.last_name))
            AS seller
    FROM first_purchases
    INNER JOIN public.products AS products
        ON first_purchases.product_id = products.product_id
    INNER JOIN public.customers AS customers
        ON first_purchases.customer_id = customers.customer_id
    INNER JOIN public.employees AS employees
        ON first_purchases.sales_person_id = employees.employee_id
    INNER JOIN promo
        ON products.price = promo.promo_price
)

SELECT
    customer,
    sale_date,
    seller
FROM promo_first_purchases
ORDER BY customer_id ASC;
