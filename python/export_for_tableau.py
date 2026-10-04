from pathlib import Path

import pandas as pd
from sqlalchemy import text

from db import get_engine

OUT_DIR = Path(__file__).resolve().parents[1] / "data" / "processed"

QUERIES = {
    "segment_summary": """
        SELECT segment,
               COUNT(*) AS customers,
               ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS customer_share_pct,
               ROUND(SUM(volume_12m), 2) AS total_volume_12m,
               ROUND(SUM(fee_12m), 2) AS total_fee_12m,
               ROUND(100.0 * SUM(fee_12m) / SUM(SUM(fee_12m)) OVER (), 2) AS fee_share_pct,
               ROUND(AVG(fee_12m), 2) AS avg_fee_per_customer
        FROM vw_customer_segments
        GROUP BY segment
        ORDER BY total_fee_12m DESC
    """,
    "customer_segments": "SELECT * FROM vw_customer_segments ORDER BY customer_id",
    "monthly_trends": """
        SELECT DATE_TRUNC('month', transaction_date)::date AS month,
               COUNT(*) AS txn_count,
               ROUND(SUM(amount), 2) AS total_value,
               ROUND(SUM(fee_amount), 2) AS total_fee
        FROM transactions
        GROUP BY 1
        ORDER BY 1
    """,
}


def main():
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    engine = get_engine()
    with engine.connect() as conn:
        for name, sql in QUERIES.items():
            df = pd.read_sql(text(sql), conn)
            path = OUT_DIR / f"{name}.csv"
            df.to_csv(path, index=False)
            print(f"{name}.csv saved ({len(df):,} rows)")


if __name__ == "__main__":
    main()