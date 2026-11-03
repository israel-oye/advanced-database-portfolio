# Portfolio 3 — Transactions & Concurrency

**Case study:** Kowojọ — Multi-tenant Dues Management Platform  
**Course:** MIT 8103 Advanced Database Systems
**Prerequisites:** Portfolio 1 schema and Portfolio 2 seed data loaded

---

## Overview

Dues payments in Kowojọ involve coordinated writes across two tables (`transactions` and `audit_logs`), concurrent access from multiple members paying simultaneously, and financial reports that must read consistent data across multiple queries. This portfolio demonstrates how PostgreSQL transaction control and concurrency mechanisms address each of these requirements.

---

## ACID Properties in Kowojọ

| Property | Definition | Application |
| --- | --- | --- |
| **Atomicity** | All writes in a transaction succeed together or none persist | Payment record + audit log commit as one unit; a crash between the two inserts leaves no partial state |
| **Consistency** | A transaction moves the database between two valid states | Duplicate-payment guard ensures a member never has two completed transactions for the same schedule |
| **Isolation** | Concurrent transactions do not interfere with each other | `SELECT FOR UPDATE` on the member row queues concurrent payment attempts; each session sees a clean snapshot |
| **Durability** | Committed data survives process crashes and restarts | PostgreSQL WAL (Write-Ahead Log) replays committed transactions on recovery |

---

## Transaction Scenarios (`transactions.sql`)

| # | Scenario | Concept Demonstrated | Outcome | Image |
| --- | --- | --- | --- | -- |
| S1 | Successful dues payment | Atomicity + `SELECT FOR UPDATE` | Payment and audit log commit together; member row locked for the transaction duration | [Result 1](screenshots/acid-scenarios-1.png) |
| S2 | Duplicate payment blocked | Consistency guard + implicit rollback | Existing completed payment detected; `RAISE EXCEPTION` fires; no row is written | [Result 2](screenshots/acid-scenarios-2.png) |
| S3 | SAVEPOINT — partial failure recovery | Selective rollback | Audit log INSERT fails (null actor); nested exception block rolls back only the audit write; fallback entry commits alongside the payment | [Result 3](screenshots/acid-scenarios-3.png) |

### Scenario 3 — SAVEPOINT detail

PL/pgSQL's nested `BEGIN … EXCEPTION` block acts as an explicit `SAVEPOINT`:

```
Outer block starts
  ├── INSERT INTO transactions  ← succeeds; payment row exists
  ├── Inner BEGIN (= SAVEPOINT)
  │     └── INSERT INTO audit_logs (actor_id = NULL)  ← fails
  │         EXCEPTION: not_null_violation
  │         ROLLBACK TO SAVEPOINT  ← only the audit INSERT is undone
  │         INSERT INTO audit_logs (fallback actor)  ← succeeds
  └── Outer block commits: payment + fallback audit log both durable
```

---

## Isolation Levels (`concurrency.sql`)

| Level | Snapshot Behaviour | Kowojọ Use Case | Image |
| --- | --- | --- | -- |
| `READ COMMITTED` *(default)* | Each statement sees the latest committed row at execution time | Routine member queries, dashboard reads | [image](screenshots/conc--query_result-read-committed.png) |
| `REPEATABLE READ` | Snapshot fixed at transaction start; no new committed rows appear mid-transaction | Revenue reconciliation; cross-tenant summaries where two aggregates must be consistent | [image](screenshots/conc--query_result_repeatable_read_combined.png) |
| `SERIALIZABLE` | Full serial ordering enforced; transactions with conflicting read-write dependencies abort (SQLSTATE 40001) | Payment existence check where two concurrent sessions must not both read "not yet paid" | [image](screenshots/conc--query_result-serializable.png) |

---

## Concurrency Hazards and Mitigations

| Hazard | Description | How Kowojọ Addresses It |
| --- | --- | --- |
| **Lost update** | Two sessions both read "not paid", both insert — one write overwrites the other | `SELECT FOR UPDATE` forces Session B to block until Session A commits; Session B re-reads and detects the existing payment |
| **Dirty read** | A session reads an uncommitted row from a concurrent session | Impossible in PostgreSQL; the minimum isolation is `READ COMMITTED` |
| **Non-repeatable read** | The same row read twice in one transaction returns different values | `REPEATABLE READ` for all financial summary queries |
| **Phantom read** | A range query returns a different set of rows on re-execution within a transaction | `REPEATABLE READ` prevents phantoms in PostgreSQL (stronger than the SQL standard guarantee for this level) |
| **Double charge** | A member is billed twice for the same dues schedule | Application-level duplicate guard in S2 + database-level `SELECT FOR UPDATE` in S1 provide two layers of protection |

---

## Files

| File | Description |
| --- | --- |
| `transactions.sql` | Three annotated scenarios demonstrating ACID properties using explicit `BEGIN`/`COMMIT` and PL/pgSQL `DO` blocks |
| `concurrency.sql` | Isolation level examples, `SELECT FOR UPDATE` demonstration, and a concurrent session timeline with hazard summary table |
| `screenshots/` | folder containing screen captures of ACID scenarios and isolatioin level examples |
| `README.md` | This document |
