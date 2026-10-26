"""Собирает дашборд «Продажи» в локальном Superset через REST API.

Источник данных — таблицы схемы reports (csv-выгрузки проекта, загруженные
в PostgreSQL). Повторный запуск пересоздаёт датасеты, графики и дашборд.
Запуск: make dashboard-build (контейнер tools).
"""

import io
import json
import os
import uuid
import zipfile

import requests

SUPERSET_URL = os.environ.get("SUPERSET_URL", "http://localhost:8088")
USERNAME = os.environ.get("SUPERSET_ADMIN_USER", "admin")
PASSWORD = os.environ.get("SUPERSET_ADMIN_PASSWORD", "admin")
DATABASE_NAME = "salesdb"
SCHEMA = "reports"
DASHBOARD_SLUG = "sales"
DASHBOARD_TITLE = "Продажи: продавцы и покупатели"

MILLION = 1_000_000

WEEKDAY_LABELS_SQL = """
SELECT
    seller,
    day_of_week,
    income,
    CASE day_of_week
        WHEN 'monday' THEN '1 Пн'
        WHEN 'tuesday' THEN '2 Вт'
        WHEN 'wednesday' THEN '3 Ср'
        WHEN 'thursday' THEN '4 Чт'
        WHEN 'friday' THEN '5 Пт'
        WHEN 'saturday' THEN '6 Сб'
        WHEN 'sunday' THEN '7 Вс'
    END AS day_label
FROM reports.day_of_the_week_income
""".strip()

# Датасеты: имя -> SQL виртуального датасета (None — физическая таблица).
DATASETS = {
    "customers_count": None,
    "top_10_total_income": None,
    "lowest_average_income": None,
    "day_of_the_week_income_labeled": WEEKDAY_LABELS_SQL,
    "age_groups": None,
    "customers_by_month": None,
    "special_offer": None,
}


def sql_metric(expression, label):
    return {
        "expressionType": "SQL",
        "sqlExpression": expression,
        "label": label,
        "optionName": f"metric_{uuid.uuid4().hex[:12]}",
    }


def bar_params(x_column, metric, x_title, y_title, number_format,
               horizontal=False, sort_by_metric=True, sort_asc=False,
               axis_max=None):
    params = {
        "x_axis": x_column,
        "metrics": [metric],
        "groupby": [],
        "adhoc_filters": [],
        "row_limit": 1000,
        "orientation": "horizontal" if horizontal else "vertical",
        "show_value": True,
        "show_legend": False,
        "rich_tooltip": True,
        "y_axis_format": number_format,
        "x_axis_title": x_title,
        "x_axis_title_margin": 125 if horizontal else 30,
        "y_axis_title": y_title,
        "y_axis_title_margin": 30 if horizontal else 50,
        "y_axis_title_position": "Left",
        "truncateXAxis": True,
        "x_axis_sort_asc": sort_asc,
        "color_scheme": "supersetColors",
    }
    if sort_by_metric:
        params["x_axis_sort"] = metric["label"]
    if axis_max is not None:
        # Запас по оси, чтобы подпись самого длинного столбца не обрезалась.
        params["truncateYAxis"] = True
        params["y_axis_bounds"] = [0, axis_max]
    return params


