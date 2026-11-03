# Portfolio 5 — Distributed & Cloud Databases

**Case study:** Kowojọ — Multi-tenant Dues Management Platform  
**Course:** MIT 8103 Advanced Database Systems · MIVA Open University  
**Database:** PostgreSQL 15+ (partitioning demo), Neon DB (cloud deployment)

---

## The Scaling Problem

At three tenants and 30 transactions, Kowojọ fits comfortably on a single server. At three thousand tenants and millions of transactions, a single PostgreSQL instance becomes a bottleneck — one node handling every read, every write, and every report query simultaneously. Distributed database design is the discipline of spreading that load across multiple nodes without breaking the guarantees the application depends on.

---

## Table Partitioning — Data Locality at the Disk Level

Kowojọ's `transactions` table carries `tenant_id` on every row, a deliberate denormalisation introduced in Portfolio 1 for fast tenant-scoped queries. That same column is the natural partition key.

`partitioning.sql` creates `transactions_partitioned` as a declarative LIST-partitioned table with one child partition per tenant:

```
transactions_partitioned        ← routing shell (doesn't have any rows)
├── transactions_tenant_osaa    ← all OSAA rows
├── transactions_tenant_ifem    ← all IFEM rows
└── transactions_tenant_ltfc    ← all LTFC rows
```

When a query filters on `tenant_id`, PostgreSQL's planner applies **partition pruning** — it identifies which partition can contain matching rows and ignores the others entirely. The `EXPLAIN` output at the end of `partitioning.sql` shows only one partition being scanned regardless of how many exist. A screenshot of the query is attached in the `screenshots` folder.

This is the same principle that underlies distributed sharding. The difference is physical location: in a local setup, the partitions are sub-tables on the same disk; in a distributed cluster, each partition lives on a separate node in a separate data centre. While partitoning does not demonstrate distributed architecture, it provides a local proof of concept for sharding

---

## CAP Theorem and Where Kowojọ Sits

The CAP theorem states that a distributed system can guarantee at most two of three properties simultaneously:

| Property | What it means |
| --- | --- |
| **Consistency (C)** | Every read returns the most recently written value i.e all nodes agree on the current state |
| **Availability (A)** | Every request receives a response, even if some nodes are down |
| **Partition Tolerance (P)** | The system keeps running even when network partitions split nodes apart |

Network partitions are not optional — they happen in any real distributed system. So the practical choice is always between **CP** and **AP**.

### PostgreSQL (Neon DB): CP

In a single node deployment like this, PostgreSQL favours consistency over availability – although, configuration could modify this. When Kowojọ records a dues payment, the transaction either commits fully or does not commit at all. If a network partition means a replica cannot acknowledge a write, PostgreSQL will sacrifice availability (i.e the write is held) rather than let two nodes hold conflicting versions of the ledger. For a fintech platform where double charges and lost payments are unacceptable, this is the right trade-off. An unavailable system is recoverable; corrupted financial records are not.

Neon DB inherits PostgreSQL's CP guarantees and layers on top a serverless architecture where storage and compute are separated. The write-ahead log (WAL) is streamed to Neon's storage layer continuously, so even if the compute node goes down, no committed data is lost.

### MongoDB Atlas — Tunable, defaulting to CP

MongoDB's consistency model is configurable per operation through **write concern** and **read preference**. At default settings (write concern `majority`, read preference `primary`), Atlas behaves as a CP system — a write is only acknowledged once a majority of replica set members have confirmed it. Relaxing those settings (e.g. read preference `secondaryPreferred`) shifts the system toward AP: reads can be served from any replica, which is faster but may return stale data.

In Kowojọ's MongoDB layer (member profiles), eventual staleness is tolerable. A member profile showing yesterday's department change does no financial harm. So reads on profiles can safely use `secondaryPreferred` for lower latency, while writes remain at `majority` for durability.

### The practical rule for Kowojọ

| Layer | Database | CAP position | Reason |
| --- | --- | --- | --- |
| Payments, dues, audit logs | PostgreSQL / Neon DB | CP | Financial correctness is non-negotiable |
| Member profiles | MongoDB Atlas | CP for writes, AP for reads | Profile staleness is tolerable; write durability is not |

---

## Replication Strategy

For Kowojọ, the chosen model is primary-replica:

- The primary node handles all writes: dues payments, member approvals, audit log entries
- One or more read replicas could serve the reporting queries from Portfolio 2 (dues collected per org, monthly revenue, members who have not paid). These queries are heavy, tenant-wide scans; running them on a replica keeps them off the primary's write path

Neon DB implements repliction through its branching model: the primary is the main branch; read replicas are compute endpoints that share the same storage layer; although replica branches read from the same storage as the primary instead of receiving data over a network link, there might be brief lags behind the primary due to them being asynchronous per the documentation.

---

## Cloud Deployment

| Component | Service | Why |
| --- | --- | --- |
| PostgreSQL | **Neon DB** | Serverless PostgreSQL; scales to zero when idle; branching for safe schema migrations; built-in connection pooling via PgBouncer; generous free tier |
| MongoDB | **MongoDB Atlas** | Managed replica sets; configurable write concern; free M0 tier for development |

### Connection pooling

At scale, every API request that opens a direct PostgreSQL connection is a risk — PostgreSQL has a hard ceiling on simultaneous connections, and a traffic spike can exhaust it. Neon DB includes PgBouncer-based connection pooling (which could be configured by adding a flag to the hostname in the connection string), which means hundreds of application connections share a small pool of actual database connections.

---

## Files

| File | Purpose |
| --- | --- |
| `partitioning.sql` | Creates `transactions_partitioned` with three tenant-scoped LIST partitions, migrates seed data, verifies distribution, and runs `EXPLAIN` to show partition pruning |
| `screenshots/` | `EXPLAIN` output showing partition pruning in action |
| `README.md` | This document |
