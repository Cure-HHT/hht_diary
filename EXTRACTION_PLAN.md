# Spec Reorganization - Detailed Extraction Plan

**Version**: 1.0
**Date**: 2025-10-17
**Status**: DRAFT - Awaiting Approval
**Total Content**: 7,627 lines across 21 files (268KB)

---

## Executive Summary

This document maps how content from existing spec files will be reorganized into the v2 hierarchical structure. The reorganization follows these principles:

1. **Audience Separation**: PRD (requirements) → OPS (operations) → DEV (implementation)
2. **Topic Hierarchy**: General → Specific (e.g., security → security-RBAC → security-RLS)
3. **Reference > Duplication**: Files reference related content rather than duplicating it
4. **Compliance Preservation**: All compliance-critical content must be traceable

---

## Critical Observations

### Not All "Redundancy" Is True Redundancy

Most apparent duplication is actually **the same topic at different abstraction levels**:

- **PRD Level**: "System MUST have encryption at rest" (requirement)
- **OPS Level**: "Enable encryption via Supabase settings" (procedure)
- **DEV Level**: "Use `sslmode=require` in connection string" (implementation)

**True redundancy** = Same information at same level, duplicated

**Complementary content** = Same topic at different levels (KEEP)

### Constitutional Content Requires Special Handling

Files containing **🔒 IMMUTABLE principles**:
- `dev-core-practices.md` (551 lines) - The 5 Constitutional Principles
- `dev-principles-quick-reference.md` (142 lines) - Quick reference card

**Risk**: Splitting constitutional content could fragment the "source of truth"
**Recommendation**: Keep constitutional content centralized, reference from elsewhere

### Files Marked for Deletion/Review

Several files have explicit TODOs:
- `database_reference2.md` - "Redundant with other files"
- `authentication_auditing.md` - "Delete certain sections"
- `DATA_CLASSIFICATION.md` - "Review for redundancies"
- `LOGGING_STRATEGY.md` - "Might be entirely redundant"
- `ops_schema_migration.md` - "Contains redundant information"

**Action Required**: Verify each TODO, extract unique content before deletion

---

## File-by-File Extraction Map

### PRD Files (Product Requirements)

#### 1. PROJECT_SUMMARY.md → prd-app.md
**Lines**: 357 | **Status**: Summary document

| Section | Lines | Destination | Action | Notes |
|---------|-------|-------------|--------|-------|
| Overview | 1-17 | prd-app.md | MOVE | High-level project description |
| What's Been Created | 18-36 | prd-app.md | MOVE | Deliverables summary |
| Key Features | 37-67 | prd-app.md | REFERENCE | Details in prd-database.md, prd-security.md |
| Database Schema | 68-113 | prd-database.md | REFERENCE | Full schema in prd-database.md |
| Deployment Options | 114-142 | ops-database-setup.md | REFERENCE | Full guide in ops-database-setup.md |
| Access Control Summary | 210-220 | prd-security-RBAC.md | REFERENCE | Full spec in prd-security-RBAC.md |
| Compliance Features | 221-247 | prd-clinical-trials.md | MOVE | FDA requirements |
| File Reference | 282-296 | prd-app.md | UPDATE | Update to reference v2 structure |

**Redundancy Assessment**: 60% references to other docs, 40% unique summary content
**Extraction Complexity**: LOW
**Compliance Risk**: LOW

---

#### 2. db-spec.md → prd-database.md + prd-database-event-sourcing.md + prd-security-*.md
**Lines**: 471 | **Status**: Core PRD - HIGH VALUE

| Section | Lines | Destination | Action | Notes |
|---------|-------|-------------|--------|-------|
| Document Information | 1-8 | prd-database.md | MOVE | Metadata |
| Executive Summary | 9-18 | prd-database.md | MOVE | Core architecture description |
| Event Sourcing Pattern | 19-88 | prd-database-event-sourcing.md | MOVE | Detailed ES architecture |
| Data Identification | 89-102 | prd-database.md | MOVE | UUID strategy |
| Database Enforcement Rules | 103-127 | prd-database.md | MOVE | Referential integrity, validation |
| Access Control (RBAC) | 128-213 | prd-security-RBAC.md | MOVE | Role definitions, policies |
| Conflict Resolution | 214-232 | prd-database.md | MOVE | Multi-device sync |
| Data Synchronization | 233-263 | prd-database.md | MOVE | Offline-first protocol |
| FDA 21 CFR Part 11 | 264-284 | prd-clinical-trials.md | MOVE | Compliance requirements |
| Data Model Summary | 285-306 | prd-database.md | MOVE | Table overview |
| Performance | 307-323 | prd-database.md | MOVE | Indexing, scaling |
| Security Requirements | 324-347 | prd-security.md | MOVE | Encryption, logging, backup |
| JSONB Schema Examples | 348-381 | dev-data-models.md | REFERENCE | Full schema in dev-data-models-jsonb.md |
| Appendix | 414-471 | prd-database.md | MOVE | Quick reference |

