-- Kowojọ — Portfolio 2: Query Processing and Optimisation
-- queries.sql — Core SQL queries for the Kowojọ platform

-- Run seed.sql first to populate the database before executing these queries.
--
-- Usage:
--     psql -U your_user -d kowojo_db -f queries.sql
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Q1: All active members for a specific organisation
-- -----------------------------------------------------------------------------
-- Retrieves the full name, membership number, designation, and join date
-- for every active member within the Osun State Alumni Association.
-- This is the most common lookup an org_admin performs.
-- -----------------------------------------------------------------------------
SELECT
    u.first_name,
    u.last_name,
    m.membership_number,
    d.name AS designation,
    m.joined_at::DATE AS joined_date
FROM
    members m
    JOIN users u ON u.id = m.user_id
    LEFT JOIN designations d ON d.id = m.designation_id
WHERE
    m.tenant_id = 'a0000000-0000-0000-0000-000000000001'
    AND m.status = 'active'
ORDER BY m.joined_at;

-- -----------------------------------------------------------------------------
-- Q2: Total dues collected per organisation
-- -----------------------------------------------------------------------------
-- Aggregates all successful transaction amounts grouped by tenant.
-- Gives the platform admin a high-level view of collection across the system.
-- -----------------------------------------------------------------------------
SELECT
    t.name AS organisation,
    COUNT(tx.id) AS total_payments,
    SUM(tx.amount) AS total_collected,
    tx.currency
FROM transactions tx
    JOIN tenants t ON t.id = tx.tenant_id
WHERE
    tx.status = 'successful'
GROUP BY
    t.id,
    t.name,
    tx.currency
ORDER BY total_collected DESC;

-- -----------------------------------------------------------------------------
-- Q3: Full payment history for a specific member
-- -----------------------------------------------------------------------------
-- Retrieves every transaction for a given member, showing which dues
-- schedule it was for, the amount paid, status, and payment channel.
-- Typical use: a member viewing their own payment history.
-- -----------------------------------------------------------------------------
SELECT ds.name AS dues_schedule, tx.amount, tx.currency, tx.status, tx.payment_channel, tx.payment_reference, tx.paid_at
FROM
    transactions tx
    JOIN dues_schedules ds ON ds.id = tx.dues_schedule_id
WHERE
    tx.member_id = 'd0000000-0000-0000-0000-000000000001'
ORDER BY tx.created_at DESC;

-- -----------------------------------------------------------------------------
-- Q4: Members who have never successfully paid for a specific dues schedule
-- -----------------------------------------------------------------------------
-- Uses a LEFT JOIN with a NULL check to find members who have no
-- successful transaction against the Annual Dues 2024 schedule.
-- Useful for identifying who to chase for payment. Members who have pending payments will not be included
-- This query is a good candidate for optimisation (see optimisation.sql).
-- -----------------------------------------------------------------------------
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

-- -----------------------------------------------------------------------------
-- Q5: Top paying members in an organisation (by total amount paid)
-- -----------------------------------------------------------------------------
-- Ranks members by their total successful payments.
-- Useful for identifying the most engaged/up-to-date members.
-- -----------------------------------------------------------------------------
SELECT
    u.first_name,
    u.last_name,
    m.membership_number,
    COUNT(tx.id) AS payment_count,
    SUM(tx.amount) AS total_paid
FROM
    transactions tx
    JOIN members m ON m.id = tx.member_id
    JOIN users u ON u.id = m.user_id
WHERE
    tx.tenant_id = 'a0000000-0000-0000-0000-000000000001'
    AND tx.status = 'successful'
GROUP BY
    u.first_name,
    u.last_name,
    m.membership_number
ORDER BY total_paid DESC
LIMIT 5;

-- -----------------------------------------------------------------------------
-- Q6: Transaction volume and revenue per month for a tenant
-- -----------------------------------------------------------------------------
-- Uses DATE_TRUNC to group transactions by calendar month.
-- DATE_TRUNC('month', paid_at) rounds a timestamp down to the first
-- of its month — this is how PostgreSQL handles time-based grouping.
-- Good candidate for optimisation since it scans the paid_at column.
-- -----------------------------------------------------------------------------
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

-- -----------------------------------------------------------------------------
-- Q7: Members still pending approval after 30 days
-- -----------------------------------------------------------------------------
-- Flags members who registered more than 30 days ago but have not
-- yet been approved. Helps admins catch neglected applications.
-- NOW() returns the current timestamp in PostgreSQL.
-- INTERVAL '30 days' is PostgreSQL's way of expressing a time duration.
-- -----------------------------------------------------------------------------
SELECT
    u.first_name,
    u.last_name,
    u.email,
    m.membership_number,
    m.joined_at::DATE AS applied_on,
    (NOW() - m.joined_at)::TEXT AS time_waiting
FROM members m
    JOIN users u ON u.id = m.user_id
WHERE
    m.status = 'pending'
    AND m.joined_at < NOW() - INTERVAL '30 days'
ORDER BY m.joined_at;

-- -----------------------------------------------------------------------------
-- Q8: Full audit trail for a specific transaction
-- -----------------------------------------------------------------------------
-- Retrieves all audit log entries related to a given transaction ID.
-- Includes the name of the actor (admin) who triggered each event,
-- or flags it as system-generated if actor_id is NULL.
-- -----------------------------------------------------------------------------
SELECT al.action, al.description, COALESCE(
        u.first_name || ' ' || u.last_name, 'System'
    ) AS performed_by, al.created_at
FROM audit_logs al
    LEFT JOIN users u ON u.id = al.actor_id
WHERE
    al.target_type = 'transaction'
    AND al.target_id = 'f0000000-0000-0000-0000-000000000009'
ORDER BY al.created_at;