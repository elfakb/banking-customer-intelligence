-- 02_customer_analytics.sql
-- Customer base, customer-level aggregation, activity status, behavior.

-- 1. Customers by city
SELECT city,
       COUNT(*)            AS customers,
       ROUND(AVG(age), 1)  AS avg_age
FROM customers
GROUP BY city
ORDER BY customers DESC;

-- 2. Customers by age band
SELECT CASE
           WHEN age < 25 THEN '18-24'
           WHEN age < 35 THEN '25-34'
           WHEN age < 45 THEN '35-44'
           WHEN age < 55 THEN '45-54'
           ELSE '55+'
       END AS age_band,
       COUNT(*) AS customers
FROM customers
GROUP BY 1
ORDER BY 1;

-- 3. Product ownership
SELECT p.product_name,
       COUNT(DISTINCT a.customer_id) AS customers,
       COUNT(*)                      AS accounts
FROM accounts a
JOIN products p ON p.product_id = a.product_id
GROUP BY p.product_name
ORDER BY customers DESC;

-- 4. Customer-level aggregation (CTE): top 20 customers by fee revenue
WITH customer_summary AS (
    SELECT c.customer_id,
           c.customer_name,
           c.city,
           COUNT(DISTINCT a.account_id)         AS accounts,
           COUNT(t.transaction_id)              AS txn_count,
           COALESCE(SUM(t.amount), 0)           AS total_amount,
           COALESCE(SUM(t.fee_amount), 0)       AS total_fee,
           MIN(t.transaction_date)              AS first_txn_date,
           MAX(t.transaction_date)              AS last_txn_date
    FROM customers c
    LEFT JOIN accounts a     ON a.customer_id = c.customer_id
    LEFT JOIN transactions t ON t.account_id  = a.account_id
    GROUP BY c.customer_id, c.customer_name, c.city
)
SELECT *,
       ROUND(total_amount / NULLIF(txn_count, 0), 2) AS avg_txn_amount
FROM customer_summary
ORDER BY total_fee DESC
LIMIT 20;

-- 5. Active / inactive customers (reference date = last date in the data)
WITH ref AS (
    SELECT MAX(transaction_date) AS ref_date FROM transactions
),
last_txn AS (
    SELECT a.customer_id, MAX(t.transaction_date) AS last_txn_date
    FROM accounts a
    JOIN transactions t ON t.account_id = a.account_id
    GROUP BY a.customer_id
)
SELECT CASE
           WHEN l.last_txn_date IS NULL                THEN 'No transactions'
           WHEN r.ref_date - l.last_txn_date <= 90     THEN 'Active (last 90 days)'
           WHEN r.ref_date - l.last_txn_date <= 180    THEN 'Lapsed (91-180 days)'
           ELSE 'Inactive (180+ days)'
       END AS activity_status,
       COUNT(*) AS customers,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct_of_customers
FROM customers c
LEFT JOIN last_txn l ON l.customer_id = c.customer_id
CROSS JOIN ref r
GROUP BY 1
ORDER BY customers DESC;

-- 6. Transaction frequency distribution per customer
WITH txn_per_customer AS (
    SELECT c.customer_id, COUNT(t.transaction_id) AS txn_count
    FROM customers c
    LEFT JOIN accounts a     ON a.customer_id = c.customer_id
    LEFT JOIN transactions t ON t.account_id  = a.account_id
    GROUP BY c.customer_id
)
SELECT CASE
           WHEN txn_count = 0   THEN '0'
           WHEN txn_count < 20  THEN '1-19'
           WHEN txn_count < 50  THEN '20-49'
           WHEN txn_count < 100 THEN '50-99'
           WHEN txn_count < 200 THEN '100-199'
           ELSE '200+'
       END AS txn_count_bucket,
       COUNT(*) AS customers
FROM txn_per_customer
GROUP BY 1
ORDER BY MIN(txn_count);

-- 7. Preferred channel per customer (most used channel)
WITH customer_channel AS (
    SELECT a.customer_id,
           t.channel,
           COUNT(*) AS txn_count,
           ROW_NUMBER() OVER (
               PARTITION BY a.customer_id
               ORDER BY COUNT(*) DESC, t.channel
           ) AS rn
    FROM transactions t
    JOIN accounts a ON a.account_id = t.account_id
    GROUP BY a.customer_id, t.channel
)
SELECT channel AS preferred_channel,
       COUNT(*) AS customers,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct_of_customers
FROM customer_channel
WHERE rn = 1
GROUP BY channel
ORDER BY customers DESC;