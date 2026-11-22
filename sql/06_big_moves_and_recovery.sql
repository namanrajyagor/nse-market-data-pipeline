-- ============================================================
-- 06_big_moves_and_recovery.sql
-- Q10: Biggest single-day moves, and how long the deepest falls took to recover.
-- Uses the validated fact table; not investment advice.
-- ============================================================

-- 1. Nifty 50: biggest single-day moves since Nov 2021
SELECT trade_date,
       ROUND(100 * daily_return, 2)   AS move_pct,
       ROUND(adj_close_price, 1)      AS nifty_level
FROM analytics.fct_daily_prices
WHERE is_index
ORDER BY ABS(daily_return) DESC NULLS LAST
LIMIT 8;

-- 2. Individual stocks: biggest single-day moves
SELECT ticker, sector, trade_date,
       ROUND(100 * daily_return, 1)   AS move_pct
FROM analytics.fct_daily_prices
WHERE NOT is_index
ORDER BY ABS(daily_return) DESC NULLS LAST
LIMIT 10;

-- 3. Deepest falls: peak date, bottom date, and time to recover (Nifty + 8 deepest stocks)
WITH f AS (
    SELECT symbol, ticker, is_index, trade_date, adj_close_price, running_peak, drawdown
    FROM analytics.fct_daily_prices
),
trough AS (                               -- the worst day of each stock's history
    SELECT DISTINCT ON (symbol)
           symbol, ticker, is_index,
           trade_date    AS trough_date,
           drawdown      AS max_drawdown,
           running_peak  AS peak_price
    FROM f
    ORDER BY symbol, drawdown ASC, trade_date
),
peak AS (                                 -- the last day it stood at that peak before falling
    SELECT t.symbol, MAX(f.trade_date) AS peak_date
    FROM trough t
    JOIN f ON f.symbol = t.symbol
          AND f.trade_date <= t.trough_date
          AND f.adj_close_price = t.peak_price
    GROUP BY t.symbol
),
recovery AS (                             -- the first day it got back to that peak
    SELECT t.symbol, MIN(f.trade_date) AS recovery_date
    FROM trough t
    JOIN f ON f.symbol = t.symbol
          AND f.trade_date > t.trough_date
          AND f.adj_close_price >= t.peak_price
    GROUP BY t.symbol
)
SELECT t.ticker,
       p.peak_date,
       t.trough_date,
       ROUND(100 * t.max_drawdown, 1)                              AS max_drawdown_pct,
       (t.trough_date - p.peak_date)                               AS days_falling,
       r.recovery_date,
       COALESCE((r.recovery_date - t.trough_date)::text, 'not yet') AS days_to_recover
FROM trough t
JOIN peak p USING (symbol)
LEFT JOIN recovery r USING (symbol)
WHERE t.is_index
   OR t.symbol IN (SELECT symbol FROM trough WHERE NOT is_index ORDER BY max_drawdown LIMIT 8)
ORDER BY t.is_index DESC, t.max_drawdown;