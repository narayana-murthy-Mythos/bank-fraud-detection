# Bank Fraud Detection Using SQL Triggers

A banking fraud detection system that enforces fraud rules directly in the PostgreSQL database layer using triggers, instead of relying on application-side validation.

The idea is simple: in real banking systems, multiple services write to the same database, and application-only checks can be bypassed. By putting detection, risk scoring, and account control at the data layer, every write path is covered no matter which service it comes from.

## Problem Statement

In real-world banking systems:

- Millions of transactions occur daily
- Fraud must be detected in near real time
- Application-only checks are fragile and bypassable
- Multiple services often write to the same database

The goal is a centralized fraud detection system that works independently of application logic and guarantees enforcement at the data source.

## How It Works

```
Transaction insert
    -> validation triggers (amount, account status, daily limit)
    -> velocity fraud detection
    -> risk score update
    -> auto freeze at threshold
    -> fraud alerts + notification queue
    -> Streamlit monitoring dashboard
    -> manual email dispatch by analyst
```

## Database Schema

### customers

| Column      | Type      | Description                |
| ----------- | --------- | -------------------------- |
| customer_id | UUID (PK) | Unique customer identifier |
| full_name   | TEXT      | Customer full name         |
| email       | TEXT      | Contact email              |
| created_at  | TIMESTAMP | Record creation time       |

### accounts

| Column          | Type      | Description               |
| --------------- | --------- | ------------------------- |
| account_id      | UUID (PK) | Unique account identifier |
| customer_id     | UUID (FK) | Linked customer           |
| account_status  | TEXT      | ACTIVE / FROZEN           |
| daily_txn_limit | NUMERIC   | Daily transaction cap     |
| risk_score      | INT       | Accumulated fraud risk    |
| created_at      | TIMESTAMP | Account creation time     |

### transactions

| Column        | Type      | Description            |
| ------------- | --------- | ---------------------- |
| txn_id        | UUID (PK) | Transaction identifier |
| account_id    | UUID (FK) | Account used           |
| amount        | NUMERIC   | Transaction amount     |
| txn_type      | TEXT      | POS / ATM / TRANSFER   |
| direction     | TEXT      | IN / OUT               |
| source        | TEXT      | Origin of transaction  |
| txn_timestamp | TIMESTAMP | Event time             |

### fraud_alerts

| Column        | Type        | Description            |
| ------------- | ----------- | ---------------------- |
| alert_id      | SERIAL (PK) | Alert identifier       |
| account_id    | UUID        | Impacted account       |
| rule_name     | TEXT        | Fraud rule name        |
| alert_message | TEXT        | Human-readable message |
| created_at    | TIMESTAMP   | Detection time         |

### notification_queue

| Column          | Type        | Description              |
| --------------- | ----------- | ------------------------ |
| notification_id | SERIAL (PK) | Notification id          |
| account_id      | UUID        | Impacted account         |
| event_type      | TEXT        | Event code               |
| message         | TEXT        | Notification message     |
| processed       | BOOLEAN     | Consumed by worker       |
| created_at      | TIMESTAMP   | Emission time            |

## Fraud Rules

All six rules are implemented as SQL trigger functions.

1. **Transaction amount validation** - rejects zero or negative transactions before insert
2. **Account status validation** - blocks transactions on frozen accounts, even direct DB writes
3. **Daily transaction limit** - computes total spend per calendar day and rejects transactions over the cap
4. **Velocity fraud detection** - flags 3 or more transactions within a 1-minute window, raises an alert (does not block) and adds +20 to the account risk score
5. **Risk-based auto freeze** - freezes the account automatically when risk score reaches 60
6. **Notification emission** - writes events to the notification queue for velocity fraud and auto-freeze, consumed by the dashboard and worker

## Project Structure

```
bank-fraud-detection/
    sql/
        01_schema.sql        tables + pgcrypto extension
        02_triggers.sql      the six fraud rules as trigger functions
        03_sample_data.sql   5 customers, 5 accounts, seed transactions
    dashboard.py             Streamlit monitoring dashboard
    notifications.py         notification queue worker (polls every 5s)
    test_email.py            SMTP sanity check
    .env.example             copy to .env and fill in
    requirements.txt
```

## Setup

Create the database and load the SQL:

```bash
psql -h localhost -U postgres -c "CREATE DATABASE frauddb;"
psql -h localhost -U postgres -d frauddb -f sql/01_schema.sql
psql -h localhost -U postgres -d frauddb -f sql/02_triggers.sql
psql -h localhost -U postgres -d frauddb -f sql/03_sample_data.sql
```

Configure the environment:

```bash
cp .env.example .env
# set DB_PASSWORD, and SMTP credentials if you want email alerts
```

Install dependencies and run:

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
streamlit run dashboard.py
```

Optionally run the notification worker in another terminal:

```bash
python notifications.py
```

## Trying It Out

In the dashboard's transaction simulator, submit 3 or more transactions for the same customer within a minute. You should see a velocity fraud alert appear, the risk score climb, and at 60 the account freezes automatically. Any further transaction on that account is then rejected at the database layer.

## Possible Extensions

- Amount deviation vs historical average
- Night-time / unusual-hours detection
- Geo-velocity (impossible travel)
- High-risk merchant and blacklisted counterparty checks
- Alert deduplication and SOC escalation workflows
- ML-based risk enrichment
