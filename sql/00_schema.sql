-- 00_schema.sql
-- Creates the star-schema tables. Re-running this file resets the database.

DROP TABLE IF EXISTS transactions CASCADE;
DROP TABLE IF EXISTS accounts CASCADE;
DROP TABLE IF EXISTS branches CASCADE;
DROP TABLE IF EXISTS products CASCADE;
DROP TABLE IF EXISTS customers CASCADE;

CREATE TABLE customers (
    customer_id    INTEGER PRIMARY KEY,
    customer_name  VARCHAR(100) NOT NULL,
    age            INTEGER,
    city           VARCHAR(50),
    join_date      DATE NOT NULL
);

CREATE TABLE products (
    product_id        INTEGER PRIMARY KEY,
    product_name      VARCHAR(50) NOT NULL,
    product_category  VARCHAR(30)
);

CREATE TABLE branches (
    branch_id    INTEGER PRIMARY KEY,
    branch_name  VARCHAR(100) NOT NULL,
    city         VARCHAR(50)
);

CREATE TABLE accounts (
    account_id   INTEGER PRIMARY KEY,
    customer_id  INTEGER NOT NULL REFERENCES customers (customer_id),
    product_id   INTEGER NOT NULL REFERENCES products (product_id),
    open_date    DATE NOT NULL
);

CREATE TABLE transactions (
    transaction_id    BIGINT PRIMARY KEY,
    account_id        INTEGER NOT NULL REFERENCES accounts (account_id),
    branch_id         INTEGER NOT NULL REFERENCES branches (branch_id),
    transaction_date  DATE NOT NULL,
    transaction_type  VARCHAR(30) NOT NULL,
    amount            NUMERIC(14, 2) NOT NULL,
    channel           VARCHAR(20) NOT NULL,
    fee_amount        NUMERIC(10, 2) NOT NULL DEFAULT 0
);

CREATE INDEX idx_accounts_customer     ON accounts (customer_id);
CREATE INDEX idx_transactions_account  ON transactions (account_id);
CREATE INDEX idx_transactions_date     ON transactions (transaction_date);
CREATE INDEX idx_transactions_channel  ON transactions (channel);