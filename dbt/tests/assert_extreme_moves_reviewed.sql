{{ config(severity='warn') }}
-- Warns about any one-day move above 20% that has not been reviewed yet.
-- Reviewed moves (verified against news) are listed in the reviewed_extreme_moves seed.
select f.symbol, f.trade_date, f.daily_return
from {{ ref('fct_daily_prices') }} f
left join {{ ref('reviewed_extreme_moves') }} r
    on r.symbol = f.symbol and r.trade_date = f.trade_date
where f.is_extreme_move
  and r.symbol is null