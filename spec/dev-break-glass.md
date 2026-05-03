# Development Specification: Break-Glass Workflow Implementation

**Version**: 1.0
**Audience**: Backend, DevOps, Platform engineers
**Status**: Draft
**Last Updated**: 2026-05-02

## Overview

This document specifies the implementation contract for the DevOps break-glass GCP access mechanism defined in `ops-break-glass.md` (REQ-o00084). It covers the GitHub Actions reusable workflows, composite actions, Slack routing, IAM-policy mutation semantics, and identity-resolution flow.

> **See**: ops-break-glass.md for the operational requirements
> **See**: docs/superpowers/specs/2026-05-02-break-glass-design.md for the phase design
> **See**: docs/runbooks/break-glass.md for operator procedures

## Architecture

The implementation lives in two repositories:

- **Core (`hht_diary`)** — sponsor-agnostic reusable workflows (`reusable-break-glass-grant.yml`, `reusable-break-glass-sweep.yml`, `reusable-break-glass-doctor.yml`) and composite actions (`notify-devops-breakglass`, `breakglass-doctor`).
- **Sponsor (e.g. `hht_diary_callisto`)** — thin `workflow_dispatch` wrappers that supply sponsor-scoped variables (project IDs, WIF provider, binding-manager SA, Slack channels) and a CODEOWNERS-protected roster file mapping `github.actor` → `@anspar.org` email.

All grant workflows authenticate via GitHub OIDC → Workload Identity Federation, impersonate a per-environment binding-manager service account holding `roles/resourcemanager.projectIamAdmin`, and apply a single transactional `set-iam-policy` to bind the requested roles to the requester's Workspace identity with a CEL `request.time` expiry condition.

## Table of Contents

- [Requirements](#requirements)

---

## Requirements

# REQ-d00161: Break-Glass Workflow Implementation

**Level**: dev | **Status**: Draft | **Implements**: REQ-o00084

## Rationale

REQ-o00084 establishes the operational obligations for break-glass GCP access: time-bound bindings to `@anspar.org` identities, denylist enforcement, approval gating, contemporaneous notification, and audit-grade record retention. This requirement defines the implementation contract that satisfies those obligations: the workflow shape, the transactional IAM mutation semantics, the doctor-driven preflight gating, the Slack composite-action routing table, and the roster-driven identity resolution.

The transactional `set-iam-policy` semantics matter because partial application of a multi-role grant during incident response would leave the engineer holding unexpected partial powers — for example, viewer access without the storage-admin access that prompted the request, leading to confusion and wasted incident time. A single `get-iam-policy` → in-memory mutation → `set-iam-policy` with the captured `etag` makes grants all-or-nothing and halves the audit-log noise compared to per-role binding calls.

Doctor-driven preflight gating shifts configuration failures left from incident time to provisioning time. Without it, a missing repo Variable or a misconfigured WIF provider would surface as a cryptic `gcloud` error in the middle of an incident. With it, the workflow aborts before any IAM mutation with an operator-actionable remediation message.

The Slack composite owns the routing table internally so that callers (the grant, sweep, and doctor workflows) say "this happened" rather than "post to alerts" — re-routing an event later does not require coordinated changes across callers. The composite exits success on Slack post failure because the IAM binding is the system of record; failing the workflow because Slack is unreachable would not undo the binding and would obscure operational state during an incident.

The roster file as the sole source of `github.actor` → email mapping eliminates dependence on GitHub SAML SSO (which the org does not enforce) and gives a CODEOWNERS-protected, PR-reviewable, auditable identity contract. Cloud Identity API verification on top of the roster catches stale entries (suspended accounts, renames) before they cause a binding to a nonexistent identity.

## Assertions

A. The grant workflow SHALL apply IAM bindings transactionally via a single `gcloud projects set-iam-policy` invocation with the `etag` captured from a preceding `get-iam-policy`, such that all requested roles are bound or none are.

B. The grant workflow SHALL invoke the doctor's `preflight` mode before performing any IAM mutation, and SHALL abort with the doctor's remediation message on any preflight failure.

C. The grant workflow SHALL reject any role request matching the denylist (the predefined names and name patterns enumerated in `breakglass-doctor` configuration) before invocation of preflight or any IAM mutation.

D. The grant workflow SHALL enforce a minimum binding duration of 15 minutes and a maximum duration of 1440 minutes (24 hours) regardless of caller-supplied inputs.

E. The grant workflow SHALL block the request when `${{ github.actor }}` was the most recent author of `breakglass-roster.yml` within the preceding 7 days.

F. The grant workflow SHALL write `condition.title` as `breakglass-<run-id>` and `condition.description` as a JSON object containing at least the fields `actor`, `ticket`, `justification`, `run_url`, and `expires_at`.

G. The sweeper workflow SHALL identify stale bindings by `condition.title` prefix `breakglass-` AND `condition.description.expires_at` parsed as a past timestamp, and SHALL retry `set-iam-policy` etag conflicts up to three times with exponential backoff (2s, 4s, 8s) before deferring to the next scheduled run.

H. The sweeper workflow SHALL emit a Slack lifecycle summary on every run, including runs that swept zero bindings, to prevent silent-failure modes.

I. The Slack composite action SHALL route events to channels per a fixed routing table owned within the composite, dedupe destinations resolving to the same channel ID, and SHALL log a `::warning::` annotation and exit success on Slack post failure.

J. The Slack composite action SHALL DM the grantee on `grant_granted`, `grant_blocked`, and `grant_denylist` events when a Slack bot token and the grantee's verified Workspace email are available, and SHALL silently skip the DM (without failing the workflow) when either is unavailable.

K. The doctor composite action SHALL implement three modes: `static` (no live API calls, suitable for PR CI), `preflight` (fast live checks, invoked from the grant workflow), and `full` (comprehensive provisioning audit, invoked from the doctor workflow); each mode SHALL produce a markdown job summary with `✅` / `❌` / `⚠️` per check and copy-pasteable remediation commands for any `❌`.

L. The doctor composite action SHALL verify the requester's resolved Workspace email via the Cloud Identity API; verification failure SHALL block elevated grants and SHALL emit a warning (without blocking) for read-only grants.

M. The roster file `breakglass-roster.yml` SHALL be the sole source of truth for `github.actor` → `@anspar.org` email mapping in the workflows, and SHALL be protected either by a CODEOWNERS rule requiring code-owner review on any modification or by a branch-protection rule requiring at least two reviewers — sponsor repos may pick whichever GitHub plan tier supports.

N. The reusable workflows SHALL be referenced from sponsor wrappers by commit SHA or release tag, never by branch name, to ensure audit reproducibility; the doctor `static` mode SHALL flag any branch-pinned reference.

*End* *Break-Glass Workflow Implementation* | **Hash**: 4cc5e2e4
