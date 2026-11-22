# Orchestration — Airflow

Apache Airflow 3.4.0, running locally in WSL (Ubuntu 24.04) with `airflow standalone`. DAG file: `dags/nse_market_pipeline.py`.

## Setup
| Setting | Value | Why |
|---|---|---|
| Metadata database | PostgreSQL (`airflow_meta`) | Production-style; SQLite is for quick tests only |
| Executor | LocalExecutor, parallelism 2 | Matches the 2 CPU threads given to WSL |
| Timezone | Asia/Kolkata | Schedule and UI in IST |
| Example DAGs | Off | Clean UI |
| Credentials | `~/.pgpass` | No password in config files |
| Settings | `airflow.env` (`source airflow.env`) | One command to load the configuration |
| UI | http://localhost:8080 | Reached from Windows through WSL mirrored networking |

## DAG: `nse_market_pipeline`
```
load_prices  →  dbt_source_freshness  →  dbt_build
```
| Task | Command | Timeout | Retries |
|---|---|---|---|
| load_prices | `.venv/bin/python extract/load_prices.py --mode incremental` | 20 min | 2 (exponential back-off from 5 min) |
| dbt_source_freshness | `.venv-dbt/bin/dbt source freshness` | 10 min | 0 |
| dbt_build | `.venv-dbt/bin/dbt build` (seeds, models, 23 tests) | 20 min | 0 — a failed data test will not fix itself |

| DAG setting | Value | Why |
|---|---|---|
| Schedule | `30 18 * * 1-5` | 18:30 IST on weekdays, 3 hours after NSE closes (15:30) |
| catchup | False | Do not back-run every missed day |
| max_active_runs | 1 | Two loads never run at the same time |
| dagrun_timeout | 1 hour | A stuck run is stopped |
| on_failure_callback | writes to `logs/alerts.log` | Alert hook (email/Slack in a company) |

Each task calls its own virtual environment, so Airflow and dbt dependencies never conflict.

## Verified runs (17 Nov 2026)
| Run | Result | Notes |
|---|---|---|
| Scheduled (16 Nov 18:30 slot, created on unpause) | Success | Ran first |
| Manual #1 | Success, 1 m 16 s | load 54.3 s → freshness 6.0 s → build 14.4 s; queued until the scheduled run finished (max_active_runs = 1); dbt `PASS=31 WARN=1 ERROR=0` |
| Manual #2 (failure test) | Failed → recovered | See below |

## Failure test
1. Planted an impossible row in raw: RELIANCE.NS, Sunday 2026-11-15, close = −1
2. Triggered the DAG: load ✅, freshness ✅, **dbt_build ❌** — `PASS=19 WARN=2 ERROR=1 SKIP=10`
   - `assert_valid_ohlc` failed (negative price); the extreme-move check also warned (−100% move)
   - The 3 marts and their tests were **skipped**, so analysts kept the last good data
   - Task failed once with no retry; the alert was written to `logs/alerts.log`
3. Deleted the bad row and **cleared only `dbt_build`** → try 2 succeeded (`PASS=31 WARN=1 ERROR=0`); the load was not repeated

## Limitations
- Runs only while the laptop, WSL and `airflow standalone` are running; in production Airflow would run on a server or a managed service
- Alerts go to a local file instead of email or Slack
- No NSE holiday calendar in the schedule: on a weekday holiday the load simply finds no new day, and the tests still pass