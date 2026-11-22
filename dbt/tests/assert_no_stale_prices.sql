{{ config(severity='warn') }}
-- Warns when a row repeats the previous day's close AND volume exactly,
-- which usually means the source copied the previous day.
with p as (
    select symbol, trade_date, close_price, volume,
           lag(close_price) over (partition by symbol order by trade_date) as prev_close,
           lag(volume)      over (partition by symbol order by trade_date) as prev_volume
    from {{ ref('fct_daily_prices') }}
)
select symbol, trade_date, close_price, volume
from p
where close_price = prev_close
  and volume = prev_volume
  and volume > 0