**Redundancy Assessment**: Unique, authoritative PRD content
**Extraction Complexity**: MEDIUM (needs careful splitting)
**Compliance Risk**: HIGH (core compliance document)
**Recommendation**: This is the source of truth - split carefully with clear cross-references

---

#### 3. prd-role-based-access-spec.md → prd-security-RBAC.md
**Lines**: 49 | **Status**: Well-scoped PRD

| Section | Lines | Destination | Action | Notes |
|---------|-------|-------------|--------|-------|
| Overview | 1-6 | prd-security-RBAC.md | MOVE | Complete |
| Core Principles | 7-14 | prd-security-RBAC.md | MOVE | All principles |
| Roles & Permissions | 15-29 | prd-security-RBAC.md | MOVE | Role definitions |
| Auditing Notes | 30-31 | prd-security-RBAC.md | MOVE | Audit requirements |
| Implementation (DRAFT) | 32-49 | ops-security.md | REFERENCE | OPS-level details |

**Redundancy Assessment**: Minimal - complements db-spec.md RBAC section
**Extraction Complexity**: LOW
**Compliance Risk**: MEDIUM
**Action**: Merge with db-spec.md RBAC content, resolve any conflicts

---

#### 4. prd-role-based-user-stories.md → prd-security-RBAC.md
**Lines**: 42 | **Status**: User stories

| Section | Lines | Destination | Action | Notes |
|---------|-------|-------------|--------|-------|
| All user stories | 1-42 | prd-security-RBAC.md | APPEND | Add after role definitions |

**Redundancy Assessment**: None - unique user stories
**Extraction Complexity**: LOW
**Compliance Risk**: LOW

---

### DEV Files (Development)

#### 5. dev-principles-quick-reference.md → dev-core-practices.md
**Lines**: 142 | **Status**: Constitutional quick reference

| Section | Lines | Destination | Action | Notes |
|---------|-------|-------------|--------|-------|
| The Five Immutable Principles | 1-31 | dev-core-practices.md | MERGE | Integrate with full principles |
| Phase -1 Validation Gates | 32-60 | dev-core-practices.md | CROSS-REF | Already detailed in main doc |
| Audit Trail vs Operational Logging | 61-82 | dev-compliance-practices.md | CROSS-REF | Full version exists |
| TDD Workflow | 83-119 | dev-core-practices.md | CROSS-REF | Already detailed |
| AI Development Rules | 120-142 | dev-core-practices.md | MERGE | Add if not present |

**Redundancy Assessment**: 70% redundant with dev-core-practices.md
**Extraction Complexity**: LOW
**Compliance Risk**: MEDIUM (constitutional content)
**Recommendation**: Keep as quick reference OR fully merge into dev-core-practices.md
**Decision Needed**: Should this exist as a separate quick-reference card, or be fully integrated?

---

#### 6. dev-compliance-practices.md → dev-compliance-practices.md + prd-clinical-trials.md
**Lines**: 518 | **Status**: Core compliance document

| Section | Lines | Destination | Action | Notes |
|---------|-------|-------------|--------|-------|
| Scope and Definitions | 1-20 | dev-compliance-practices.md | KEEP | Audit vs Logging distinction |
| Constitutional Principles for AI | 21-71 | dev-core-practices.md | CROSS-REF | Belongs with main constitution |
| Regulatory Framework | 72-108 | prd-clinical-trials.md | MOVE | PRD-level requirements |
| Key Compliance Areas | 109-167 | prd-clinical-trials.md | MOVE | ALCOA+, signatures, audit trail |
| Implementation Requirements | 168-280 | dev-compliance-practices.md | KEEP | Developer implementation guide |
| Authentication & Authorization | 191-218 | dev-security.md | CROSS-REF | Security implementation |
| Data Encryption | 219-245 | dev-security.md | CROSS-REF | Security implementation |
| Validation and Testing | 246-282 | dev-compliance-practices.md | KEEP | Testing requirements |
| Change Control | 289-325 | ops-database-migration.md | CROSS-REF | OPS procedures |
| Compliance Don'ts | 326-340 | dev-compliance-practices.md | KEEP | Developer checklist |
| Data Privacy (GDPR, HIPAA) | 341-382 | prd-security.md | CROSS-REF | PRD requirements |
| Observability Requirements | 383-501 | dev-compliance-practices.md | KEEP | Structured logging for devs |
| Standards and Regulations | 502-517 | prd-clinical-trials.md | CROSS-REF | PRD level |

