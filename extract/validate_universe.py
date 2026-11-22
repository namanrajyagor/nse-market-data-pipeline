"""Check that every symbol in the stock universe returns recent prices from Yahoo Finance."""
from pathlib import Path

import pandas as pd
import yfinance as yf

UNIVERSE = Path(__file__).parent / "stock_universe.csv"

universe = pd.read_csv(UNIVERSE)
symbols = universe["yf_symbol"].tolist()
print(f"Checking {len(symbols)} symbols...")

# One batch request for the last 10 days of every symbol
data = yf.download(symbols, period="10d", interval="1d", group_by="ticker",
                   auto_adjust=False, progress=False, threads=True)

rows = []
for sym in symbols:
    try:
        df = data[sym].dropna(subset=["Close"])
        n, last = len(df), (df.index.max().date() if len(df) else None)
    except KeyError:          # symbol not returned at all
        n, last = 0, None
    rows.append({"yf_symbol": sym, "rows_last_10d": n, "last_date": last})

report = universe.merge(pd.DataFrame(rows), on="yf_symbol")
bad = report[report["rows_last_10d"] == 0]

print("\nStocks per sector:")
print(report.groupby("sector").size().rename("count").to_string())
print(f"\nOK symbols: {len(report) - len(bad)} / {len(report)}")
if len(bad):
    print("\nFAILED symbols (no data returned):")
    print(bad[["yf_symbol", "company", "sector"]].to_string(index=False))
else:
    print("All symbols returned data")