-- Kowojọ — Portfolio 3: ACID Transaction Scenarios
-- MIT 8103 Advanced Database Systems · MIVA Open University
-- ============================================================
-- This script demonstrates the four ACID properties (Atomicity,
-- Consistency, Isolation, and Durability) using PostgreSQL
-- transactions in a dues-payment system.
--
-- It assumes that the database schema from Portfolio 1 and the
-- sample data from Portfolio 2 have already been loaded.
-- ============================================================


-- ============================================================
-- SCENARIO 1: Successful Dues Payment
-- Properties demonstrated: Atomicity, Durability and row locking
-- ============================================================
-- In this scenario, a member makes payment for their annual dues.
-- Two records need to be created: the payment transaction and
-- its corresponding audit log entry.
--
-- Both operations should succeed together. If something goes
-- wrong before the transaction is committed, PostgreSQL rolls
-- back the changes so that only a complete transaction is saved.
-- This is where Atomicity comes in.
--
-- The SELECT FOR UPDATE statement is also used to lock the
-- selected member's row. This prevents another transaction from
-- modifying or processing the same member's record until the
-- current transaction is completed.

BEGIN;

-- Step 1: Lock the selected member's record.
SELECT id
FROM members
WHERE
    id = (
        SELECT m.id
        FROM members m
            JOIN dues_schedules ds ON ds.tenant_id = m.tenant_id
        WHERE
          m.status = 'active'
          AND ds.is_active
          AND NOT EXISTS (
              SELECT 1
              FROM transactions t
              WHERE
                  t.member_id = m.id
                  AND t.dues_schedule_id = ds.id
          )
        ORDER BY m.id, ds.id
        LIMIT 1
    )
FOR UPDATE;

-- Step 2: Create the payment record and its audit log entry.
-- The CTE (Common Table expression) allows both operations to be performed as part of
-- the same transaction, so they are committed together.
WITH
    target AS (
        SELECT
            m.id AS member_id,
            m.user_id AS user_id,
            m.tenant_id AS tenant_id,
            ds.id AS schedule_id,
            ds.amount AS amount
        FROM members m
            JOIN dues_schedules ds ON ds.tenant_id = m.tenant_id
        WHERE
            m.status = 'active'
            AND ds.is_active
            AND NOT EXISTS (
                SELECT 1
                FROM transactions t
                WHERE
                    t.member_id = m.id
                    AND t.dues_schedule_id = ds.id
            )
        ORDER BY m.id, ds.id
        LIMIT 1
    ),
    new_txn AS (
        INSERT INTO
            transactions (
                id,
                tenant_id,
                member_id,
                dues_schedule_id,
                amount,
                currency,
                status,
                payment_reference,
                paid_at
            )
        SELECT
            gen_random_uuid (),
            t.tenant_id,
            t.member_id,
            t.schedule_id,
            t.amount,
            'NGN',
            'successful',
            'PSK-P3-S1-001',
            NOW()
        FROM target t
        RETURNING
            id,
            tenant_id
    )
INSERT INTO
    audit_logs (
        id,
        tenant_id,
        actor_id,
        action,
        target_type,
        target_id,
        description
    )
SELECT gen_random_uuid (), n.tenant_id, t.user_id, 'payment.successful', 'transaction', n.id::TEXT, 'Dues payment completed; reference PSK-P3-S1-001'
FROM new_txn n
    CROSS JOIN target t;

COMMIT;

-- At this point, both records have been saved successfully.
-- The row lock is also released after the transaction commits.


-- ============================================================
-- SCENARIO 2: Preventing Duplicate Payments
-- Property demonstrated: Consistency
-- ============================================================
-- Here, we check whether the member has already paid for the
-- selected dues schedule before attempting to record another
-- payment.
--
-- If a successful payment already exists, the script raises
-- an exception instead of inserting another transaction.
-- This helps prevent the same member from being charged twice
-- for the same dues schedule.
--
-- The exception also causes the current PL/pgSQL block to
-- roll back its changes, ensuring that an unsuccessful attempt
-- does not leave incomplete data in the database.

DO $$
DECLARE
  v_member_id   UUID;
  v_user_id     UUID;
  v_tenant_id   UUID;
  v_schedule_id UUID;
  v_amount      NUMERIC;
  v_duplicate   UUID;