**Redundancy Assessment**: Minimal - most content unique and valuable
**Extraction Complexity**: MEDIUM (split between PRD and DEV)
**Compliance Risk**: HIGH (core compliance guidance)
**Action**: Split regulatory framework (→ PRD) from implementation guidance (→ DEV)

---

#### 7. dev-continuous-compliance.md → dev-compliance-practices.md
**Lines**: 44 | **Status**: Maintenance schedule

| Section | Lines | Destination | Action | Notes |
|---------|-------|-------------|--------|-------|
| Regular Activities | 1-28 | dev-compliance-practices.md | APPEND | Add as final section |
| When to Involve Experts | 29-40 | dev-compliance-practices.md | APPEND | Decision guide |
| Reference Material | 41-44 | dev-compliance-practices.md | APPEND | Link |

**Redundancy Assessment**: None - unique operational schedule
**Extraction Complexity**: LOW
**Compliance Risk**: LOW
**Action**: Append entire file to dev-compliance-practices.md as "Continuous Compliance" section

---

#### 8. dev-core-practices.md → dev-core-practices.md
**Lines**: 551 | **Status**: Constitutional document - KEEP INTACT

| Section | Lines | Destination | Action | Notes |
|---------|-------|-------------|--------|-------|
| Entire file | 1-551 | dev-core-practices.md | KEEP | Source of truth for constitution |

**Redundancy Assessment**: This IS the source of truth
**Extraction Complexity**: NONE (preserve as-is)
**Compliance Risk**: HIGH (constitutional principles)
**Action**: Keep complete. Consider merging dev-principles-quick-reference.md INTO this file
**Recommendation**: Add a "Quick Reference" section at the top for easy lookup

---

#### 9. database_code_reference.md → dev-database-queries.md
**Lines**: 505 | **Status**: SQL quick reference

| Section | Lines | Destination | Action | Notes |
|---------|-------|-------------|--------|-------|
| Database Structure | 1-19 | dev-database.md | CROSS-REF | Overview |
| Key Concepts | 20-30 | dev-database.md | CROSS-REF | Overview |
| Common SQL Operations | 31-113 | dev-database-queries.md | MOVE | SQL examples |
| Supabase JavaScript Examples | 114-214 | dev-database-queries.md | MOVE | JS examples |
| Role-Based Access | 215-277 | dev-database-queries.md | MOVE | Access patterns |
| Useful Queries | 278-354 | dev-database-queries.md | MOVE | Common queries |
| Conflict Resolution | 355-397 | dev-database-queries.md | MOVE | Conflict SQL |
| Maintenance Commands | 398-444 | dev-database-queries.md | MOVE | Maintenance |
| Environment Variables | 445-462 | ops-database-setup.md | CROSS-REF | OPS configuration |
| Troubleshooting | 463-483 | dev-database-queries.md | MOVE | Common issues |
| File Locations | 484-495 | prd-app.md | CROSS-REF | Update to v2 structure |

**Redundancy Assessment**: Unique practical examples
**Extraction Complexity**: LOW
**Compliance Risk**: LOW
**Action**: Move wholesale to dev-database-queries.md, minimal changes needed

---

### OPS Files (Operations)

#### 10. database_setup.md → ops-database-setup.md
**Lines**: 559 | **Status**: Comprehensive setup guide

| Section | Lines | Destination | Action | Notes |
|---------|-------|-------------|--------|-------|
| Entire guide | 1-559 | ops-database-setup.md | MOVE | Complete Supabase setup |

**Redundancy Assessment**: Check against database_reference2.md for duplication
**Extraction Complexity**: LOW (mostly self-contained)
**Compliance Risk**: LOW
**Action**: Move complete, verify no critical content in database_reference2.md missing

---

#### 11. database_reference2.md → ANALYZE FOR UNIQUE CONTENT
**Lines**: 728 | **Status**: Has TODO "Redundant with other files"

**Action Required**: Line-by-line comparison with:
- database_setup.md
- database_code_reference.md
- db-spec.md

| Section | Lines | Destination | Action | Notes |
|---------|-------|-------------|--------|-------|
| TODO comment | 1 | DELETE | N/A | Instruction to check redundancy |
| Architecture Overview | 2-46 | CHECK | COMPARE | vs. db-spec.md |
| Quick Start | 47-85 | CHECK | COMPARE | vs. database_setup.md |
| Deployment to Supabase | 86-182 | CHECK | COMPARE | vs. database_setup.md |
| Database Schema | 183-247 | CHECK | COMPARE | vs. db-spec.md |
| Access Control | 248-313 | CHECK | COMPARE | vs. prd-security-RBAC.md |
| Security Features | 314-346 | CHECK | COMPARE | vs. SECURITY.md |
| Usage Examples | 347-498 | CHECK | COMPARE | vs. database_code_reference.md |
| Maintenance | 499-598 | CHECK | COMPARE | vs. ops-deployment.md |
| Troubleshooting | 599-674 | CHECK | COMPARE | vs. database_code_reference.md |
| File Structure | 675-709 | UPDATE | N/A | Update for v2 structure |

