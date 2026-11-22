-- The Nifty 50's beta against itself must be exactly 1; anything else means the calculation broke.
select symbol, beta_1y
from {{ ref('mart_stock_performance') }}
where is_index
  and (beta_1y is null or abs(beta_1y - 1) > 0.000001)