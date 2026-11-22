# Data Quality — Tests, Findings and Fixes

Run everything with `dbt build` (seeds → models → tests, in dependency order). If a test fails, every model that depends on the failing one is **skipped**, so bad data never reaches the marts. Freshness is checked with `dbt source freshness`.

## Checks
| Check | Type | Severity | Fails / warns when |
|---|---|---|---|
| Source freshness (`raw.daily_prices.loaded_at`) | freshness | warn > 30 h, error > 96 h | The loader has not run recently (96 h tolerates a weekend) |
| unique / not_null (16 generic tests) | generic | error | Duplicate stock-days, missing keys or prices, unknown sectors or trend labels, price rows for unknown stocks |
| assert_valid_ohlc | custom | error | Price ≤ 0, high < low, close outside the day's range (0.1% tolerance), negative volume |
| assert_no_missing_trading_days | custom | error | A stock has no raw row at all on a day the Nifty 50 traded (= pipeline failed to load) |
| assert_all_stocks_up_to_date | custom | error | A stock's latest date is behind the others (its load failed) |
| assert_index_beta_is_one | custom | error | Nifty 50 beta against itself ≠ 1 (calculation broke) |
| assert_no_stale_prices | custom | warn | Close and volume both identical to the previous day (copied row) |
| assert_extreme_moves_reviewed | custom | warn | A >20% one-day move not yet in the `reviewed_extreme_moves` seed |
| assert_no_source_gaps | custom | warn | The source sent only a no-trade placeholder on a trading day |

**Error vs warn:** errors mean the data is definitely wrong and block the marts; warnings flag things a person must review (a big move can be real) or cannot fix (data the source never had).

**Trading calendar:** the Nifty 50 index is used as the calendar — it has a row on every NSE trading day and none on holidays — so holidays are never reported as missing data.

## Findings and fixes
| # | Finding | How it was caught | Fix |
|---|---|---|---|
| 1 | TRENT −33% on 2026-01-01: source applied the 1:2 bonus adjustment 5 months early | Extreme-move flag; non-tick price 2864.9333 = 4297.40 / 1.5 | `price_adjustments` seed (× 2/3 before 2026-01-01) |
| 2 | TMPV −40% on 2025-10-14: demerger not adjusted | Extreme-move flag | `price_adjustments` seed (× 0.598487) |
| 3 | 5 Adani moves >20% | Extreme-move flag; verified against news | Recorded as real in `reviewed_extreme_moves` |
| 4 | Reliance +11.6% on 2026-11-02 | High 20-day volatility; verified against news (Q2 results) | None — real |
| 5 | Phantom rows for all 50 stocks on 2026-01-15, an NSE holiday (Maharashtra civic elections; NSE first said it would stay open, then reversed on 12 Jan) | Missing-days test flagged the Nifty as "missing" — the index was right, the stock rows were fake (zero volume, flat prices) | Staging drops no-trade placeholder rows |
| 6 | Source lost real trading data: 49 stocks on 2025-03-18 (Nifty traded normally) + 9 single-stock days | Placeholder rows found while fixing #5 | Dropped in staging; reported by `assert_no_source_gaps` (warn, 58 rows) |
| 7 | Reliance identical close on 12 and 13 Nov 2026 | Manual review | None — volumes differ, so a genuine unchanged close (stale test checks close **and** volume) |
| 8 | Risk of storing an unfinished day | Design review (loader run at 14:26, market open) | Loader skips today's bar before 16:00 IST |
| 9 | Seed factor inferred as float, turning prices into floats | `ROUND(double, int)` error | Explicit seed column types (`numeric(14,10)`) |

## Row counts
| Layer | Rows |
|---|---|
| raw.daily_prices | 62,500 (as received, never modified) |
| Placeholder rows dropped in staging | 108 (50 holiday + 58 source gaps) |
| fct_daily_prices | 62,392 |

## Final result
`dbt build`: **PASS=31, WARN=1 (source gaps), ERROR=0** — 3 seeds, 6 models, 23 tests.