**Extraction Complexity**: HIGH (requires detailed comparison)
**Compliance Risk**: MEDIUM (might contain unique setup details)
**Recommendation**: Do NOT delete until verified that 100% of content exists elsewhere
**Action**: Create comparison matrix showing unique vs. duplicate content

---

#### 12. PRODUCTION_OPERATIONS.md → ops-deployment.md
**Lines**: 322 | **Status**: TICKET-007 implementation summary

| Section | Lines | Destination | Action | Notes |
|---------|-------|-------------|--------|-------|
| Overview | 1-23 | ops-deployment.md | MOVE | Add as case study |
| Files Modified | 24-64 | ops-deployment.md | MOVE | Example migration |
| How It Works | 65-89 | ops-database-setup.md | CROSS-REF | Environment configuration |
| Deployment Instructions | 90-169 | ops-deployment.md | MOVE | Example procedures |
| Testing | 170-204 | ops-deployment.md | MOVE | Verification examples |
| Compliance Benefits | 205-222 | prd-clinical-trials.md | CROSS-REF | Requirements met |
| Monitoring | 223-250 | ops-deployment.md | MOVE | Monitoring examples |
| Rollback Plan | 251-269 | ops-database-migration.md | CROSS-REF | Rollback procedures |
| Related Tickets | 270-278 | ops-deployment.md | MOVE | Ticket tracking |
| Acceptance Criteria | 279-293 | ops-deployment.md | MOVE | Completion checklist |
| Summary | 294-322 | ops-deployment.md | MOVE | Lessons learned |

**Redundancy Assessment**: Unique case study, valuable as example
**Extraction Complexity**: LOW
**Compliance Risk**: LOW
**Action**: Move to ops-deployment.md as a "Case Study" section

---

#### 13. DEPLOYMENT_CHECKLIST.md → ops-deployment.md
**Lines**: 438 | **Status**: Has TODO "Check all other .md files for information that should be in this file"

| Section | Lines | Destination | Action | Notes |
|---------|-------|-------------|--------|-------|
| Pre-Deployment | 1-28 | ops-deployment.md | MOVE | Planning checklist |
| Database Deployment | 29-63 | ops-deployment.md | MOVE | Deployment steps |
| Supabase Configuration | 64-97 | ops-database-setup.md | CROSS-REF | Setup procedures |
| Initial Data Setup | 98-128 | ops-deployment.md | MOVE | Initial config |
| Testing | 129-174 | ops-deployment.md | MOVE | Test checklist |
| Monitoring & Logging | 175-203 | ops-deployment.md | MOVE | Monitoring setup |
| Backup & Recovery | 204-222 | ops-deployment.md | MOVE | Backup procedures |
| Security Hardening | 223-253 | ops-security.md | CROSS-REF | Security checklist |
| Scheduled Jobs | 254-280 | ops-deployment.md | MOVE | Cron jobs |
| Documentation | 281-309 | ops-deployment.md | MOVE | Doc requirements |
| Training | 310-328 | ops-deployment.md | MOVE | Training checklist |
| Go-Live | 329-368 | ops-deployment.md | MOVE | Launch procedures |
| Maintenance Schedule | 369-403 | ops-deployment.md | MOVE | Ongoing maintenance |
| Emergency Contacts | 404-413 | ops-deployment.md | MOVE | Contact list |
| Sign-Off | 414-438 | ops-deployment.md | MOVE | Approval section |

**Redundancy Assessment**: Comprehensive checklist, minimal duplication
**Extraction Complexity**: LOW
**Compliance Risk**: MEDIUM (deployment procedures are compliance-controlled)
**Action**: Move complete, this becomes the master deployment checklist
**TODO**: Scan other files to ensure deployment info references this checklist

---

#### 14. ops_schema_migration.md → ops-database-migration.md
**Lines**: 516 | **Status**: Has TODOs about redundant examples

