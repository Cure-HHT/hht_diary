# Database Migration Files

## Overview

This directory holds **delta migration files** applied on top of the rev-1 baseline.

---

## Rev-1 Baseline

The consolidated source files (`database/schema.sql`, `database/triggers.sql`,
`database/rls_policies.sql`, `database/roles.sql`, etc.) together with
`database/init.sql` constitute the **rev-1 baseline**.

A fresh or reset database is stamped at version 1 by inserting a sentinel row:

```sql
INSERT INTO schema_migrations (id, name)
VALUES (1, 'rev1_baseline')
ON CONFLICT (id) DO NOTHING;
```

This row is written by `reset_database()` in
`infrastructure/docker/db-schema-job/entrypoint.sh` immediately after
applying the consolidated schema. It tells the migrate runner that all
rev-1 objects are already present — so migrations numbered `002`+ are not
re-applied.

---

## Adding a New Migration

1. **Identify the change** — what schema delta is needed?
2. **Update the relevant source file** (`schema.sql`, `triggers.sql`, etc.)
   so the single-source baseline reflects the final state. *(Note: a
   full `pg_dump`-regenerated-baseline workflow that keeps the source files
   perfectly in sync with accumulated migrations is a planned future
   refinement; for now, update both the source file and write a delta
   migration.)*
3. **Pick the next number**: migrations start at `002` and increment
   sequentially (three-digit, zero-padded). Never reuse a number.
4. **Create the migration file**: `database/migrations/002_description.sql`
5. **Create the matching rollback**: `database/migrations/rollback/002_rollback.sql`
6. **Test locally** (apply migration, verify, apply rollback, verify).
7. **Commit both files together.**

### Migration file format

```sql
-- =====================================================
-- Migration: <Brief title>
-- Number: 002
-- Description: <What and why>
-- Dependencies: Requires rev-1 baseline (id=1)
-- Reference: database/schema.sql, spec/...
-- =====================================================

BEGIN;

-- Delta SQL here (use IF NOT EXISTS / idempotent guards)

COMMIT;
```

### Rollback file format

```sql
-- =====================================================
-- Rollback: <Brief title>
-- Number: 002
-- Description: Reverses migration 002
-- =====================================================

BEGIN;

-- Reversal SQL here

COMMIT;
```

---

## Key Principles

- Migrations are numbered sequentially from `002`; the baseline is implicitly `001`/`rev1_baseline`.
- Each migration is **immutable once deployed** — fix forward with a new migration.
- Every migration must have a matching `rollback/NNN_rollback.sql`.
- Write migrations to be **idempotent** (`IF NOT EXISTS`, `IF EXISTS`) so
  a retry after a crash is safe.
- Wrap in `BEGIN` / `COMMIT` for atomicity.
- Do NOT redefine objects that are part of the rev-1 baseline — only add
  true deltas.

---

## Directory Structure

```
database/migrations/
+-- README.md          # This file
+-- rollback/
    +-- .gitkeep       # Keeps the directory tracked until the first rollback file is added
```

When migrations exist:

```
database/migrations/
+-- README.md
+-- 002_description.sql
+-- rollback/
    +-- 002_rollback.sql
```
