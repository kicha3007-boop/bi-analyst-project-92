# Локальный стенд проекта «Продажи»: PostgreSQL с базой торговой площадки,
# Superset с дашбордом и инструменты для выгрузок, скриншотов и презентации.

COMPOSE = docker compose
CHECK_IMAGE = hexletprojects/data_analytics_l1_project_ru:latest

.PHONY: up build down reset load reports load-reports psql dashboard \
	dashboard-build dashboard-export screenshots presentation lint test

build:
	$(COMPOSE) build --no-cache superset

up: build
	$(COMPOSE) up -d --wait db superset
	@echo "Дашборд: http://localhost:8088/superset/dashboard/sales/ (admin / admin)"

down:
	$(COMPOSE) --profile tools down

# Полный сброс: удалить тома и поднять стенд с нуля.
reset:
	$(COMPOSE) --profile tools down -v
	$(MAKE) up

# Перезалить данные в работающую базу (дамп, Google-таблицы, выгрузки).
load:
	$(COMPOSE) exec -T db sh /project/scripts/reload_db.sh

# Пересчитать все csv-выгрузки запросами из queries.sql.
reports:
	$(COMPOSE) exec -T db sh /project/scripts/export_reports.sh

# Загрузить csv-выгрузки в схему reports (данные для дашборда).
load-reports:
	$(COMPOSE) exec -T db sh -c 'psql -X -q -v ON_ERROR_STOP=1 \
		-U "$$POSTGRES_USER" -d "$$POSTGRES_DB" \
		-f /docker-entrypoint-initdb.d/30_reports.sql'

psql:
	$(COMPOSE) exec db sh -c 'psql -U "$$POSTGRES_USER" -d "$$POSTGRES_DB"'

# Импортировать готовый дашборд из superset/export/dashboard.zip
# (при старте контейнера superset это происходит автоматически).
dashboard:
	$(COMPOSE) exec -T superset /app/import_dashboard.sh
	@echo "Дашборд: http://localhost:8088/superset/dashboard/sales/"

# Собрать дашборд заново через REST API Superset и выгрузить его в zip.
dashboard-build:
	$(COMPOSE) --profile tools build --no-cache tools
	$(COMPOSE) --profile tools run --rm tools python scripts/build_dashboard.py
	$(MAKE) dashboard-export

dashboard-export:
	$(COMPOSE) exec -T superset superset export-dashboards \
		-f /app/export/dashboard.zip

# Скриншоты графиков дашборда для презентации (presentation/img/).
screenshots:
	$(COMPOSE) --profile tools run --rm tools python scripts/screenshots.py

# Собрать presentation.pdf из presentation/slides.html.
presentation:
	$(COMPOSE) --profile tools run --rm tools python scripts/render_pdf.py

lint:
	docker run --rm -v "$(CURDIR):/project/code" --entrypoint sh $(CHECK_IMAGE) \
		-c "python3 -m sqlfluff lint /project/code/queries.sql"

# Автопроверка Хекслета локально: сверка csv и наличие файлов.
test:
	docker run --rm -v "$(CURDIR):/project/code" --entrypoint sh $(CHECK_IMAGE) \
		-c "make setup >/dev/null 2>&1; make test"
