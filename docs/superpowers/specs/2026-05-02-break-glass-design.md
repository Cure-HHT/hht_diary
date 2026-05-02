# Break-Glass GCP Access via GitHub Actions — Phase 1 Design

**Date:** 2026-05-02
**Ticket:** [CUR-1227](https://linear.app/cure-hht-diary/issue/CUR-1227)
**Parent capability:** [CUR-647](https://linear.app/cure-hht-diary/issue/CUR-647) (zero-trust GCP administration)
**Branch:** `claude/break-glass-gcp-actions-afLN6`
**Scope:** Core repo `hht_diary` (reusable workflows, composite actions, runbook); sponsor wrappers in `hht_diary_callisto`. Sponsor-side files are out of scope for this PR but the contract is fixed here.

## Summary

DevOps engineers hold no standing GCP roles. When an incident requires elevated access, they dispatch a GitHub Actions workflow that grants a time-bound IAM binding directly to their `@anspar.org` identity, with notification to Slack and tamper-evident logging in GCP Cloud Audit Logs. Two flavors: read-only (self-service, up to 24h) and elevated (approval-gated, up to 4h). A weekly sweeper removes expired bindings; a doctor workflow validates provisioning state.

## Architecture

```text
+------------------------+        +-------------------------+
| sponsor repo wrapper   |        | core repo reusable      |
| break-glass-readonly   | -uses-> reusable-break-glass-    |
| break-glass-elevated   |        | grant.yml               |
+------------------------+        +-------------------------+
        |                                    |
        | env-gate (elevated only)           | OIDC -> WIF
        v                                    v
   GitHub Environment              binding-manager-<env> SA
   breakglass-<env>                (roles/resourcemanager.
   (required reviewers,             projectIamAdmin)
    excludes self)                          |
                                            v
                                   gcloud projects
                                   set-iam-policy
                                   (transactional, etag)
                                            |
                +---------------------------+--------+
                |                           |        |
                v                           v        v
         user binding              GCP Cloud      Slack
         user:alice@anspar.org     Audit Logs     bot
         + CEL: request.time <     (system of     (channel
         timestamp("<expiry>")     record)        + DM)
         title: breakglass-<run-id>
```

Three reusable workflows in core, one composite for Slack, one composite for the doctor (modes: static / preflight / full):

```text
hht_diary/.github/
├── workflows/
│   ├── reusable-break-glass-grant.yml      # workflow_call
│   ├── reusable-break-glass-sweep.yml      # workflow_call
│   └── reusable-break-glass-doctor.yml     # workflow_call (mode=full)
└── actions/
    ├── notify-devops-breakglass/action.yml # composite, owns Slack routing table
    └── breakglass-doctor/action.yml        # composite, mode: static|preflight|full
```

Sponsor wrappers (separate PR / repo):

```text
hht_diary_callisto/.github/
├── workflows/
│   ├── break-glass-readonly.yml            # workflow_dispatch -> grant
│   ├── break-glass-elevated.yml            # workflow_dispatch (env-gated) -> grant
│   ├── break-glass-sweep.yml               # cron 0 18 * * 1 + dispatch
│   └── break-glass-doctor.yml              # workflow_dispatch
├── breakglass-roster.yml                   # github_login -> @anspar.org email
└── CODEOWNERS                              # 2 reviewers required on roster
```

## Components

### 1. `reusable-break-glass-grant.yml`

**Inputs:** `gcp_project_id`, `wif_provider`, `binding_manager_sa`, `roster_path`, `environment_label` (dev/qa/uat), `roles` (JSON array), `duration_minutes`, `max_duration_minutes`, `ticket` (CUR-XXX), `justification`, `dry_run`, `slack_lifecycle_channel`, `slack_alerts_channel`, `workspace_lookup_sa` (optional).

**Secret:** `slack_bot_token`.

**Outputs:** `expires_at` (ISO-8601 Z), `condition_title` (`breakglass-<run-id>`), `roles_applied` (JSON array).

**Steps:**

1. **Validate inputs** — `ticket` matches `^CUR-\d+$`; `duration_minutes` ∈ [15, min(max_duration_minutes, 1440)]; `roles` parses as non-empty JSON array; no role hits the denylist (predefined names + patterns `*.IamAdmin`, `*.RoleAdmin`, `*.organizationAdmin`, `*.serviceAccountUser`, `*.serviceAccountTokenCreator`).
2. **Resolve grantee** — load `breakglass-roster.yml`, look up `${{ github.actor }}` → email; fail if absent. Validate email ends `@anspar.org`.
3. **Self-grant check** — fail if `${{ github.actor }}` was the most-recent author of `breakglass-roster.yml` within 7 days (queried via `git log`).
4. **Preflight** — invoke `breakglass-doctor` composite with `mode: preflight`. Aborts grant with the doctor's remediation message on any ❌.
5. **Slack: requested** — composite action posts to lifecycle channel with actor, env, roles, duration, ticket, justification, run URL.
6. **Auth** — `google-github-actions/auth@v2` → impersonate `binding_manager_sa` via WIF.
7. **Compute condition** — title `breakglass-<run-id>`, expression `request.time < timestamp("<expires_at>")`, description JSON `{"actor","ticket","justification","run_url","expires_at"}`.
8. **Apply binding (transactional)** — single `get-iam-policy` → mutate in-memory (add one binding per role with the same condition) → single `set-iam-policy` with the captured `etag`. All-or-nothing.
9. **Slack: granted** — composite posts to lifecycle channel + DMs grantee with expiry, roles, hint command (`gcloud auth login <email> && gcloud config set project <project>`).

If `dry_run`, steps 5–9 print to job summary and skip the actual `set-iam-policy`.

### 2. `reusable-break-glass-sweep.yml`

**Inputs:** `gcp_project_id`, `wif_provider`, `binding_manager_sa`, `slack_lifecycle_channel`, `slack_alerts_channel`, `dry_run`.

**Secret:** `slack_bot_token`.

**Steps:**

1. Auth via WIF → impersonate `binding_manager_sa`.
2. `get-iam-policy` (preserves etag).
3. Identify stale: bindings where `condition.title` starts with `breakglass-` AND `description.expires_at` parses + is in the past. Bindings with unparseable description → log to alerts as "manual cleanup needed", leave in policy.
4. Build new policy = original − stale.
5. `set-iam-policy` with original etag. On etag conflict: retry up to 3 times with exponential backoff (2s/4s/8s); after 3 failures, post to alerts and exit success (next week's run picks up).
6. Slack lifecycle summary (always, even N=0): `🧹 Break-glass sweep — <env> · Swept N · Oldest past-expiry: Xd Yh · Roles: <breakdown>`.

Workflow declares `concurrency: breakglass-sweep-${{ inputs.environment_label }}` (cancel-in-progress: false) to prevent racing matrix runs.

### 3. `reusable-break-glass-doctor.yml`

Wraps the `breakglass-doctor` composite at `mode: full`, posts ❌ count + run URL to alerts on failure.

### 4. `actions/notify-devops-breakglass` (composite)

**Inputs:** `event_type` (semantic key), `payload` (JSON), `bot_token`, `lifecycle_channel`, `alerts_channel`, `grantee_email` (optional, for DM lookup).

**Internal routing table:**

```text
event_type           channels                    DM grantee?
-------------------  --------------------------  -----------
grant_requested      [lifecycle]                 no
grant_granted        [lifecycle]                 yes
grant_blocked        [alerts]                    yes
grant_denylist       [alerts]                    yes
sweep_summary        [lifecycle]                 no
sweep_failure        [alerts]                    no
doctor_failure       [alerts]                    no
```

If a target channel is unset, that destination silently no-ops. If both targets resolve to the same channel ID, dedupe (post once). On Slack post failure: `::warning::` annotation, exit 0 (the IAM binding has already been applied — failing the workflow doesn't undo it; GCP audit logs remain authoritative).

Bot scopes: `chat:write`, `chat:write.public`, `users:read`, `users:read.email`.

### 5. `actions/breakglass-doctor` (composite)

Three modes:

- **`static`** — no GCP/Slack API calls. Repo Variables present, secrets present, roster file parses, every email ends `@anspar.org`, each `github_login` is org member (via `GITHUB_TOKEN`), CODEOWNERS covers `breakglass-roster.yml`, caller workflows pin reusable refs by SHA. Suitable for PR CI.
- **`preflight`** — fast live checks before granting. WIF auth succeeds, project visible, binding-manager SA reachable, roster contains actor, configured channel IDs non-empty, Workspace Cloud Identity lookup of actor's email succeeds (required for elevated, warn-only for readonly).
- **`full`** — static + preflight + slow checks. Binding-manager SA holds `roles/resourcemanager.projectIamAdmin`, GitHub Environment `breakglass-<env>` exists with required reviewers + "prevent self-review" enabled, Slack bot is a member of each configured channel, custom roles in project containing `*.setIamPolicy` (warning, for human review against denylist gap), all roster emails resolve in Workspace, Logs Router sink → retention-locked GCS exists for Admin Activity logs.

**Output:** GitHub Actions job summary in markdown — `✅` / `❌` / `⚠️` per check, with copy-pasteable `gcloud` / `gh` remediation command for any `❌`.

### 6. Runbook

`infrastructure/runbooks/break-glass.md` — operator-facing doc covering when to use readonly vs. elevated, who can approve, finding/creating a CUR ticket, what to do if Slack is down, what to do if doctor preflight fails mid-incident. Referenced from each `workflow_dispatch` description.

## Security model

- **Identity** — every binding goes to `user:<email>@anspar.org`. Email resolution is roster-driven (committed YAML in sponsor repo, CODEOWNERS-protected, verified live via Cloud Identity API).
- **Authorization to mint** — only the `binding_manager_<env>` SA can `setIamPolicy`. The runner reaches it only via WIF, with attribute conditions tying the OIDC token to `repo:cure-hht/<sponsor>:*` AND `environment:breakglass-<env>` (the latter forces elevated grants through the GitHub Environment gate).
- **Approval gate** — caller wrapper job declares `environment: breakglass-<env>`; the gate fires on the caller before the reusable executes. "Prevent self-review" is enabled on the Environment so requester ≠ approver.
- **Self-grant prevention** — required-reviewer gate (above) plus a runtime check that blocks grants where `github.actor` was the most-recent author of `breakglass-roster.yml` within 7 days. Closes the "edit roster + immediately request" path even when the requester is also a reviewer.
- **Denylist** — predefined high-risk roles + name patterns are rejected before any binding is attempted. Custom roles containing `*.setIamPolicy` are flagged by the doctor for human review (live permission lookup deferred to v2).
- **Time bound** — `request.time < timestamp("<expiry>")` CEL condition makes expired bindings inert at the deadline (no privilege after expiry, even if the binding remains in the policy until the sweeper removes it).
- **Audit** — GCP Cloud Audit Logs are the system of record (Admin Activity logs cover IAM mutations natively). Logs Router sink → retention-locked GCS provides the long-term, tamper-evident archive for FDA 21 CFR Part 11 retention SLAs. Slack notifications are operational visibility, not the audit record.

## Failure modes

| Failure | Behavior |
| --- | --- |
| Roster missing actor | Grant aborts; alerts post with remediation ("add `<actor>` to `.github/breakglass-roster.yml`") |
| Workspace lookup fails (elevated) | Grant aborts with remediation message |
| Workspace lookup unconfigured (readonly) | Warning in summary; grant proceeds |
| Denylist hit | Grant aborts; alerts + DM to grantee |
| WIF auth fails | Grant aborts; alerts post; doctor full will diagnose |
| Binding-manager SA missing role | Grant aborts mid-`set-iam-policy`; alerts post; doctor full asserts SA roles |
| Etag conflict during grant | Grant fails; user retries (rare in practice — grants are infrequent) |
| Etag conflict during sweep | Retry 3x with backoff; on persistent conflict, post to alerts and exit success (next sweep picks up) |
| Slack outage during grant | Banner + `::error::` annotation; workflow exits 0 (binding succeeded; GCP is SOR) |
| Clock skew | Minimum 15-min duration absorbs typical drift |
| Workflow run cancelled mid-grant | The transactional `set-iam-policy` either committed before cancel (binding present, sweeper handles) or didn't (no binding) — no partial state |

## Test strategy

End-to-end validation in Callisto **dev** environment (no separate sandbox project):

1. Doctor `full` against dev/qa/uat — must pass before manual smoke tests.
2. Readonly grant in dev with `roles/browser` (innocuous), 30min duration. Verify binding lands, condition expires, sweeper removes. Repeat for qa/uat.
3. Elevated grant in dev with `roles/storage.objectViewer`, 30min duration, requires approval. Verify environment gate blocks until approval, binding lands post-approval.
4. Denylist test: dispatch elevated with `roles/owner` — verify rejection + alerts post + DM.
5. Self-grant test: edit roster, immediately dispatch — verify 7-day block triggers.
6. Sweeper dry-run on each env to confirm parsing of real bindings.

CI runs doctor `static` on PRs touching `reusable-break-glass-*.yml`, `notify-devops-breakglass/*`, `breakglass-doctor/*` (core) and `break-glass-*.yml`, `breakglass-roster.yml`, `CODEOWNERS` (sponsor).

## Out of scope (deferred to follow-ons under CUR-647)

- Reminders (scheduled DM N min before expiry)
- Super-break-glass with multi-person approval for currently-denylisted roles
- Live custom-role permission scanning to close the custom-role denylist gap
- Active-grants dashboard view (lives in the DevOps Monitor app — see Notion `3261cf6424e681f39aa9d630a3d92daf`)
- IAM-binding quota alerting in sweeper (warn when approaching the per-resource binding quota)

## Requirements

Implements existing PRD assertions:

- **REQ-p00010** (FDA 21 CFR Part 11 Compliance) — supports ALCOA+ via attributable Workspace identity, contemporaneous Slack + GCP audit logs, tamper-evident retention-locked sink.
- **REQ-p00014** (Least Privilege Access) — DevOps holds no standing roles; access is on-demand, scoped, and time-bound.
- **REQ-p01018** (Security Audit and Compliance) — GCP Cloud Audit Logs are the system of record; per-grant audit chain is reproducible from `condition.title=breakglass-<run-id>` back to the GitHub run, the requesting actor's roster entry, and the approval reviewer.

This phase introduces:

- **REQ-o00084: DevOps Break-Glass GCP Access** — capability requirement, written to `spec/ops-break-glass.md`. Implements REQ-p00014 and REQ-p01018. Assertions:
  - A. The system SHALL bind elevated GCP roles to `@anspar.org` Workspace identities only.
  - B. The system SHALL bind elevated GCP roles for a finite duration not exceeding 24 hours, enforced by an IAM Condition on the binding.
  - C. The system SHALL deny grants of privilege-escalation roles (predefined name list and pattern match) without exception in Phase 1.
  - D. The system SHALL require approval by a second authorized reviewer for any grant of write or admin roles.
  - E. The system SHALL emit an audit-grade record of every grant request, approval, denial, and revocation that is retained for the sponsor's retention SLA.
  - F. The system SHALL prevent a requester from also acting as their own approver.

- **REQ-d00161: Break-Glass Workflow Implementation** — implementation requirement, written to `spec/dev-break-glass.md`. Implements REQ-o00084. Assertions:
  - A. The grant workflow SHALL apply IAM bindings transactionally (single `set-iam-policy` with `etag`); partial role application SHALL NOT occur.
  - B. The grant workflow SHALL invoke the doctor's preflight checks before any IAM mutation and SHALL abort with the doctor's remediation message on failure.
  - C. The sweeper workflow SHALL identify stale bindings by `condition.title` prefix `breakglass-` AND past-expiry parsed from `condition.description.expires_at`, and SHALL retry etag conflicts up to three times with exponential backoff before deferring.
  - D. The Slack composite action SHALL route events to channels per a fixed routing table owned in the composite, and SHALL exit success on Slack post failure (the binding is the system of record).
  - E. The roster file SHALL be the sole source of `github.actor` → `@anspar.org` email mapping, and SHALL be CODEOWNERS-protected requiring two reviewers.
  - F. Identity verification SHALL include a Cloud Identity API lookup of the resolved email; verification failure SHALL abort elevated grants and SHALL warn but proceed for readonly grants.

Per CLAUDE.md §"Phase Design Spec Requirements", per-implementation `// Implements: REQ-X-A+B — prose` and per-test `// Verifies: REQ-X-A` annotations are required on every implementation/test file this phase touches. The implementation plan will write REQ-o00084 and REQ-d00161 to `spec/ops-break-glass.md` and `spec/dev-break-glass.md` respectively, and `elspais fix` will regenerate `spec/INDEX.md`.
