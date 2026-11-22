"""
NSE Market Pipeline — Streamlit dashboard.

Reads only the tested dbt marts (plus the raw load log, dbt results and Airflow
history for the Pipeline health tab). Run from the project folder:
    .venv-app/bin/streamlit run dashboard/app.py --server.headless true
For learning and analysis only — not investment advice.
"""
import json
from collections import Counter
from datetime import timedelta
from decimal import Decimal
from pathlib import Path

import pandas as pd
import plotly.express as px
import streamlit as st
from sqlalchemy import create_engine, text

PROJECT = Path(__file__).resolve().parent.parent
RUN_RESULTS = PROJECT / "dbt" / "target" / "run_results.json"
PERIODS = {"1M": 21, "3M": 63, "1Y": 252}           # trading days
TREND_ORDER = ["Strong uptrend", "Uptrend", "Downtrend", "Strong downtrend", "Not enough history"]
TREND_COLORS = {"Strong uptrend": "#1a9850", "Uptrend": "#91cf60", "Downtrend": "#fc8d59",
                "Strong downtrend": "#d73027", "Not enough history": "#bbbbbb"}
# One fixed colour per sector, used in every chart
SECTOR_LIST = ["Automobile", "Banking", "Consumer & Services", "Energy & Power", "FMCG", "Financial Services",
               "Healthcare", "IT", "Infrastructure & Materials", "Metals & Mining", "Telecom"]
SECTOR_COLORS = dict(zip(SECTOR_LIST, px.colors.qualitative.Dark24))
SECTOR_COLORS["Nifty 50 (index)"] = "#000000"
LINE_NAMES = {"price": "Price", "ma_50": "50-day average", "ma_200": "200-day average"}
LINE_COLORS = {"Price": "#1f4e79", "50-day average": "#6baed6", "200-day average": "#d73027"}

st.set_page_config(page_title="NSE Market Pipeline", page_icon="📈", layout="wide")


# ------------------------------------------------------------------ data access
@st.cache_resource
def get_engine(db: str):
    # No password here: PostgreSQL reads it from ~/.pgpass
    return create_engine(f"postgresql+psycopg2://postgres@localhost:5432/{db}")


@st.cache_data(ttl=300)
def q(sql: str, params: dict | None = None, db: str = "nse_market") -> pd.DataFrame:
    with get_engine(db).connect() as conn:
        df = pd.read_sql(text(sql), conn, params=params)
    for col in df.columns:                           # PostgreSQL NUMERIC arrives as Decimal
        values = df[col].dropna()
        if len(values) and isinstance(values.iloc[0], Decimal):
            df[col] = df[col].astype(float)
    return df


def pct(series):
    return (100 * series).round(1)


def price_chart(hist, title, y_label):
    """Price with 50- and 200-day averages, with readable legend names."""
    d = hist.rename(columns=LINE_NAMES)
    return px.line(d, x="trade_date", y=list(LINE_NAMES.values()), title=title,
                   color_discrete_map=LINE_COLORS,
                   labels={"trade_date": "", "value": y_label, "variable": ""})


# ------------------------------------------------------------------ shared data
perf = q("SELECT * FROM analytics.mart_stock_performance")
trends = q("SELECT * FROM analytics.mart_trend_signals")
fresh = q("""
    SELECT MAX(trade_date) AS raw_latest,
           EXTRACT(EPOCH FROM now() - MAX(loaded_at)) / 3600 AS hours_since_load
    FROM raw.daily_prices
""")

nifty = perf[perf["is_index"]].iloc[0]
stocks = perf[~perf["is_index"]].copy()
as_of = perf["latest_date"].max()
raw_latest = fresh["raw_latest"].iloc[0]

sectors = q("SELECT sector, trade_date, sector_return, sector_index FROM analytics.mart_sector_daily "
            "WHERE trade_date <= :d ORDER BY trade_date", {"d": as_of})

# ------------------------------------------------------------------ header
st.title("📈 NSE Market Data Pipeline")
st.caption(f"50 large-cap NSE stocks + Nifty 50 · validated data as of **{as_of}** · "
           "Yahoo Finance → Python loader → PostgreSQL → dbt (23 tests) → Airflow · Not investment advice")
if raw_latest > as_of:
    st.warning(f"Raw data reaches **{raw_latest}**, but that day has not passed every data test yet, "
               f"so the dashboard shows the last validated day (**{as_of}**). See **Pipeline health**.")

