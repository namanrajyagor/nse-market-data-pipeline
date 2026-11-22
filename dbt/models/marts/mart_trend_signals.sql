-- One row per stock (latest trading day): position vs 50/200-day averages,
-- 52-week range and a simple trend label.

with prices as (

    select * from {{ ref('fct_daily_prices') }}

),

latest as (

    select distinct on (symbol) *
    from prices
    order by symbol, trade_date desc

),

range_52w as (

    select
        p.symbol,
        max(p.adj_close_price) as high_52w,
        min(p.adj_close_price) as low_52w
    from prices p
    join latest l using (symbol)
    where p.trade_date > l.trade_date - interval '365 days'
    group by p.symbol

)

select
    l.symbol,
    l.ticker,
    l.company,
    l.sector,
    l.is_index,
    l.trade_date                               as as_of_date,
    l.adj_close_price                          as price,
    l.ma_50,
    l.ma_200,
    l.adj_close_price / l.ma_50 - 1            as pct_vs_ma_50,
    l.adj_close_price / l.ma_200 - 1           as pct_vs_ma_200,
    (l.ma_50 > l.ma_200)                       as golden_cross,
    r.high_52w,
    r.low_52w,
    l.adj_close_price / r.high_52w - 1         as pct_from_52w_high,
    case
        when l.ma_200 is null                                             then 'Not enough history'
        when l.adj_close_price > l.ma_50 and l.ma_50 > l.ma_200           then 'Strong uptrend'
        when l.adj_close_price > l.ma_200                                 then 'Uptrend'
        when l.adj_close_price < l.ma_50 and l.ma_50 < l.ma_200           then 'Strong downtrend'
        else 'Downtrend'
    end                                        as trend_signal
from latest l
join range_52w r using (symbol)