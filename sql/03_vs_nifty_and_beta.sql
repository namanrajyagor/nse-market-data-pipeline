-- ============================================================
-- 03_vs_nifty_and_beta.sql
-- Q7: How did stocks perform against the Nifty 50, and how strongly do they move with it?
-- Uses the marts (last validated snapshot); not investment advice.
-- ============================================================

-- 1. How many of the 50 stocks beat the Nifty 50 over each period?
WITH n AS (
    SELECT return_1m, return_3m, return_1y, cagr
    FROM analytics.mart_stock_performance
    WHERE is_index
)
SELECT
    COUNT(*)                                                    AS stocks,
    COUNT(*) FILTER (WHERE s.return_1m > n.return_1m)           AS beat_nifty_1m,
    COUNT(*) FILTER (WHERE s.return_3m > n.return_3m)           AS beat_nifty_3m,
    COUNT(*) FILTER (WHERE s.return_1y > n.return_1y)           AS beat_nifty_1y,
    COUNT(*) FILTER (WHERE s.cagr > n.cagr)                     AS beat_nifty_cagr,
    ROUND((100 * MAX(n.return_1y))::numeric, 1)                 AS nifty_ret_1y_pct,
    ROUND((100 * PERCENTILE_CONT(0.5) WITHIN GROUP
          (ORDER BY s.return_1y::float8))::numeric, 1)          AS median_stock_ret_1y_pct
FROM analytics.mart_stock_performance s
CROSS JOIN n
WHERE NOT s.is_index;

-- 2. Most aggressive stocks (highest beta)
SELECT ticker, sector,
       ROUND(beta_1y::numeric, 2)               AS beta,
       ROUND(correlation_1y::numeric, 2)        AS correlation,
       ROUND((100 * return_1y)::numeric, 1)     AS ret_1y_pct
FROM analytics.mart_stock_performance
WHERE NOT is_index
ORDER BY beta_1y DESC
LIMIT 5;

-- 3. Most defensive stocks (lowest beta)
SELECT ticker, sector,
       ROUND(beta_1y::numeric, 2)               AS beta,
       ROUND(correlation_1y::numeric, 2)        AS correlation,
       ROUND((100 * return_1y)::numeric, 1)     AS ret_1y_pct
FROM analytics.mart_stock_performance
WHERE NOT is_index
ORDER BY beta_1y ASC
LIMIT 5;

-- 4. Average beta and correlation by sector (aggressive vs defensive sectors)
SELECT sector,
       COUNT(*)                                     AS stocks,
       ROUND(AVG(beta_1y)::numeric, 2)              AS avg_beta,
       ROUND(AVG(correlation_1y)::numeric, 2)       AS avg_correlation
FROM analytics.mart_stock_performance
WHERE NOT is_index
GROUP BY sector
ORDER BY avg_beta DESC;