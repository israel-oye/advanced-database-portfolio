# Portfolio 2 — Query Processing and Optimisation

**Case Study:** Kowojọ — Multi-tenant Dues Management Platform
**Database:** PostgreSQL

---

## Overview

This portfolio demonstrates SQL query design and performance analysis
against the Kowojọ database. It covers queries for common platform
operations, execution plan analysis using `EXPLAIN ANALYZE`, and
index-based optimisation with documented before/after results.

---

## Files

| File | Purpose |
| --- | --- |
| `seed.sql` | Populates the database with 3 tenants, 24 members, 6 dues schedules, and 28 transactions |
| `queries.sql` | Eight SQL queries covering core platform operations |
| `optimisation.sql` | EXPLAIN ANALYZE runs and index creation for two candidate queries |
| `screenshots/` | Query result evidence from DBeaver |

---

## Queries

| # | Query | Concepts Used |
| --- | --- | --- |
| Q1 | Active members for a specific organisation | Filtered SELECT, multi-table JOIN |
| Q2 | Total dues collected per organisation | GROUP BY, SUM aggregation |
| Q3 | Full payment history for a specific member | Multi-table JOIN, ORDER BY |
| Q4 | Members who have never paid a specific dues schedule | LEFT JOIN, NULL check (anti-join pattern) |
| Q5 | Top paying members in an organisation | GROUP BY, ORDER BY, LIMIT |
| Q6 | Monthly transaction volume for a tenant | DATE_TRUNC time-based grouping |
| Q7 | Members pending approval for over 30 days | Date arithmetic, INTERVAL |
| Q8 | Full audit trail for a specific transaction | COALESCE for nullable actor handling |

Query result screenshots are in the `screenshots/` folder for Q1, Q2, Q3, Q4, and Q8.

---

## Optimisation Analysis

Two queries were selected as optimisation candidates based on their
join complexity and filter patterns against the transactions table.

### Candidate 1: Q4 (Members with no payment for a dues schedule)

**Index created:**

```sql
CREATE INDEX idx_transactions_member_schedule
    ON transactions (member_id, dues_schedule_id, status);
```

| Metric | Before | After |
| --- | --- | --- |
| Execution Time | 2.542 ms | 0.580 ms |
| Planning Time | 28.020 ms | 1.332 ms |
| Scan type | Seq Scan | Seq Scan |

PostgreSQL continued using a Sequential Scan in both runs. With only 28
transaction rows, the optimiser correctly determined that reading the whole
table was cheaper than navigating an index. Execution time fell from
2.542 ms to 0.580 ms and Planning Time from 28.020 ms to 1.332 ms, but these
differences are not evidence that the index was used. The plan did not
change, and the first run in a session typically pays a one-off cost to load
table metadata and warm the cache, so I treat the timings as inconclusive.
The index is justified by the query's shape: its key order matches the join
and filter columns. At production scale, PostgreSQL would be expected to
switch to an Index Scan, navigating directly to the matching rows instead of
reading the entire table.

---

### Candidate 2: Q6 (Monthly revenue by tenant)

**Index created:**

```sql
CREATE INDEX idx_transactions_tenant_status_paid
    ON transactions (tenant_id, status, paid_at);
```

| Metric | Before | After |
| --- | --- | --- |
| Execution Time | 1.838 ms | 0.070 ms |
| Planning Time | 0.681 ms | 1.890 ms |
| Scan type | Seq Scan | Seq Scan |

The Seq Scan remained in both runs for the same reason as Q4.
The 97% drop in execution time reflects data caching rather than
index usage — the transactions table was already in memory from
prior queries. Planning Time increased slightly after the index
was added because the optimiser now evaluates an additional
strategy before making its decision, which is expected behaviour.

A screenshot of the Q6 execution plan post-index is in `screenshots/`.

At production scale, the composite index on `(tenant_id, status,
paid_at)` would allow PostgreSQL to locate the target tenant's
successful transactions directly and avoid a separate sort step
before the `DATE_TRUNC` grouping.

### Note on Small Datasets

Both optimisation candidates produced Seq Scans before and after
indexing. This is correct and expected behaviour — PostgreSQL's
query optimiser is cost-based and will only use an index when the
estimated cost of doing so is lower than a sequential scan. For
tables with tens of rows, it rarely is. The value of this exercise
is demonstrating understanding of why the planner makes each
choice, and being able to predict how behaviour changes at scale.

---

## Screenshots

| File | Contents |
| --- | --- |
| `Q1-Fetching members in an organisation.png` | Q1 result set |
| `Q2-Total dues collected by organisation.png` | Q2 aggregation result |
| `Q3 - Payment history for a specific member.png` | Q3 payment history |
| `Q4 - Fetch members yet to pay dues.png` | Q4 anti-join result |
| `Q8 - Audit trail of a transaction.png` | Q8 audit log output |
| `Q6 - Optimization after adding index.png` | EXPLAIN ANALYZE output after index creation |
