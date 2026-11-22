-- ============================================================
-- 05_sector_correlation.sql
-- Q9: Which sectors move together, and which help diversify?
-- Correlation of daily sector returns over the last 365 days (validated marts).
-- ============================================================

-- Every pair of sectors (including the Nifty 'Index'), computed once for this session
CREATE TEMP VIEW sector_pairs AS
WITH r AS (
    SELECT sector, trade_date, sector_return
    FROM analytics.mart_sector_daily
    WHERE sector_return IS NOT NULL
      AND trade_date > (SELECT MAX(trade_date) FROM analytics.mart_sector_daily) - INTERVAL '365 days'
)
SELECT a.sector                                  AS sector_a,
       b.sector                                  AS sector_b,
       CORR(a.sector_return, b.sector_return)    AS corr,
       COUNT(*)                                  AS days
FROM r a
JOIN r b
  ON a.trade_date = b.trade_date
 AND a.sector < b.sector          -- each pair once, no sector paired with itself
GROUP BY a.sector, b.sector;

-- 1. Sectors that move together most (weakest diversification)
SELECT sector_a, sector_b, ROUND(corr::numeric, 2) AS correlation, days
FROM sector_pairs
WHERE 'Index' NOT IN (sector_a, sector_b)
ORDER BY corr DESC
LIMIT 5;

-- 2. Sectors that move together least (best diversification)
SELECT sector_a, sector_b, ROUND(corr::numeric, 2) AS correlation, days
FROM sector_pairs
WHERE 'Index' NOT IN (sector_a, sector_b)
ORDER BY corr ASC
LIMIT 5;

-- 3. Each sector: correlation with the Nifty 50, and average correlation with the other sectors
SELECT sector,
       ROUND((MAX(corr) FILTER (WHERE other = 'Index'))::numeric, 2)   AS corr_with_nifty,
       ROUND((AVG(corr) FILTER (WHERE other <> 'Index'))::numeric, 2)  AS avg_corr_with_other_sectors
FROM (
    SELECT sector_a AS sector, sector_b AS other, corr FROM sector_pairs
    UNION ALL
    SELECT sector_b, sector_a, corr FROM sector_pairs
) x
WHERE sector <> 'Index'
GROUP BY sector
ORDER BY avg_corr_with_other_sectors DESC;