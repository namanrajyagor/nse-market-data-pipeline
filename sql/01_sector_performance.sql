-- ============================================================
-- 01_sector_performance.sql
-- Q5: Which sectors performed best and worst, and which stocks led each sector?
-- Uses the marts (last validated snapshot); not investment advice.
-- ============================================================

-- 1. Analysis as-of date (the latest date in the validated marts)
SELECT MAX(latest_date) AS analysis_as_of
FROM analytics.mart_stock_performance;

-- 2. Sector returns from the equal-weight sector index (base 100 = Nov 2021)
WITH asof AS (
    SELECT MAX(latest_date) AS d FROM analytics.mart_stock_performance
),
s AS (
    SELECT sector, trade_date, sector_index,
           ROW_NUMBER() OVER (PARTITION BY sector ORDER BY trade_date DESC) AS rn   -- 1 = latest day
    FROM analytics.mart_sector_daily, asof
    WHERE trade_date <= asof.d
)
SELECT
    sector,
    ROUND((100 * (MAX(sector_index) FILTER (WHERE rn = 1)
                / MAX(sector_index) FILTER (WHERE rn = 22) - 1))::numeric, 1)  AS ret_1m_pct,
    ROUND((100 * (MAX(sector_index) FILTER (WHERE rn = 1)
                / MAX(sector_index) FILTER (WHERE rn = 64) - 1))::numeric, 1)  AS ret_3m_pct,
    ROUND((100 * (MAX(sector_index) FILTER (WHERE rn = 1)
                / MAX(sector_index) FILTER (WHERE rn = 253) - 1))::numeric, 1) AS ret_1y_pct,
    ROUND((MAX(sector_index) FILTER (WHERE rn = 1) - 100)::numeric, 1)          AS since_nov_2021_pct
FROM s
GROUP BY sector
ORDER BY ret_1y_pct DESC;

-- 3. Best and worst stock in each sector over 1 year
WITH r AS (
    SELECT sector, ticker, return_1y,
           RANK() OVER (PARTITION BY sector ORDER BY return_1y DESC) AS best_rank,
           RANK() OVER (PARTITION BY sector ORDER BY return_1y ASC)  AS worst_rank,
           COUNT(*) OVER (PARTITION BY sector)                       AS stocks
    FROM analytics.mart_stock_performance
    WHERE NOT is_index
)
SELECT
    sector,
    stocks,
    MAX(ticker) FILTER (WHERE best_rank = 1)                                  AS best_stock,
    ROUND((100 * MAX(return_1y) FILTER (WHERE best_rank = 1))::numeric, 1)    AS best_1y_pct,
    MAX(ticker) FILTER (WHERE worst_rank = 1)                                 AS worst_stock,
    ROUND((100 * MAX(return_1y) FILTER (WHERE worst_rank = 1))::numeric, 1)   AS worst_1y_pct
FROM r
GROUP BY sector, stocks
ORDER BY sector;