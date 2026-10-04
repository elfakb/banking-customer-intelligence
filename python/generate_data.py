"""Generate a synthetic banking dataset (customers, accounts, products, branches, transactions).

All data is fake. Run: python python/generate_data.py
"""
from pathlib import Path

import numpy as np
import pandas as pd
from faker import Faker

SEED = 42
N_CUSTOMERS = 1500
DATA_START = pd.Timestamp("2024-01-01")
DATA_END = pd.Timestamp("2025-12-31")
OUT_DIR = Path(__file__).resolve().parents[1] / "data" / "raw"

rng = np.random.default_rng(SEED)
fake = Faker()
Faker.seed(SEED)

CITIES = ["Istanbul", "Ankara", "Izmir", "Bursa", "Antalya", "Adana", "Konya", "Gaziantep"]
CITY_WEIGHTS = [0.30, 0.15, 0.12, 0.08, 0.08, 0.08, 0.07, 0.12]

PRODUCTS = [
    (1, "Checking Account", "Deposit"),
    (2, "Savings Account", "Deposit"),
    (3, "Credit Card", "Credit"),
    (4, "Personal Loan", "Loan"),
    (5, "Mortgage", "Loan"),
]
# Every customer has a checking account; other products are optional
PRODUCT_OWNERSHIP_PROB = {2: 0.55, 3: 0.40, 4: 0.15, 5: 0.05}
# Average transactions per month for each product (before the customer activity multiplier)
MONTHLY_TXN_RATE = {1: 3.0, 2: 0.6, 3: 2.5, 4: 1.0, 5: 1.0}

PRODUCT_TXN_TYPES = {
    1: (["Deposit", "Withdrawal", "Transfer", "Payment"], [0.25, 0.25, 0.25, 0.25]),
    2: (["Deposit", "Withdrawal", "Transfer"], [0.60, 0.15, 0.25]),
    3: (["Payment"], [1.0]),
    4: (["Loan Payment"], [1.0]),
    5: (["Loan Payment"], [1.0]),
}

BASE_AMOUNT = {"Deposit": 1500, "Withdrawal": 400, "Transfer": 700, "Payment": 250, "Loan Payment": 900}

CHANNELS = ["Mobile", "Web", "ATM", "Branch", "POS"]
CHANNEL_PROBS = {
    "Deposit":      [0.25, 0.15, 0.30, 0.30, 0.00],
    "Withdrawal":   [0.05, 0.00, 0.60, 0.30, 0.05],
    "Transfer":     [0.50, 0.35, 0.00, 0.15, 0.00],
    "Payment":      [0.30, 0.20, 0.00, 0.05, 0.45],
    "Loan Payment": [0.40, 0.30, 0.00, 0.30, 0.00],
}

# Fee = amount * type rate * channel multiplier (capped at 50)
FEE_RATE = {"Deposit": 0.0, "Withdrawal": 0.002, "Transfer": 0.003, "Payment": 0.009, "Loan Payment": 0.004}
CHANNEL_FEE_MULT = {"Mobile": 0.6, "Web": 0.7, "ATM": 1.2, "Branch": 1.5, "POS": 1.0}


def build_products():
    return pd.DataFrame(PRODUCTS, columns=["product_id", "product_name", "product_category"])


def build_branches():
    rows, branch_id = [], 1
    for city in CITIES:
        n_branches = 4 if city == "Istanbul" else 2
        for i in range(1, n_branches + 1):
            rows.append((branch_id, f"{city} Branch {i}", city))
            branch_id += 1
    return pd.DataFrame(rows, columns=["branch_id", "branch_name", "city"])


def build_customers(branches):
    start = pd.Timestamp("2015-01-01")
    end = pd.Timestamp("2025-06-30")
    join_days = rng.integers(0, (end - start).days + 1, N_CUSTOMERS)
    join_dates = start + pd.to_timedelta(join_days, unit="D")

    cities = rng.choice(CITIES, size=N_CUSTOMERS, p=CITY_WEIGHTS)
    ages = np.clip(rng.normal(40, 12, N_CUSTOMERS).round(), 18, 80).astype(int)

    customers = pd.DataFrame({
        "customer_id": np.arange(1, N_CUSTOMERS + 1),
        "customer_name": [fake.name() for _ in range(N_CUSTOMERS)],
        "age": ages,
        "city": cities,
        "join_date": join_dates,
    })

    # Hidden attributes that drive behaviour (not saved to CSV)
    branch_by_city = branches.groupby("city")["branch_id"].apply(list).to_dict()
    churned = (rng.random(N_CUSTOMERS) < 0.15) & (join_dates <= pd.Timestamp("2025-01-01"))
    churn_start = pd.Timestamp("2024-06-01")
    churn_end = pd.Timestamp("2025-09-30")
    churn_days = rng.integers(0, (churn_end - churn_start).days + 1, N_CUSTOMERS)
    churn_dates = churn_start + pd.to_timedelta(churn_days, unit="D")

    meta = pd.DataFrame({
        "income": rng.lognormal(0, 0.8, N_CUSTOMERS),     # drives transaction size
        "activity": rng.lognormal(0, 0.6, N_CUSTOMERS),   # drives transaction frequency
        "home_branch": [int(rng.choice(branch_by_city[c])) for c in cities],
        "end_date": [churn_dates[i] if churned[i] else DATA_END for i in range(N_CUSTOMERS)],
    }, index=customers["customer_id"])
    return customers, meta


