-- ============================================================
-- 00_raw_schema.sql
-- Raw layer: prices exactly as received + a log of every load
-- ============================================================

CREATE SCHEMA IF NOT EXISTS raw;

-- One row per stock per trading day
CREATE TABLE IF NOT EXISTS raw.daily_prices (
    symbol      TEXT          NOT NULL,              -- Yahoo symbol, e.g. RELIANCE.NS
    trade_date  DATE          NOT NULL,
    open        NUMERIC(14,4),
    high        NUMERIC(14,4),
    low         NUMERIC(14,4),
    close       NUMERIC(14,4),                       -- actual closing price
    adj_close   NUMERIC(14,4),                       -- adjusted for splits and dividends
    volume      BIGINT,
    source      TEXT          NOT NULL DEFAULT 'yfinance',
    run_id      TEXT          NOT NULL,              -- which pipeline run loaded this row
    loaded_at   TIMESTAMPTZ   NOT NULL DEFAULT now(),
    PRIMARY KEY (symbol, trade_date)                 -- makes duplicates impossible
);

CREATE INDEX IF NOT EXISTS idx_daily_prices_trade_date ON raw.daily_prices (trade_date);

-- One row per stock per pipeline run
CREATE TABLE IF NOT EXISTS raw.load_log (
    run_id         TEXT         NOT NULL,
    symbol         TEXT         NOT NULL,
    load_mode      TEXT         NOT NULL,            -- 'backfill' or 'incremental'
    start_date     DATE,
    end_date       DATE,
    rows_received  INTEGER,
    rows_upserted  INTEGER,
    status         TEXT         NOT NULL,            -- 'success', 'no_data' or 'failed'
    error_message  TEXT,
    started_at     TIMESTAMPTZ  NOT NULL,
    finished_at    TIMESTAMPTZ  NOT NULL DEFAULT now(),
    PRIMARY KEY (run_id, symbol)
);