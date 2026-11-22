# Extract & Load — How Raw Data Gets In

## Source and universe
- **Source:** Yahoo Finance via `yfinance` (daily OHLCV, unadjusted close + adjusted close)
- **Universe:** `extract/stock_universe.csv` — 50 large-cap NSE stocks across 11 sectors + the Nifty 50 index (`^NSEI`)
- **Validation:** `extract/validate_universe.py` checks every symbol returns recent data before loading
  - `TATAMOTORS.NS` failed (delisted after the 2025 demerger) → replaced with `TMPV.NS` after confirming it carries the full 5-year history (1,236 trading days)
  - Note for data quality: the demerger causes a large one-day price drop that is a corporate action, not a real crash

## Raw tables (`sql/00_raw_schema.sql`)
| Table | Grain | Key | Purpose |
|---|---|---|---|
| raw.daily_prices | stock × trading day | (symbol, trade_date) | Prices exactly as received + run_id and loaded_at (lineage) |
| raw.load_log | stock × run | (run_id, symbol) | Mode, date range, rows received/upserted, status, error |

Prices use `NUMERIC(14,4)` (exact), not floating point.

## Loader (`extract/load_prices.py`)
| Mode | What it loads |
|---|---|
| `--mode backfill` | Last 5 years for every symbol |
| `--mode incremental` | From (latest loaded date − 7 calendar days ≈ 5 trading days) to today |

| Reliability feature | How |
|---|---|
| Idempotent | `INSERT … ON CONFLICT (symbol, trade_date) DO UPDATE` |
| Look-back window | Re-loads recent days to catch late data and corrections |
| Retries | 3 attempts with exponential back-off (2s, 4s) |
| Failure isolation | One symbol failing does not stop the run; error logged |
| Atomic per symbol | Prices and the log row commit together |
| Logging | `raw.load_log` + `logs/load_prices.log` |
| Exit code | Non-zero if any symbol failed (so the scheduler marks the run failed) |
| Credentials | Read from `~/.pgpass`, never in code |
| Timezone | Linux set to Asia/Kolkata so "today" is the Indian trading date |

## Results
| Run | Symbols | Rows upserted | Failures |
|---|---|---|---|
| Test backfill (2 symbols) | 2 | 2,467 | 0 |
| Full backfill | 51 | 62,447 | 0 |
| Incremental #1 | 51 | 255 | 0 |
| Incremental #2 (re-run) | 51 | 255 | 0 |

- **Table total: 62,449 rows**, 51 symbols, 17 Nov 2021 – 13 Nov 2026
- JIOFIN.NS has 798 days (listed 21 Aug 2023) — genuine shorter history
- **Idempotency proven:** total unchanged after two incremental runs; 0 duplicate keys