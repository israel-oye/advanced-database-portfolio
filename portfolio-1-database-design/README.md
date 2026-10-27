# Portfolio 1: Database Design and Modelling

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
| `users` | Login identities: authentication, personal info, and platform role |
| `designations` | Organisation-defined titles for members (e.g. Chairman, Secretary) |
| `members` | A user's membership record within a specific organisation |
| `dues_schedules` | Payment rules defined by an organisation |
| `transactions` | Payment records: every dues payment attempt |
| `audit_logs` | Append-only log of every significant system event |

---

## Normalisation

Before settling on the final schema, I walked through the standard
normal forms to make sure the design was clean and defensible.
Here is how the Kowojọ schema holds up.

### First Normal Form (1NF)

A table is in 1NF when every column holds a single, indivisible value
and every row is uniquely identified.

Every table in this schema uses a UUID primary key, so uniqueness is
guaranteed. No column stores multiple values in one field. For
example, a member's designation is not stored as a comma-separated
string inside the `members` table; it gets its own `designations`
table with a foreign key reference. The `gateway_response` column on
`transactions` stores JSONB, which might look like a violation at
first glance, but it is treated as a single opaque value from an
external payment gateway — not a repeating group of structured
data that belongs in its own table.

### Second Normal Form (2NF)

2NF requires that every non-key column depends on the whole primary key, not just part of it. This is mainly relevant when a table has a
composite primary key (one made of multiple columns combined).

Every table in this schema uses a single-column UUID primary key, so
there is no possibility of a partial dependency. 2NF is satisfied
across the board by design.

### Third Normal Form (3NF)

3NF requires that no non-key column depends on another non-key column; only on the primary key directly.

The clearest design decision this drove was separating `users` from
`members`. A user's name and email belong to their login identity,
they don't depend on which organisation they belong to. If I had
stored membership details and login details in one table, changing
an organisation-specific field would risk touching authentication
data, and vice versa. Keeping them separate means each table's
columns depend only on their own primary key.

The `designations` table came from the same reasoning. I initially
considered putting a `designation_name` column directly on `members`,
but that would mean the name of a designation (e.g, "Financial
Secretary") would depend on the designation concept, not on the
member's own primary key. Pulling it into its own table fixed that
and also means an organisation can rename a designation in one place
without updating every member row.

### A Deliberate Denormalisation

The one place I knowingly stepped back from strict 3NF is the
`tenant_id` column on the `transactions` table. Technically this is
derivable by joining through `members`, so it is redundant. I kept
it because almost every financial query in the system will be scoped
to a tenant, and removing a join on that critical path is a worthwhile
trade-off. I am aware it introduces a maintenance responsibility; if a member ever moved between tenants (which the current design does
not support anyway), this column would need updating too. The
trade-off is acceptable given the query performance benefit and the
constraint that tenant assignment is immutable in this system.

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

### Designations vs Roles

The `roles` concept controls **what a user can do** (access control).
The `designations` table controls **what a member is called** within
their organisation (display metadata). These are deliberately
separated:

- An org's "Chairman" and "Financial Secretary" are designations (they carry no special platform permissions)
- Whether someone can approve new members or view all transactions
  is determined by their platform role (`org_admin` vs `member`)

---

## NoSQL Note

Organisation-specific member profile data (e.g. matric numbers,
licence numbers, custom fields) is intentionally not stored here.
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

Integer IDs are sequential and predictable; in a multi-tenant system,
a member with id=1 in one organisation could be confused with id=1
in another. UUIDs are globally unique and make cross-tenant data
handling safer.

### Why is `amount` stored on `transactions` and not just referenced from `dues_schedules`?

If a dues amount changes next year, historical payment records must still reflect what was actually paid at the time. Storing the amount on the transaction row preserves this historical accuracy.

### Why is `tenant_id` on `transactions` (denormalisation)?

As explained in the normalisatioon sectioion above, tenant_id is technically derivable via `transaction → member → tenant`.
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
├── teardown.sql
├── .env.example
└── README.md
```
