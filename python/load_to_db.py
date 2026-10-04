"""Create the schema and load the CSV files into PostgreSQL.

Run: python python/load_to_db.py
"""
from pathlib import Path

import pandas as pd
from sqlalchemy import text

from db import get_engine

ROOT = Path(__file__).resolve().parents[1]
RAW_DIR = ROOT / "data" / "raw"
SCHEMA_FILE = ROOT / "sql" / "00_schema.sql"

# Load order matters because of foreign keys
TABLES = [
    ("products", []),
    ("branches", []),
    ("customers", ["join_date"]),
    ("accounts", ["open_date"]),
    ("transactions", ["transaction_date"]),
]


def main():
    engine = get_engine()

    with engine.begin() as conn:
        conn.exec_driver_sql(SCHEMA_FILE.read_text())
    print("Schema created.")

    for table, date_cols in TABLES:
        df = pd.read_csv(RAW_DIR / f"{table}.csv", parse_dates=date_cols)
        for col in date_cols:
            df[col] = df[col].dt.date
        df.to_sql(table, engine, if_exists="append", index=False, chunksize=5000, method="multi")
        print(f"Loaded {table}: {len(df):,} rows")

    with engine.connect() as conn:
        print("\nRow counts in database:")
        for table, _ in TABLES:
            n = conn.execute(text(f"SELECT COUNT(*) FROM {table}")).scalar()
            print(f"  {table:<14} {n:>10,}")


if __name__ == "__main__":
    main()