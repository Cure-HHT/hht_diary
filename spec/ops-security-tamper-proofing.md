# Tamper-Proofing & Auditability Implementation

**Version**: 1.0
**Audience**: Operations/DevOps
**Last Updated**: 2025-10-17

> **See**: prd-security.md for security requirements
> **See**: ops-security-authentication.md for authentication auditing
> **See**: prd-clinical-trials.md for compliance requirements

---

## Objective
Provide tamper-evident auditing for schema/permission changes and privileged operations to satisfy HIPAA and 21 CFR Part 11 expectations.

## Scope
- In-scope: DDL, GRANT/REVOKE, role creation, RLS changes, admin break-glass access, exports.
- Out-of-scope: UX feature design, schema modeling.

## Requirements
- Enable pgaudit for DDL and auth events.
- Insert-only audit schema; daily checkpoint to Storage with hash chain.
- Break-glass API with reason, approver, TTL; tag all elevated actions.
- Alerts for RLS disabled, super-role grants, mass export.

# Implementation: Tamper-Proofing on Supabase (DRAFT)

## Stack
- Supabase Postgres with pgaudit
- Audit schema (+ Storage checkpoints)
- Edge Functions for alerts and break-glass

## Checklist
1. Enable pgaudit and verify logs.
2. Create audit schema; grant INSERT-only to audit_writer.
3. Triggers for role/GRANT changes, RLS changes, export jobs.
4. Break-glass endpoints; short-lived JWT with elevated role; auto-revoke.
5. Email/webhook alerts for critical events.
6. Nightly checkpoint with SHA-256 chain.
7. Weekly digest; limited read access to Auditor/Admin (RO).

---

## References

- **Security Architecture**: prd-security.md
- **Authentication Auditing**: ops-security-authentication.md
- **Compliance Requirements**: prd-clinical-trials.md
- **Database Setup**: ops-database-setup.md

---

**Source Files**:
- `tamper-proofing.md` (moved 2025-10-17)
