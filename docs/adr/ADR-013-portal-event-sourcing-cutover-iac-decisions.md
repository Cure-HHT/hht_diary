# ADR-013: Portal `event_sourcing_datastore` Cutover — Database Administration & IaC Boundary Decisions

**Date**: 2026-04-26
**Deciders**: TBD
**Compliance**: FDA 21 CFR Part 11
**Ticket**: [CUR-1170](https://linear.app/cure-hht-diary/issue/CUR-1170/portal-sponsor-portal-event-source-cutover-onto-portal-actions-unified)

## Status

Proposed — decisions deferred.

This ADR enumerates the architecture decisions that the portal cutover from raw `package:postgres` to `event_sourcing_datastore` (via a new `PostgresBackend` implementation of `StorageBackend`) will force. It does NOT resolve them. Its purpose is to record the question surface so that none of these decisions is forgotten before CUR-1170 begins implementation, and so that each can move from "open" to "resolved" individually.

---

## Context

**Foundations**: CUR-1154 delivers `event_sourcing_datastore` and the `StorageBackend` abstraction. CUR-1159 delivers events-lib extensions and the `portal_actions` library (`ActionDispatcher`, `AuthorizationPolicy`, `IdempotencyStore`). CUR-1170 is the portal-app consumption of those foundations.

The CUR-1159 design (`docs/superpowers/specs/2026-04-22-events-lib-extensions-design.md:840`) explicitly defers the PostgreSQL `StorageBackend` implementation to "a separate port to portal ticket" — that ticket is CUR-1170, and this ADR is the architectural anchor for it.

### Current state (verified in repo)

The portal-server today does NOT use `append_only_datastore` or `event_sourcing_datastore`. It uses `package:postgres` directly (`apps/sponsor-portal/portal_functions/lib/src/database.dart`), setting RLS session variables (`request.jwt.claims`, `role`, `user_id`) before each query. Auditing and authorization live entirely in PostgreSQL: 35 KB of RLS policies (`database/rls_policies.sql`), an immutable event store (`record_audit`/`record_state` in `database/schema.sql`), tamper-evident hash chains (`database/tamper_detection.sql`), separate audit tables (`admin_action_log`, `portal_user_audit_log`, `auth_audit_log`, `email_audit_log`), and a SQL break-glass primitive (`break_glass_authorizations` table at `database/schema.sql:498-549` plus `has_break_glass_auth()` — REQ-o00026).

Database deployment is split between Terraform and human/CI hands:

```text
+------------------+    +-------------------------+    +-------------------+
| Terraform        |    | Hand / CI               |    | Portal app        |
+------------------+    +-------------------------+    +-------------------+
| Cloud SQL inst.  |    | postgres superuser:     |    | connects only     |
|   pgaudit on     |    |   provenance unknown    |    | as app_user      |
|   PITR, backups  |    | schema/triggers/RLS:    |    | sets RLS session  |
|   private VPC IP |    |   psql, CI test only    |    |   vars per query  |
| Database (one)   |    |   no prod deploy path   |    | NO DDL            |
| app_user         |    | first-admin seed:       |    | does NOT call     |
|   pwd from tf    |    |   sponsor seed_data.sql |    |   break_glass_*   |
|   var (Doppler)  |    |   manual psql           |    +-------------------+
| Audit-logs GCS   |    | DB_PASSWORD: tf var,    |
|   25-yr lock     |    |   not in Secret Manager |
|   for cloudaudit |    | break-glass: SQL only,  |
|   (NOT pgaudit)  |    |   no operator tool      |
+------------------+    +-------------------------+
```

References: `infrastructure/terraform/modules/cloud-sql/main.tf:81-210`, `infrastructure/terraform/modules/audit-logs/main.tf:48-142`, `database/README.md:131-192`.

### Cutover delta (per CUR-1170)

The portal will refactor onto `PostgresBackend`; `ActionDispatcher` will mediate UI dispatch with idempotency and denial-event telemetry; the role-permission matrix produced by the `portal_actions` permission-discovery tool will replace today's RLS-driven authorization surface; and `admin_action_log`, `portal_user_audit_log`, `auth_audit_log`, `email_audit_log` will consolidate into the unified event log.

This consolidation forces decisions that today's raw-Postgres model did not have to make.

---

## Decision

**Decision deferred.** This ADR records the open questions and the trade-offs framing each. Each will be resolved either in CUR-1170's implementation plan or in a follow-up ADR before CUR-1170 implementation lands.

### Open decisions

#### A. Schema ownership

Will `PostgresBackend` own the DDL for the unified event log, or will those tables continue to live in `database/*.sql` and be applied by ops?

- **A1.** Library-owned: the library ships migrations, deploy step calls `PostgresBackend.migrate()`, schema versioning is internal to the library.
- **A2.** Ops-owned: tables live in `database/*.sql`, applied by ops/CI as today; the library only reads/writes them.
- **A3.** Split: library owns event-log tables; ops owns sponsor-specific projections, RLS policies, and the role-permission matrix.

Frame: where does the version-of-record for schema state live, and who is responsible for forward/back compatibility when the library evolves? Interacts with `docs/superpowers/specs/2026-04-26-phase4.19-event-promoter-design.md` (chain-of-promoters strategy for schema evolution).

#### B. Production schema deploy path

Today the schema is applied as `postgres` superuser via psql in the CI test path. There is no production path; the cutover adds new tables (event log, role-permission matrix), forcing the question.

- **B1.** Named `migrator` role distinct from superuser, granted only DDL on the relevant schemas, credential held by CD.
- **B2.** CD job runs as superuser via a short-lived credential issued by Cloud SQL IAM authentication.
- **B3.** Library-driven migration at app startup using `app_user` (requires elevating `app_user`'s privileges — generally undesirable).

Frame: who holds the `postgres` superuser credential today is undocumented. The cutover is the natural moment to close that gap rather than perpetuate it.

#### C. Postgres role / GRANT model

With `PostgresBackend` writing the event log on every action, does it deserve a distinct DB role from the read-side?

- **C1.** One `app_user`, table-level GRANTs revoke `UPDATE`/`DELETE`/`TRUNCATE` on event-log tables.
- **C2.** Two roles: `event_writer` (INSERT-only on event log) and `app_user` (SELECT on projections), with the library connecting as both.
- **C3.** One `app_user`, append-only enforced only by triggers (current model).

Frame: C2 makes "the portal cannot retroactively edit history" enforceable by GRANT, not just by trigger. Tamper-evidence under Part 11 favors GRANT-level enforcement.

#### D. Authorization surface

Today RLS policies are the authorization surface. CUR-1170 introduces a role-permission matrix consumed by `AuthorizationPolicy`. Will RLS be removed, retained as defense-in-depth, or restructured?

- **D1.** Remove RLS entirely; trust the dispatcher.
- **D2.** Retain RLS as a coarse-grained backstop (e.g. patient_id isolation) while the matrix handles fine-grained permissions.
- **D3.** Restructure RLS so it consumes the same matrix (matrix is the source of truth, RLS reads it via session variable).

Frame: defense-in-depth is the FDA-friendly answer, but D2/D3 add complexity. CUR-1170 declares scope-aware permissions out of scope; D2 might cover patient-scoping during the transition.

#### E. Audit-log consolidation strategy

CUR-1170 lists `admin_action_log`, `portal_user_audit_log`, `auth_audit_log`, `email_audit_log` for consolidation into the unified event log. Cutover style?

- **E1.** Cutover with frozen legacy tables (read-only after the switch).
- **E2.** Cutover plus one-time backfill that emits synthetic events from existing rows.
- **E3.** Drop legacy tables (greenfield — no historical data yet).

Frame: project state is greenfield, never deployed. E3 is likely correct, but worth recording the choice explicitly so it is not re-litigated.

#### F. Break-glass mechanics

Today break-glass is a SQL function (`has_break_glass_auth()`) plus an `admin_action_log` write. Under the unified event log, `admin_action_log` goes away. Does break-glass become an action with its own typed event?

- **F1.** `BreakGlassGrantedEvent` flows through `ActionDispatcher` like any other action; tamper-evident under the same hash chain.
- **F2.** Break-glass remains a SQL-side primitive invoked out-of-band, with a follow-on event recorded.
- **F3.** Replace break-glass with a two-person-rule action protocol.

Frame: F1 is the cleanest fit and gives Part 11 tamper-evidence "for free," but it requires the operator UX (today: nonexistent) to be designed at the same time.

#### G. Secret Manager wiring

Today `DB_PASSWORD` enters Terraform as a tf variable (origin: Doppler at `terraform apply` time). The cutover does not strictly require a change, but the gap is small enough to close together.

- **G1.** Provision `google_secret_manager_secret`/`_version` in Terraform; mount into Cloud Run via secret env binding.
- **G2.** Continue with env-var injection from Doppler in CI/CD.

Frame: Secret Manager + IAM gives a more auditable secret-rotation story; Doppler+env is what the team uses today.

#### H. pgaudit log destination

pgaudit is enabled on the instance, but only `cloudaudit.*` (admin plane) has a locked-retention GCS sink. pgaudit data-plane logs flow to Cloud Logging without a dedicated sink.

- **H1.** Add a `google_logging_project_sink` for pgaudit and route to a separate GCS bucket the portal SA cannot read or delete.
- **H2.** Leave pgaudit in Cloud Logging; lock retention on the log bucket itself.

Frame: Part 11 requires tamper-evident audit trails. If the portal SA can ever reach the audit logs, the chain is in-blast-radius.

### Out of scope for this ADR

- Wire format / event schema details — covered by `docs/superpowers/specs/2026-04-25-phase4.16-event-versioning-design.md`.
- Mobile-side concerns — owned by CUR-1154 and the mobile-event-sourcing-refactor branch.
- Per-area portal action catalog — per-area sub-issues per CUR-1170.
- Role-permission matrix admin GUI — explicitly out of scope per CUR-1170.

---

## Consequences

### Positive

- A single document records the IaC/admin/bootstrap/lockdown decision surface for the portal cutover, so design conversations do not have to re-discover the questions.
- Decisions are individually addressable (A through H). Each can move from "open" to "resolved" independently, in this ADR or in follow-on ADRs.
- Several gaps in the *current* IaC story (B, G, H) get surfaced for closure during the cutover, rather than persisting indefinitely.

### Negative

- Until the decisions are made, work on CUR-1170 cannot start in earnest — only foundational work that is invariant under all options.
- Some decisions are coupled (notably A↔B↔C and C↔D↔F). Resolving them out of order risks rework.

---

## Alternatives Considered

**Resolve all decisions in this ADR now.** Rejected: the team is not prepared to make these decisions today, and forcing premature resolution would lock in possibly wrong answers under FDA constraints.

**Defer all of this to CUR-1170's implementation plan.** Rejected: the questions are architecture-level, not implementation-level, and would lose visibility inside an implementation plan.

**Capture as a checklist on the ticket only.** Rejected: ADRs are the project's chosen vehicle for architectural decisions and have a review/approval lifecycle; tickets do not.

---

## Related Decisions

- **ADR-001**: Event Sourcing Pattern — provides the Part 11 frame this ADR's decisions inherit.
- **ADR-003**: Row-Level Security — Decision D may deprecate or restructure ADR-003.
- **ADR-005**: Database Migration Strategy — Decisions A and B refine or partially supersede ADR-005 for the unified event log.
- **ADR-009**: Pulumi Infrastructure as Code — Decisions B, G, H operate within ADR-009's IaC boundary.
- **ADR-011**: Event Sourcing Refinements — Decision E inherits ADR-011's model.
- **CUR-1170**: Portal sponsor-portal event-source cutover (ticket implementing the decisions in this ADR).
- **CUR-1154**: `event_sourcing_datastore` library + `StorageBackend` abstraction.
- **CUR-1159**: `portal_actions` library, events-lib extensions.

Requirement assignments (REQ-d / REQ-o) are TBD; they will be claimed in the CUR-1170 implementation plan once decisions A–H are resolved.

---

## References

- `docs/superpowers/specs/2026-04-22-events-lib-extensions-design.md:840` — `StorageBackend` contract; explicitly defers PostgreSQL backend to a separate port-to-portal ticket.
- `docs/superpowers/specs/2026-04-26-phase4.19-event-promoter-design.md` — chain-of-promoters strategy for event-schema evolution (relevant to Decision A).
- `apps/sponsor-portal/portal_functions/lib/src/database.dart` — current portal DB layer (no datastore lib).
- `database/schema.sql:498-549` — `break_glass_authorizations` and audit tables.
- `database/rls_policies.sql` — current authorization surface (relevant to Decision D).
- `infrastructure/terraform/modules/cloud-sql/main.tf:81-210` — current Cloud SQL provisioning.
- `infrastructure/terraform/modules/audit-logs/main.tf:48-142` — current audit-log GCS sink.
- `database/README.md:131-192` — first-admin seeding via sponsor-repo `seed_data.sql`.

---

## Change Log

| Date       | Change                                          | Author                          |
|------------|-------------------------------------------------|---------------------------------|
| 2026-04-26 | Initial ADR (Proposed; decisions A–H deferred)  | Michael Lewis with Claude Code  |
