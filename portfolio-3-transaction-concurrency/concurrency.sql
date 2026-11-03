-- Kowojọ — Portfolio 3: Isolation Levels & Concurrency Control
-- MIT 8103 Advanced Database Systems · MIVA Open University
-- ============================================================
-- PostgreSQL uses MVCC (Multi-Version Concurrency Control) to
-- manage how transactions access data at the same time.
-- This allows transactions to read data without necessarily
-- having to wait for other transactions to release their locks.
--
-- The isolation level determines how much of the changes made
-- by other transactions can be seen while a transaction runs.
--
-- The available isolation levels are:
--   READ UNCOMMITTED → PostgreSQL treats this as READ COMMITTED
--   READ COMMITTED   → Each statement gets its own snapshot
--   REPEATABLE READ  → All reads use the same transaction snapshot
--   SERIALIZABLE     → Transactions behave as though they ran one
--                      after another; conflicting transactions
--                      may be aborted.
-- ============================================================


-- ============================================================
-- LEVEL 1: READ COMMITTED (PostgreSQL default)
-- ============================================================
-- With READ COMMITTED, each SQL statement sees the latest
-- committed data available when that statement begins.
--
-- This means that if another transaction updates a record and
-- commits while the current transaction is still running, a
-- later SELECT statement in the current transaction can see
-- that update.
--
-- In other words, reading the same record twice in one
-- transaction does not always guarantee the same result.
--
-- For Kowojọ, this isolation level is suitable for ordinary
-- member lookups and dashboard queries where each statement
-- can work with the latest available data.

BEGIN;

SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

SELECT t.id, t.amount, t.status, t.paid_at, m.membership_number, ds.name AS schedule_title
FROM
    transactions t
    JOIN members m ON m.id = t.member_id
    JOIN dues_schedules ds ON ds.id = t.dues_schedule_id
WHERE
    t.status = 'successful'
ORDER BY t.paid_at DESC;

COMMIT;


-- ============================================================
-- LEVEL 2: REPEATABLE READ
-- ============================================================
-- Unlike READ COMMITTED, REPEATABLE READ uses one snapshot
-- throughout the transaction.
--
-- Once the transaction starts, changes committed by other
-- sessions afterwards will not be visible to its subsequent
-- SELECT statements.
--
-- This is useful when running reports that involve multiple
-- queries. For example, when generating a revenue report, we
-- want the different queries to work with the same set of data
-- instead of producing results based on different snapshots.
--
-- In Kowojọ, this can be useful for revenue reconciliation and
-- reports that compare payment totals across organisations.

BEGIN;

SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;

-- First query: get the number of payments and total amount
-- collected by each organisation.
SELECT
    ten.name AS organisation,
    COUNT(t.id) AS payment_count,
    SUM(t.amount) AS total_collected
FROM transactions t
    JOIN tenants ten ON ten.id = t.tenant_id
WHERE
    t.status = 'successful'
GROUP BY
    ten.id,
    ten.name
ORDER BY total_collected DESC;

-- Second query: calculate the revenue collected each month.
-- Both queries use the same snapshot, so a payment committed
-- by another session between the two queries will not appear
-- in this result either.
SELECT DATE_TRUNC('month', t.paid_at) AS month, SUM(t.amount) AS monthly_revenue
FROM transactions t
WHERE
    t.status = 'successful'
GROUP BY
    1
ORDER BY 1;

COMMIT;


-- ============================================================
-- LEVEL 3: SERIALIZABLE
-- ============================================================
-- SERIALIZABLE provides the strictest isolation level.
-- PostgreSQL monitors transactions to check whether their
-- operations could produce a result that is inconsistent with
-- running those transactions one after another.
--
-- If PostgreSQL detects a conflict that cannot be resolved
-- while maintaining this behaviour, it aborts one of the
-- transactions and returns a serialization failure.
--
-- The application must handle this error (SQLSTATE 40001)
-- and retry the transaction where appropriate.
--
-- In Kowojọ, this is relevant to checking whether a member
-- has already paid for a particular dues schedule.
-- If two sessions both check for an existing payment at the
-- same time and both get a negative result, they may both
-- attempt to insert a payment. SERIALIZABLE can detect the
-- resulting conflict and abort one of the transactions.

BEGIN;

SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;

-- Check whether the selected member has already made a
-- successful payment for the selected dues schedule.
-- If another session performs the same check and attempts
-- the same operation, PostgreSQL may detect a conflict
-- between the two transactions.
WITH
    target AS (
        SELECT m.id AS member_id, ds.id AS schedule_id
        FROM members m
            JOIN dues_schedules ds ON ds.tenant_id = m.tenant_id
        ORDER BY m.id, ds.id
        LIMIT 1
    )
