-- Staging: clean names and types for raw prices (one row per stock per trading day).
-- Also applies confirmed corrections from the price_adjustments seed to the
-- adjusted close, so returns are not distorted by corporate actions the source
-- handled wrongly. The raw table itself is never changed.

with source as (

    select * from {{ source('raw', 'daily_prices') }}

),

adjustments as (

    select * from {{ ref('price_adjustments') }}

),

-- combined correction factor for each price row (product of all factors that apply)
factors as (

    select
        s.symbol,
        s.trade_date,
        exp(sum(ln(a.factor)))   as correction_factor
    from source s
    join adjustments a
        on a.symbol = s.symbol
       and s.trade_date < a.adjust_before_date
    group by s.symbol, s.trade_date

)

select
    s.symbol,                                                    -- e.g. RELIANCE.NS, ^NSEI
    replace(s.symbol, '.NS', '')                as ticker,       -- e.g. RELIANCE
    s.trade_date,
    s.open                                      as open_price,
    s.high                                      as high_price,
    s.low                                       as low_price,
    s.close                                     as close_price,
    coalesce(s.adj_close, s.close)              as source_adj_close_price,   -- as received
    coalesce(s.adj_close, s.close)
        * coalesce(f.correction_factor, 1)      as adj_close_price,          -- corrected, used for returns
    (f.correction_factor is not null)           as is_price_corrected,
    s.volume,
    s.loaded_at
from source s
left join factors f
    on f.symbol = s.symbol
   and f.trade_date = s.trade_date
-- drop "no-trade" placeholder rows (zero volume, flat OHLC copied from the previous close),
-- e.g. the 15-Jan-2026 NSE holiday (Maharashtra civic elections) that the source filled in
where not (
    coalesce(s.volume, 0) = 0
    and s.open = s.high
    and s.high = s.low
    and s.low = s.close
)