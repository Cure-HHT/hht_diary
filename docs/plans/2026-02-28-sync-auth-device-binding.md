# Sync Authentication Device Binding — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add formal requirement assertions for server-side device UUID verification during sync, and the PRD-level identity assurance justification for not requiring app-level login.

**Architecture:** Two spec file edits — append assertions to REQ-p01030 in prd-evidence-records.md, and add a new REQ-d00114 section to dev-portal-api.md. Then refresh the elspais graph and validate.

**Tech Stack:** Markdown (spec files), elspais MCP (graph validation), GitHub Actions (REQ ID claim)

---

### Task 1: Claim REQ-d00114 via GitHub Actions

The project requires new REQ IDs to be allocated via the `claim-requirement-number.yml` workflow to prevent conflicts.

**Step 1: Trigger the GitHub Actions workflow**

Run:
```bash
gh workflow run claim-requirement-number.yml \
  -f prefix=d \
  -f file=dev-portal-api.md \
  -f title="Sync Request Device Binding Verification"
```

**Step 2: Wait for workflow to complete and verify**

Run:
```bash
gh run list --workflow=claim-requirement-number.yml --limit=1
```

Expected: Workflow completes successfully, allocating REQ-d00114.

**Step 3: Pull the INDEX.md update**

Run:
```bash
git pull origin main
```

Expected: `spec/INDEX.md` now contains REQ-d00114 entry.

**Step 4: Commit checkpoint** — no local changes yet, just synced.

---

### Task 2: Add PRD assertions to REQ-p01030

**Files:**
- Modify: `spec/prd-evidence-records.md:301` (after assertion K, before the End marker)

**Step 1: Add assertions L and M**

Insert the following after line 301 (`K. The system SHALL log failed authentication attempts for audit purposes.`) and before the `*End*` marker:

```markdown

L. The system SHALL use device-specific UUID binding as an identity assurance control, establishing a one-to-one association between the enrolled patient and a single application instance.

M. The system SHALL treat the combination of mandatory device-level lock screen authentication and device UUID binding as equivalent to application-level login credentials for the purpose of patient identity assurance during data submission.
```

**Step 2: Validate the file parses correctly**

Run elspais refresh and check REQ-p01030:

```bash
# Use elspais MCP: refresh_graph() then get_requirement("REQ-p01030")
```

Expected: REQ-p01030 now shows 13 assertions (A through M). Assertions L and M appear with the correct text.

**Step 3: Commit**

```bash
git add spec/prd-evidence-records.md
git commit -m "[CUR-113] Add identity assurance assertions to REQ-p01030

Add PRD assertions establishing device UUID binding as an identity
assurance control (L) and authentication equivalency with device
lock screen (M). These provide formal traceability for the regulatory
justification documented in docs/authentication-strategy.md.

Implements: REQ-p01030

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

### Task 3: Add new DEV requirement REQ-d00114 to dev-portal-api.md

**Files:**
- Modify: `spec/dev-portal-api.md:188` (after the Section 4 end marker `---`, before `## References`)

**Step 1: Insert Section 5 with REQ-d00114**

Insert the following between the `---` on line 188 and `## References` on line 190:

```markdown

## Section 5: Sync Request Device Binding

# REQ-d00114: Sync Request Device Binding Verification

**Level**: Dev | **Status**: Draft | **Implements**: REQ-p01030

## Rationale

Server-side verification that the device UUID presented in each sync request matches the device UUID registered at enrollment. This enforcement is the technical mechanism that makes device UUID binding an effective identity assurance control per REQ-p01030-L. Without server-side verification, the UUID is informational only and provides no authentication value. The device UUID is already generated client-side (REQ-d00013) and recorded at enrollment (REQ-d00109); this requirement closes the loop by mandating server-side verification on every subsequent sync request.

## Assertions

A. The server SHALL verify that the device UUID included in each sync request matches the device UUID recorded at enrollment for the presenting token.

B. The server SHALL reject sync requests where the device UUID does not match the enrolled device UUID.

C. The server SHALL return HTTP 403 with error code `DEVICE_MISMATCH` for rejected device UUID mismatch requests.

D. The server SHALL NOT disclose the expected device UUID in the error response.

E. The server SHALL log all device UUID mismatch events to the audit trail, including the presented device UUID, the expected device UUID, the token identifier, and the request timestamp.

F. The server SHALL enforce device UUID verification independently of token validity checks.

*End* *Sync Request Device Binding Verification* | **Hash**: TBD

---
```

