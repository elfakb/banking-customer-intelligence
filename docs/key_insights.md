# Key Insights

## Final Question
**Which customer segments generate the highest financial value?**

Source: `sql/04_customer_segmentation.sql` (query 1), `data/processed/segment_summary.csv`

| Segment | Customers | % of Customers | % of Volume | % of Fee Revenue | Avg Fee / Customer |
|---|---|---|---|---|---|
| High Value | 259 | 17.27% | 55.84% | 57.80% | 561.58 |
| Medium Value | 387 | 25.80% | 26.18% | 25.13% | 163.39 |
| Low Value | 647 | 43.13% | 14.07% | 12.79% | 49.75 |
| Inactive | 207 | 13.80% | 3.92% | 4.29% | 52.12 |

**Answer:** The High Value segment generates the highest financial value. It is 17.3% of customers but produces 55.8% of transaction volume and 57.8% of fee revenue. An average High Value customer earns about 3.35x the fee of the average customer (561.58 vs. roughly 167.77). High and Medium Value together are 43.1% of customers and generate 82.9% of fee revenue.

## Supporting Findings
- **Concentration:** Low Value is the largest group (43.1% of customers) but produces only 12.8% of fee revenue, about 0.30x the average customer.
- **Medium Value** earns almost exactly its proportional share (25.1% of revenue from 25.8% of customers).
- **Inactive customers:** 207 customers (13.8%) had no transaction in the last 90 days. They still carry 4.3% of 12-month fee revenue, and their average fee per customer (52.12) is slightly above Low Value (49.75). This is revenue at risk and a win-back opportunity.
- **Channels** (`03`, query 3): [fill in from your query output]
- **Growth** (`05`, query 1): [fill in from your query output]
- **Fees** (`06`, queries 1-3): [fill in from your query output]

## Recommendations
1. **Protect High Value customers.** Losing a few of them costs more fee revenue than losing many Low Value customers.
2. **Upgrade Medium Value customers.** They are the largest pool for moving into High Value through cross-selling (cards, savings, loans).
3. **Run a win-back campaign for Inactive customers**, since they were recently active and still carry measurable revenue.
4. **Keep servicing cost low for Low Value customers** by steering them to digital channels.

## Limitations
- The data is synthetic; patterns reflect the generation rules in `generate_data.py`, not real customer behavior.
- Fees are modelled as a percentage of amount with a cap; real fee structures are more complex.
- Segments use a single 12-month window and a fixed 20/30/50 split.