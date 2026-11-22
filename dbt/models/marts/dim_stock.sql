-- Dimension: one row per stock (plus the Nifty 50 index) with company and sector.

select
    yf_symbol                       as symbol,     -- e.g. RELIANCE.NS
    replace(yf_symbol, '.NS', '')   as ticker,     -- e.g. RELIANCE
    company,
    sector,
    (is_index = 1)                  as is_index    -- true only for ^NSEI
from {{ ref('stock_universe') }}