BEGIN
  -- Get the member and dues schedule used in Scenario 1.
  SELECT t.member_id, m.user_id, t.tenant_id, t.dues_schedule_id, t.amount
  INTO   v_member_id, v_user_id, v_tenant_id, v_schedule_id, v_amount
  FROM   transactions t
  JOIN   members m ON m.id = t.member_id
  WHERE  t.payment_reference = 'PSK-P3-S1-001';

  -- Check whether a successful payment already exists.
  SELECT id INTO v_duplicate
  FROM   transactions
  WHERE  member_id        = v_member_id
    AND  dues_schedule_id = v_schedule_id
    AND  status           = 'successful'
  LIMIT  1;

  IF v_duplicate IS NOT NULL THEN
    -- A payment already exists, so stop the operation here.
    RAISE EXCEPTION
      'DUPLICATE_PAYMENT — member % already has a successful payment (txn: %) for schedule %',
      v_member_id, v_duplicate, v_schedule_id;
  END IF;

  -- If no previous payment is found, proceed with the INSERT.
  INSERT INTO transactions (
    id, tenant_id, member_id, dues_schedule_id,
    amount, currency, status, payment_reference, paid_at
  ) VALUES (
    gen_random_uuid(), v_tenant_id, v_member_id, v_schedule_id,
    v_amount, 'NGN', 'successful', 'PSK-P3-S2-001', NOW()
  );

EXCEPTION
  WHEN OTHERS THEN
    -- Catch the exception and display a message explaining why
    -- the payment was not processed.
    RAISE NOTICE '[S2 BLOCKED] Duplicate payment prevented: %', SQLERRM;
END;
$$;


-- ============================================================
-- SCENARIO 3: SAVEPOINT — Recovering from a Partial Failure
-- Property demonstrated: Partial rollback using SAVEPOINT
-- ============================================================
-- This scenario shows what happens when the payment record is
-- created successfully but an error occurs while writing the
-- corresponding audit log.
--
-- The first audit log INSERT is deliberately made to fail by
-- passing NULL for target_type, which violates the NOT NULL
-- constraint on that column.
--
-- Instead of rolling back the entire operation, we use a nested
-- BEGIN...EXCEPTION block. PostgreSQL uses an implicit savepoint
-- for this block, allowing the failed operation to be rolled back
-- without affecting the payment record already created.
--
-- A second audit log entry is then inserted with a valid
-- target_type. This allows the payment and its fallback audit
-- record to be saved when the outer block completes successfully.

DO $$
DECLARE
  v_txn_id      UUID := gen_random_uuid();
  v_member_id   UUID;
  v_user_id     UUID;
  v_tenant_id   UUID;
  v_schedule_id UUID;
  v_amount      NUMERIC;
BEGIN
  SELECT m.id, m.user_id, m.tenant_id, ds.id, ds.amount
  INTO   v_member_id, v_user_id, v_tenant_id, v_schedule_id, v_amount
  FROM   members m
  JOIN   dues_schedules ds ON ds.tenant_id = m.tenant_id
  WHERE
    m.status = 'active'
    AND ds.is_active
    AND NOT EXISTS (
        SELECT 1
        FROM transactions t
        WHERE
            t.member_id = m.id
            AND t.dues_schedule_id = ds.id
    )
  ORDER  BY m.id, ds.id
  LIMIT  1;

  -- Step 1: Insert the payment record.
  INSERT INTO transactions (
    id, tenant_id, member_id, dues_schedule_id,
    amount, currency, status, payment_reference, paid_at
  ) VALUES (
    v_txn_id, v_tenant_id, v_member_id, v_schedule_id,
    v_amount, 'NGN', 'successful', 'PSK-P3-S3-001', NOW()
  );

  -- Step 2: Try to create the normal audit log entry.
  -- The nested BEGIN block acts as a savepoint. If the INSERT
  -- fails, PostgreSQL rolls back this block without undoing
  -- the payment record created in Step 1.
  BEGIN
    INSERT INTO audit_logs (id, tenant_id, actor_id, action, target_type, target_id, description)
    VALUES (
      gen_random_uuid(), v_tenant_id,
      v_user_id,
      'payment.successful',
      NULL,             -- Deliberately causes a NOT NULL constraint violation on target_type
      v_txn_id::TEXT,
      'Dues payment recorded'
    );

  EXCEPTION
    WHEN not_null_violation THEN
      -- The first audit log INSERT has failed, but the payment
      -- record is still intact because of the savepoint.
      RAISE NOTICE '[S3] Audit INSERT failed (null target_type) — rolling back to savepoint';

      -- Step 3: Insert another audit log entry with a valid
      -- target_type so that the payment is still properly logged.
      INSERT INTO audit_logs (id, tenant_id, actor_id, action, target_type, target_id, description)
      VALUES (
        gen_random_uuid(), v_tenant_id,
        v_user_id,
        'payment.audit_fallback',
        'transaction',    -- Use a known value for target_type instead of NULL
        v_txn_id::TEXT,
        'Fallback audit: target_type was unavailable from event classifier at payment time'
      );
  END;

  RAISE NOTICE '[S3] Complete — payment % committed with fallback audit entry', v_txn_id;
END;
$$;
