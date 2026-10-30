# Portfolio 4 — NoSQL: Document Modelling with MongoDB

**Case study:** Kowojọ: Multi-tenant Dues Management Platform  
**Course:** MIT 8103 Advanced Database Systems · MIVA Open University  
**Database:** MongoDB (local instance)  
**Prerequisites:** Portfolio 1 schema and Portfolio 2 seed data loaded in PostgreSQL

---

## Why MongoDB Exists Alongside PostgreSQL

Kowojọ is a multi-tenant platform. Every organisation that registers on it — an alumni association, a medical cooperative, a founders' circle — shares the same core data model: tenants, members, dues schedules, transactions, audit logs. That shared structure lives perfectly well in Postgresql, and that is exactly where it belongs.

The problem surfaces when you ask what a member profile actually looks like. For Osun State Alumni Association, a profile means a matric number, a graduation year, a faculty, and a degree class. For Ife Medical Cooperative Society, a profile means an MDCN licence number, a clinical specialization, a hospital affiliation, and on top of that, the cooperative's own financial fields: share units, loan eligibility, monthly contribution. For Lagos Tech Founders Circle, a profile means a startup name, an industry vertical, a funding stage, and a team size.

These three organisations are all tenants on the same platform but their member profiles share almost nothing in common. Forcing them into a single SQL table would mean either creating multiple nullable columns most of which will be empty or building a separate profile table for every organisation type that ever joins. Both approaches break the moment a fourth organisation signs up with a new set of requirements.

MongoDB solves this by storing each member's profile as a document whose shape is determined entirely by what that organisation actually needs. The collection holds all profiles regardless of tenant type. No schem is enforced.

---

## How PostgreSQL and MongoDB Talk to Each Other

The two databases do not know about each other at the database level. They are connected entirely by a shared key in application code.

Every document in the `member_profiles` collection carries two fields at the top level: `member_id` and `tenant_id`. These are the exact UUID primary keys from the `members` and `tenants` tables in PostgreSQL. When the Kowojọ application needs to display a member's full record, it fetches the financial and membership data from PostgreSQL using the member's UUID, then uses that same UUID to query MongoDB for the profile. The join happens in application logic, not in a database engine.

This architecture is called polyglot persistence i.e using more than one database technology, each one handling the kind of data it is best suited for. PostgreSQL owns everything that benefits from strict typing, referential integrity, and transactional guarantees: identity, payments, audit logs. MongoDB owns everything that benefits from schema flexibility: the organisation-specific profile data that changes depending on the tenant's requirement.

---

## The Three Profile Shapes In the Test Databases

### Osun State Alumni Association

The alumni association's members are identified by their time at the university. Every profile has a `matric_number`, a `graduation_year`, a `faculty`, a `department`, and a `degree_class`. These fields are meaningful only within an alumni context. A doctor or a startup founder has no matric number.

### Ife Medical Cooperative Society

The medical cooperative members are practising physicians who also belong to a savings cooperative, which means their profile must carry two entirely different categories of information simultaneously. The clinical half includes an MDCN licence number, a specialization, a hospital affiliation, and a licence expiry year. The cooperative half includes share units, loan eligibility, and a monthly contribution figure.

### Lagos Tech Founders Circle

The founders' circle demonstrates a different kind of flexibility: the data itself is still evolving. Two of the four founding members are in an accelerator programme and carry an `accelerator` field; the other two are not and do not. As members raise funding, change their `funding_stage`, or grow their team, their profile document is updated in place. If the circle decides next year to track pitch deck URLs or co-founder details, that field can be added to new documents without touching existing ones.

---

## Files

| File | Purpose |
| --- | --- |
| `seed.js` | Creates the `kowojo` database, drops and recreates `member_profiles`, and inserts 12 documents across the three tenant types. Run with `mongosh --file seed.js`. |
| `queries.js` | Three queries demonstrating dot-notation filtering, comparison operators, and the aggregation pipeline. Paste each block individually into mongosh and observe the output. |
| `screenshots/` | Screenshots taken from MongoDB Compass and monogosh after running both scripts |
| `README.md` | This document. |

---

## Screenshots

The `screenshots/` folder contains the following captures taken from MongoDB Compass (localhost:27017):

| File | What it shows |
| --- | --- |
| `01-collection-overview.png` | The full `member_profiles` collection — all 12 documents listed, confirming the seed ran correctly |
| `02-alumni-document.png` | One Osun Alumni document expanded — profile shape: matric_number, graduation_year, faculty, department, degree_class |
| `03-medical-coop-document.png` | One Ife Medical Coop document expanded — hybrid profile: MDCN credentials + cooperative financials |
| `04-founders-document.png` | One Lagos Tech Founders document expanded — startup profile: startup_name, industry, funding_stage, team_size |
| `05-query1-result.png` | Output of Query 1 — three loan-eligible Ife Medical Coop members |
| `06-query2-result.png` | Output of Query 2 — two practitioners with licences expiring by 2026 |
| `07-query3-result.png` | Output of Query 3 — aggregation pipeline result: member count and unverified tally per tenant type |

---

## Query Summary

| # | Query | Technique | Result |
| --- | --- | --- | --- |
| Q1 | Loan-eligible members in Ife Medical Coop | `find()` with dot-notation filter on nested field | 3 documents |
| Q2 | Practitioners with licences expiring by 2026 | `find()` with `$lte` comparison operator | 2 documents |
| Q3 | Member count and unverified profiles by tenant type | Aggregation pipeline: `$group` → `$project` → `$sort` | 3 summary documents |
