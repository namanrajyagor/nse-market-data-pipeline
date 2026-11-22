-- One row per sector per trading day: equal-weight sector return and a sector index
-- starting at 100 (each day = average return of the sector's stocks, compounded).

with daily as (

    select
        sector,
        trade_date,
        avg(daily_return)       as sector_return,
        count(daily_return)     as stocks_reporting
    from {{ ref('fct_daily_prices') }}
    group by sector, trade_date

)

select
    sector,
    trade_date,
    sector_return,
    stocks_reporting,
    100 * exp(sum(ln(1 + coalesce(sector_return, 0))) over (
        partition by sector
        order by trade_date
        rows between unbounded preceding and current row
    ))                          as sector_index
from daily