# Complete File Update List for Event Sourcing Terminology

## Status Legend
- ✅ COMPLETED
- ⏳ IN PROGRESS
- ⏺️ PENDING
- ⚪ OPTIONAL (low priority or example files)

---

## Critical Database Files (9 files)

| # | File | Status | Priority | Notes |
|---|------|--------|----------|-------|
| 1 | `database/schema.sql` | ✅ | CRITICAL | Core schema - DONE |
| 2 | `database/triggers.sql` | ✅ | CRITICAL | Event store triggers - DONE |
| 3 | `database/indexes.sql` | ⏺️ | HIGH | Index comments |
| 4 | `database/rls_policies.sql` | ⏺️ | HIGH | Policy comments |
| 5 | `database/roles.sql` | ⏺️ | MEDIUM | Role/permission comments |
| 6 | `database/tamper_detection.sql` | ⏺️ | MEDIUM | Hash validation comments |
| 7 | `database/init.sql` | ⏺️ | HIGH | Initialization script comments |
| 8 | `database/compliance_verification.sql` | ⏺️ | MEDIUM | Compliance query comments |
| 9 | `database/seed_data.sql` | ⏺️ | LOW | Test data comments |

---

## Core Specification Documents (7 files)

| # | File | Status | Priority | Notes |
|---|------|--------|----------|-------|
| 10 | `spec/db-spec.md` | ⏳ | **CRITICAL** | PRIMARY architecture doc |
| 11 | `spec/JSONB_SCHEMA.md` | ⏺️ | HIGH | Already partially updated |
| 12 | `spec/README.md` | ⏺️ | HIGH | Project overview |
| 13 | `spec/QUICK_REFERENCE.md` | ⏺️ | HIGH | Quick reference guide |
| 14 | `database/README.md` | ⏺️ | HIGH | Database documentation |
| 15 | `database/dart/README.md` | ⏺️ | HIGH | Dart integration docs |
| 16 | `spec/compliance-practices.md` | ⏺️ | HIGH | Compliance documentation |

---

## Architecture Decision Records (4 files)

| # | File | Status | Priority | Notes |
|---|------|--------|----------|-------|
| 17 | `docs/adr/ADR-001-event-sourcing-pattern.md` | ⏺️ | **CRITICAL** | KEY Event Sourcing ADR |
| 18 | `docs/adr/ADR-002-jsonb-flexible-schema.md` | ⏺️ | MEDIUM | Schema ADR |
| 19 | `docs/adr/ADR-003-row-level-security.md` | ⏺️ | MEDIUM | RLS ADR |
| 20 | `docs/adr/ADR-004-investigator-annotations.md` | ⏺️ | MEDIUM | Annotations ADR |

---

## Dart Code Files (5 files)

| # | File | Status | Priority | Notes |
|---|------|--------|----------|-------|
| 21 | `database/dart/diary_repository.dart` | ⏺️ | HIGH | SQL queries + comments |
| 22 | `database/dart/event_deletion_handler.dart` | ⏺️ | MEDIUM | Deletion logic comments |
| 23 | `database/dart/models.dart` | ⏺️ | MEDIUM | Data model comments |
| 24 | `database/dart/deletion_models.dart` | ⏺️ | LOW | Supporting types |
| 25 | `database/dart/ui_example.dart` | ⏺️ | LOW | UI examples |

---

## Operations & Deployment Documents (7 files)

| # | File | Status | Priority | Notes |
|---|------|--------|----------|-------|
| 26 | `spec/DEPLOYMENT_CHECKLIST.md` | ⏺️ | HIGH | Deployment guide |
| 27 | `spec/PRODUCTION_OPERATIONS.md` | ⏺️ | HIGH | Operations guide |
| 28 | `spec/MIGRATION_STRATEGY.md` | ⏺️ | MEDIUM | Migration docs |
| 29 | `spec/SECURITY.md` | ⏺️ | HIGH | Security documentation |
| 30 | `spec/DATA_CLASSIFICATION.md` | ⏺️ | MEDIUM | Data classification |
| 31 | `spec/LOGGING_STRATEGY.md` | ⏺️ | MEDIUM | Logging strategy |
| 32 | `spec/SUPABASE_SETUP.md` | ⏺️ | MEDIUM | Supabase setup guide |

---

## Test Files (3 files)