with st.sidebar:
    st.header("Controls")
    if st.button("Refresh data"):
        st.cache_data.clear()
        st.rerun()
    st.caption("Data is cached for 5 minutes.")

tabs = st.tabs(["Overview", "Sectors", "Risk & return", "Trends", "Stock explorer", "Pipeline health"])

# ------------------------------------------------------------------ 1. Overview
with tabs[0]:
    in_up = trends[~trends["is_index"] & trends["trend_signal"].isin(["Strong uptrend", "Uptrend"])]
    c = st.columns(5)
    c[0].metric("Nifty 50", f"{nifty['latest_price']:,.0f}", f"{100 * nifty['return_1m']:+.1f}% (1M)")
    c[1].metric("Nifty 50, 1-year return", f"{100 * nifty['return_1y']:+.1f}%")
    c[2].metric("Median stock, 1-year return", f"{100 * stocks['return_1y'].median():+.1f}%")
    c[3].metric("Stocks beating the Nifty (1Y)", f"{(stocks['return_1y'] > nifty['return_1y']).sum()} / {len(stocks)}")
    c[4].metric("Stocks in an uptrend", f"{len(in_up)} / {len(stocks)}")

    period = st.radio("Period", ["6M", "1Y", "3Y", "All"], index=1, horizontal=True, key="nifty_period")
    hist = q("SELECT trade_date, adj_close_price AS price, ma_50, ma_200 FROM analytics.fct_daily_prices "
             "WHERE is_index AND trade_date <= :d ORDER BY trade_date", {"d": as_of})
    hist["trade_date"] = pd.to_datetime(hist["trade_date"])
    days = {"6M": 182, "1Y": 365, "3Y": 1095, "All": None}[period]
    if days:
        hist = hist[hist["trade_date"] >= hist["trade_date"].max() - pd.Timedelta(days=days)]
    st.plotly_chart(price_chart(hist, "Nifty 50 with its 50- and 200-day moving averages", "Nifty 50"))

    def return_table(d):
        return pd.DataFrame({"Stock": d["ticker"], "Company": d["company"], "Sector": d["sector"],
                             "1Y return %": pct(d["return_1y"])})

    left, right = st.columns(2)
    left.subheader("Best 5 stocks, 1 year")
    left.dataframe(return_table(stocks.nlargest(5, "return_1y")), hide_index=True)
    right.subheader("Worst 5 stocks, 1 year")
    right.dataframe(return_table(stocks.nsmallest(5, "return_1y")), hide_index=True)

# ------------------------------------------------------------------ 2. Sectors
with tabs[1]:
    idx = (sectors.pivot(index="trade_date", columns="sector", values="sector_index")
           .sort_index().ffill().rename(columns={"Index": "Nifty 50 (index)"}))
    choice = st.radio("Return over", ["1M", "3M", "1Y", "Since Nov 2021"], index=2,
                      horizontal=True, key="sector_period")
    if choice in PERIODS:
        ret = idx.iloc[-1] / idx.iloc[-1 - PERIODS[choice]] - 1
    else:
        ret = idx.iloc[-1] / 100 - 1
    bars = ret.sort_values().rename("return").reset_index()
    bars["Return %"] = pct(bars["return"])
    fig = px.bar(bars, x="Return %", y="sector", orientation="h", color="Return %",
                 color_continuous_scale="RdYlGn", color_continuous_midpoint=0, text="Return %",
                 title=f"Sector returns, {choice} (equal-weight)", labels={"sector": ""})
    fig.update_traces(textposition="outside", cliponaxis=False)
    st.plotly_chart(fig)

    picked = st.multiselect("Sectors to plot", list(idx.columns), default=list(idx.columns))
    fig = px.line(idx.reset_index(), x="trade_date", y=picked, color_discrete_map=SECTOR_COLORS,
                  title="Sector index (Nov 2021 = 100, equal-weight)",
                  labels={"trade_date": "", "value": "Index", "variable": "Sector"})
    st.plotly_chart(fig)

    last_year = sectors[sectors["trade_date"] > as_of - timedelta(days=365)]
    corr = (last_year.pivot(index="trade_date", columns="sector", values="sector_return")
            .rename(columns={"Index": "Nifty 50"}).corr().round(2))
    fig = px.imshow(corr, text_auto=True, color_continuous_scale="RdBu_r", zmin=-1, zmax=1, aspect="auto",
                    title="Correlation of daily sector returns, last 365 days (low = better diversification)",
                    labels={"x": "", "y": ""})
    fig.update_layout(height=650)
    st.plotly_chart(fig)
    st.caption("Telecom contains one stock (Bharti Airtel). Sectors are equal-weighted; the Nifty is weighted "
               "by company size. Today's large caps only (survivorship bias).")

