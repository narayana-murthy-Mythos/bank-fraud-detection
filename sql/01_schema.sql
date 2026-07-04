-- =====================================================================
-- Bank Fraud Detection — Schema
-- Run as: psql -U postgres -d frauddb -f sql/01_schema.sql
-- =====================================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;  -- gen_random_uuid()

DROP TABLE IF EXISTS notification_queue CASCADE;
DROP TABLE IF EXISTS fraud_alerts CASCADE;
DROP TABLE IF EXISTS transactions CASCADE;
DROP TABLE IF EXISTS accounts CASCADE;
DROP TABLE IF EXISTS customers CASCADE;

-- ---------------------------------------------------------------------
-- customers: customer identity (persona layer)
-- ---------------------------------------------------------------------
CREATE TABLE customers (
    customer_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    full_name   TEXT NOT NULL,
    email       TEXT NOT NULL,
    created_at  TIMESTAMP NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------
-- accounts: bank accounts and risk posture
-- ---------------------------------------------------------------------
CREATE TABLE accounts (
    account_id      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id     UUID NOT NULL REFERENCES customers (customer_id),
    account_status  TEXT NOT NULL DEFAULT 'ACTIVE'
                    CHECK (account_status IN ('ACTIVE', 'FROZEN')),
    daily_txn_limit NUMERIC NOT NULL DEFAULT 100000,
    risk_score      INT NOT NULL DEFAULT 0,
    created_at      TIMESTAMP NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------
-- transactions: all monetary movements
-- ---------------------------------------------------------------------
CREATE TABLE transactions (
    txn_id        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    account_id    UUID NOT NULL REFERENCES accounts (account_id),
    amount        NUMERIC NOT NULL,
    txn_type      TEXT NOT NULL CHECK (txn_type IN ('POS', 'ATM', 'TRANSFER')),
    direction     TEXT NOT NULL CHECK (direction IN ('IN', 'OUT')),
    source        TEXT,
    txn_timestamp TIMESTAMP NOT NULL DEFAULT now()
);

CREATE INDEX idx_txn_account_time ON transactions (account_id, txn_timestamp);

-- ---------------------------------------------------------------------
-- fraud_alerts: detected fraud signals
-- ---------------------------------------------------------------------
CREATE TABLE fraud_alerts (
    alert_id      SERIAL PRIMARY KEY,
    account_id    UUID NOT NULL,
    rule_name     TEXT NOT NULL,
    alert_message TEXT NOT NULL,
    created_at    TIMESTAMP NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------
-- notification_queue: event emission for downstream systems
-- ---------------------------------------------------------------------
CREATE TABLE notification_queue (
    notification_id SERIAL PRIMARY KEY,
    account_id      UUID NOT NULL,
    event_type      TEXT NOT NULL,
    message         TEXT NOT NULL,
    processed       BOOLEAN NOT NULL DEFAULT false,
    created_at      TIMESTAMP NOT NULL DEFAULT now()
);