def chart_specs():
    income_mln = sql_metric(f"SUM(income) / {MILLION}.0", "Выручка, млн")
    return [
        {
            "key": "customers_count",
            "name": "Всего покупателей в базе",
            "dataset": "customers_count",
            "viz_type": "big_number_total",
            "params": {
                "metric": sql_metric("MAX(customers_count)", "Покупателей"),
                "subheader": "покупателей в таблице customers",
                "y_axis_format": ",d",
                "adhoc_filters": [],
            },
        },
        {
            "key": "special_offer_count",
            "name": "Первая покупка — акционный товар",
            "dataset": "special_offer",
            "viz_type": "big_number_total",
            "params": {
                "metric": sql_metric("COUNT(*)", "Покупателей"),
                "subheader": "покупателей пришли за товаром с нулевой ценой",
                "y_axis_format": ",d",
                "adhoc_filters": [],
            },
        },
        {
            "key": "top_10_total_income",
            "name": "Топ-10 продавцов по выручке, млн",
            "dataset": "top_10_total_income",
            "viz_type": "echarts_timeseries_bar",
            "params": bar_params(
                "seller", income_mln, "Продавец", "Выручка, млн",
                ",.0f", horizontal=True, sort_asc=True, axis_max=6000,
            ),
        },
        {
            "key": "top_10_operations",
            "name": "Топ-10 продавцов: количество сделок",
            "dataset": "top_10_total_income",
            "viz_type": "echarts_timeseries_bar",
            "params": bar_params(
                "seller", sql_metric("SUM(operations)", "Сделок"),
                "Продавец", "Сделок", ",d", horizontal=True, sort_asc=True,
            ),
        },
        {
            "key": "lowest_average_income",
            "name": "Средняя выручка за сделку ниже средней по всем",
            "dataset": "lowest_average_income",
            "viz_type": "echarts_timeseries_bar",
            "params": bar_params(
                "seller",
                sql_metric("SUM(average_income)", "Средняя выручка за сделку"),
                "Продавец", "Средняя выручка за сделку", ",d",
                horizontal=True, sort_asc=False, axis_max=275000,
            ),
        },
        {
            "key": "income_by_weekday",
            "name": "Выручка по дням недели, млн",
            "dataset": "day_of_the_week_income_labeled",
            "viz_type": "echarts_timeseries_bar",
            "params": {
                **bar_params(
                    "day_label", income_mln, "День недели", "Выручка, млн",
                    ",.0f", sort_by_metric=False,
                ),
                "x_axis_sort": "day_label",
                "x_axis_sort_asc": True,
            },
        },
        {
            "key": "seller_weekday_pivot",
            "name": "Выручка продавцов по дням недели, млн",
            "dataset": "day_of_the_week_income_labeled",
            "viz_type": "pivot_table_v2",
            "params": {
                "groupbyRows": ["seller"],
                "groupbyColumns": ["day_label"],
                "metrics": [income_mln],
                "metricsLayout": "COLUMNS",
                "aggregateFunction": "Sum",
                "valueFormat": ",.1f",
                "rowTotals": True,
                "colTotals": True,
                "rowOrder": "value_z_to_a",
                "colOrder": "key_a_to_z",
                "adhoc_filters": [],
                "row_limit": 10000,
                "conditional_formatting": [],
            },
        },
        {
            "key": "age_groups",
            "name": "Покупатели по возрастным группам",
            "dataset": "age_groups",
            "viz_type": "pie",
            "params": {
                "groupby": ["age_category"],
                "metric": sql_metric("SUM(age_count)", "Покупателей"),
                "adhoc_filters": [],
                "row_limit": 100,
                "sort_by_metric": False,
                "show_labels": True,
                "label_type": "key_value_percent",
                "number_format": ",d",
                "labels_outside": True,
                "label_line": True,
                "show_legend": True,
                "legendOrientation": "top",
                "donut": True,
                "show_total": True,
                "innerRadius": 35,
                "outerRadius": 70,
                "color_scheme": "supersetColors",
            },
        },
        {
            "key": "income_by_month",
            "name": "Выручка по месяцам, млн",
            "dataset": "customers_by_month",
            "viz_type": "echarts_timeseries_bar",
            "params": {
                **bar_params(
                    "selling_month", income_mln, "Месяц", "Выручка, млн",
                    ",.0f", sort_by_metric=False,
                ),
                "x_axis_sort": "selling_month",
                "x_axis_sort_asc": True,
            },
        },
        {
            "key": "customers_by_month",
            "name": "Уникальные покупатели по месяцам",
            "dataset": "customers_by_month",
            "viz_type": "echarts_timeseries_bar",
            "params": {
                **bar_params(
                    "selling_month",
                    sql_metric("SUM(total_customers)", "Покупателей"),
                    "Месяц", "Покупателей", ",d", sort_by_metric=False,
                ),
                "x_axis_sort": "selling_month",
                "x_axis_sort_asc": True,
            },
        },
        {
            "key": "special_offer_table",
            "name": "Покупатели, начавшие с акционного товара",
            "dataset": "special_offer",
            "viz_type": "table",
            "params": {
                "query_mode": "raw",
                "all_columns": ["customer", "sale_date", "seller"],
                "order_by_cols": [],
                "adhoc_filters": [],
                "row_limit": 1000,
                "table_timestamp_format": "%Y-%m-%d",
                "include_search": False,
                "show_cell_bars": False,
            },
        },
    ]


