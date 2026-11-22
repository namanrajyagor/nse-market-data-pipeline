-- Fails when any stock's latest date is behind the overall latest date
-- (usually means that stock's load failed).
with latest as (
    select symbol, max(trade_date) as last_date
    from {{ ref('fct_daily_prices') }}
    group by symbol
)
select symbol, last_date, (select max(last_date) from latest) as expected_date
from latest
where last_date < (select max(last_date) from latest)