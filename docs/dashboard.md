# Dashboard — Streamlit

`dashboard/app.py` · Streamlit 1.67 + Plotly · own virtual environment (`.venv-app`)

## Run
```
.venv-app/bin/streamlit run dashboard/app.py --server.headless true
```
Open http://localhost:8501 (reachable from Windows through WSL mirrored networking). Stop with Ctrl + C.

## Design
| Decision | Why |
|---|---|
| Reads only the tested dbt marts (+ load log, dbt results, Airflow history) | The dashboard can never show data that failed a test |
| Banner when raw data is ahead of the validated marts | Viewers always know which day they are looking at, and why |
| Separate environment `.venv-app` | Installing Streamlit into Airflow's pinned environment could upgrade shared libraries and break Airflow |
| Connection via `~/.pgpass` | No password in code |
| `st.cache_data` (5 min) + Refresh button | Fast clicks, no repeated queries |
| One fixed colour per sector across all charts | Consistent reading between charts |
| Times shown in IST | Match the user's clock |

## Tabs
| Tab | Content | Business question |
|---|---|---|
| Overview | Nifty level and 1M change, Nifty vs median-stock 1Y return, stocks beating the Nifty, breadth; Nifty with 50/200-day averages (6M/1Y/3Y/All); best and worst 5 stocks | Big picture |
| Sectors | Sector returns (1M/3M/1Y/since Nov 2021); sector index lines; correlation heatmap | Q5, Q9 |
| Risk & return | Volatility vs return scatter (Nifty as a star); risk table with return/risk, beta, CAGR, drawdowns | Q6, Q7 |
| Trends | Uptrend / golden-cross / 52-week-high counts; breadth by sector; trend table | Q8 |
| Stock explorer | Any stock: key metrics, adjusted price with averages, drawdown chart; note on corrected stocks | Drill-down, Q10 |
| Pipeline health | Raw vs validated day, hours since last load, stocks behind; last dbt build (passed / warnings / errors / skipped and the failing checks); recent loads; Airflow runs | Is the data trustworthy and fresh? |

## Validation
All dashboard figures were checked against the SQL analysis (`docs/market_insights.md`), e.g. Nifty 25,291, 1Y −0.9% vs median stock +3.2%, 29/50 beating the Nifty, 35/50 in an uptrend, 19 golden crosses, sector returns and correlations, Adani Enterprises max drawdown −71.3%.

## Live example (18 Nov 2026)
Yahoo had not published 17 Nov for Apollo Hospitals and Dr. Reddy's. The up-to-date test failed, the marts stayed at 16 Nov, and the dashboard showed the banner and, in Pipeline health, the 2 stocks behind, the failing check and the load history (morning load 304 rows = 49 × 6 + 2 × 5).

## Limitations
- Runs locally only (not deployed); Streamlit Community Cloud could host it, but it would need a cloud database
- Pipeline health reads the most recent dbt command's results file