# Раскладка дашборда: строки из (ключ графика | markdown, ширина, высота).
LAYOUT = [
    [("md:# Продажи торговой площадки\nСентябрь – декабрь 1992 года. "
      "Данные — выгрузки запросов из `queries.sql` (схема `reports`).", 12, 14)],
    [("customers_count", 4, 40), ("special_offer_count", 4, 40),
     ("age_groups", 4, 40)],
    [("md:## Продавцы", 12, 8)],
    [("top_10_total_income", 6, 60), ("top_10_operations", 6, 60)],
    [("lowest_average_income", 6, 60), ("income_by_weekday", 6, 60)],
    [("seller_weekday_pivot", 12, 104)],
    [("md:## Покупатели", 12, 8)],
    [("income_by_month", 6, 50), ("customers_by_month", 6, 50)],
    [("special_offer_table", 12, 70)],
]


class Superset:
    def __init__(self, base_url):
        self.base_url = base_url.rstrip("/")
        self.session = requests.Session()

    def login(self, username, password):
        response = self.session.post(
            f"{self.base_url}/api/v1/security/login",
            json={"username": username, "password": password,
                  "provider": "db", "refresh": True},
            timeout=30,
        )
        response.raise_for_status()
        token = response.json()["access_token"]
        self.session.headers["Authorization"] = f"Bearer {token}"

    def request(self, method, path, **kwargs):
        response = self.session.request(
            method, f"{self.base_url}/api/v1/{path}", timeout=60, **kwargs
        )
        if response.status_code >= 400:
            raise RuntimeError(
                f"{method} {path}: {response.status_code} {response.text}"
            )
        return response.json() if response.text else {}

    def list_all(self, resource):
        return self.request(
            "GET", f"{resource}/", params={"q": "(page_size:100)"}
        )["result"]


def delete_previous(api, chart_names):
    for dashboard in api.list_all("dashboard"):
        if dashboard.get("slug") == DASHBOARD_SLUG:
            api.request("DELETE", f"dashboard/{dashboard['id']}")
    for chart in api.list_all("chart"):
        if chart["slice_name"] in chart_names:
            api.request("DELETE", f"chart/{chart['id']}")
    for dataset in api.list_all("dataset"):
        if dataset["table_name"] in DATASETS:
            api.request("DELETE", f"dataset/{dataset['id']}")


def create_datasets(api, database_id):
    ids = {}
    for name, sql in DATASETS.items():
        payload = {"database": database_id, "schema": SCHEMA,
                   "table_name": name}
        if sql:
            payload["sql"] = sql
        ids[name] = api.request("POST", "dataset/", json=payload)["id"]
    return ids


def chart_uuids(api, chart_ids):
    """uuid графиков нужен в раскладке: по нему импорт связывает графики.

    REST API отдаёт uuid только в выгрузке, поэтому берём его из zip-архива
    экспорта графиков (файл charts/<имя>_<id>.yaml).
    """
    ids = ",".join(str(chart_id) for chart_id in chart_ids.values())
    response = api.session.get(
        f"{api.base_url}/api/v1/chart/export/",
        params={"q": f"!({ids})"}, timeout=60,
    )
    response.raise_for_status()
    uuids = {}
    with zipfile.ZipFile(io.BytesIO(response.content)) as archive:
        for name in archive.namelist():
            if "/charts/" not in name:
                continue
            chart_id = int(name.rsplit("/", 1)[1].rsplit("_", 1)[-1][:-5])
            for line in archive.read(name).decode().splitlines():
                if line.startswith("uuid: "):
                    uuids[chart_id] = line.split(": ", 1)[1].strip()
    return uuids


