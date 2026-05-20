#!/usr/bin/env python3
"""
yfinance_seed.py - emits CSV rows of CUSIP/symbol/name mappings for the top
~1000 US tickers, scraped from yfinance.

Output: stdout CSV with header: cusip,symbol,name,exchange,cik

Usage:
    python3 bin/yfinance_seed.py > /tmp/seed.csv

Install:
    pip install yfinance
"""
import csv
import sys
import time

try:
    import yfinance as yf
except ImportError:
    print("ERROR: pip install yfinance", file=sys.stderr)
    sys.exit(1)

# Top US tickers by market cap. Replace this list with the source of your choice
# (e.g. fetch from a static S&P 1500 + ETF universe file).
TICKERS = """
AAPL MSFT NVDA GOOGL GOOG AMZN META TSLA BRK-B JPM V XOM JNJ WMT MA UNH PG HD
CVX ABBV LLY KO PEP COST AVGO TMO MRK ADBE NFLX PFE BAC DIS ABT CRM CSCO
ACN DHR WFC NKE LIN VZ CMCSA NEE TXN BMY HON UPS UNP RTX QCOM PM PYPL ORCL
IBM AMD CAT INTC GS DE GE AXP AMGN MS BLK SCHW T C BA SBUX MMM CB MO COP
LOW MDLZ TJX BKNG LMT NOW SO PLD ELV ISRG SYK ZTS GILD ETN ICE DUK SHW APD
""".split()

# Some popular ETFs for additional coverage.
ETFS = "SPY QQQ IWM IVV VOO VTI VTV VUG TLT GLD SLV".split()

writer = csv.writer(sys.stdout)
writer.writerow(["cusip", "symbol", "name", "exchange", "cik"])

for symbol in TICKERS + ETFS:
    try:
        info = yf.Ticker(symbol).info
        cusip = info.get("cusip") or (info.get("isin", "")[2:11] if info.get("isin") else None)
        if not cusip:
            continue
        writer.writerow([
            cusip,
            symbol,
            info.get("longName") or info.get("shortName") or "",
            info.get("exchange") or "",
            "",  # CIK not in yfinance - backfilled by SEC sync later
        ])
        time.sleep(0.05)
    except Exception as e:
        print(f"skip {symbol}: {e}", file=sys.stderr)
