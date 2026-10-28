-- Kowojọ — Portfolio 2: Query Processing and Optimisation
-- optimisation.sql — EXPLAIN ANALYZE runs and indexing evidence

-- This file demonstrates query optimisation using PostgreSQL's EXPLAIN ANALYZE.
--
-- EXPLAIN ANALYZE actually executes the query and reports:
--   - The execution plan PostgreSQL chose
--   - Estimated vs actual row counts
--   - Time spent at each step
--   - Whether indexes were used (Index Scan) or not (Seq Scan)
--
-- =============================================================================
-- CANDIDATE 1: Q4 — Members who have never paid for a dues schedule
-- =============================================================================
-- This query does a LEFT JOIN between members and transactions, filtered
-- by dues_schedule_id and status. Without an index on those two columns
-- together, PostgreSQL will scan the entire transactions table for every
-- member row it checks.

-- Step 1: Baseline before creating the index
EXPLAIN
ANALYZE
SELECT u.first_name, u.last_name, m.membership_number, m.status
FROM
    members m
    JOIN users u ON u.id = m.user_id
    LEFT JOIN transactions tx ON tx.member_id = m.id
    AND tx.dues_schedule_id = 'e0000000-0000-0000-0000-000000000001'
    AND tx.status = 'successful'
WHERE
    m.tenant_id = 'a0000000-0000-0000-0000-000000000001'
    AND tx.id IS NULL
ORDER BY m.membership_number;

-- Step 2: A composite index on the columns used in the JOIN condition.
-- A composite index covers multiple columns together.
-- This index is useful when queries filter on both member_id and
-- dues_schedule_id at the same time
CREATE INDEX IF NOT EXISTS idx_transactions_member_schedule ON transactions (
    member_id,
    dues_schedule_id,
    status
);

-- Step 3: Run after the index was added
EXPLAIN
ANALYZE
SELECT u.first_name, u.last_name, m.membership_number, m.status
FROM
    members m
    JOIN users u ON u.id = m.user_id
    LEFT JOIN transactions tx ON tx.member_id = m.id
    AND tx.dues_schedule_id = 'e0000000-0000-0000-0000-000000000001'
    AND tx.status = 'successful'
WHERE
    m.tenant_id = 'a0000000-0000-0000-0000-000000000001'
    AND tx.id IS NULL
ORDER BY m.membership_number;


-- =============================================================================
-- CANDIDATE 2: Q6 — Monthly transaction volume for a tenant
-- =============================================================================
-- This query groups transactions by month using DATE_TRUNC on paid_at.
-- Without an index on paid_at, PostgreSQL must scan every transaction
-- row to evaluate the date condition.

-- Step 1
EXPLAIN
ANALYZE
SELECT
    DATE_TRUNC('month', tx.paid_at) AS month,
    COUNT(tx.id) AS transaction_count,
    SUM(tx.amount) AS monthly_revenue
FROM transactions tx
WHERE
    tx.tenant_id = 'a0000000-0000-0000-0000-000000000002'
    AND tx.status = 'successful'
    AND tx.paid_at IS NOT NULL
GROUP BY
    DATE_TRUNC('month', tx.paid_at)
ORDER BY month;

-- Step 2: Creating an index on tenant_id + status + paid_at.
CREATE INDEX IF NOT EXISTS idx_transactions_tenant_status_paid ON transactions (tenant_id, status, paid_at);

-- Step 3
EXPLAIN
ANALYZE
SELECT
    DATE_TRUNC('month', tx.paid_at) AS month,
    COUNT(tx.id) AS transaction_count,
    SUM(tx.amount) AS monthly_revenue
FROM transactions tx
WHERE
    tx.tenant_id = 'a0000000-0000-0000-0000-000000000002'
    AND tx.status = 'successful'
    AND tx.paid_at IS NOT NULL
GROUP BY
    DATE_TRUNC('month', tx.paid_at)
ORDER BY month;

