-- =====================================================================
-- Bank Fraud Detection — Triggers & Functions
-- All six fraud rules enforced at the database layer.
-- Run as: psql -U postgres -d frauddb -f sql/02_triggers.sql
-- =====================================================================

-- Tunable thresholds
--   Velocity window:   1 minute
--   Velocity count:    >= 3 txns in window raises an alert
--   Risk increment:    +20 per velocity alert
--   Freeze threshold:  risk_score >= 60

-- =====================================================================
-- Rule 1: Transaction Amount Validation (BEFORE INSERT — blocks)
-- =====================================================================
CREATE OR REPLACE FUNCTION fn_validate_amount()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.amount IS NULL OR NEW.amount <= 0 THEN
        RAISE EXCEPTION 'FRAUD RULE 1: Invalid transaction amount (%). Amount must be positive.', NEW.amount;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_validate_amount ON transactions;
CREATE TRIGGER trg_validate_amount
    BEFORE INSERT ON transactions
    FOR EACH ROW
    EXECUTE FUNCTION fn_validate_amount();

-- =====================================================================
-- Rule 2: Account Status Validation (BEFORE INSERT — blocks)
-- =====================================================================
CREATE OR REPLACE FUNCTION fn_validate_account_status()
RETURNS TRIGGER AS $$
DECLARE
    v_status TEXT;
BEGIN
    SELECT account_status INTO v_status
    FROM accounts
    WHERE account_id = NEW.account_id;

    IF v_status IS NULL THEN
        RAISE EXCEPTION 'FRAUD RULE 2: Account % does not exist.', NEW.account_id;
    END IF;

    IF v_status <> 'ACTIVE' THEN
        RAISE EXCEPTION 'FRAUD RULE 2: Account % is % — transactions are blocked.', NEW.account_id, v_status;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_validate_account_status ON transactions;
CREATE TRIGGER trg_validate_account_status
    BEFORE INSERT ON transactions
    FOR EACH ROW
    EXECUTE FUNCTION fn_validate_account_status();

-- =====================================================================
-- Rule 3: Daily Transaction Limit (BEFORE INSERT — blocks)
-- =====================================================================
CREATE OR REPLACE FUNCTION fn_daily_txn_limit()
RETURNS TRIGGER AS $$
DECLARE
    v_limit       NUMERIC;
    v_spent_today NUMERIC;
BEGIN
    SELECT daily_txn_limit INTO v_limit
    FROM accounts
    WHERE account_id = NEW.account_id;

    SELECT COALESCE(SUM(amount), 0) INTO v_spent_today
    FROM transactions
    WHERE account_id = NEW.account_id
      AND txn_timestamp::date = NEW.txn_timestamp::date;

    IF v_spent_today + NEW.amount > v_limit THEN
        RAISE EXCEPTION
            'FRAUD RULE 3: Daily limit exceeded. Limit=%, already spent=%, attempted=%.',
            v_limit, v_spent_today, NEW.amount;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_daily_txn_limit ON transactions;
CREATE TRIGGER trg_daily_txn_limit
    BEFORE INSERT ON transactions
    FOR EACH ROW
    EXECUTE FUNCTION fn_daily_txn_limit();

-- =====================================================================
-- Rule 4: Velocity Fraud Detection (AFTER INSERT — alerts, no block)
--         + Rule 6: Notification Emission
-- =====================================================================
CREATE OR REPLACE FUNCTION fn_velocity_fraud()
RETURNS TRIGGER AS $$
DECLARE
    v_recent_count INT;
BEGIN
    SELECT COUNT(*) INTO v_recent_count
    FROM transactions
    WHERE account_id = NEW.account_id
      AND txn_timestamp >= NEW.txn_timestamp - INTERVAL '1 minute';

    IF v_recent_count >= 3 THEN
        INSERT INTO fraud_alerts (account_id, rule_name, alert_message)
        VALUES (
            NEW.account_id,
            'VELOCITY_FRAUD',
            format('%s transactions within 1 minute detected on account %s.',
                   v_recent_count, NEW.account_id)
        );

        -- Risk score accumulation (may fire the auto-freeze trigger)
        UPDATE accounts
        SET risk_score = risk_score + 20
        WHERE account_id = NEW.account_id;

        -- Rule 6: notification emission
        INSERT INTO notification_queue (account_id, event_type, message)
        VALUES (
            NEW.account_id,
            'VELOCITY_FRAUD_DETECTED',
            format('High transaction velocity: %s txns in 1 minute on account %s.',
                   v_recent_count, NEW.account_id)
        );
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_velocity_fraud ON transactions;
CREATE TRIGGER trg_velocity_fraud
    AFTER INSERT ON transactions
    FOR EACH ROW
    EXECUTE FUNCTION fn_velocity_fraud();

-- =====================================================================
-- Rule 5: Risk-Based Auto Freeze (BEFORE UPDATE on accounts)
--         + Rule 6: Notification Emission
-- =====================================================================
CREATE OR REPLACE FUNCTION fn_auto_freeze()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.risk_score >= 60 AND OLD.account_status = 'ACTIVE' THEN
        NEW.account_status := 'FROZEN';

        INSERT INTO fraud_alerts (account_id, rule_name, alert_message)
        VALUES (
            NEW.account_id,
            'AUTO_FREEZE',
            format('Account %s auto-frozen: risk score reached %s (threshold 60).',
                   NEW.account_id, NEW.risk_score)
        );

        -- Rule 6: notification emission
        INSERT INTO notification_queue (account_id, event_type, message)
        VALUES (
            NEW.account_id,
            'ACCOUNT_AUTO_FROZEN',
            format('Account %s was automatically frozen at risk score %s.',
                   NEW.account_id, NEW.risk_score)
        );
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_auto_freeze ON accounts;
CREATE TRIGGER trg_auto_freeze
    BEFORE UPDATE OF risk_score ON accounts
    FOR EACH ROW
    EXECUTE FUNCTION fn_auto_freeze();