| Section | Lines | Destination | Action | Notes |
|---------|-------|-------------|--------|-------|
| TODO comments | 1-5 | DELETE | N/A | Instructions about redundancy |
| Overview | 6-18 | ops-database-migration.md | MOVE | Migration principles |
| Directory Structure | 19-31 | ops-database-migration.md | MOVE | File organization |
| Migration File Naming | 32-45 | ops-database-migration.md | MOVE | Naming convention |
| Migration Process | 46-257 | ops-database-migration.md | MOVE | Step-by-step procedures |
| Zero-Downtime Patterns | 258-324 | ops-database-migration.md | MOVE | Migration patterns |
| Compliance Requirements | 325-367 | prd-clinical-trials.md | CROSS-REF | Change control |
| Migration Tools | 368-394 | ops-database-migration.md | MOVE | Tool evaluation |
| Migration Checklist | 395-432 | ops-database-migration.md | MOVE | Template |
| Common Scenarios | 433-459 | ops-database-migration.md | SIMPLIFY | Remove verbose examples |
| Troubleshooting | 460-489 | ops-database-migration.md | MOVE | Common issues |
| References | 490-496 | ops-database-migration.md | MOVE | Links |
| Change Log | 497-503 | ops-database-migration.md | MOVE | Version history |
| Approval | 504-516 | ops-database-migration.md | MOVE | Document metadata |

**Redundancy Assessment**: Examples section has duplication (per TODO)
**Extraction Complexity**: LOW
**Compliance Risk**: HIGH (change control procedures)
**Action**: Move complete, simplify "Common Scenarios" section to remove verbose examples that duplicate PRODUCTION_OPERATIONS.md

---

### Security Files

#### 15. SECURITY.md → prd-security.md + ops-security.md
**Lines**: 484 | **Status**: Mixed PRD and OPS content

| Section | Lines | Destination | Action | Notes |
|---------|-------|-------------|--------|-------|
| Overview | 1-20 | prd-security.md | MOVE | Security architecture |
| Encryption | 21-85 | prd-security.md | SPLIT | Architecture → PRD, Config → OPS |
| Access Controls | 86-151 | prd-security-RLS.md | MOVE | RLS policies |
| Authentication | 152-193 | prd-security.md | MOVE | Auth requirements |
| Audit Trail | 194-233 | prd-clinical-trials.md | CROSS-REF | Compliance reqs |
| Network Security | 234-268 | ops-security.md | MOVE | Operational procedures |
| Security Monitoring | 269-315 | ops-security.md | MOVE | Monitoring setup |
| Incident Response | 316-356 | ops-security.md | MOVE | Response procedures |
| Backup and Recovery | 357-388 | ops-deployment.md | CROSS-REF | Backup procedures |
| Compliance Certifications | 389-424 | prd-clinical-trials.md | MOVE | Compliance status |
| Security Hardening Checklist | 425-463 | ops-security.md | MOVE | Operational checklist |
| Contact | 464-466 | ops-security.md | MOVE | Contact info |
| Revision History | 467-484 | Both | SPLIT | Maintain in both files |

**Redundancy Assessment**: Well-organized, minimal duplication
**Extraction Complexity**: MEDIUM (requires careful PRD/OPS split)
**Compliance Risk**: HIGH (security architecture is compliance-critical)
**Action**: Split between PRD (architecture/requirements) and OPS (procedures/checklists)

---

#### 16. tamper-proofing.md → ops-security-tamper-proofing.md
**Lines**: 31 | **Status**: Concise PRD/implementation

| Section | Lines | Destination | Action | Notes |
|---------|-------|-------------|--------|-------|
| PRD: Objective | 1-9 | prd-security.md | CROSS-REF | Requirement stated |
| Implementation Checklist | 10-31 | ops-security-tamper-proofing.md | MOVE | Implementation steps |

**Redundancy Assessment**: None - concise and specific
**Extraction Complexity**: LOW
**Compliance Risk**: MEDIUM
**Action**: Move implementation to OPS, cross-reference PRD requirement

---

#### 17. authentication_auditing.md → ops-security-authentication.md
**Lines**: 434 | **Status**: Has TODOs to remove "why" sections

| Section | Lines | Destination | Action | Notes |
|---------|-------|-------------|--------|-------|
| TODO comments | 1-2 | DELETE | N/A | Instructions |
| Why It's Necessary | 3-30 | REVIEW | DELETE? | May be redundant with compliance docs |
| What's Been Added | 31-63 | ops-security-authentication.md | MOVE | Implementation details |
| How to Deploy | 64-149 | ops-security-authentication.md | MOVE | Deployment guide |
| Compliance Reports | 150-223 | ops-security-authentication.md | MOVE | Report queries |
| OAuth Provider Tracking | 224-272 | ops-security-authentication.md | MOVE | Provider details |
| Integration | 273-324 | dev-database-queries.md | CROSS-REF | Query examples |
| Row-Level Security | 325-339 | prd-security-RLS.md | CROSS-REF | RLS policies |
| Comparison with ctest | 340-354 | DELETE | N/A | Project-specific comparison |
| Deployment Checklist | 355-368 | ops-security-authentication.md | MOVE | Checklist |
| Maintenance | 369-390 | ops-security-authentication.md | MOVE | Ongoing tasks |
| Regulatory Audits | 391-420 | ops-security-authentication.md | MOVE | Audit procedures |
| Conclusion | 421-434 | DELETE | N/A | Summary |

