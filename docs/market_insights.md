# Market Insights — NSE Large Caps (Nov 2021 – Nov 2026)

**Data:** 50 large-cap NSE stocks + Nifty 50 index, from the tested dbt marts.
**As of:** 16 Nov 2026 — the last snapshot that passed every data test. (On 18 Nov, Yahoo had not yet published 17 Nov for Apollo Hospitals and Dr. Reddy's, so the up-to-date test blocked the marts from publishing a half-updated day.)
**SQL:** `sql/01_sector_performance.sql` … `sql/06_big_moves_and_recovery.sql`
**For learning and analysis only — not investment advice.**

## Key takeaways
1. **The typical stock beat the index over the last year:** Nifty 50 −0.9%, median stock +3.2%; 29 of 50 stocks beat it. The Nifty is weighted by company size, and its giants (HDFC Bank −15.7%, Reliance −9.7%, Infosys −18.4%) were weak.
2. **Over the last 1–3 months the reverse:** the Nifty rallied on a few heavyweights (+11.8% in 1 month) while only 15 of 50 stocks beat it over 3 months.
3. **Stock choice mattered more than sector:** inside one sector the gap between best and worst stock reached 60 points (Bajaj Auto +24.8% vs Tata Motors PV −35.1%).
4. **Higher volatility did not pay:** low-, medium- and high-volatility groups earned similar 5-year growth (12.5–13.3% a year), but high-volatility stocks suffered falls ~1.6× deeper (−48% vs −29%).
5. **IT is the strongest diversifier:** average correlation with other sectors 0.15 (it follows global tech demand and the rupee); IT is also the only sector flat over 5 years (−0.1%).
6. **The market recovers faster than single stocks:** the Nifty's worst fall (−16.5%) recovered in 147 days; 5 of the 8 deepest stock falls have not recovered.

## Q5. Sector performance (equal-weight sector index)
| Sector | 1M | 3M | 1Y | Since Nov 2021 |
|---|---|---|---|---|
| Metals & Mining | +5.0% | −4.6% | **+15.0%** | +119.2% |
| Infrastructure & Materials | +9.7% | +2.8% | +12.7% | +181.3% |
| Consumer & Services | +12.8% | +3.7% | +12.3% | +147.5% |
| Banking | +13.4% | +12.4% | +10.1% | +77.6% |
| Healthcare | +11.5% | +1.9% | +5.7% | +113.4% |
| Telecom (1 stock) | +20.0% | +11.1% | +4.1% | +212.3% |
| Energy & Power | +5.3% | −0.6% | +2.4% | +150.8% |
| **Nifty 50** | +11.8% | +3.7% | −0.9% | +41.3% |
| Financial Services | +8.8% | −3.0% | −4.1% | +49.1% |
| Automobile | +7.1% | −10.3% | −5.5% | +143.7% |
| IT | +8.9% | +3.9% | −5.8% | **−0.1%** |
| FMCG | +6.4% | −2.1% | **−9.8%** | +36.7% |

Widest gaps inside a sector (1Y): Automobile Bajaj Auto +24.8% vs TMPV −35.1%; IT Tech Mahindra +30.0% vs Infosys −18.4%; Banking ICICI Bank +21.1% vs HDFC Bank −15.7%. Only Metals had every stock positive.

## Q6. Risk vs return
- Nifty 50 volatility 14.2% — lower than every single stock (lowest 19.7%): diversification
- Best return per unit of risk (1Y): Titan 1.27, Adani Ports 1.06, Bajaj Auto 1.01, Tech Mahindra 1.01, ICICI Bank 1.00
- Shriram Finance returned +25.9% but with 37.6% volatility (0.69) — similar return to Titan with far more swinging

| Volatility group | Avg 1Y return | Avg 5Y CAGR | Avg worst fall |
|---|---|---|---|
| Low (19.7–24.1%) | +3.3% | 12.8% | −29.3% |
| Medium (24.2–27.4%) | +1.0% | 12.5% | −34.1% |
| High (27.5–37.6%) | +3.5% | 13.3% | −48.0% |

## Q7. Versus the Nifty 50, and beta
- Stocks beating the Nifty: 21/50 (1M), 15/50 (3M), 29/50 (1Y), 35/50 (since 2021)
- Highest beta: Shriram Finance 1.93, IndiGo 1.75, Bajaj Finance 1.54, Adani Enterprises 1.51, Jio Financial 1.51 — lenders and an airline amplify market moves
- Sector beta: Financial Services 1.34, Consumer 1.28, Auto 1.21 … Healthcare 0.52, Energy 0.44
- **ONGC investigation:** beta 0.02 and correlation 0.01 looked impossible. A one-day date shift was ruled out (lagged correlations vs a Reliance control), and prices were confirmed against news (28 Jan 2026 +8.3% on the Reliance deep-water deal; 2 Nov 2026 +4.19% to ₹234.83). Correlation was 0.57 the year before. Likely cause: ONGC rises with crude oil, which tends to hurt an oil-importing market. **Low beta ≠ low risk** — it means risk unrelated to the market.

## Q8. Trend signals and breadth
- Nifty 50: 25,291; +8.3% vs 50-day average, +5.4% vs 200-day; uptrend but no golden cross yet — a recent recovery
- Breadth: 35 of 50 stocks (70%) in an uptrend, but only 19 with a golden cross — many uptrends are young
- 100% of Banking, Consumer and Healthcare stocks in uptrends; Energy only 1 of 5
- At 52-week highs: Bharti Airtel, Eternal, Kotak Bank; furthest below: TMPV −34%, Infosys −29%, Jio Financial −27%
- Wipro: 26% below its 52-week high yet in an uptrend — it fell, then recovered above its 200-day average

## Q9. Sector correlations
- Most correlated: Financial Services–Infrastructure 0.79, Banking–Financial Services 0.78 — a "domestic economy" cluster with little diversification between them
- Least correlated: Energy–IT 0.04, Healthcare–IT 0.09; IT appears in all five lowest pairs
- Banking has the highest correlation with the Nifty (0.87) — banks and financials are its largest weight
- Correlations rise in crashes, when diversification is needed most

## Q10. Big moves and recovery
| Nifty 50 date | Move | Event |
|---|---|---|
| 4 Jun 2024 | −5.93% | Lok Sabha election results |
| 24 Feb 2022 | −4.78% | Russia invades Ukraine |
| 12 May 2025 | +3.82% | India–Pakistan ceasefire rally |
| 3 & 5 Jun 2024 | +3.25%, +3.36% | Exit polls; post-results rebound |
| 7 Apr 2025 | −3.24% | Global sell-off on US tariffs |

- 6 of the 10 largest single-stock moves were Adani group stocks; election day appears 3 times
| Stock | Fall | Days falling | Recovery |
|---|---|---|---|
| Nifty 50 | −16.5% | 151 | 147 days |
| Eternal | −73.9% | 243 | 574 days |
| Adani Ports | −52.3% | 135 | 306 days |
| Adani Enterprises | −71.3% | 69 | not yet |
| Tata Motors PV | −62.1% | 840 | not yet (new low on 17 Nov 2026) |
| Wipro | −52.4% | 1,729 | not yet |

## Caveats
- **Survivorship bias:** the universe is today's large caps, which flatters long-term returns and makes most sectors beat the Nifty
- **Equal-weight sectors** (the Nifty is weighted by company size); Telecom has one stock
- One 5-year period; small groups (4–6 stocks per sector)
- Where the source lost a day (e.g. 18 Mar 2025), the next day's return covers two days
- Free data source (Yahoo Finance); errors found are documented in `data_quality.md`