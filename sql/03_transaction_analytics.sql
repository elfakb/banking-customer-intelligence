-- 03_transaction_analytics.sql
-- Volume, value, average transaction, channel performance, monthly trends.

-- 1. Overall KPIs
SELECT COUNT(*)                   AS total_transactions,
       ROUND(SUM(amount), 2)      AS total_value,
       ROUND(AVG(amount), 2)      AS avg_transaction,
       ROUND(SUM(fee_amount), 2)  AS total_fee_revenue
FROM transactions;

-- 2. By transaction type
SELECT transaction_type,
       COUNT(*)                  AS txn_count,
       ROUND(SUM(amount), 2)     AS total_value,
       ROUND(AVG(amount), 2)     AS avg_transaction,
       ROUND(SUM(fee_amount), 2) AS total_fee,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS share_of_txn_pct
FROM transactions
GROUP BY transaction_type
ORDER BY total_value DESC;

-- 3. Channel performance
SELECT channel,
       COUNT(*)                  AS txn_count,
       ROUND(SUM(amount), 2)     AS total_value,
       ROUND(AVG(amount), 2)     AS avg_transaction,
       ROUND(SUM(fee_amount), 2) AS total_fee,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)        AS share_of_txn_pct,
       ROUND(100.0 * SUM(amount) / SUM(SUM(amount)) OVER (), 1)  AS share_of_value_pct
FROM transactions
GROUP BY channel
ORDER BY txn_count DESC;

-- 4. Product performance
SELECT p.product_name,
       COUNT(*)                    AS txn_count,
       ROUND(SUM(t.amount), 2)     AS total_value,
       ROUND(AVG(t.amount), 2)     AS avg_transaction,
       ROUND(SUM(t.fee_amount), 2) AS total_fee
FROM transactions t
JOIN accounts a ON a.account_id = t.account_id
JOIN products p ON p.product_id = a.product_id
GROUP BY p.product_name
ORDER BY total_value DESC;

-- 5. Monthly transaction trend
SELECT DATE_TRUNC('month', transaction_date)::date AS month,
       COUNT(*)                  AS txn_count,
       ROUND(SUM(amount), 2)     AS total_value,
       ROUND(AVG(amount), 2)     AS avg_transaction,
       ROUND(SUM(fee_amount), 2) AS total_fee
FROM transactions
GROUP BY 1
ORDER BY 1;

-- 6. Monthly channel mix (share of transactions per channel in each month)
SELECT DATE_TRUNC('month', transaction_date)::date AS month,
       channel,
       COUNT(*) AS txn_count,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (
           PARTITION BY DATE_TRUNC('month', transaction_date)
       ), 1) AS channel_share_pct
FROM transactions
GROUP BY 1, channel
ORDER BY 1, txn_count DESC;

-- 7. Top 10 branches by transaction value
SELECT b.branch_name,
       b.city,
       COUNT(*)                  AS txn_count,
       ROUND(SUM(t.amount), 2)   AS total_value,
       ROUND(SUM(t.fee_amount), 2) AS total_fee
FROM transactions t
JOIN branches b ON b.branch_id = t.branch_id
GROUP BY b.branch_name, b.city
ORDER BY total_value DESC
LIMIT 10;