-- One row per stock: period returns, CAGR, 1-year risk, drawdowns and beta vs the Nifty 50.

with prices as (

    select * from {{ ref('fct_daily_prices') }}

),

latest as (

    select symbol, max(trading_day_number) as last_day_no
    from prices
    group by symbol

),

-- prices at fixed offsets (in trading days) from each stock's latest day
points as (

    select
        p.symbol,
        max(p.trade_date)      filter (where p.trading_day_number = l.last_day_no)       as latest_date,
        max(p.adj_close_price) filter (where p.trading_day_number = l.last_day_no)       as latest_price,
        max(p.adj_close_price) filter (where p.trading_day_number = l.last_day_no - 21)  as price_1m_ago,
        max(p.adj_close_price) filter (where p.trading_day_number = l.last_day_no - 63)  as price_3m_ago,
        max(p.adj_close_price) filter (where p.trading_day_number = l.last_day_no - 252) as price_1y_ago,
        min(p.trade_date)                                                                as first_date,
        max(p.adj_close_price) filter (where p.trading_day_number = 1)                   as first_price,
        min(p.drawdown)                                                                  as max_drawdown,
        max(p.drawdown)        filter (where p.trading_day_number = l.last_day_no)       as current_drawdown
    from prices p
    join latest l using (symbol)
    group by p.symbol

),

-- annualised volatility over the last 252 trading days
risk_1y as (

    select
        p.symbol,
        stddev_samp(p.daily_return) * sqrt(252) as volatility_1y
    from prices p
    join latest l using (symbol)
    where p.trading_day_number > l.last_day_no - 252
    group by p.symbol

),

index_returns as (

    select trade_date, daily_return as index_return
    from prices
    where is_index

),

-- beta and correlation vs the Nifty 50 over the last 252 trading days
beta_1y as (

    select
        p.symbol,
        covar_samp(p.daily_return, i.index_return) / nullif(var_samp(i.index_return), 0) as beta_1y,
        corr(p.daily_return, i.index_return)                                             as correlation_1y
    from prices p
    join latest l using (symbol)
    join index_returns i using (trade_date)
    where p.trading_day_number > l.last_day_no - 252
    group by p.symbol

)

select
    d.symbol,
    d.ticker,
    d.company,
    d.sector,
    d.is_index,
    pt.first_date,
    pt.latest_date,
    pt.latest_price,
    pt.latest_price / pt.price_1m_ago - 1                                   as return_1m,
    pt.latest_price / pt.price_3m_ago - 1                                   as return_3m,
    pt.latest_price / pt.price_1y_ago - 1                                   as return_1y,
    pt.latest_price / pt.first_price - 1                                    as return_since_start,
    power(pt.latest_price / pt.first_price,
          365.25 / (pt.latest_date - pt.first_date)) - 1                    as cagr,
    r.volatility_1y,
    (pt.latest_price / pt.price_1y_ago - 1) / nullif(r.volatility_1y, 0)    as return_to_risk_1y,
    pt.max_drawdown,
    pt.current_drawdown,
    b.beta_1y,
    b.correlation_1y
from {{ ref('dim_stock') }} d
join points pt using (symbol)
left join risk_1y r using (symbol)
left join beta_1y b using (symbol)