# ------------------------------------------------------------------ 3. Risk & return
with tabs[2]:
    d = stocks.assign(vol=pct(stocks["volatility_1y"]), ret=pct(stocks["return_1y"]))
    fig = px.scatter(d, x="vol", y="ret", color="sector", hover_name="company", text="ticker",
                     color_discrete_map=SECTOR_COLORS, category_orders={"sector": SECTOR_LIST},
                     title="Risk vs return over the last year (each dot is a stock)",
                     labels={"vol": "Volatility, 1 year (%)", "ret": "Return, 1 year (%)", "sector": "Sector"})
    fig.update_traces(textposition="top center", textfont_size=9)
    fig.add_scatter(x=[100 * nifty["volatility_1y"]], y=[100 * nifty["return_1y"]], mode="markers+text",
                    text=["NIFTY 50"], textposition="bottom center", name="Nifty 50",
                    marker=dict(size=18, symbol="star", color="black"))
    fig.add_hline(y=0, line_dash="dot")
    fig.update_layout(height=620)
    st.plotly_chart(fig)
    st.caption("Up-left is best: more return for less risk. The Nifty has lower volatility than every "
               "single stock — diversification.")

    table = pd.DataFrame({
        "Stock": stocks["ticker"], "Sector": stocks["sector"],
        "1Y return %": pct(stocks["return_1y"]), "Volatility %": pct(stocks["volatility_1y"]),
        "Return / risk": stocks["return_to_risk_1y"].round(2), "Beta": stocks["beta_1y"].round(2),
        "CAGR %": pct(stocks["cagr"]), "Max drawdown %": pct(stocks["max_drawdown"]),
        "Below peak now %": pct(stocks["current_drawdown"]),
    }).sort_values("Return / risk", ascending=False)
    st.dataframe(table, hide_index=True, height=420)

# ------------------------------------------------------------------ 4. Trends
with tabs[3]:
    t = trends[~trends["is_index"]]
    c = st.columns(3)
    c[0].metric("Stocks in an uptrend", f"{t['trend_signal'].isin(['Strong uptrend', 'Uptrend']).sum()} / {len(t)}")
    c[1].metric("Golden crosses (50-day above 200-day)", f"{int(t['golden_cross'].sum())} / {len(t)}")
    c[2].metric("Within 1% of 52-week high", f"{(t['pct_from_52w_high'] >= -0.01).sum()} / {len(t)}")

    counts = t.groupby(["sector", "trend_signal"]).size().reset_index(name="stocks")
    breadth = (t.assign(up=t["trend_signal"].isin(["Strong uptrend", "Uptrend"]))
               .groupby("sector")["up"].mean().sort_values(ascending=False))
    fig = px.bar(counts, x="sector", y="stocks", color="trend_signal",
                 title="Market breadth: trend by sector (sorted by share in an uptrend)",
                 category_orders={"trend_signal": TREND_ORDER, "sector": list(breadth.index)},
                 color_discrete_map=TREND_COLORS, labels={"sector": "", "trend_signal": "Trend"})
    st.plotly_chart(fig)

    tt = pd.DataFrame({
        "Stock": t["ticker"], "Sector": t["sector"], "Trend": t["trend_signal"],
        "vs 50-day %": pct(t["pct_vs_ma_50"]), "vs 200-day %": pct(t["pct_vs_ma_200"]),
        "Golden cross": t["golden_cross"], "From 52-week high %": pct(t["pct_from_52w_high"]),
    })
    tt["_order"] = tt["Trend"].map({s: i for i, s in enumerate(TREND_ORDER)})
    st.dataframe(tt.sort_values(["_order", "From 52-week high %"], ascending=[True, False]).drop(columns="_order"),
                 hide_index=True, height=420)

