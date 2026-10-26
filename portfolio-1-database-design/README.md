# Portfolio 1 — Database Design and Modelling

**Case Study:** Kowojọ: a Multi-tenant Dues Management Platform
**Database:** PostgreSQL
**ORM:** SQLAlchemy 2.0

---

## What This Portfolio Demonstrates

- A fully normalised relational schema for a multi-tenant financial platform
- Entity identification, relationship mapping, and constraint design
- Implementation of the schema as a runnable Python/SQLAlchemy package
- ER diagram generated from the live database (via DBeaver)
- Hand-authored Postgres DDL script (`schema.sql`) demonstrating understanding of the SQL that underlies the ORM abstraction

---

## Entities and Their Purpose

| Table | Purpose |
| --- | --- |
| `tenants` | Organisations registered on the platform |
| `users` | Login identities — authentication, personal info, and platform role |
| `designations` | Organisation-defined titles for members (e.g. Chairman, Secretary) |
| `members` | A user's membership record within a specific organisation |
| `dues_schedules` | Payment rules defined by an organisation |
| `transactions` | Payment records — every dues payment attempt |
| `audit_logs` | Append-only log of every significant system event |

---

## Multi-tenancy Approach

Kowojọ uses a shared schema with `tenant_id` column strategy.
All tenant data lives in shared tables, and every record is scoped
to a tenant via a `tenant_id` foreign key. This approach:

- Keeps the schema simple and transparent
- Allows cross-tenant reporting at the platform level (for platform admins)
- Is easy to enforce through application-level query filtering

---

## Access Control Design (RBAC)

Platform-level access is controlled by a `RoleEnum` column directly
on the `users` table. The three fixed roles are:

| Role | Description |
| --- | --- |
| `platform_admin` | Full access across all tenants |
| `org_admin` | Manages one organisation's members, dues, and transactions |
| `member` | Can view own data and make payments |

These roles are enforced at the database level via a PostgreSQL
Enum type (`role_enum`), meaning the database itself rejects any
value outside these three. This is intentionally stricter than a
plain string column.

### Designations vs Roles — an important distinction

The `roles` concept controls **what a user can do** (access control).
The `designations` table controls **what a member is called** within
their organisation (display metadata). These are deliberately
separated:

- An org's "Chairman" and "Financial Secretary" are designations —
  they carry no special platform permissions
- Whether someone can approve new members or view all transactions
  is determined by their platform role (`org_admin` vs `member`)

---

## NoSQL Note

Organisation-specific member profile data (e.g. matric numbers,
licence numbers, custom fields) is intentionally **not** stored here.
It will live in MongoDB, linked to the `members` table via `member.id`.
See Portfolio 4 for the NoSQL model.

---

## How to Run the Python Package for the schema

### 1. Set up a virtual environment

```bash
python -m venv venv
venv\Scripts\activate
pip install -r requirements.txt
```

### 2. Configure your database connection

```bash
cp .env.example .env
# Edit .env and fill in your PostgreSQL credentials
```

Your `.env` should look like:
`DATABASE_URL=postgresql://your_user:your_password@localhost:5432/kowojo_db`

### 3. Create the database in PostgreSQL (if it doesn't exist)

```sql
CREATE DATABASE kowojo_db;
```

### 4. Run the table creation script

```bash
python -m kowojo_db.init_db
```

You should see all table names printed on success.

---

## DDL Script

`schema.sql` contains the full PostgreSQL DDL for the Kowojọ schema,
hand-authored to match the SQLAlchemy models exactly.

It can be run independently of the Python package:

    psql -U your_user -d kowojo_db -f schema.sql

This script serves as human-readable documentation of the schema and demonstrates understanding of the raw SQL beneath the ORM layer.
A commented-out teardown block at the top of the file allows the database to be reset cleanly during development.


## Schema Design Notes

### Why UUIDs instead of integer IDs?

Integer IDs are sequential and predictable — in a multi-tenant system,
a member with id=1 in one organisation could be confused with id=1
in another. UUIDs are globally unique and make cross-tenant data
handling safer.

### Why is `amount` stored on `transactions` and not just referenced from `dues_schedules`?

If a dues amount changes next year, historical payment records must still reflect what was actually paid at the time. Storing the amount on the transaction row preserves this historical accuracy.

### Why is `tenant_id` on `transactions` (denormalisation)?

It is technically derivable via `transaction → member → tenant`.
However, almost every financial query will be scoped by tenant.
Storing `tenant_id` directly on transactions avoids a join on every such query.

### Why JSONB for `gateway_response` on transactions?

Payment gateway responses (e.g. from Paystack) contain varying
fields depending on the payment channel. JSONB stores this flexibly
without requiring a rigid schema, while still allowing the data to
be queried if needed.

### Why no `updated_at` on `audit_logs`?

Audit logs are append-only by design. A log entry should never be
modified after it is written; that would defeat the purpose of an
audit trail. The absence of `updated_at` enforces this intention
at the model level.

---

## File Structure

```
portfolio-1-database-design/
├── kowojo_db/
│ ├── init.py
│ ├── base.py 
│ ├── database.py 
│ ├── init_db.py 
│ └── models/
│ ├── init.py 
│ ├── tenant.py
│ ├── user.py 
│ ├── designation.py 
│ ├── member.py
│ ├── dues_schedule.py
│ ├── transaction.py
│ └── audit_log.py
├── kowojo_db - ERD.png
├── requirements.txt
├── schema.sql
├── .env.example
└── README.md
```
