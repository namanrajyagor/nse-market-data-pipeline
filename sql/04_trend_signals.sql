-- ============================================================
-- 04_trend_signals.sql
-- Q8: Which stocks are in an uptrend or downtrend, and how broad is the market's trend?
-- Uses the marts (last validated snapshot); not investment advice.
-- ============================================================

-- 1. The Nifty 50's own trend
SELECT ticker, as_of_date,
       ROUND(price, 1)                              AS price,
       ROUND(100 * pct_vs_ma_50, 1)                 AS vs_ma50_pct,
       ROUND(100 * pct_vs_ma_200, 1)                AS vs_ma200_pct,
       golden_cross,
       trend_signal
FROM analytics.mart_trend_signals
WHERE is_index;

-- 2. Market breadth by sector, plus an "ALL STOCKS" total row (GROUPING SETS)
SELECT COALESCE(sector, 'ALL STOCKS')                                              AS sector,
       COUNT(*)                                                                    AS stocks,
       COUNT(*) FILTER (WHERE trend_signal IN ('Strong uptrend', 'Uptrend'))       AS in_uptrend,
       COUNT(*) FILTER (WHERE trend_signal IN ('Strong downtrend', 'Downtrend'))   AS in_downtrend,
       COUNT(*) FILTER (WHERE golden_cross)                                        AS golden_cross,
       ROUND(100.0 * COUNT(*) FILTER (WHERE trend_signal IN ('Strong uptrend', 'Uptrend'))
             / COUNT(*), 0)                                                        AS pct_in_uptrend
FROM analytics.mart_trend_signals
WHERE NOT is_index
GROUP BY GROUPING SETS ((sector), ())
ORDER BY GROUPING(sector), pct_in_uptrend DESC, sector;

-- 3. Closest to their 52-week high
SELECT ticker, sector,
       ROUND(100 * pct_from_52w_high, 1)   AS from_52w_high_pct,
       trend_signal
FROM analytics.mart_trend_signals
WHERE NOT is_index
ORDER BY pct_from_52w_high DESC
LIMIT 5;

-- 4. Furthest below their 52-week high
SELECT ticker, sector,
       ROUND(100 * pct_from_52w_high, 1)   AS from_52w_high_pct,
       trend_signal
FROM analytics.mart_trend_signals
WHERE NOT is_index
ORDER BY pct_from_52w_high ASC
LIMIT 5;