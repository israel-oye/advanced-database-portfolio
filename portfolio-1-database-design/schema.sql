-- Kowojọ — Advanced Database Systems Portfolio
-- Portfolio 1: Database Design and Modelling
-- schema.sql — Full DDL for the Kowojọ PostgreSQL schema


-- -----------------------------------------------------------------------------
-- ENUM TYPES
-- Defined before tables because columns reference them by name.


-- Platform-level access roles.
-- Controls what a user is permitted to do on the Kowojọ platform.
CREATE TYPE role_enum AS ENUM (
    'platform_admin',   -- Full access across all tenants
    'org_admin',        -- Manages one organisation's members and dues
    'member'            -- Can view own data and make payments
);

-- Membership lifecycle states.
CREATE TYPE membership_status_enum AS ENUM (
    'pending',      -- Registered but not yet approved
    'active',       -- Fully approved and in good standing
    'suspended',    -- Temporarily restricted
    'expired',      -- Membership period has lapsed
    'inactive'      -- Voluntarily deactivated
);

-- How often a dues schedule recurs.
CREATE TYPE dues_frequency_enum AS ENUM (
    'one_time',
    'monthly',
    'quarterly',
    'biannual',
    'annual'
);

-- Lifecycle states of a payment transaction.
CREATE TYPE transaction_status_enum AS ENUM (
    'pending',      -- Initiated but not yet confirmed by the gateway
    'successful',   -- Confirmed and recorded
    'failed',       -- Payment attempt was unsuccessful
    'reversed'      -- A previously successful payment was reversed
);

-- -----------------------------------------------------------------------------
-- TABLE: tenants
-- The top-level entity. Every other record in the system belongs to a tenant.
-- -----------------------------------------------------------------------------
CREATE TABLE tenants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
    name VARCHAR(255) NOT NULL,
    slug VARCHAR(100) NOT NULL UNIQUE,
    email VARCHAR(255) NOT NULL UNIQUE,
    phone VARCHAR(20),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- slug is used in URLs and lookups — index for fast retrieval
CREATE INDEX idx_tenants_slug ON tenants (slug);

COMMENT ON TABLE tenants IS 'Organisations registered on the Kowojọ platform';

COMMENT ON COLUMN tenants.slug IS 'URL-safe unique identifier for the organisation';

COMMENT ON COLUMN tenants.is_active IS 'Whether the organisation account is currently active';

-- -----------------------------------------------------------------------------
-- TABLE: users
-- Authentication identities. Separated from membership so login credentials
-- remain stable regardless of organisational changes.
-- -----------------------------------------------------------------------------
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
    email VARCHAR(255) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    phone VARCHAR(20),
    role role_enum NOT NULL DEFAULT 'member',
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_users_email ON users (email);

COMMENT ON TABLE users IS 'Login identities for all platform users';

COMMENT ON COLUMN users.password_hash IS 'Hashed password (bcrypt/argon2). Plain text is never stored.';

COMMENT ON COLUMN users.role IS 'Platform-level access role enforced by PostgreSQL enum type';

-- -----------------------------------------------------------------------------
-- TABLE: designations
-- Organisation-defined titles for members (e.g. Chairman, Secretary).
-- These are display labels only — they do not affect platform permissions.
-- Permissions are controlled exclusively by users.role.
-- -----------------------------------------------------------------------------
CREATE TABLE designations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
    tenant_id UUID NOT NULL REFERENCES tenants (id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_designations_tenant_id ON designations (tenant_id);

COMMENT ON TABLE designations IS 'Organisation-defined member titles. Separate from platform roles.';

COMMENT ON COLUMN designations.tenant_id IS 'The organisation that owns this designation';

COMMENT ON COLUMN designations.name IS 'Title as defined by the organisation e.g. Chairman, Financial Secretary';

-- -----------------------------------------------------------------------------
-- TABLE: members
-- A user's membership record within a specific organisation.
-- This is the bridge between users and tenants.
--
-- Note: Organisation-specific profile fields (matric number, licence number,
-- custom attributes) are stored in MongoDB, linked via this record's id.
-- See Portfolio 4 for the NoSQL model.
-- -----------------------------------------------------------------------------
CREATE TABLE members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
    tenant_id UUID NOT NULL REFERENCES tenants (id) ON DELETE CASCADE,
    user_id UUID NOT NULL UNIQUE REFERENCES users (id) ON DELETE CASCADE,
    designation_id UUID REFERENCES designations (id) ON DELETE SET NULL,
    membership_number VARCHAR(50) NOT NULL,
    status membership_status_enum NOT NULL DEFAULT 'pending',
    joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    approved_by UUID REFERENCES users (id) ON DELETE SET NULL,
    approved_at TIMESTAMPTZ
);

CREATE INDEX idx_members_tenant_id ON members (tenant_id);

CREATE INDEX idx_members_user_id ON members (user_id);

-- Membership number must be unique within an organisation (not platform-wide)
CREATE UNIQUE INDEX idx_members_tenant_membership_number ON members (tenant_id, membership_number);

COMMENT ON TABLE members IS 'Membership records linking users to organisations';

COMMENT ON COLUMN members.user_id IS 'Unique — one user can belong to one organisation at a time';

COMMENT ON COLUMN members.membership_number IS 'Organisation-scoped identifier e.g. OSAA-00123';

COMMENT ON COLUMN members.approved_by IS 'The org_admin user who approved this membership';

