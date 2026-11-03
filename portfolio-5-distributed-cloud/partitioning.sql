
-- STEP 1: Creating the partitioned parent table
-- PARTITION BY LIST (tenant_id) tells PostgreSQL that rows are
-- routed to child partitions based on an exact tenant_id value.


DROP TABLE IF EXISTS transactions_partitioned CASCADE;

CREATE TABLE transactions_partitioned (
    id UUID NOT NULL,
    tenant_id UUID NOT NULL,
    member_id UUID NOT NULL,
    dues_schedule_id UUID NOT NULL,
    amount NUMERIC(10, 2) NOT NULL,
    currency VARCHAR(3) NOT NULL DEFAULT 'NGN',
    status transaction_status_enum NOT NULL DEFAULT 'pending',
    payment_reference VARCHAR(255),
    payment_channel VARCHAR(50),
    paid_at TIMESTAMPTZ,
    gateway_response JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
)
PARTITION BY
    LIST (tenant_id);


-- STEP 2: Create one partition per tenant
-- Each partition is a real physical table. PostgreSQL automatically
-- routes INSERTs and filters SELECTs to the correct partition.
-- In a distributed system, each of these would live on a
-- separate database node: one per tenant tier.

CREATE TABLE transactions_tenant_osaa PARTITION OF transactions_partitioned FOR
VALUES
    IN (
        'a0000000-0000-0000-0000-000000000001'
    );

COMMENT ON TABLE transactions_tenant_osaa IS 'Partition: Osun State Alumni Association transactions';

CREATE TABLE transactions_tenant_ifem PARTITION OF transactions_partitioned FOR
VALUES
    IN (
        'a0000000-0000-0000-0000-000000000002'
    );

COMMENT ON TABLE transactions_tenant_ifem IS 'Partition: Ife Medical Cooperative Society transactions';

CREATE TABLE transactions_tenant_ltfc PARTITION OF transactions_partitioned FOR
VALUES
    IN (
        'a0000000-0000-0000-0000-000000000003'
    );

COMMENT ON TABLE transactions_tenant_ltfc IS 'Partition: Lagos Tech Founders Circle transactions';

-- STEP 3: Copy seed data from the original transactions table
-- PostgreSQL routes each row to the correct child partition
-- automatically based on its tenant_id value.

INSERT INTO
    transactions_partitioned
SELECT
    id,
    tenant_id,
    member_id,
    dues_schedule_id,
    amount,
    currency,
    status,
    payment_reference,
    payment_channel,
    paid_at,
    gateway_response,
    created_at,
    updated_at
FROM transactions;

-- STEP 4: Verifying row distribution across partitions
-- Each tenant's rows appear only in their own partition.

SELECT 'transactions_partitioned (total)' AS partition_name, COUNT(*) AS row_count
FROM transactions_partitioned
UNION ALL
SELECT 'transactions_tenant_osaa', COUNT(*)
FROM transactions_tenant_osaa
UNION ALL
SELECT 'transactions_tenant_ifem', COUNT(*)
FROM transactions_tenant_ifem
UNION ALL
SELECT 'transactions_tenant_ltfc', COUNT(*)
FROM transactions_tenant_ltfc
ORDER BY partition_name;

-- STEP 5: This demonstrates partition pruning
-- When a query filters on tenant_id, PostgreSQL's query planner
-- eliminates irrelevant partitions before execution (it only
-- reads the one partition that can contain matching rows.)
-- This is called partition pruning.

EXPLAIN
SELECT id, amount, status, paid_at
FROM transactions_partitioned
WHERE
    tenant_id = 'a0000000-0000-0000-0000-000000000001';

-- In a distributed database, partition pruning translates directly
-- to node pruning: only the node holding that tenant's shard
-- receives the query. The other nodes are never contacted.