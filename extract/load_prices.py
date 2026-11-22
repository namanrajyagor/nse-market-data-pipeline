"""
Extract daily NSE prices from Yahoo Finance and load them into PostgreSQL (raw.daily_prices).

Modes
  backfill     load the last N years for every symbol
  incremental  load only recent days: from (latest date already loaded - look-back) to today

Idempotent: rows are upserted on (symbol, trade_date), so re-running never creates duplicates.
Every symbol's result is written to raw.load_log.
"""
import argparse
import logging
import os
import sys
import time
from datetime import date, datetime, timedelta, timezone
from pathlib import Path

import pandas as pd
import psycopg2
import yfinance as yf
from psycopg2.extras import execute_values

PROJECT_DIR = Path(__file__).resolve().parent.parent
UNIVERSE_FILE = PROJECT_DIR / "extract" / "stock_universe.csv"
LOG_FILE = PROJECT_DIR / "logs" / "load_prices.log"

# Connection settings - the password is NOT here; PostgreSQL reads it from ~/.pgpass
DB = dict(
    host=os.getenv("PGHOST", "localhost"),
    port=int(os.getenv("PGPORT", "5432")),
    dbname=os.getenv("PGDATABASE", "nse_market"),
    user=os.getenv("PGUSER", "postgres"),
)
MAX_RETRIES = 3

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)s | %(message)s",
    handlers=[logging.StreamHandler(sys.stdout), logging.FileHandler(LOG_FILE)],
)
log = logging.getLogger("load_prices")

UPSERT_SQL = """
INSERT INTO raw.daily_prices
    (symbol, trade_date, open, high, low, close, adj_close, volume, run_id)
VALUES %s
ON CONFLICT (symbol, trade_date) DO UPDATE SET
    open = EXCLUDED.open, high = EXCLUDED.high, low = EXCLUDED.low,
    close = EXCLUDED.close, adj_close = EXCLUDED.adj_close, volume = EXCLUDED.volume,
    run_id = EXCLUDED.run_id, loaded_at = now()
"""

LOG_SQL = """
INSERT INTO raw.load_log
    (run_id, symbol, load_mode, start_date, end_date, rows_received, rows_upserted,
     status, error_message, started_at)
VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
"""


def latest_dates(conn):
    """Latest trade_date already loaded for each symbol."""
    with conn.cursor() as cur:
        cur.execute("SELECT symbol, MAX(trade_date) FROM raw.daily_prices GROUP BY symbol")
        return dict(cur.fetchall())


def download(symbol, start, end):
    """Download daily prices with retries; returns a tidy DataFrame (may be empty)."""
    for attempt in range(1, MAX_RETRIES + 1):
        try:
            df = yf.download(symbol, start=start, end=end + timedelta(days=1),  # end is exclusive
                             interval="1d", auto_adjust=False, actions=False,
                             progress=False, threads=False)
            break
        except Exception as exc:                      # network errors, rate limits
            if attempt == MAX_RETRIES:
                raise
            wait = 2 ** attempt
            log.warning("%s: attempt %d failed (%s), retrying in %ds", symbol, attempt, exc, wait)
            time.sleep(wait)

    if df is None or df.empty:
        return pd.DataFrame()
    if isinstance(df.columns, pd.MultiIndex):         # yfinance may return (field, ticker) columns
        df.columns = df.columns.get_level_values(0)
    df = df.rename(columns={"Open": "open", "High": "high", "Low": "low", "Close": "close",
                            "Adj Close": "adj_close", "Volume": "volume"})
    df = df.dropna(subset=["close"])
    df["trade_date"] = df.index.date
    return df[["trade_date", "open", "high", "low", "close", "adj_close", "volume"]]


def to_rows(symbol, df, run_id):
    """Convert the DataFrame into plain Python tuples for PostgreSQL."""
    def num(x):
        return None if pd.isna(x) else float(x)
    return [
        (symbol, r.trade_date, num(r.open), num(r.high), num(r.low), num(r.close),
         num(r.adj_close), None if pd.isna(r.volume) else int(r.volume), run_id)
        for r in df.itertuples(index=False)
    ]


def main():
    parser = argparse.ArgumentParser(description="Load NSE daily prices into PostgreSQL")
    parser.add_argument("--mode", choices=["backfill", "incremental"], required=True)
    parser.add_argument("--years", type=int, default=5, help="history to load in backfill mode")
    parser.add_argument("--lookback-days", type=int, default=7,
                        help="calendar days re-loaded in incremental mode (~5 trading days)")
    parser.add_argument("--symbols", nargs="*", help="optional subset of symbols (for testing)")
    args = parser.parse_args()

    universe = pd.read_csv(UNIVERSE_FILE)
    symbols = args.symbols or universe["yf_symbol"].tolist()
    today = date.today()
    run_id = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ") + f"_{args.mode}"
    log.info("Run %s started: %d symbols", run_id, len(symbols))

    conn = psycopg2.connect(**DB)
    latest = latest_dates(conn) if args.mode == "incremental" else {}

    totals = {"success": 0, "no_data": 0, "failed": 0, "rows": 0}
    for symbol in symbols:
        started = datetime.now(timezone.utc)
        if args.mode == "backfill" or symbol not in latest:   # new symbol -> full history
            start, mode = today - timedelta(days=365 * args.years), "backfill"
        else:
            start, mode = latest[symbol] - timedelta(days=args.lookback_days), "incremental"

        rows_received = rows_upserted = 0
        error = None
        try:
            df = download(symbol, start, today)
            if len(df) and datetime.now().hour < 16:   # NSE closes 15:30 IST: skip today's incomplete bar
                df = df[df["trade_date"] < today]
            rows_received = len(df)
            if rows_received:
                with conn.cursor() as cur:
                    execute_values(cur, UPSERT_SQL, to_rows(symbol, df, run_id), page_size=1000)
                rows_upserted = rows_received
                status = "success"
            else:
                status = "no_data"
        except Exception as exc:
            conn.rollback()                                  # discard this symbol's partial work
            status, error = "failed", str(exc)[:500]
            log.error("%s: FAILED - %s", symbol, error)

        with conn.cursor() as cur:
            cur.execute(LOG_SQL, (run_id, symbol, mode, start, today, rows_received,
                                  rows_upserted, status, error, started))
        conn.commit()                                        # prices + log row saved together
        totals[status] += 1
        totals["rows"] += rows_upserted
        log.info("%-15s %-11s %s -> %s  rows=%-5d %s", symbol, mode, start, today, rows_upserted, status)
        time.sleep(0.3)                                      # be polite to the free API

    conn.close()
    log.info("Run %s finished: %d success, %d no_data, %d failed, %d rows upserted",
             run_id, totals["success"], totals["no_data"], totals["failed"], totals["rows"])
    sys.exit(1 if totals["failed"] else 0)                   # non-zero exit -> Airflow marks failure


if __name__ == "__main__":
    main()