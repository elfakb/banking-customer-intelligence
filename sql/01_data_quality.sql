-- 01_data_quality.sql
-- Sanity checks before analysis.

-- 1. Row counts
SELECT 'customers' AS table_name, COUNT(*) AS row_count FROM customers
UNION ALL SELECT 'accounts', COUNT(*) FROM accounts
UNION ALL SELECT 'products', COUNT(*) FROM products
UNION ALL SELECT 'branches', COUNT(*) FROM branches
UNION ALL SELECT 'transactions', COUNT(*) FROM transactions;

-- 2. Date range of the transaction data
SELECT MIN(transaction_date) AS first_txn_date,
       MAX(transaction_date) AS last_txn_date
FROM transactions;

-- 3. NULL checks on key columns
SELECT
    COUNT(*) FILTER (WHERE account_id IS NULL)       AS null_account,
    COUNT(*) FILTER (WHERE transaction_date IS NULL) AS null_date,
    COUNT(*) FILTER (WHERE amount IS NULL)           AS null_amount,
    COUNT(*) FILTER (WHERE channel IS NULL)          AS null_channel
FROM transactions;

-- 4. Duplicate transaction IDs (expected: 0 rows)
SELECT transaction_id, COUNT(*) AS duplicates
FROM transactions
GROUP BY transaction_id
HAVING COUNT(*) > 1;

-- 5. Invalid amounts or fees (expected: 0)
SELECT
    COUNT(*) FILTER (WHERE amount <= 0)     AS non_positive_amount,
    COUNT(*) FILTER (WHERE fee_amount < 0)  AS negative_fee,
    COUNT(*) FILTER (WHERE fee_amount > amount) AS fee_above_amount
FROM transactions;

-- 6. Orphan records (expected: 0)
SELECT COUNT(*) AS orphan_transactions
FROM transactions t
LEFT JOIN accounts a ON a.account_id = t.account_id
WHERE a.account_id IS NULL;

-- 7. Transactions dated before the account was opened (expected: 0)
SELECT COUNT(*) AS txn_before_account_open
FROM transactions t
JOIN accounts a ON a.account_id = t.account_id
WHERE t.transaction_date < a.open_date;

-- 8. Distinct values of categorical columns
SELECT 'transaction_type' AS column_name, transaction_type AS value, COUNT(*) AS cnt
FROM transactions GROUP BY transaction_type
UNION ALL
SELECT 'channel', channel, COUNT(*) FROM transactions GROUP BY channel
ORDER BY column_name, cnt DESC;