def build_accounts(customers):
    rows, account_id = [], 1
    for cust in customers.itertuples():
        owned = [1] + [p for p, prob in PRODUCT_OWNERSHIP_PROB.items() if rng.random() < prob]
        for product_id in owned:
            open_date = cust.join_date + pd.Timedelta(days=int(rng.integers(0, 181)))
            open_date = min(open_date, DATA_END)
            rows.append((account_id, cust.customer_id, product_id, open_date))
            account_id += 1
    return pd.DataFrame(rows, columns=["account_id", "customer_id", "product_id", "open_date"])


def build_transactions(accounts, meta):
    frames = []
    for acc in accounts.itertuples():
        m = meta.loc[acc.customer_id]
        start = max(acc.open_date, DATA_START)
        end = m["end_date"]
        n_days = (end - start).days
        if n_days <= 0:
            continue

        lam = MONTHLY_TXN_RATE[acc.product_id] * m["activity"] * n_days / 30.4
        n = rng.poisson(lam)
        if n == 0:
            continue

        # Exponent < 1 pushes dates toward the end of the period (business growth)
        offsets = (n_days * (rng.random(n) ** 0.75)).astype(int)
        dates = start + pd.to_timedelta(offsets, unit="D")

        types, probs = PRODUCT_TXN_TYPES[acc.product_id]
        tx_types = rng.choice(types, size=n, p=probs)
        base = np.array([BASE_AMOUNT[t] for t in tx_types])
        product_mult = 2.5 if acc.product_id == 5 else 1.0
        amounts = base * m["income"] * product_mult * rng.lognormal(0, 0.7, n)

        frames.append(pd.DataFrame({
            "account_id": acc.account_id,
            "branch_id": int(m["home_branch"]),
            "transaction_date": dates,
            "transaction_type": tx_types,
            "amount": np.clip(amounts.round(2), 5, None),
        }))

    tx = pd.concat(frames, ignore_index=True)

    tx["channel"] = ""
    for tx_type, probs in CHANNEL_PROBS.items():
        mask = tx["transaction_type"] == tx_type
        tx.loc[mask, "channel"] = rng.choice(CHANNELS, size=int(mask.sum()), p=probs)

    rate = tx["transaction_type"].map(FEE_RATE)
    mult = tx["channel"].map(CHANNEL_FEE_MULT)
    tx["fee_amount"] = (tx["amount"] * rate * mult).clip(upper=50).round(2)

    tx = tx.sort_values(["transaction_date", "account_id"]).reset_index(drop=True)
    tx.insert(0, "transaction_id", tx.index + 1)
    return tx[["transaction_id", "account_id", "branch_id", "transaction_date",
               "transaction_type", "amount", "channel", "fee_amount"]]


def main():
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    products = build_products()
    branches = build_branches()
    customers, meta = build_customers(branches)
    accounts = build_accounts(customers)
    transactions = build_transactions(accounts, meta)

    for df, col in [(customers, "join_date"), (accounts, "open_date"), (transactions, "transaction_date")]:
        df[col] = df[col].dt.strftime("%Y-%m-%d")

    products.to_csv(OUT_DIR / "products.csv", index=False)
    branches.to_csv(OUT_DIR / "branches.csv", index=False)
    customers.to_csv(OUT_DIR / "customers.csv", index=False)
    accounts.to_csv(OUT_DIR / "accounts.csv", index=False)
    transactions.to_csv(OUT_DIR / "transactions.csv", index=False)

    print(f"customers:    {len(customers):>8,}")
    print(f"accounts:     {len(accounts):>8,}")
    print(f"branches:     {len(branches):>8,}")
    print(f"products:     {len(products):>8,}")
    print(f"transactions: {len(transactions):>8,}")
    print(f"Files saved to {OUT_DIR}")


if __name__ == "__main__":
    main()