-- 1. Fee revenue and take rate by channel
SELECT channel,
       ROUND(SUM(fee_amount), 2) AS total_fee,
       ROUND(100.0 * SUM(fee_amount) / SUM(SUM(fee_amount)) OVER (), 2) AS fee_share_pct,
       ROUND(100.0 * SUM(fee_amount) / NULLIF(SUM(amount), 0), 3)       AS take_rate_pct
FROM transactions
GROUP BY channel
ORDER BY total_fee DESC;

-- 2. Fee revenue by transaction type
SELECT transaction_type,
       ROUND(SUM(fee_amount), 2) AS total_fee,
       ROUND(100.0 * SUM(fee_amount) / SUM(SUM(fee_amount)) OVER (), 2) AS fee_share_pct,
       ROUND(AVG(fee_amount), 2) AS avg_fee_per_txn
FROM transactions
GROUP BY transaction_type
ORDER BY total_fee DESC;

-- 3. Fee revenue by product
SELECT p.product_name,
       ROUND(SUM(t.fee_amount), 2) AS total_fee,
       ROUND(100.0 * SUM(t.fee_amount) / SUM(SUM(t.fee_amount)) OVER (), 2) AS fee_share_pct
FROM transactions t
JOIN accounts a ON a.account_id = t.account_id
JOIN products p ON p.product_id = a.product_id
GROUP BY p.product_name
ORDER BY total_fee DESC;

-- 4. Monthly fee revenue and take rate
SELECT DATE_TRUNC('month', transaction_date)::date AS month,
       ROUND(SUM(fee_amount), 2) AS total_fee,
       ROUND(100.0 * SUM(fee_amount) / NULLIF(SUM(amount), 0), 3) AS take_rate_pct
FROM transactions
GROUP BY 1
ORDER BY 1;

-- 5. Fee revenue by customer segment (last 12 months)
SELECT s.segment,
       COUNT(DISTINCT s.customer_id)  AS customers,
       ROUND(SUM(t.fee_amount), 2)    AS total_fee,
       ROUND(100.0 * SUM(t.fee_amount) / SUM(SUM(t.fee_amount)) OVER (), 2) AS fee_share_pct
FROM transactions t
JOIN accounts a              ON a.account_id  = t.account_id
JOIN vw_customer_segments s  ON s.customer_id = a.customer_id
WHERE t.transaction_date > (SELECT MAX(transaction_date) FROM transactions) - 365
GROUP BY s.segment
ORDER BY total_fee DESC;

-- 6. Segment x channel fee matrix (last 12 months)
SELECT s.segment,
       ROUND(SUM(t.fee_amount) FILTER (WHERE t.channel = 'Mobile'), 2) AS mobile,
       ROUND(SUM(t.fee_amount) FILTER (WHERE t.channel = 'Web'), 2)    AS web,
       ROUND(SUM(t.fee_amount) FILTER (WHERE t.channel = 'ATM'), 2)    AS atm,
       ROUND(SUM(t.fee_amount) FILTER (WHERE t.channel = 'Branch'), 2) AS branch,
       ROUND(SUM(t.fee_amount) FILTER (WHERE t.channel = 'POS'), 2)    AS pos
FROM transactions t
JOIN accounts a              ON a.account_id  = t.account_id
JOIN vw_customer_segments s  ON s.customer_id = a.customer_id
WHERE t.transaction_date > (SELECT MAX(transaction_date) FROM transactions) - 365
GROUP BY s.segment
ORDER BY s.segment;

-- 7. Top 10 branches by fee revenue
SELECT b.branch_name,
       b.city,
       ROUND(SUM(t.fee_amount), 2) AS total_fee,
       ROUND(100.0 * SUM(t.fee_amount) / SUM(SUM(t.fee_amount)) OVER (), 2) AS fee_share_pct
FROM transactions t
JOIN branches b ON b.branch_id = t.branch_id
GROUP BY b.branch_name, b.city
ORDER BY total_fee DESC
LIMIT 10;