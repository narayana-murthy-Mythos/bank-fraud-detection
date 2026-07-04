-- =====================================================================
-- Bank Fraud Detection — Sample Data
-- Run as: psql -U postgres -d frauddb -f sql/03_sample_data.sql
-- =====================================================================

INSERT INTO customers (customer_id, full_name, email) VALUES
    ('11111111-1111-1111-1111-111111111111', 'Alice Johnson',  'alice.johnson@example.com'),
    ('22222222-2222-2222-2222-222222222222', 'Bob Smith',      'bob.smith@example.com'),
    ('33333333-3333-3333-3333-333333333333', 'Charlie Davis',  'charlie.davis@example.com'),
    ('44444444-4444-4444-4444-444444444444', 'Diana Prince',   'diana.prince@example.com'),
    ('55555555-5555-5555-5555-555555555555', 'Ethan Hunt',     'ethan.hunt@example.com');

INSERT INTO accounts (account_id, customer_id, account_status, daily_txn_limit, risk_score) VALUES
    ('aaaaaaa1-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 'ACTIVE', 50000,  0),
    ('aaaaaaa2-0000-0000-0000-000000000002', '22222222-2222-2222-2222-222222222222', 'ACTIVE', 20000,  0),
    ('aaaaaaa3-0000-0000-0000-000000000003', '33333333-3333-3333-3333-333333333333', 'ACTIVE', 100000, 0),
    ('aaaaaaa4-0000-0000-0000-000000000004', '44444444-4444-4444-4444-444444444444', 'ACTIVE', 30000,  0),
    ('aaaaaaa5-0000-0000-0000-000000000005', '55555555-5555-5555-5555-555555555555', 'ACTIVE', 10000,  0);

-- A few normal historical transactions (spread over past days so they
-- don't trip the velocity or daily-limit rules)
INSERT INTO transactions (account_id, amount, txn_type, direction, source, txn_timestamp) VALUES
    ('aaaaaaa1-0000-0000-0000-000000000001', 1200, 'POS',      'OUT', 'seed', now() - INTERVAL '3 days'),
    ('aaaaaaa1-0000-0000-0000-000000000001',  500, 'ATM',      'OUT', 'seed', now() - INTERVAL '2 days'),
    ('aaaaaaa2-0000-0000-0000-000000000002', 3000, 'TRANSFER', 'IN',  'seed', now() - INTERVAL '2 days'),
    ('aaaaaaa3-0000-0000-0000-000000000003',  750, 'POS',      'OUT', 'seed', now() - INTERVAL '1 day'),
    ('aaaaaaa4-0000-0000-0000-000000000004', 2200, 'TRANSFER', 'OUT', 'seed', now() - INTERVAL '1 day');
