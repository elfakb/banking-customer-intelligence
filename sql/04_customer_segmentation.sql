

CREATE OR REPLACE VIEW vw_customer_segments AS
WITH ref AS (
    SELECT MAX(transaction_date) AS ref_date FROM transactions
),
customer_12m AS (
    SELECT c.customer_id,
           COUNT(t.transaction_id)         AS txn_count_12m,
           COALESCE(SUM(t.amount), 0)      AS volume_12m,
           COALESCE(SUM(t.fee_amount), 0)  AS fee_12m,
           MAX(t.transaction_date)         AS last_txn_date
    FROM customers c
    LEFT JOIN accounts a     ON a.customer_id = c.customer_id
    LEFT JOIN transactions t ON t.account_id  = a.account_id
         AND t.transaction_date > (SELECT (ref_date - INTERVAL '12 months')::date FROM ref)
    GROUP BY c.customer_id
),
flagged AS (
    SELECT cm.*,
           r.ref_date - cm.last_txn_date AS days_since_last_txn,
           (cm.last_txn_date IS NOT NULL
            AND cm.last_txn_date > r.ref_date - 90) AS is_active
    FROM customer_12m cm
    CROSS JOIN ref r
),
scored AS (
    SELECT f.customer_id,
           0.5 * PERCENT_RANK() OVER (ORDER BY f.volume_12m)
         + 0.5 * PERCENT_RANK() OVER (ORDER BY f.fee_12m) AS value_score
    FROM flagged f
    WHERE f.is_active
),
ranked AS (
    SELECT s.customer_id,
           s.value_score,
           PERCENT_RANK() OVER (ORDER BY s.value_score DESC) AS score_pct
    FROM scored s
)
SELECT c.customer_id,
       c.customer_name,
       c.city,
       c.age,
       f.txn_count_12m,
       ROUND(f.volume_12m, 2) AS volume_12m,
       ROUND(f.fee_12m, 2)    AS fee_12m,
       ROUND(f.volume_12m / NULLIF(f.txn_count_12m, 0), 2) AS avg_txn_12m,
       f.last_txn_date,
       f.days_since_last_txn,
       ROUND(r.value_score::numeric, 4) AS value_score,
       CASE
           WHEN NOT f.is_active    THEN 'Inactive'
           WHEN r.score_pct < 0.20 THEN 'High Value'
           WHEN r.score_pct < 0.50 THEN 'Medium Value'
           ELSE 'Low Value'
       END AS segment
FROM customers c
JOIN flagged f      ON f.customer_id = c.customer_id
LEFT JOIN ranked r  ON r.customer_id = c.customer_id;


-- 1. Segment summary: who generates the most financial value?
SELECT segment,
       COUNT(*)                                                    AS customers,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2)          AS customer_share_pct,
       ROUND(SUM(volume_12m), 2)                                   AS total_volume_12m,
       ROUND(100.0 * SUM(volume_12m) / SUM(SUM(volume_12m)) OVER (), 2) AS volume_share_pct,
       ROUND(SUM(fee_12m), 2)                                      AS total_fee_12m,
       ROUND(100.0 * SUM(fee_12m) / SUM(SUM(fee_12m)) OVER (), 2)  AS fee_share_pct,
       ROUND(AVG(fee_12m), 2)                                      AS avg_fee_per_customer,
       ROUND(AVG(txn_count_12m), 1)                                AS avg_txn_per_customer
FROM vw_customer_segments
GROUP BY segment
ORDER BY total_fee_12m DESC;

-- 2. Segment by city
SELECT city,
       COUNT(*) FILTER (WHERE segment = 'High Value')   AS high_value,
       COUNT(*) FILTER (WHERE segment = 'Medium Value') AS medium_value,
       COUNT(*) FILTER (WHERE segment = 'Low Value')    AS low_value,
       COUNT(*) FILTER (WHERE segment = 'Inactive')     AS inactive,
       COUNT(*)                                         AS total
FROM vw_customer_segments
GROUP BY city
ORDER BY total DESC;

-- 3. Segment by age band
SELECT CASE
           WHEN age < 25 THEN '18-24'
           WHEN age < 35 THEN '25-34'
           WHEN age < 45 THEN '35-44'
           WHEN age < 55 THEN '45-54'
           ELSE '55+'
       END AS age_band,
       segment,
       COUNT(*) AS customers
FROM vw_customer_segments
GROUP BY 1, 2
ORDER BY 1, 2;

-- 4. Top 20 high-value customers
SELECT customer_id, customer_name, city, txn_count_12m, volume_12m, fee_12m, value_score
FROM vw_customer_segments
WHERE segment = 'High Value'
ORDER BY value_score DESC
LIMIT 20;