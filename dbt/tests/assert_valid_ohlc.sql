-- Fails on impossible prices: non-positive values, high below low,
-- close outside the day's range (0.1% tolerance), or negative volume.
select symbol, trade_date, open_price, high_price, low_price, close_price, volume
from {{ ref('fct_daily_prices') }}
where open_price <= 0 or high_price <= 0 or low_price <= 0 or close_price <= 0
   or high_price < low_price
   or close_price > high_price * 1.001
   or close_price < low_price * 0.999
   or volume < 0