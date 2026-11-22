# NSE Market Data Pipeline — Project Design

## 1. Objective
Act as a Data Engineer for a brokerage / fintech research team. Analysts currently download stock prices by hand, so the data is often late, incomplete or inconsistent. Build a pipeline that delivers **clean, tested, automatically refreshed daily price data** for large-cap NSE stocks, plus ready-to-use metrics — and then use it to answer market questions.

## 2. Stakeholders
| Stakeholder | Needs |
|---|---|
| Research analysts | Trustworthy daily prices and returns, ready by evening on each trading day |
| Portfolio / risk team | Volatility, drawdowns, sector performance, comparison with the Nifty 50 |
| Data team (me) | A pipeline that is automated, re-runnable, tested and easy to monitor |

## 3. Scope
- **Universe:** a fixed list of ~50 large-cap NSE stocks based on the Nifty 50 (snapshot taken when the project was built) + the **Nifty 50 index** as a benchmark
- **Data:** daily OHLCV (open, high, low, close, adjusted close, volume) per stock
- **History:** 5-year backfill, then daily incremental loads
- **Source:** Yahoo Finance via the `yfinance` Python library (symbols end in `.NS`; Nifty 50 index = `^NSEI`)
- **Currency / timezone:** Indian Rupees (₹); trading dates in IST

**Out of scope:** intraday or real-time data, order-book data, investment advice.

## 4. Business questions

### A. Pipeline (data engineering)
1. Can analysts get clean daily prices for the universe, refreshed automatically after market close on every trading day?
2. Is loading **incremental** (only new days) and **idempotent** (re-running never creates duplicates)?
3. Are data-quality problems (missing days, duplicates, impossible prices, stale data) caught **before** analysts use the data?
4. Is the pipeline **observable** — run history, row counts, failures, retries and freshness?

### B. Market insights (analytics)
5. Which stocks and sectors performed best and worst over 1 month, 3 months, 1 year and 5 years?
6. How do stocks compare on risk vs return (volatility, return per unit of risk, maximum drawdown)?
7. How did each stock perform against the Nifty 50 (relative performance, beta)?
8. Which stocks are in an uptrend or downtrend (price vs 50-day and 200-day moving averages)?
9. How correlated are sectors with each other (diversification)?
10. What were the biggest single-day moves, and how long did large drawdowns take to recover?

## 5. Architecture
```
Yahoo Finance (yfinance)  — ~50 NSE stocks + ^NSEI
        │  Python extract & load (incremental, idempotent, logged)
        ▼
PostgreSQL  raw schema
   raw.daily_prices      prices exactly as received + load metadata
   raw.load_log          one row per stock per run (rows, status, errors)
        │  dbt (SQL transformations + tests)
        ▼
PostgreSQL  analytics schema
   staging   →  stg_daily_prices            cleaned, typed, de-duplicated
   marts     →  dim_stock                   stock, company, sector
                fct_daily_prices            prices + daily returns, moving averages, volatility
                mart_stock_performance      period returns, risk, drawdown, beta
                mart_sector_daily           equal-weight sector index per day
                mart_trend_signals          trend status vs 50/200-day averages
        │
        ▼
Dashboard (Streamlit) + SQL market insights

Orchestration: Airflow runs extract → load → dbt run → dbt test
every weekday at 18:30 IST, with retries and failure alerts.
```

## 6. Data contract (what each table guarantees)
| Table | Grain (one row per) | Primary key | Freshness | Key guarantees / tests |
|---|---|---|---|---|
| raw.daily_prices | stock × trading date | (symbol, trade_date) | Updated each run | Unique key; loaded_at recorded |
| raw.load_log | stock × pipeline run | (run_id, symbol) | Each run | Status = success / failed; row counts |
| stg_daily_prices | stock × trading date | (symbol, trade_date) | — | Not null; unique; price > 0; high ≥ low; close between low and high; volume ≥ 0 |
| dim_stock | stock | symbol | Static (seed) | Unique; every stock has a sector |
| fct_daily_prices | stock × trading date | (symbol, trade_date) | Latest trading day by 19:00 IST | Unique; every symbol exists in dim_stock; no extreme daily return without a flag |
| mart_stock_performance | stock | symbol | Daily | One row per stock; values within sensible ranges |
| mart_sector_daily | sector × trading date | (sector, trade_date) | Daily | Unique; every sector present each day |
| mart_trend_signals | stock (latest day) | symbol | Daily | One row per stock |

**Service level:** data for a trading day available by **19:00 IST** (NSE closes at 15:30 IST).

## 7. Design decisions
| Decision | Reason |
|---|---|
| **Idempotent upsert** on (symbol, trade_date) with `INSERT … ON CONFLICT DO UPDATE` | Re-running a day replaces rows instead of duplicating them |
| **Look-back window:** each run re-loads the last 5 trading days | Catches late corrections and days missed by a failed run |
| **Raw layer kept exactly as received** | Problems can be traced back to the source; transformations can be rebuilt |
| **Adjusted close for returns, raw close kept too** | Adjusted prices account for splits and dividends, so returns aren't distorted |
| **NSE holidays are not "missing data"** | Gaps are checked against trading days that other stocks traded, not calendar days |
| **dbt for transformations** | SQL models in dependency order, with built-in tests and documentation |
| **Airflow for orchestration** | Scheduling, task order, retries, run history and alerts |
| **Separate environments for Airflow and dbt** | Avoids dependency conflicts between the two tools |
| **WSL + lightweight Airflow (no Docker)** | Runs on an 8 GB laptop |

## 8. Known limitations
- `yfinance` is an unofficial free source: data can have gaps or occasional errors → caught by tests, not trusted blindly
- **Survivorship bias:** the universe is today's large caps; stocks that dropped out of the index earlier are not included, which flatters long-term returns
- Index membership changes over time; the list is a fixed snapshot
- For learning and analysis only — not investment advice