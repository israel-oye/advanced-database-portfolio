# Kowojọ — Advanced Database Systems Portfolio

**Course:** MIT 8103 Advanced Database Systems
**Institution:** MIVA Open University — School of Post Graduate Studies
**Academic Session:** 2026/2027 | First Semester Continuous Assessment
**Matric Number:** 2026/A/MIT/0905
**Student:** Israel Oyeboade

---

## Selected Case Study / Organisation

**Organisation Name:** Kowojọ

**Nature of the System:**
Kowojọ is a multi-tenant dues management platform designed for organisations such as alumni associations, cooperatives, professional bodies, student unions, and similar groups, to manage their members' dues payments in a structured, centralised way. Rather than each organisation setting up its own fragmented means of collecting dues (spreadsheets, bank transfers, WhatsApp coordination), Kowojọ provides a unified platform where organisations onboard as tenants, members register under their organisation, and dues are collected and tracked systematically.

**Users of the Database:**

- **Platform administrators** — oversee all tenants and platform health
- **Organisation administrators** — manage their organisation's members, dues schedules, and payment records
- **Members** — register under an organisation, pay dues, and view their membership and payment history

**Major Data to be Stored:**

- Tenant (organisation) records
- Member profiles and authentication data
- Dues schedules and payment plans
- Payment and transaction records
- Audit logs
- Organisation-specific member attributes (variable schema per tenant)

**Key Operations the Database Will Support:**

- Onboarding a new organisation as a tenant
- Registering members under a specific organisation
- Creating and managing dues payment schedules
- Recording, verifying, and reversing payments
- Querying payment status and dues history per member or organisation
- Generating membership and payment summaries
- Storing and retrieving per-tenant custom member profile data

---

## Architecture Overview

Kowojọ uses a **polyglot persistence** approach:

- **PostgreSQL** serves as the primary relational database, handling all structured, transactional, and financially critical data — tenants, members, dues, payments, and audit logs.
- **MongoDB** handles organisation-specific member profile data, where the schema varies per tenant. A medical association may require license number and specialty; a student union may require matric number, department, and level. A document store is the natural fit for this variability.

Multi-tenancy is implemented using a **shared schema with `tenant_id` column** strategy — all tenant data lives in shared tables, scoped by a `tenant_id` foreign key. This balances simplicity, query transparency, and the ability to reason about cross-tenant operations where needed.

---

## Portfolio Structure

```
advanced-database-portfolio/
├── portfolio-1-database-design/
│   ├── er-diagram.png
│   ├── schema.sql
│   └── README.md
├── portfolio-2-query-optimisation/
│   ├── queries.sql
│   ├── execution-plans/
│   └── README.md
├── portfolio-3-transactions-concurrency/
│   ├── transactions.sql
│   └── README.md
├── portfolio-4-nosql/
│   ├── mongo-model.js
│   ├── sample-documents.json
│   └── README.md
├── portfolio-5-distributed-cloud/
│   ├── architecture-notes.md
│   └── README.md
└── README.md  ← this file
```

---

## Portfolio Activities Summary

### Portfolio 1 — Database Design and Modelling

Design of the core relational schema for Kowojọ, including an ER diagram, relational schema with all keys and constraints, and normalisation walkthrough up to 3NF.

### Portfolio 2 — Query Processing and Optimisation

SQL queries covering common platform operations — dues status per member, payment history, tenant-scoped aggregations. Includes execution plan analysis and indexing strategy.

### Portfolio 3 — Transactions and Concurrency

Demonstration of atomic payment recording, rollback on failed transactions, and concurrency control mechanisms relevant to a financial ledger context.

### Portfolio 4 — NoSQL and Advanced Data Models

MongoDB-based modelling of organisation-specific member profiles. Includes document design, sample data, and justification of the polyglot persistence choice.

### Portfolio 5 — Distributed and Cloud Database Exercise

Discussion and setup of replication, data isolation strategies for multi-tenant data, and cloud deployment considerations for a platform like Kowojọ.

---

## Tools and Technologies

| Layer | Technology |
| --- | --- |
| Relational Database | PostgreSQL |
| NoSQL Database | MongoDB |
| Query & Schema Tools | psql, pgAdmin, DBeaver |
| NoSQL Client | MongoDB Compass / mongosh |
| Version Control | Git + GitHub |
| Diagramming | dbdiagram.io / draw.io, lucidchart.com |

---

## Academic Integrity and AI Use Declaration

This portfolio represents individual work. All database design decisions, SQL scripts, queries, and documentation were authored and verified by the student.

**AI Use:** Claude (Anthropic) was used as a learning and drafting aid during this project — specifically for brainstorming architectural decisions and generating initial drafts of documentation. All outputs were reviewed, tested, and verified by the student. The student takes full responsibility for the accuracy and understanding of all submitted work.

---

## References

*To be completed as the portfolio develops.*

---

*Kowojọ — because dues should be the easiest part of running an organisation.*

---