**Redundancy Assessment**: "Why" section likely duplicates compliance practices
**Extraction Complexity**: LOW
**Compliance Risk**: MEDIUM
**Action**: Remove "why" and conclusion sections if redundant, move implementation and procedures to OPS

---

#### 18. DATA_CLASSIFICATION.md → prd-security.md + ops-security.md
**Lines**: 396 | **Status**: Has TODOs about redundancy

| Section | Lines | Destination | Action | Notes |
|---------|-------|-------------|--------|-------|
| TODO comments | 1-3 | DELETE | N/A | Instructions |
| Executive Summary | 4-20 | prd-security.md | MOVE | Privacy-by-design principle |
| Data Classification | 21-119 | prd-security.md | MOVE | Classification schema |
| Encryption Strategy | 120-178 | prd-security.md | MOVE | Encryption decisions |
| Privacy-by-Design | 179-221 | prd-security.md | MOVE | Architecture approach |
| Compliance Justification | 222-263 | prd-clinical-trials.md | MOVE | Regulatory compliance |
| Security Controls | 264-291 | ops-security.md | MOVE | Operational controls |
| Risk Assessment | 292-331 | ops-security.md | MOVE | Threat analysis |
| Developer Guidelines | 332-354 | dev-security.md | MOVE | Coding guidelines |
| Audit Checklist | 355-372 | ops-security.md | MOVE | Verification checklist |
| References | 373-389 | prd-security.md | MOVE | Regulatory references |

**Redundancy Assessment**: Check against SECURITY.md for duplication
**Extraction Complexity**: MEDIUM
**Compliance Risk**: HIGH
**Action**: Compare with SECURITY.md, merge/consolidate where appropriate

---

### Data Model Files

#### 19. JSONB_SCHEMA.md → dev-data-models.md + dev-data-models-jsonb.md
**Lines**: 503 | **Status**: Has TODO about "single source of truth"

| Section | Lines | Destination | Action | Notes |
|---------|-------|-------------|--------|-------|
| TODO comments | 1-3 | DELETE | N/A | Instructions |
| Document Information | 4-12 | dev-data-models.md | MOVE | Metadata |
| Overview | 13-30 | dev-data-models.md | MOVE | Architecture context |
| Design Principles | 31-53 | dev-data-models.md | MOVE | ALCOA+, versioning, UUID |
| Top-Level Structure | 54-80 | dev-data-models-jsonb.md | MOVE | EventRecord schema |
| Event Type: Epistaxis | 81-230 | dev-data-models-jsonb.md | MOVE | Epistaxis schema v1.0 |
| Event Type: Survey | 231-338 | dev-data-models-jsonb.md | MOVE | Survey schema v1.0 |
| Future Event Types | 339-349 | dev-data-models.md | MOVE | Roadmap |
| Schema Evolution | 350-381 | dev-data-models.md | MOVE | Versioning strategy |
| Database Storage | 382-446 | dev-database.md | CROSS-REF | Storage implementation |
| Validation Requirements | 447-463 | dev-database.md | CROSS-REF | Validation functions |
| Compliance Notes | 464-489 | dev-compliance-practices.md | CROSS-REF | ALCOA+ application |
| References | 490-503 | dev-data-models.md | MOVE | Links |

**Redundancy Assessment**: Unique schema definitions
**Extraction Complexity**: MEDIUM
**Compliance Risk**: HIGH (data model is compliance-critical)
**Action**: Split overview/principles (→ dev-data-models.md) from detailed schemas (→ dev-data-models-jsonb.md)
**TODO Resolution**: Each schema version becomes its own section, clearly marked

---

#### 20. LOGGING_STRATEGY.md → dev-compliance-practices.md
**Lines**: 505 | **Status**: Has TODO "might be entirely redundant"

| Section | Lines | Destination | Action | Notes |
|---------|-------|-------------|--------|-------|
| TODO comment | 1-2 | DELETE | N/A | Instructions |
| Overview | 3-14 | dev-compliance-practices.md | COMPARE | Check if exists |
| Audit Trail (Compliance) | 15-78 | dev-compliance-practices.md | COMPARE | Already documented? |
| Operational Logging | 79-197 | dev-compliance-practices.md | COMPARE | Observability section |
| Separation of Concerns | 198-211 | dev-compliance-practices.md | COMPARE | Key distinction |
| Examples | 212-301 | dev-compliance-practices.md | MERGE | Add if not present |
| Application Layer | 302-334 | dev-compliance-practices.md | MERGE | Implementation guide |
| Compliance Implications | 335-373 | prd-clinical-trials.md | CROSS-REF | Regulatory impact |
| Monitoring & Alerting | 374-410 | ops-deployment.md | CROSS-REF | Operational procedures |
| Testing | 411-446 | dev-compliance-practices.md | MERGE | Test examples |
| Team Training | 447-474 | dev-compliance-practices.md | MERGE | Guidelines |
| Summary | 475-489 | dev-compliance-practices.md | MERGE | Decision matrix |
| References | 490-505 | dev-compliance-practices.md | UPDATE | Cross-references |

