-- ============================================================
-- Kowojọ — Portfolio 3: Isolation Levels & Concurrency Control
-- MIT 8103 Advanced Database Systems · MIVA Open University
-- ============================================================
-- PostgreSQL implements MVCC (Multi-Version Concurrency Control).
-- Rather than blocking readers with locks, each transaction sees
-- a consistent snapshot of the database. The isolation level
-- controls how that snapshot is taken and how long it is held.
--
-- Isolation levels (weakest → strongest):
--   READ UNCOMMITTED → treated as READ COMMITTED in PostgreSQL
--   READ COMMITTED   → snapshot per statement (default)
--   REPEATABLE READ  → snapshot per transaction; no phantom rows
--   SERIALIZABLE     → full serial ordering; anomalies abort the txn
-- ============================================================

-- ─────────────────────────────────────────────────────────────
-- LEVEL 1: READ COMMITTED (PostgreSQL default)
-- ─────────────────────────────────────────────────────────────
-- Each statement in the transaction sees the most recently
-- committed version of every row at the moment that statement
-- executes. Two reads of the same row in one transaction may
-- return different values if another session commits between them.
--
-- Use in Kowojọ: routine member lookups, dashboard reads,
-- single-statement reports where cross-statement consistency
-- is not required.

BEGIN;

SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

SELECT t.id, t.amount, t.status, t.paid_at, m.membership_number, ds.title AS schedule_title
FROM
    transactions t
    JOIN members m ON m.id = t.member_id
    JOIN dues_schedules ds ON ds.id = t.dues_schedule_id
WHERE
    t.status = 'completed'
ORDER BY t.paid_at DESC;

COMMIT;

-- ─────────────────────────────────────────────────────────────
-- LEVEL 2: REPEATABLE READ
-- ─────────────────────────────────────────────────────────────
-- The snapshot is taken once at the start of the transaction and
-- held for all subsequent reads. Rows committed by concurrent
-- sessions after this transaction began will NOT appear in any
-- read, no matter how many statements execute.
--
-- Use in Kowojọ: revenue reconciliation reports and cross-tenant
-- summaries where both SELECT statements must see identical data.
-- A concurrent payment committing mid-report will not distort
-- either aggregate.

BEGIN;

SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;

-- First read: totals per organisation
SELECT
    ten.name AS organisation,
    COUNT(t.id) AS payment_count,
    SUM(t.amount) AS total_collected
FROM transactions t
    JOIN tenants ten ON ten.id = t.tenant_id
WHERE
    t.status = 'completed'
GROUP BY
    ten.id,
    ten.name
ORDER BY total_collected DESC;

-- Second read in the same transaction — identical snapshot.
-- A dues payment that committed between these two statements
-- is invisible here, so monthly_revenue aligns with the totals above.
SELECT DATE_TRUNC('month', t.paid_at) AS month, SUM(t.amount) AS monthly_revenue
FROM transactions t
WHERE
    t.status = 'completed'
GROUP BY
    1
ORDER BY 1;

COMMIT;

-- ─────────────────────────────────────────────────────────────
-- LEVEL 3: SERIALIZABLE
-- ─────────────────────────────────────────────────────────────
-- PostgreSQL tracks read-write dependencies between concurrent
-- SERIALIZABLE transactions. If committing a transaction would
-- violate the serial execution order, PostgreSQL aborts it with:
--   ERROR: could not serialize access due to read/write dependencies
--   SQLSTATE 40001
-- The application must catch 40001 and retry the transaction.
--
-- Use in Kowojọ: the payment existence check on the critical path.
-- Two sessions both reading "no completed payment exists" and then
-- both inserting would normally succeed under READ COMMITTED,
-- producing a double charge. Under SERIALIZABLE one is aborted.

BEGIN;

SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;

-- Read: does a completed payment already exist for this member + schedule?
-- Under SERIALIZABLE, if Session B reads the same "false" result
-- and both then insert, PostgreSQL detects the cycle and aborts one.
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
            t.status = 'completed'
    ) AS already_paid;

-- If already_paid = false → proceed with payment INSERT (see transactions.sql S1).
-- If already_paid = true  → skip; this is a duplicate attempt.

COMMIT;

-- ─────────────────────────────────────────────────────────────
-- SELECT FOR UPDATE: Pessimistic Row Locking
-- ─────────────────────────────────────────────────────────────
-- The practical mechanism Kowojọ uses on every dues payment.
-- Acquires an exclusive row-level lock immediately rather than
-- relying on PostgreSQL to detect a serialization anomaly after
-- the fact. Concurrent sessions queue at the lock; only one
-- proceeds at a time — no retries required on the application side.

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

-- Session B running the identical SELECT FOR UPDATE on this row
-- will BLOCK at this point until Session A issues COMMIT or ROLLBACK.
-- Once unblocked, Session B re-reads the row and detects that
-- Session A already recorded a completed payment — duplicate blocked.

ROLLBACK;
-- Release the lock; demonstration only

-- ─────────────────────────────────────────────────────────────
-- CONCURRENT SESSION TIMELINE
-- ─────────────────────────────────────────────────────────────
-- Two members simultaneously attempt to pay the same dues schedule.
-- SELECT FOR UPDATE on the member row serialises the two sessions.
--
-- [Session A — arrives first]
--   T1  BEGIN;
--   T2  SELECT id FROM members WHERE id = '<member>' FOR UPDATE;
--           → Lock acquired on member row
--   T3  INSERT INTO transactions (...) VALUES (..., 'completed', ...);
--   T4  INSERT INTO audit_logs   (...) VALUES (...);
--   T5  COMMIT;
--           → Lock released; payment and audit log are durable
--
-- [Session B — concurrent duplicate attempt]
--   T2  BEGIN;
--   T3  SELECT id FROM members WHERE id = '<member>' FOR UPDATE;
--           → BLOCKS — waits for Session A's lock
--       (Session A commits at T5)
--           → Session B unblocks
--   T6  Query transactions WHERE member_id = '<member>'
--         AND dues_schedule_id = '<schedule>' AND status = 'completed';
--           → Returns Session A's row
--   T7  Duplicate detected → ROLLBACK;
--
-- Result: exactly one payment row; no double charge.
--
-- ─────────────────────────────────────────────────────────────
-- ISOLATION LEVEL SUMMARY
-- ─────────────────────────────────────────────────────────────
--
-- Hazard               | READ COMMITTED | REPEATABLE READ | SERIALIZABLE
-- ---------------------|----------------|-----------------|-------------
-- Dirty read           | Prevented      | Prevented       | Prevented
-- Non-repeatable read  | Possible       | Prevented       | Prevented
-- Phantom read         | Possible       | Prevented*      | Prevented
-- Lost update          | Possible       | Prevented*      | Prevented
-- Serialization anomaly| Possible       | Possible        | Prevented
--
-- * PostgreSQL's REPEATABLE READ prevents phantoms and lost updates
--   beyond what the SQL standard requires for that level.
--
-- Kowojọ defaults: READ COMMITTED for reads; REPEATABLE READ for
-- financial reports; SELECT FOR UPDATE (not SERIALIZABLE) for
-- payment writes — lower overhead, no retry loop required.