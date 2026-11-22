# Transformations — dbt Models

dbt project in `dbt/` (dbt Core 1.12.7 + dbt-postgres 1.11.0). All models are built in the `analytics` schema with `dbt seed && dbt run`.

## Lineage
```
raw.daily_prices (source)        seeds: stock_universe, price_adjustments
        │                                   │
        ▼                                   ▼
stg_daily_prices (view) ◄──── price_adjustments      dim_stock (table) ◄── stock_universe
        │                                                  │
        └──────────────────────┬───────────────────────────┘
                               ▼
                     fct_daily_prices (table)
              ┌────────────────┼──────────────────┐
              ▼                ▼                  ▼
 mart_stock_performance  mart_sector_daily  mart_trend_signals
```

## Models
| Model | Type | Grain | Rows | Purpose |
|---|---|---|---|---|
| stg_daily_prices | view | stock × day | 62,449 | Clean names/types; applies confirmed price corrections |
| dim_stock | table | stock | 51 | Ticker, company, sector, index flag |
| fct_daily_prices | table | stock × day | 62,449 | Daily return, MA 20/50/200, 20-day volatility, running peak, drawdown, extreme-move flag |
| mart_stock_performance | table | stock | 51 | 1M/3M/1Y returns, CAGR, 1Y volatility, return-to-risk, max/current drawdown, 1Y beta and correlation vs Nifty 50 |
| mart_sector_daily | table | sector × day | 14,797 | Equal-weight daily sector return and index (base 100) |
| mart_trend_signals | table | stock | 51 | Price vs MA50/MA200, golden cross, 52-week range, trend label |

## Key calculations
| Metric | Definition |
|---|---|
| Daily return | adj_close / previous adj_close − 1 (window LAG per stock) |
| Moving averages | Average of last 20/50/200 trading days; NULL until enough history |
| Volatility | Sample standard deviation of daily returns × √252 |
| Drawdown | adj_close / running maximum − 1 |
| CAGR | (last / first)^(365.25 / days) − 1 |
| Beta (1Y) | covar(stock, Nifty) / var(Nifty) over last 252 trading days |
| Sector index | 100 × cumulative product of (1 + average daily return of the sector's stocks) |

## Data corrections (seed `price_adjustments`)
The fact table flags any one-day move above ±20%. Of 7 flags, 5 were real events (Adani Enterprises Feb 2023 sell-off and rebound, Adani Ports election-day fall Jun 2024, Adani Enterprises Nov 2024) and 2 were source errors:

| Stock | Problem | Evidence | Correction |
|---|---|---|---|
| TRENT.NS | −33% on 2026-01-01 | 1:2 bonus record date was 2026-06-04; 1-Jan price 2864.9333 = 4297.40 / 1.5 (not a valid NSE tick); no drop on 2026-06-04 | Prices before 2026-01-01 × 2/3 |
| TMPV.NS | −40.2% on 2025-10-14 | Demerger record date of the commercial vehicle business | Prices before 2025-10-14 × 0.598487 (assumes no market move that day) |

- Corrections are applied in staging; `raw` is never changed. `source_adj_close_price` keeps the original value and `is_price_corrected` marks changed rows (TRENT 1,019, TMPV 965).
- Reliance's +11.6% on 2026-11-02 was verified as real (Q2 results) and left unchanged.
- The seed's factor column is typed `numeric(14,10)` so prices stay exact decimals.

## Validation
- fct_daily_prices: 62,449 rows (= raw); 52,300 rows with MA200 (= 62,449 − 51 × 199)
- Nifty 50 beta vs itself = 1.00; Nifty sector index 140.5 ≈ (1 + 7.1% CAGR)^5
- Trend signals cover all 51 symbols

## Snapshot (as of 2026-11-13)
- Nifty 50: 1Y −1.8%, CAGR 7.1%, volatility 14.2%, max drawdown −16.5%
- Best 1Y: ADANIPORTS +33.0%, TECHM +29.1%, TITAN +28.8%; worst: TMPV −28.9%, ITC −26.7%, JIOFIN −23.5%
- Sector index (Nov 2021 = 100): Telecom 305.4 (one stock), Infrastructure 279.9 … IT 99.7
- Trend: 16 strong uptrend, 17 uptrend, 15 downtrend, 3 strong downtrend

## Caveats
- Survivorship bias: the universe is today's large caps, so sector indices beat the Nifty 50
- Equal-weight sectors (not market-cap weighted); Telecom has one stock
- Not investment advice