SELECT EXISTS (
        SELECT 1
        FROM
            transactions t
            JOIN target tgt ON t.member_id = tgt.member_id
            AND t.dues_schedule_id = tgt.schedule_id
        WHERE
            t.status = 'successful'
    ) AS already_paid;

-- If already_paid = false, the payment can proceed.
-- The INSERT operation is shown in transactions.sql, Scenario 1.
-- If already_paid = true, the payment should not be processed.

COMMIT;


-- ============================================================
-- SELECT FOR UPDATE: Pessimistic Row Locking
-- ============================================================
-- Another way to prevent two sessions from processing the same
-- member's payment at the same time is to lock the member's row.
--
-- SELECT FOR UPDATE is used for this purpose. It acquires a
-- row-level lock and prevents other transactions from acquiring
-- a conflicting lock on that same row until the current
-- transaction ends.
--
-- This is the approach used in Kowojọ when processing dues
-- payments. Rather than allowing both sessions to proceed and
-- checking for conflicts afterwards, the second session has
-- to wait until the first one finishes.

BEGIN;

SELECT id
FROM members
WHERE
    id = (
        SELECT m.id
        FROM members m
            JOIN dues_schedules ds ON ds.tenant_id = m.tenant_id
        ORDER BY m.id
        LIMIT 1
    )
FOR UPDATE;

-- If Session B executes the same SELECT FOR UPDATE on this
-- member, it will have to wait while Session A holds the lock.
-- After Session A commits or rolls back, Session B can proceed.
-- It can then check whether a payment has already been recorded.

ROLLBACK;
-- The transaction is rolled back here to release the lock.
-- This is only a demonstration; no payment is being processed.


-- ============================================================
-- CONCURRENT SESSION TIMELINE
-- ============================================================
-- This example shows what happens when two sessions attempt
-- to pay for the same dues schedule at roughly the same time.
--
-- Since both sessions are working with the same member, the
-- SELECT FOR UPDATE statement ensures that they do not process
-- the payment simultaneously.
--
-- [Session A — first payment attempt]
--   T1  BEGIN;
--   T2  SELECT id FROM members WHERE id = '<member>' FOR UPDATE;
--           → The lock is acquired successfully.
--   T3  INSERT INTO transactions (...) VALUES (..., 'completed', ...);
--   T4  INSERT INTO audit_logs   (...) VALUES (...);
--   T5  COMMIT;
--           → The changes are saved and the lock is released.
--
-- [Session B — second payment attempt]
--   T2  BEGIN;
--   T3  SELECT id FROM members WHERE id = '<member>' FOR UPDATE;
--           → Session B has to wait for Session A to finish.
--       (Session A commits at T5)
--           → Session B is now allowed to continue.
--   T6  Query transactions WHERE member_id = '<member>'
--         AND dues_schedule_id = '<schedule>' AND status = 'completed';
--           → The payment recorded by Session A is found.
--   T7  Duplicate detected → ROLLBACK;
--
-- The result is that Session B does not proceed with another
-- payment after finding the existing successful transaction.


-- ============================================================
-- ISOLATION LEVEL SUMMARY
-- ============================================================
--
-- The table below summarises the behaviour of the three
-- isolation levels discussed above.
--
-- Hazard               | READ COMMITTED | REPEATABLE READ | SERIALIZABLE
-- ---------------------|----------------|-----------------|-------------
-- Dirty read           | Prevented      | Prevented       | Prevented
-- Non-repeatable read  | Possible       | Prevented       | Prevented
-- Phantom read         | Possible       | Prevented*      | Prevented
-- Lost update          | Possible       | Prevented*      | Prevented
-- Serialization anomaly| Possible       | Possible        | Prevented
--
-- * PostgreSQL's REPEATABLE READ also prevents phantom reads
--   and certain lost-update situations, providing stronger
--   protection than the SQL standard requires at this level.
--
-- For Kowojọ, READ COMMITTED is suitable for ordinary queries,
-- while REPEATABLE READ is useful for reports that need to work
-- with a consistent snapshot of the data.
--
-- For payment operations, SELECT FOR UPDATE is used to control
-- access to the member's record. This provides a straightforward
-- way to coordinate concurrent payment attempts without relying
-- entirely on SERIALIZABLE transactions and retry handling.
