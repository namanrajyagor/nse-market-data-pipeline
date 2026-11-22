-- ============================================================
-- 02_risk_vs_return.sql
-- Q6: Return per unit of risk, deepest falls, and whether higher risk paid off.
-- Uses the marts (last validated snapshot); not investment advice.
-- ============================================================

-- 1. Benchmark: the Nifty 50
SELECT ticker,
       ROUND((100 * return_1y)::numeric, 1)      AS ret_1y_pct,
       ROUND((100 * volatility_1y)::numeric, 1)  AS vol_1y_pct,
       ROUND(return_to_risk_1y::numeric, 2)      AS return_to_risk
FROM analytics.mart_stock_performance
WHERE is_index;

-- 2. Top 10 stocks by return per unit of risk (1 year)
SELECT ticker, sector,
       ROUND((100 * return_1y)::numeric, 1)      AS ret_1y_pct,
       ROUND((100 * volatility_1y)::numeric, 1)  AS vol_1y_pct,
       ROUND(return_to_risk_1y::numeric, 2)      AS return_to_risk
FROM analytics.mart_stock_performance
WHERE NOT is_index
ORDER BY return_to_risk_1y DESC
LIMIT 10;

-- 3. Deepest falls from a peak over the full history, and where each stock stands now
SELECT ticker, sector,
       ROUND((100 * max_drawdown)::numeric, 1)      AS max_drawdown_pct,
       ROUND((100 * current_drawdown)::numeric, 1)  AS current_drawdown_pct,
       ROUND((100 * cagr)::numeric, 1)              AS cagr_pct
FROM analytics.mart_stock_performance
WHERE NOT is_index
ORDER BY max_drawdown
LIMIT 8;

-- 4. Did higher risk pay? Stocks split into three equal groups by 1-year volatility
WITH t AS (
    SELECT *, NTILE(3) OVER (ORDER BY volatility_1y) AS vol_group
    FROM analytics.mart_stock_performance
    WHERE NOT is_index
)
SELECT CASE vol_group WHEN 1 THEN '1. Low volatility'
                      WHEN 2 THEN '2. Medium volatility'
                      ELSE '3. High volatility' END     AS risk_group,
       COUNT(*)                                          AS stocks,
       ROUND((100 * MIN(volatility_1y))::numeric, 1)     AS min_vol_pct,
       ROUND((100 * MAX(volatility_1y))::numeric, 1)     AS max_vol_pct,
       ROUND((100 * AVG(return_1y))::numeric, 1)         AS avg_ret_1y_pct,
       ROUND((100 * AVG(cagr))::numeric, 1)              AS avg_cagr_pct,
       ROUND((100 * AVG(max_drawdown))::numeric, 1)      AS avg_max_drawdown_pct
FROM t
GROUP BY vol_group
ORDER BY vol_group;