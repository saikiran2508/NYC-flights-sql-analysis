"""
Run every analysis query in sql/05_analysis.sql, save each result to
results/<name>.csv, and build the charts in charts/.

Usage:
    python run_analysis.py
Connection settings come from the standard PG* environment variables
(PGHOST, PGPORT, PGUSER, PGPASSWORD, PGDATABASE).
"""
import re
from pathlib import Path

import matplotlib.pyplot as plt
import pandas as pd
import psycopg2

ROOT = Path(__file__).parent
RESULTS = ROOT / "results"
CHARTS = ROOT / "charts"
RESULTS.mkdir(exist_ok=True)
CHARTS.mkdir(exist_ok=True)


def load_queries(path: Path) -> dict[str, str]:
    """Split the SQL file on '-- @query <name>' markers."""
    text = path.read_text()
    parts = re.split(r"^-- @query (\w+)\s*$", text, flags=re.MULTILINE)
    return {name: sql.strip().rstrip(";") for name, sql in zip(parts[1::2], parts[2::2])}


def run_queries() -> dict[str, pd.DataFrame]:
    out = {}
    with psycopg2.connect("") as conn:
        for name, sql in load_queries(ROOT / "sql" / "05_analysis.sql").items():
            df = pd.read_sql_query(sql, conn)
            df.to_csv(RESULTS / f"{name}.csv", index=False)
            out[name] = df
            print(f"{name}: {len(df)} rows")
    return out


def style(ax, title, ylabel):
    ax.set_title(title, loc="left", fontsize=12, fontweight="bold")
    ax.set_ylabel(ylabel)
    ax.spines[["top", "right"]].set_visible(False)
    ax.grid(axis="y", alpha=0.3)


def make_charts(r: dict[str, pd.DataFrame]) -> None:
    color = "#2563eb"

    # Carrier on-time ranking
    df = r["q2_carrier_scorecard"].sort_values("on_time_pct")
    fig, ax = plt.subplots(figsize=(8, 5))
    ax.barh(df["airline"], df["on_time_pct"], color=color)
    ax.set_xlabel("On-time arrivals (%)")
    ax.set_title("On-time rate by carrier, NYC departures 2013", loc="left", fontweight="bold")
    ax.spines[["top", "right"]].set_visible(False)
    fig.tight_layout(); fig.savefig(CHARTS / "carrier_on_time.png", dpi=150); plt.close(fig)

    # Delay by hour of day
    df = r["q4_delay_by_hour"]
    fig, ax = plt.subplots(figsize=(8, 4.5))
    ax.plot(df["sched_dep_hour"], df["avg_dep_delay_min"], marker="o", color=color)
    ax.set_xlabel("Scheduled departure hour")
    style(ax, "Average departure delay builds through the day", "Minutes")
    fig.tight_layout(); fig.savefig(CHARTS / "delay_by_hour.png", dpi=150); plt.close(fig)

    # Monthly trend
    df = r["q3_monthly_trend"]
    fig, ax = plt.subplots(figsize=(8, 4.5))
    ax.plot(pd.to_datetime(df["month"]).dt.strftime("%b"), df["on_time_pct"], marker="o", color=color)
    style(ax, "Monthly on-time rate", "On-time arrivals (%)")
    fig.tight_layout(); fig.savefig(CHARTS / "monthly_on_time.png", dpi=150); plt.close(fig)

    # Delay propagation
    df = r["q5_delay_propagation"]
    fig, ax = plt.subplots(figsize=(8, 4.5))
    labels = df["previous_leg_status"].str.replace(r"^\d\. ", "", regex=True)
    ax.bar(labels, df["pct_departed_late"], color=color)
    style(ax, "Late inbound aircraft cause late departures", "Next flight departing 15+ min late (%)")
    fig.tight_layout(); fig.savefig(CHARTS / "delay_propagation.png", dpi=150); plt.close(fig)


if __name__ == "__main__":
    make_charts(run_queries())