**Step 2: Update the References section**

Add to the References list:

```markdown
- **Patient Authentication**: prd-evidence-records.md (REQ-p01030)
```

**Step 3: Update the Revision History table**

Add a new row:

```markdown
| 1.2 | 2026-02-28 | Added sync request device binding verification (REQ-d00114) | CUR-113 |
```

**Step 4: Validate the file parses correctly**

Run elspais refresh and check REQ-d00114:

```bash
# Use elspais MCP: refresh_graph() then get_requirement("REQ-d00114")
```

Expected: REQ-d00114 exists with 6 assertions (A through F), implements REQ-p01030, level=dev, status=Draft.

**Step 5: Verify traceability chain**

```bash
# Use elspais MCP: get_hierarchy("REQ-d00114")
```

Expected: Parent is REQ-p01030. REQ-p01030's parent chain leads to REQ-p01025.

**Step 6: Commit**

```bash
git add spec/dev-portal-api.md
git commit -m "[CUR-113] Add REQ-d00114: Sync Request Device Binding Verification

New DEV requirement mandating server-side device UUID verification
on every sync request. Implements REQ-p01030 (Patient Authentication
for Data Attribution). Assertions cover: UUID match verification,
rejection with DEVICE_MISMATCH error code, minimal disclosure,
audit logging, and independence from token validity checks.

Implements: REQ-d00114

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

### Task 4: Validate full graph health

**Step 1: Refresh the elspais graph**

```bash
# Use elspais MCP: refresh_graph(full=True)
```

**Step 2: Check graph status**

```bash
# Use elspais MCP: get_graph_status()
```

Expected: No new orphaned nodes. No new broken references.

**Step 3: Verify test coverage status**

```bash
# Use elspais MCP: get_uncovered_assertions("REQ-d00114")
```

Expected: All 6 assertions show as uncovered (no tests yet — this is spec-only work).

**Step 4: Verify REQ-p01030 coverage**

```bash
# Use elspais MCP: get_uncovered_assertions("REQ-p01030")
```

Expected: Assertions L and M show as uncovered (new). Assertions A-K status unchanged.

---

### Task 5: Update Linear ticket and commit design doc

**Step 1: Commit the design doc**

```bash
git add docs/plans/2026-02-28-sync-auth-device-binding-design.md
git add docs/plans/2026-02-28-sync-auth-device-binding.md
git commit -m "[CUR-113] Add design and implementation plan docs

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

**Step 2: Update CUR-113 ticket checklist**

Update the ticket description to check off the "Create a spec for this" item:
- [x] Create a spec for this

Add a comment summarizing what was done:
- Added REQ-p01030 assertions L (UUID binding as identity assurance) and M (authentication equivalency)
- Added REQ-d00114: Sync Request Device Binding Verification (6 assertions)
- Traceability: REQ-d00114 implements REQ-p01030

---

## Notes for Implementer

- The `**Hash**: TBD` in REQ-d00114 will be auto-computed by elspais on the next graph refresh. Leave it as TBD; the tool handles this.
- REQ-d00114 ID must be confirmed after the GitHub Actions workflow runs. If it allocates a different number, update all references accordingly.
- This plan covers **spec work only**. Implementation of the actual server-side UUID verification logic is a separate ticket.
- The `DEVICE_MISMATCH` error code (HTTP 403) is deliberately distinct from `TOKEN_REVOKED` (HTTP 401) per REQ-d00112-D, so the client can distinguish the two failure modes.