| # | File | Status | Priority | Notes |
|---|------|--------|----------|-------|
| 33 | `database/tests/test_audit_trail.sql` | ⏺️ | MEDIUM | Audit trail tests |
| 34 | `database/tests/test_compliance_functions.sql` | ⏺️ | MEDIUM | Compliance tests |
| 35 | `database/tests/README.md` | ⏺️ | LOW | Test documentation |

---

## Migration Files - Production (3 files)

| # | File | Status | Priority | Notes |
|---|------|--------|----------|-------|
| 36 | `database/migrations/009_configure_rls.sql` | ⏺️ | MEDIUM | RLS migration |
| 37 | `database/migrations/DEPLOYMENT_GUIDE.md` | ⏺️ | MEDIUM | Deployment guide |
| 38 | `database/migrations/rollback/009_rollback.sql` | ⏺️ | MEDIUM | Rollback script |

---

## Migration Files - Testing Examples (8 files)

| # | File | Status | Priority | Notes |
|---|------|--------|----------|-------|
| 39 | `database/testing/migrations/001_initial_schema.sql` | ⏺️ | LOW | Example migration |
| 40 | `database/testing/migrations/002_add_audit_metadata.sql` | ⏺️ | LOW | Example migration |
| 41 | `database/testing/migrations/003_add_encryption_docs.sql` | ⏺️ | LOW | Example migration |
| 42 | `database/testing/migrations/007_enable_state_protection.sql` | ⏺️ | MEDIUM | State protection |
| 43 | `database/testing/migrations/007_test_verification.sql` | ⏺️ | LOW | Test verification |
| 44 | `database/testing/migrations/README.md` | ⏺️ | LOW | Migration README |
| 45 | `database/testing/migrations/rollback/001_rollback.sql` | ⏺️ | LOW | Rollback example |
| 46 | `database/testing/migrations/rollback/002_rollback.sql` | ⏺️ | LOW | Rollback example |
| 47 | `database/testing/migrations/rollback/003_rollback.sql` | ⏺️ | LOW | Rollback example |
| 48 | `database/testing/migrations/rollback/007_rollback.sql` | ⏺️ | LOW | Rollback example |

---

## Miscellaneous Documentation (5 files)

| # | File | Status | Priority | Notes |
|---|------|--------|----------|-------|
| 49 | `spec/AUTH_AUDIT_README.md` | ⏺️ | MEDIUM | Auth audit docs (note: separate system) |
| 50 | `spec/COMPARISON.md` | ⏺️ | LOW | Comparison docs |
| 51 | `spec/PROJECT_SUMMARY.md` | ⏺️ | MEDIUM | Project summary |
| 52 | `database-compliance-todos.md` | ⏺️ | LOW | Compliance TODOs |
| 53 | `database/auth_audit.sql` | ⏺️ | LOW | Auth audit SQL (note: separate system) |

---

## Summary

| Priority | Count | Status |
|----------|-------|--------|
| CRITICAL | 3 | 2 done, 1 in progress |
| HIGH | 17 | 0 done |
| MEDIUM | 23 | 0 done |
| LOW | 13 | 0 done |
| **TOTAL** | **56 files** | **2 completed** |

---

## Recommended Approach

### Phase 1: CRITICAL Files (Complete First)
1. ✅ database/schema.sql - DONE
2. ✅ database/triggers.sql - DONE
3. ⏳ spec/db-spec.md - IN PROGRESS (PRIMARY architecture document)
4. docs/adr/ADR-001-event-sourcing-pattern.md (KEY Event Sourcing ADR)

### Phase 2: HIGH Priority (Core Documentation)
- All spec/*.md files that are marked HIGH
- database/README.md
- database/dart/README.md
- Dart code files with SQL queries

### Phase 3: MEDIUM Priority (Operations & Compliance)
- Operations and deployment guides
- Security and compliance docs
- Test files
- Migration documentation

### Phase 4: LOW Priority (Examples & Misc)
- Example migrations in testing/
- Rollback scripts
- Seed data
- Comparison and summary docs

---

## Questions for User

1. **Should we proceed with all 56 files?**
   - Or focus on just CRITICAL + HIGH priority (20 files)?

2. **How to handle migration example files?**
   - Update them for consistency?
   - Or leave as historical examples?

3. **Batch commits or single commit?**
   - Single comprehensive commit for all changes?
   - Or separate commits by category (database, docs, dart code)?

4. **Any files to skip?**
   - Any legacy or deprecated files we shouldn't touch?