**Redundancy Assessment**: CHECK - may duplicate dev-compliance-practices.md observability section
**Extraction Complexity**: HIGH (requires detailed comparison)
**Compliance Risk**: MEDIUM
**Action**: Compare line-by-line with dev-compliance-practices.md lines 383-501 (Observability section)
**Hypothesis**: This file expands on that section - either:
  A) Merge expansions into dev-compliance-practices.md, OR
  B) Keep separate as detailed reference, update dev-compliance-practices.md to reference it

**Decision Required**: Which approach?

---

## Extraction Strategy

### Phase 1: Low-Risk Moves (Complete First)

**Files with minimal dependencies, low compliance risk:**

1. ✅ **prd-role-based-user-stories.md** → prd-security-RBAC.md
   - Simple append operation
   - No dependencies

2. ✅ **dev-continuous-compliance.md** → dev-compliance-practices.md
   - Simple append operation
   - Complements existing content

3. ✅ **database_code_reference.md** → dev-database-queries.md
   - Self-contained examples
   - Low complexity

4. ✅ **PRODUCTION_OPERATIONS.md** → ops-deployment.md
   - Case study, self-contained
   - Valuable example

5. ✅ **tamper-proofing.md** → ops-security-tamper-proofing.md
   - Short, focused content
   - Clear destination

### Phase 2: Moderate-Risk Splits (Requires Careful Review)

**Files requiring PRD/OPS/DEV separation:**

6. 🟡 **SECURITY.md** → prd-security.md + ops-security.md
   - Split architecture from procedures
   - Review for completeness

7. 🟡 **DATA_CLASSIFICATION.md** → prd-security.md + ops-security.md
   - Check overlap with SECURITY.md
   - Merge complementary content

8. 🟡 **prd-role-based-access-spec.md** → prd-security-RBAC.md
   - Merge with db-spec.md RBAC section
   - Resolve conflicts

9. 🟡 **JSONB_SCHEMA.md** → dev-data-models.md + dev-data-models-jsonb.md
   - Split overview from schemas
   - Maintain version tracking

10. 🟡 **PROJECT_SUMMARY.md** → prd-app.md
    - Extract references vs. duplicate content
    - Update file references

### Phase 3: High-Risk Analysis (Requires Detailed Comparison)

**Files with TODOs requiring verification:**

11. 🔴 **database_reference2.md** → ANALYZE
    - Line-by-line comparison with database_setup.md and database_code_reference.md
    - Extract ONLY unique content
    - Delete after verification

12. 🔴 **LOGGING_STRATEGY.md** → dev-compliance-practices.md OR separate?
    - Compare with dev-compliance-practices.md Observability section
    - Decide: merge or reference
    - **Decision point**

13. 🔴 **authentication_auditing.md** → ops-security-authentication.md
    - Remove "why" sections per TODO
    - Extract implementation/procedures only
    - Verify no loss of unique content

14. 🔴 **ops_schema_migration.md** → ops-database-migration.md
    - Simplify verbose examples per TODO
    - Keep procedures, reduce redundant examples

### Phase 4: Constitutional Integration (Handle Last)

**Files requiring special handling:**

15. 🟣 **dev-principles-quick-reference.md** ↔ dev-core-practices.md
    - **Decision Required**: Merge or reference?
    - Option A: Keep as quick reference, update cross-refs
    - Option B: Integrate into dev-core-practices.md as "Quick Reference" section
    - **Recommendation**: Option B (single source of truth)

16. 🟣 **dev-compliance-practices.md** → Split or keep?
    - Some regulatory content belongs in prd-clinical-trials.md
    - Some security content overlaps with dev-security.md
    - **Recommendation**: Keep mostly intact, cross-reference to PRD for regulatory requirements

17. 🟣 **db-spec.md** → Split carefully
    - Core PRD document, multiple destinations
    - Requires careful splitting with clear cross-references
    - Extract last to ensure destination files are ready

### Phase 5: Core PRD Distribution (Final Step)

18. 🟣 **db-spec.md** → prd-database.md + prd-database-event-sourcing.md + prd-security-*.md
    - Extract to already-populated destination files
    - Maintain as primary reference until distribution complete
    - Verify all cross-references work

---

## Redundancy Analysis

### True Redundancy (Safe to Consolidate)

