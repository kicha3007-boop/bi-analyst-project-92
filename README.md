# Продажи

[![hexlet-check](https://github.com/kicha3007-boop/bi-analyst-project-92/actions/workflows/hexlet-check.yml/badge.svg)](https://github.com/kicha3007-boop/bi-analyst-project-92/actions)

Проанализируйте базу данных торговой площадки. Визуализируйте полученные данные в Superset и составьте итоговую презентацию с результатами

Учебный проект Хекслета: https://ru.hexlet.io/programs/bi-analyst
Как это должно работать: SQL-запросы из `queries.sql` считают отчёты по базе продаж
(сентябрь – декабрь 1992, 100 000 сделок), результаты выгружаются в csv, по ним собран
дашборд в Superset, а выводы оформлены в презентацию `presentation.pdf`.

## Стек

- PostgreSQL 17 — база торговой площадки (дамп в `db/init/10_salesdb.sql.gz`)
- SQL (линтер SQLFluff, диалект postgres)
- Apache Superset 4.1 — дашборд
- Docker Compose, Make
- Playwright (Chromium) — скриншоты графиков и сборка PDF

## Что в репозитории

| Файл | Что это |
|------|---------|
| `queries.sql` | все запросы проекта; строка `-- output: <файл>.csv` связывает запрос с выгрузкой |
| `top_10_popular_products.csv`, `top_10_profitable_products.csv` | шаги 3–4: данные Google-таблиц (копии в `data/sheets/`) |
| `customers_count.csv` | шаг 5 |
| `top_10_total_income.csv`, `lowest_average_income.csv`, `day_of_the_week_income.csv` | шаг 6: продавцы |
| `age_groups.csv`, `customers_by_month.csv`, `special_offer.csv` | шаг 7: покупатели |
| `superset/export/dashboard.zip` | выгрузка дашборда Superset (шаг 8) |
| `presentation.pdf` | презентация с выводами (шаг 9), исходник — `presentation/slides.html` |
| `db/init/` | инициализация PostgreSQL: дамп базы, копии Google-таблиц (схема `sheets`), выгрузки (схема `reports`) |

Данные: дамп учебной базы `salesdb` (таблицы customers, employees, products, sales) и
CSV-копии Google-таблиц из шагов 2–4 — всё лежит в репозитории, сеть и внешние
доступы для работы не нужны.

## Установка

Нужны Docker с Compose и GNU Make.

```bash
git clone https://github.com/kicha3007-boop/bi-analyst-project-92.git
cd bi-analyst-project-92
cp .env.example .env   # необязательно: локальные пароли по умолчанию
make up                # сборка без кэша и запуск PostgreSQL + Superset
```

При первом старте PostgreSQL загружает дамп, копии Google-таблиц и выгрузки, а Superset
импортирует дашборд из `superset/export/dashboard.zip`.

- Дашборд: http://localhost:8088/superset/dashboard/sales/ (логин `admin`, пароль `admin`)
- PostgreSQL: `localhost:15432`, база `salesdb`, пользователь/пароль `postgres`/`postgres`

## Использование

```bash
make reports          # выполнить queries.sql и перезаписать csv-выгрузки
make load-reports     # загрузить csv в схему reports (источник дашборда)
make lint             # SQLFluff для queries.sql (образ автопроверки Хекслета)
make test             # тесты автопроверки Хекслета локально
make psql             # консоль базы
make load             # перезалить данные в работающую базу
make dashboard        # повторно импортировать дашборд из zip
make dashboard-build  # собрать дашборд заново через REST API и выгрузить в zip
make screenshots      # скриншоты графиков в presentation/img/
make presentation     # собрать presentation.pdf из presentation/slides.html
make down             # остановить контейнеры (make reset — с удалением данных)
```

Полный цикл с нуля: `make up reports load-reports dashboard-build screenshots presentation test`.

### Ключевые выводы

- Выручка за период — 26,7 млрд; топ-3 продавца дают 40,7%, топ-10 — 76,5%; лидер Dirk Stringer — 4 925 млн.
- Число сделок не равно выручке: у Abraham Bennet больше всех сделок (9 460), но шестая выручка.
- 15 из 22 продавцов имеют среднюю сделку ниже средней по площадке (267 165).
- По дням недели выручка почти ровная (разброс 9,1%), слабее всего среда.
- 60,5% покупателей старше 40 лет; покупки совершили только 230 из 19 759 клиентов.
- После пика в октябре (8 358 млн) выручка снижается примерно на 4% в месяц.
- Первая покупка по акции — только у 15 покупателей.

---

<details>
<summary>Автоматические тесты Хекслета</summary>

Тесты запускаются на каждый коммит. За запуск отвечает файл `.github/workflows/hexlet-check.yml` — не удаляйте и не переименовывайте ни его, ни репозиторий.

</details>

## О Хекслете

[Хекслет](https://ru.hexlet.io/) — школа программирования: авторские программы обучения с практикой, поддержкой наставников и реальными проектами, которые остаются в резюме. Этот репозиторий — один из таких проектов.
