-- Fact: one row per stock per trading day, with returns, moving averages,
-- volatility and drawdown. All window functions run per stock in date order.

with prices as (

    select * from {{ ref('stg_daily_prices') }}

),

returns as (

    select
        *,
        row_number() over w                                           as trading_day_number,
        lag(adj_close_price) over w                                   as prev_adj_close_price,
        adj_close_price / nullif(lag(adj_close_price) over w, 0) - 1  as daily_return
    from prices
    window w as (partition by symbol order by trade_date)

),

metrics as (

    select
        *,
        -- moving averages: only once the stock has N days of history
        case when count(*) over (w rows between 19 preceding and current row) = 20
             then avg(adj_close_price) over (w rows between 19 preceding and current row) end   as ma_20,
        case when count(*) over (w rows between 49 preceding and current row) = 50
             then avg(adj_close_price) over (w rows between 49 preceding and current row) end   as ma_50,
        case when count(*) over (w rows between 199 preceding and current row) = 200
             then avg(adj_close_price) over (w rows between 199 preceding and current row) end  as ma_200,
        -- 20-day volatility, annualised (about 252 trading days a year)
        case when count(daily_return) over (w rows between 19 preceding and current row) = 20
             then stddev_samp(daily_return) over (w rows between 19 preceding and current row) * sqrt(252)
        end                                                                                      as volatility_20d,
        -- highest price so far (for drawdown)
        max(adj_close_price) over (w rows between unbounded preceding and current row)          as running_peak
    from returns
    window w as (partition by symbol order by trade_date)

)

select
    m.symbol,
    d.ticker,
    d.company,
    d.sector,
    d.is_index,
    m.trade_date,
    m.trading_day_number,
    m.open_price,
    m.high_price,
    m.low_price,
    m.close_price,
    m.adj_close_price,
    m.volume,
    m.daily_return,
    m.ma_20,
    m.ma_50,
    m.ma_200,
    m.volatility_20d,
    m.running_peak,
    m.adj_close_price / m.running_peak - 1               as drawdown,
    coalesce(abs(m.daily_return) > 0.20, false)          as is_extreme_move
from metrics m
join {{ ref('dim_stock') }} d using (symbol)