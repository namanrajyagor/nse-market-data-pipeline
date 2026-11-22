"""
NSE market data pipeline (Airflow DAG).

Every weekday at 18:30 IST (NSE closes at 15:30):
    load_prices  ->  dbt_source_freshness  ->  dbt_build
    (new days,       (did the load            (models + data-quality tests;
     idempotent)      actually land?)          failing tests block the marts)
"""
from datetime import timedelta
from pathlib import Path

import pendulum
from airflow.providers.standard.operators.bash import BashOperator
from airflow.sdk import DAG

PROJECT = Path.home() / "project3-nse-pipeline"
PYTHON = PROJECT / ".venv" / "bin" / "python"        # Airflow environment (loader)
DBT = PROJECT / ".venv-dbt" / "bin" / "dbt"          # dbt environment
DBT_DIR = PROJECT / "dbt"
ALERT_LOG = PROJECT / "logs" / "alerts.log"
DBT_FLAGS = f"--project-dir {DBT_DIR} --profiles-dir {DBT_DIR}"


def notify_failure(context):
    """Alert hook: record every failed task attempt (in a company: email / Slack)."""
    ti = context["ti"]
    line = (f"{pendulum.now('Asia/Kolkata'):%Y-%m-%d %H:%M:%S} | FAILED | dag={ti.dag_id} "
            f"| task={ti.task_id} | run={ti.run_id} | try={ti.try_number}\n")
    with open(ALERT_LOG, "a") as f:
        f.write(line)


default_args = {
    "owner": "naman",
    "retries": 2,                          # temporary network / API errors
    "retry_delay": timedelta(minutes=5),
    "retry_exponential_backoff": True,     # wait longer after each failure
    "on_failure_callback": notify_failure,
}

with DAG(
    dag_id="nse_market_pipeline",
    description="Load NSE daily prices, check freshness, build and test dbt models",
    schedule="30 18 * * 1-5",              # 18:30 IST, Monday-Friday
    start_date=pendulum.datetime(2026, 11, 1, tz="Asia/Kolkata"),
    catchup=False,                         # don't back-run every missed day
    max_active_runs=1,                     # never two loads at once
    dagrun_timeout=timedelta(hours=1),
    default_args=default_args,
    tags=["nse", "dbt", "daily"],
) as dag:

    load_prices = BashOperator(
        task_id="load_prices",
        bash_command=f"{PYTHON} {PROJECT}/extract/load_prices.py --mode incremental",
        execution_timeout=timedelta(minutes=20),
    )

    dbt_source_freshness = BashOperator(
        task_id="dbt_source_freshness",
        bash_command=f"cd {DBT_DIR} && {DBT} source freshness {DBT_FLAGS}",
        retries=0,
        execution_timeout=timedelta(minutes=10),
    )

    dbt_build = BashOperator(
        task_id="dbt_build",
        bash_command=f"cd {DBT_DIR} && {DBT} build {DBT_FLAGS}",
        retries=0,                         # a failed data test won't fix itself by retrying
        execution_timeout=timedelta(minutes=20),
    )

    load_prices >> dbt_source_freshness >> dbt_build