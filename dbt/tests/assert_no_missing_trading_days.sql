-- Fails when a stock has NO row at all (not even a source placeholder) on a day the
-- Nifty 50 index traded. The index is the trading calendar: it has a row on every NSE
-- trading day and none on holidays. A gap here means our pipeline failed to load data.
with market_days as (
    select trade_date
    from {{ ref('fct_daily_prices') }}
    where is_index
),
stock_range as (
    select symbol, min(trade_date) as first_date, max(trade_date) as last_date
    from {{ ref('fct_daily_prices') }}
    where not is_index
    group by symbol
)
select r.symbol, d.trade_date as missing_date
from stock_range r
join market_days d
    on d.trade_date between r.first_date and r.last_date
left join {{ source('raw', 'daily_prices') }} raw
    on raw.symbol = r.symbol and raw.trade_date = d.trade_date
where raw.symbol is null