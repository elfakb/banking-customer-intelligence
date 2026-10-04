# Banking Transaction & Customer Intelligence

An end-to-end analytics project on synthetic banking data: customer segmentation, transaction analytics and fee revenue analysis using PostgreSQL, Python and Tableau.

> **Business question:** Which customer segments generate the highest financial value?

## Answer in One Look

![Share of fee revenue by customer segment](dashboard/screenshots/segment_fee_share.png)

**High Value customers are 17.3% of the customer base but generate 57.8% of fee revenue**, about 3.3x their share of customers. Together, High and Medium Value customers (43.1% of customers) generate 82.9% of fee revenue.

| Segment | Customers | % of Customers | % of Volume | % of Fee Revenue |
|---|---|---|---|---|
| High Value | 259 | 17.27% | 55.84% | 57.80% |
| Medium Value | 387 | 25.80% | 26.18% | 25.13% |
| Low Value | 647 | 43.13% | 14.07% | 12.79% |
| Inactive | 207 | 13.80% | 3.92% | 4.29% |


## Project Overview

The project simulates a bank's customer and transaction data (1,500 customers, 2 years of transactions) and answers business questions about customer value, channel performance and revenue. A SQL-based segmentation model classifies customers into **High Value, Medium Value, Low Value and Inactive** and measures each segment's share of fee revenue.

> All data is **synthetic**, generated with Python (Faker + NumPy). No real customer data is used.

## Tech Stack

- **PostgreSQL:** CTEs, window functions (LAG, RANK, running totals), views
- **Python:** pandas, NumPy, Faker, SQLAlchemy
- **Tableau Public:** dashboard

## Repository Structure

```
├── data/
│   ├── raw/                  # generated CSVs (git-ignored)
│   └── processed/            # query outputs used by the dashboard
├── python/
│   ├── db.py
│   ├── generate_data.py
│   ├── load_to_db.py
│   ├── export_for_tableau.py
│   └── test_connection.py
├── sql/
│   ├── 00_schema.sql
│   ├── 01_data_quality.sql
│   ├── 02_customer_analytics.sql
│   ├── 03_transaction_analytics.sql
│   ├── 04_customer_segmentation.sql
│   ├── 05_window_functions.sql
│   └── 06_revenue_fee_analysis.sql
├── dashboard/screenshots/
├── docs/
│   ├── data_dictionary.md
│   ├── business_questions.md
│   └── key_insights.md
├── README.md
└── README_TR.md
```

## Data Model

Star schema with five tables: `customers`, `accounts`, `products`, `branches` and `transactions` (fact table). See [docs/data_dictionary.md](docs/data_dictionary.md).

## Customer Segmentation

Based on the last 12 months of data:

| Segment | Rule |
|---|---|
| Inactive | No transaction in the last 90 days |
| High Value | Top 20% of active customers by value score |
| Medium Value | Next 30% |
| Low Value | Remaining 50% |

Value score = 50% percentile rank of transaction volume + 50% percentile rank of fee revenue.

## Analyses

- **Customer analytics:** customer base, product ownership, active/inactive status, preferred channel
- **Transaction analytics:** volume, value, average transaction, channel performance, monthly trends
- **Window functions:** month-over-month growth (LAG), rankings within groups (RANK), cumulative revenue (running total)
- **Revenue / fee analysis:** fee by channel, product, transaction type and segment; take rate

## Key Findings

- **Revenue is concentrated.** High Value customers (17.3% of customers) generate 57.8% of fee revenue and 55.8% of transaction volume.
- **An average High Value customer earns about 3.35x the fee of the average customer;** a Low Value customer earns about 0.30x.
- **Low Value is the largest group (43.1% of customers) but produces only 12.8% of fee revenue.**
- **Inactive customers still carry 4.3% of 12-month fee revenue**, which is revenue at risk and a win-back opportunity.

Full analysis and recommendations: [docs/key_insights.md](docs/key_insights.md)


## How to Run

1. Clone the repository and set up the environment:
```bash
   git clone https://github.com/elfakb/banking-customer-intelligence.git
   cd banking-customer-intelligence
   python3 -m venv .venv && source .venv/bin/activate
   pip install -r requirements.txt
```
2. Create a PostgreSQL database named `banking_intelligence`, copy `.env.example` to `.env` and fill in your connection details.
3. Generate and load the data:
```bash
   python python/generate_data.py
   python python/load_to_db.py
```
4. Run the SQL files (`04` creates the view that `05` and `06` need):
```bash
   psql -p <port> -d banking_intelligence -f sql/01_data_quality.sql
   psql -p <port> -d banking_intelligence -f sql/04_customer_segmentation.sql
   psql -p <port> -d banking_intelligence -f sql/02_customer_analytics.sql
   psql -p <port> -d banking_intelligence -f sql/03_transaction_analytics.sql
   psql -p <port> -d banking_intelligence -f sql/05_window_functions.sql
   psql -p <port> -d banking_intelligence -f sql/06_revenue_fee_analysis.sql
```
5. Export dashboard data:
```bash
   python python/export_for_tableau.py
```