def build_position(chart_ids, chart_names, uuids):
    position = {
        "DASHBOARD_VERSION_KEY": "v2",
        "ROOT_ID": {"type": "ROOT", "id": "ROOT_ID",
                    "children": ["GRID_ID"]},
        "GRID_ID": {"type": "GRID", "id": "GRID_ID", "children": [],
                    "parents": ["ROOT_ID"]},
        "HEADER_ID": {"id": "HEADER_ID", "type": "HEADER",
                      "meta": {"text": DASHBOARD_TITLE}},
    }
    for row_index, row in enumerate(LAYOUT, start=1):
        row_id = f"ROW-{row_index}"
        position["GRID_ID"]["children"].append(row_id)
        position[row_id] = {
            "type": "ROW", "id": row_id, "children": [],
            "parents": ["ROOT_ID", "GRID_ID"],
            "meta": {"background": "BACKGROUND_TRANSPARENT"},
        }
        for item_index, (key, width, height) in enumerate(row, start=1):
            parents = ["ROOT_ID", "GRID_ID", row_id]
            if key.startswith("md:"):
                item_id = f"MARKDOWN-{row_index}-{item_index}"
                position[item_id] = {
                    "type": "MARKDOWN", "id": item_id, "children": [],
                    "parents": parents,
                    "meta": {"width": width, "height": height,
                             "code": key[len("md:"):]},
                }
            else:
                item_id = f"CHART-{key}"
                position[item_id] = {
                    "type": "CHART", "id": item_id, "children": [],
                    "parents": parents,
                    "meta": {"width": width, "height": height,
                             "chartId": chart_ids[key],
                             "uuid": uuids[chart_ids[key]],
                             "sliceName": chart_names[key]},
                }
            position[row_id]["children"].append(item_id)
    return position


def main():
    api = Superset(SUPERSET_URL)
    api.login(USERNAME, PASSWORD)

    database_id = next(
        db["id"] for db in api.list_all("database")
        if db["database_name"] == DATABASE_NAME
    )
    specs = chart_specs()
    chart_names = {spec["key"]: spec["name"] for spec in specs}

    delete_previous(api, set(chart_names.values()))
    dataset_ids = create_datasets(api, database_id)

    dashboard_id = api.request("POST", "dashboard/", json={
        "dashboard_title": DASHBOARD_TITLE,
        "slug": DASHBOARD_SLUG,
        "published": True,
    })["id"]

    chart_ids = {}
    for spec in specs:
        dataset_id = dataset_ids[spec["dataset"]]
        params = {
            "datasource": f"{dataset_id}__table",
            "viz_type": spec["viz_type"],
            **spec["params"],
        }
        chart_ids[spec["key"]] = api.request("POST", "chart/", json={
            "slice_name": spec["name"],
            "viz_type": spec["viz_type"],
            "datasource_id": dataset_id,
            "datasource_type": "table",
            "params": json.dumps(params, ensure_ascii=False),
            "dashboards": [dashboard_id],
        })["id"]

    api.request("PUT", f"dashboard/{dashboard_id}", json={
        "position_json": json.dumps(
            build_position(chart_ids, chart_names,
                           chart_uuids(api, chart_ids)),
            ensure_ascii=False
        ),
        "json_metadata": json.dumps({
            "color_scheme": "supersetColors",
            "refresh_frequency": 0,
            "native_filter_configuration": [],
        }),
    })

    print(f"Дашборд {dashboard_id}: {SUPERSET_URL}/superset/dashboard/"
          f"{DASHBOARD_SLUG}/")
    for key, chart_id in chart_ids.items():
        print(f"  {chart_id}: {chart_names[key]}")


if __name__ == "__main__":
    main()
