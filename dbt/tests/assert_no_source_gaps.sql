{{ config(severity='warn') }}
-- Warns about trading days (the Nifty 50 traded) where the source sent only a no-trade
-- placeholder for a stock: zero volume and flat prices. Staging drops these rows, so the
-- stock has no price that day and its next daily return covers two days.
select raw.symbol, raw.trade_date
from {{ source('raw', 'daily_prices') }} raw
join {{ ref('fct_daily_prices') }} idx
    on idx.trade_date = raw.trade_date
   and idx.is_index
where coalesce(raw.volume, 0) = 0
  and raw.open = raw.high
  and raw.high = raw.low
  and raw.low = raw.close