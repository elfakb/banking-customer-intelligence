WITH monthly AS (
    SELECT DATE_TRUNC('month', transaction_date)::date AS month,
           COUNT(*)      AS txn_count,
           SUM(amount)   AS total_value
    FROM transactions
    GROUP BY 1
)
SELECT month,
       txn_count,
       ROUND(total_value, 2) AS total_value,
       ROUND(LAG(total_value) OVER (ORDER BY month), 2) AS prev_month_value,
       ROUND(100.0 * (total_value - LAG(total_value) OVER (ORDER BY month))
             / NULLIF(LAG(total_value) OVER (ORDER BY month), 0), 2) AS mom_growth_pct
FROM monthly
ORDER BY month;

-- 2. Running total: cumulative fee revenue + 3-month moving average
WITH monthly AS (
    SELECT DATE_TRUNC('month', transaction_date)::date AS month,
           SUM(fee_amount) AS monthly_fee
    FROM transactions
    GROUP BY 1
)
SELECT month,
       ROUND(monthly_fee, 2) AS monthly_fee,
       ROUND(SUM(monthly_fee) OVER (
           ORDER BY month ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
       ), 2) AS cumulative_fee,
       ROUND(AVG(monthly_fee) OVER (
           ORDER BY month ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
       ), 2) AS moving_avg_3m
FROM monthly
ORDER BY month;

-- 3. RANK: top 3 customers by 12-month fee revenue within each city
WITH ranked AS (
    SELECT city, customer_id, customer_name, fee_12m,
           RANK() OVER (PARTITION BY city ORDER BY fee_12m DESC) AS city_rank
    FROM vw_customer_segments
)
SELECT *
FROM ranked
WHERE city_rank <= 3
ORDER BY city, city_rank;

-- 4. RANK: channels ranked by transaction value within each month (top channel per month)
WITH channel_month AS (
    SELECT DATE_TRUNC('month', transaction_date)::date AS month,
           channel,
           SUM(amount) AS total_value
    FROM transactions
    GROUP BY 1, channel
),
ranked AS (
    SELECT month, channel, ROUND(total_value, 2) AS total_value,
           RANK() OVER (PARTITION BY month ORDER BY total_value DESC) AS channel_rank
    FROM channel_month
)
SELECT *
FROM ranked
WHERE channel_rank = 1
ORDER BY month;

-- 5. RANK: branches by fee revenue (overall rank + rank within city)
WITH branch_fee AS (
    SELECT b.branch_name, b.city, SUM(t.fee_amount) AS total_fee
    FROM transactions t
    JOIN branches b ON b.branch_id = t.branch_id
    GROUP BY b.branch_name, b.city
)
SELECT branch_name,
       city,
       ROUND(total_fee, 2) AS total_fee,
       RANK() OVER (ORDER BY total_fee DESC)                       AS overall_rank,
       RANK() OVER (PARTITION BY city ORDER BY total_fee DESC)     AS rank_in_city
FROM branch_fee
ORDER BY overall_rank;

-- 6. LAG per customer: average days between consecutive transactions
WITH tx AS (
    SELECT a.customer_id,
           t.transaction_date,
           LAG(t.transaction_date) OVER (
               PARTITION BY a.customer_id
               ORDER BY t.transaction_date, t.transaction_id
           ) AS prev_txn_date
    FROM transactions t
    JOIN accounts a ON a.account_id = t.account_id
)
SELECT customer_id,
       COUNT(*) + 1                                  AS txn_count,
       ROUND(AVG(transaction_date - prev_txn_date), 1) AS avg_days_between_txn
FROM tx
WHERE prev_txn_date IS NOT NULL
GROUP BY customer_id
HAVING COUNT(*) >= 10
ORDER BY avg_days_between_txn
LIMIT 20;

-- 7. Running total per customer (first 30 transactions of customer 1)
SELECT a.customer_id,
       t.transaction_date,
       t.transaction_type,
       t.amount,
       SUM(t.amount) OVER (
           PARTITION BY a.customer_id
           ORDER BY t.transaction_date, t.transaction_id
       ) AS running_total
FROM transactions t
JOIN accounts a ON a.account_id = t.account_id
WHERE a.customer_id = 1
ORDER BY t.transaction_date, t.transaction_id
LIMIT 30;