| Content | Location 1 | Location 2 | Action |
|---------|-----------|------------|--------|
| Supabase setup steps | database_setup.md | database_reference2.md | Keep database_setup.md version |
| SQL query examples | database_code_reference.md | database_reference2.md | Keep database_code_reference.md |
| RBAC role definitions | db-spec.md | prd-role-based-access-spec.md | Merge, keep combined |
| Audit vs logging | dev-compliance-practices.md | LOGGING_STRATEGY.md | Compare, merge or reference |

### Complementary Content (Different Abstraction Levels - KEEP)

| Topic | PRD Level | OPS Level | DEV Level |
|-------|-----------|-----------|-----------|
| Encryption | Requirements (prd-security.md) | Configuration (ops-security.md) | Implementation (dev-security.md) |
| RBAC | Role definitions (prd-security-RBAC.md) | Assignment procedures (ops-security.md) | RLS queries (dev-database-queries.md) |
| Audit Trail | Requirements (prd-clinical-trials.md) | Monitoring (ops-deployment.md) | Implementation (dev-compliance-practices.md) |

---

## Cross-Reference Strategy

### Reference Format

Use consistent format for cross-references:

```markdown
> **See**: prd-security.md for security requirements
> **See**: ops-security.md for operational procedures
> **See**: dev-security.md for implementation guide
```

### Bidirectional Links

Create bidirectional references for related content:

- **prd-security.md** references → ops-security.md, dev-security.md
- **ops-security.md** references → prd-security.md (requirements), dev-security.md (implementation)
- **dev-security.md** references → prd-security.md (requirements), ops-security.md (deployment)

### Index File

Update **README.md** to include:
- File hierarchy map
- Topic index (alphabetical)
- Audience guide (by role)

---

## Compliance Risk Matrix

| File | Compliance Impact | Risk Level | Mitigation |
|------|------------------|------------|------------|
| db-spec.md | Core PRD for FDA | **HIGH** | Extract last, verify completeness |
| dev-compliance-practices.md | Implementation guide | **HIGH** | Preserve all ALCOA+ content |
| SECURITY.md | Security architecture | **HIGH** | Verify all sections preserved |
| ops_schema_migration.md | Change control | **HIGH** | Maintain change procedures |
| JSONB_SCHEMA.md | Data model | **HIGH** | Preserve all schema versions |
| dev-core-practices.md | Constitutional principles | **MEDIUM** | Keep intact, no splitting |
| DEPLOYMENT_CHECKLIST.md | Deployment procedures | **MEDIUM** | Maintain complete checklist |
| database_setup.md | Setup procedures | **MEDIUM** | Preserve all steps |
| DATA_CLASSIFICATION.md | Privacy architecture | **MEDIUM** | Verify all classifications preserved |

---

## Verification Checklist

After extraction, verify:

- [ ] All constitutional principles (🔒) preserved and traceable
- [ ] All compliance requirements (FDA, HIPAA, GDPR) documented
- [ ] All TODOs addressed
- [ ] No content deleted without verification
- [ ] Cross-references accurate and complete
- [ ] README.md updated with new structure
- [ ] All code references still valid (if any reference these docs)
- [ ] Audit trail of changes documented

---

## Decision Points Requiring Approval

### 1. dev-principles-quick-reference.md
**Question**: Merge into dev-core-practices.md or keep separate?
**Option A**: Merge as "Quick Reference" section in dev-core-practices.md
**Option B**: Keep as separate quick-reference card
**Recommendation**: Option A (single source of truth)

### 2. LOGGING_STRATEGY.md
**Question**: Is this redundant with dev-compliance-practices.md Observability section?
**Option A**: Merge unique content into dev-compliance-practices.md
**Option B**: Keep separate as detailed logging guide
**Recommendation**: Needs detailed comparison before deciding

### 3. database_reference2.md
**Question**: Delete after extracting unique content?
**Action**: Line-by-line comparison required
**Recommendation**: Do NOT delete until 100% verified

### 4. Constitutional Content
**Question**: How strictly should we preserve constitutional principles?
**Recommendation**: NO splitting of constitutional sections - preserve as single source of truth

---

## Next Steps

1. **Review this extraction plan**
2. **Approve decision points**
3. **Execute Phase 1** (low-risk moves)
4. **Review Phase 1 results**
5. **Execute remaining phases sequentially**
6. **Final verification and cleanup**

---

## Estimated Effort

- **Phase 1**: 1-2 hours (5 files, straightforward)
- **Phase 2**: 2-3 hours (5 files, requires splitting)
- **Phase 3**: 3-4 hours (4 files, requires analysis)
- **Phase 4**: 2-3 hours (3 files, constitutional handling)
- **Phase 5**: 2-3 hours (1 file, careful extraction)
- **Verification**: 2-3 hours
- **Total**: 12-18 hours of focused work

---

**Status**: DRAFT - Awaiting Approval
**Prepared by**: Claude Code
**Date**: 2025-10-17