# ------------------------------------------------------------------ 5. Stock explorer
with tabs[4]:
    options = perf.sort_values(["is_index", "ticker"], ascending=[False, True])
    labels = {f"{r.ticker} — {r.company}": r.symbol for r in options.itertuples()}
    symbol = labels[st.selectbox("Choose a stock", list(labels))]
    row = perf[perf["symbol"] == symbol].iloc[0]
    trow = trends[trends["symbol"] == symbol].iloc[0]

    c = st.columns(6)
    c[0].metric("Price", f"{row['latest_price']:,.2f}")
    c[1].metric("1-year return", f"{100 * row['return_1y']:+.1f}%")
    c[2].metric("CAGR since start", f"{100 * row['cagr']:+.1f}%")
    c[3].metric("Volatility (1Y)", f"{100 * row['volatility_1y']:.1f}%")
    c[4].metric("Beta (1Y)", f"{row['beta_1y']:.2f}")
    c[5].metric("Trend", trow["trend_signal"])

    hist = q("SELECT trade_date, adj_close_price AS price, ma_50, ma_200, drawdown "
             "FROM analytics.fct_daily_prices WHERE symbol = :s AND trade_date <= :d ORDER BY trade_date",
             {"s": symbol, "d": as_of})
    st.plotly_chart(price_chart(hist, f"{row['company']} — adjusted price with 50- and 200-day averages",
                                "Price (₹)"))
    hist["Drawdown %"] = pct(hist["drawdown"])
    fig = px.area(hist, x="trade_date", y="Drawdown %",
                  title=f"Drawdown — how far below its previous peak (worst: {100 * row['max_drawdown']:.1f}%)",
                  labels={"trade_date": ""})
    fig.update_traces(line_color="#d73027")
    st.plotly_chart(fig)
    if symbol in ("TRENT.NS", "TMPV.NS"):
        st.info("This stock's history was corrected for a corporate action the source handled wrongly "
                "(see the price_adjustments seed and docs/data_quality.md).")

# ------------------------------------------------------------------ 6. Pipeline health
with tabs[5]:
    behind = q("""
        SELECT symbol, MAX(trade_date) AS last_date
        FROM raw.daily_prices
        GROUP BY symbol
        HAVING MAX(trade_date) < (SELECT MAX(trade_date) FROM raw.daily_prices)
        ORDER BY symbol
    """)
    c = st.columns(4)
    c[0].metric("Latest day in raw data", str(raw_latest))
    c[1].metric("Latest validated day", str(as_of))
    c[2].metric("Hours since last load", f"{fresh['hours_since_load'].iloc[0]:.1f}")
    c[3].metric("Stocks behind the latest day", len(behind))
    if len(behind):
        st.dataframe(behind, hide_index=True)

    st.subheader("Last dbt build")
    if RUN_RESULTS.exists():
        results = json.loads(RUN_RESULTS.read_text())
        status = Counter(r["status"] for r in results["results"])
        c = st.columns(4)
        c[0].metric("Passed", status["pass"] + status["success"])
        c[1].metric("Warnings", status["warn"])
        c[2].metric("Errors", status["fail"] + status["error"])
        c[3].metric("Skipped", status["skipped"])
        generated = pd.Timestamp(results["metadata"]["generated_at"])
        if generated.tzinfo is None:
            generated = generated.tz_localize("UTC")
        st.caption(f"Generated at {generated.tz_convert('Asia/Kolkata'):%Y-%m-%d %H:%M:%S} IST")
        issues = [{"Check": r["unique_id"].split(".")[2], "Status": r["status"],
                   "Rows flagged": r.get("failures"), "Message": r.get("message")}
                  for r in results["results"] if r["status"] not in ("pass", "success")]
        if issues:
            st.dataframe(pd.DataFrame(issues).fillna(""), hide_index=True)
    else:
        st.info("No dbt results found yet — run `dbt build`.")

    st.subheader("Recent loads (IST)")
    st.dataframe(q("""
        SELECT run_id, MIN(load_mode) AS mode,
               MIN(started_at) AT TIME ZONE 'Asia/Kolkata'  AS started_ist,
               MAX(finished_at) AT TIME ZONE 'Asia/Kolkata' AS finished_ist,
               COUNT(*) AS symbols, SUM(rows_upserted) AS rows_upserted,
               COUNT(*) FILTER (WHERE status <> 'success') AS not_success
        FROM raw.load_log
        GROUP BY run_id
        ORDER BY MIN(started_at) DESC
        LIMIT 10
    """), hide_index=True)

    st.subheader("Airflow runs (IST)")
    try:
        st.dataframe(q("""
            SELECT run_id, run_type, state,
                   start_date AT TIME ZONE 'Asia/Kolkata' AS start_ist,
                   end_date   AT TIME ZONE 'Asia/Kolkata' AS end_ist
            FROM dag_run
            WHERE dag_id = 'nse_market_pipeline'
            ORDER BY start_date DESC NULLS LAST
            LIMIT 10
        """, db="airflow_meta"), hide_index=True)
    except Exception as exc:
        st.info(f"Airflow history not available: {exc}")