-- -----------------------------------------------------------------------------
-- TABLE: dues_schedules
-- Payment rules defined by an organisation.
-- An organisation may have multiple active schedules simultaneously.
-- -----------------------------------------------------------------------------
CREATE TABLE dues_schedules (
    id          UUID                    PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id   UUID                    NOT NULL REFERENCES tenants (id) ON DELETE CASCADE,
    name        VARCHAR(255)            NOT NULL,
    description VARCHAR(500),
    amount      NUMERIC(10, 2)          NOT NULL,
    currency    VARCHAR(3)              NOT NULL DEFAULT 'NGN',
    frequency   dues_frequency_enum     NOT NULL,
    start_date  DATE                    NOT NULL,
    end_date    DATE,
    is_active   BOOLEAN                 NOT NULL DEFAULT TRUE,
    created_at  TIMESTAMPTZ             NOT NULL DEFAULT NOW(),

-- end_date must be after start_date if provided
CONSTRAINT chk_dues_schedule_dates CHECK (
    end_date IS NULL
    OR end_date > start_date
),

-- Amount must be a positive value
CONSTRAINT chk_dues_schedule_amount CHECK (amount > 0) );

CREATE INDEX idx_dues_schedules_tenant_id ON dues_schedules (tenant_id);

COMMENT ON TABLE dues_schedules IS 'Dues payment rules created by organisations';

COMMENT ON COLUMN dues_schedules.amount IS 'NUMERIC(10,2) used for exact decimal precision — never FLOAT for money';

COMMENT ON COLUMN dues_schedules.currency IS 'ISO 4217 currency code e.g. NGN, USD';

COMMENT ON COLUMN dues_schedules.end_date IS 'NULL means the schedule is open-ended';

-- -----------------------------------------------------------------------------
-- TABLE: transactions
-- Every payment attempt made by a member.
-- The financial core of the system — rows are never deleted.
--
-- Design notes:
--   - tenant_id is denormalised here for fast tenant-scoped queries
--   - amount is stored independently of dues_schedule.amount to
--     preserve the historical value paid at the time of the transaction
--   - gateway_response stores the raw JSON from the payment provider
-- -----------------------------------------------------------------------------

CREATE TABLE transactions (
    id                  UUID                        PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id           UUID                        NOT NULL REFERENCES tenants       (id) ON DELETE RESTRICT,
    member_id           UUID                        NOT NULL REFERENCES members        (id) ON DELETE RESTRICT,
    dues_schedule_id    UUID                        NOT NULL REFERENCES dues_schedules (id) ON DELETE RESTRICT,
    amount              NUMERIC(10, 2)              NOT NULL,
    currency            VARCHAR(3)                  NOT NULL DEFAULT 'NGN',
    status              transaction_status_enum     NOT NULL DEFAULT 'pending',
    payment_reference   VARCHAR(255)                UNIQUE,
    payment_channel     VARCHAR(50),
    paid_at             TIMESTAMPTZ,
    gateway_response    JSONB,
    created_at          TIMESTAMPTZ                 NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ                 NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_transaction_amount
        CHECK (amount > 0),

-- paid_at should only be set when the transaction is successful or reversed
CONSTRAINT chk_transaction_paid_at
        CHECK (
            (status IN ('successful', 'reversed') AND paid_at IS NOT NULL)
            OR status IN ('pending', 'failed')
        )
);

CREATE INDEX idx_transactions_tenant_id ON transactions (tenant_id);

CREATE INDEX idx_transactions_member_id ON transactions (member_id);

CREATE INDEX idx_transactions_status ON transactions (status);

CREATE INDEX idx_transactions_payment_reference ON transactions (payment_reference);

COMMENT ON TABLE transactions IS 'All payment attempts — never deleted, only status-updated';

COMMENT ON COLUMN transactions.tenant_id IS 'Denormalised for fast tenant-scoped queries without joins';

COMMENT ON COLUMN transactions.amount IS 'Amount at time of payment — independent of current dues_schedule amount';

COMMENT ON COLUMN transactions.payment_reference IS 'Unique reference from the payment gateway (e.g. Paystack)';

COMMENT ON COLUMN transactions.gateway_response IS 'Raw JSONB payload from the payment gateway';

-- -----------------------------------------------------------------------------
-- TABLE: audit_logs
-- Append-only record of every significant event in the system.
-- Rows are NEVER updated or deleted — this preserves a trustworthy history.
-- -----------------------------------------------------------------------------
CREATE TABLE audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
    tenant_id UUID NOT NULL REFERENCES tenants (id) ON DELETE RESTRICT,
    actor_id UUID REFERENCES users (id) ON DELETE SET NULL,
    action VARCHAR(100) NOT NULL,
    target_type VARCHAR(50) NOT NULL,
    target_id VARCHAR(255) NOT NULL,
    description TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    -- No updated_at — audit logs are append-only by design
);

CREATE INDEX idx_audit_logs_tenant_id ON audit_logs (tenant_id);

CREATE INDEX idx_audit_logs_action ON audit_logs (action);

CREATE INDEX idx_audit_logs_actor_id ON audit_logs (actor_id);

COMMENT ON TABLE audit_logs IS 'Append-only event log. Never update or delete rows.';

COMMENT ON COLUMN audit_logs.actor_id IS 'The user who triggered the event. NULL for system-generated events.';

COMMENT ON COLUMN audit_logs.action IS 'Dot-namespaced event name e.g. payment.reversed, member.suspended';

COMMENT ON COLUMN audit_logs.target_type IS 'The entity type affected e.g. transaction, member';

COMMENT ON COLUMN audit_logs.target_id IS 'Primary key of the affected record';