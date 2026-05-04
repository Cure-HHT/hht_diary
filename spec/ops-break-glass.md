# Operations Specification: DevOps Break-Glass GCP Access

**Version**: 1.0
**Audience**: DevOps, Operations, Security
**Status**: Draft
**Last Updated**: 2026-05-02

## Overview

This document specifies the on-demand, time-bound, audit-grade GCP IAM access mechanism for DevOps engineers. It supports the zero-standing-privilege model required by FDA 21 CFR Part 11 ALCOA+ and the principle of least privilege.

Engineers hold no standing GCP roles. When elevated access is required for incident response, deployment troubleshooting, or recurring administrative tasks, they request a time-bound binding via a GitHub Actions workflow. The binding goes directly to the engineer's `@anspar.org` Workspace identity, expires automatically via an IAM Condition, and is logged in GCP Cloud Audit Logs.

> **See**: dev-break-glass.md for the workflow implementation contract
> **See**: docs/runbooks/break-glass.md for operator procedures
> **See**: ops-cicd.md for the broader CI/CD enforcement framework

## Table of Contents

- [Requirements](#requirements)

---

## Requirements

# REQ-o00084: DevOps Break-Glass GCP Access

**Level**: ops | **Status**: Draft | **Implements**: REQ-p00014, REQ-p01018

## Rationale

DevOps engineers must occasionally hold elevated GCP IAM permissions to troubleshoot deployments, investigate incidents, or perform administrative actions that cannot reasonably be automated. Granting these permissions as standing roles violates the principle of least privilege and increases the blast radius of any single account compromise; it also fails the ALCOA+ "Attributable" and "Contemporaneous" obligations under FDA 21 CFR Part 11, since standing access yields no per-event record of the *why* behind privileged actions.

This requirement establishes that elevated GCP access SHALL be granted only on demand, scoped to a finite window, attributable to a Workspace identity, and recorded in tamper-evident audit logs retained for the sponsor's data retention SLA. Approval gating prevents self-grant; identity verification prevents binding to nonexistent or stale identities; a denylist prevents grants of roles capable of further privilege escalation.

The mechanism complements separate work to revoke standing permissions and migrate org-level super-admin to service-account impersonation, ensuring there is a path to elevated access at all times without any human holding standing privilege.

## Assertions

A. The system SHALL bind elevated GCP roles only to identities whose verified email is in the `@anspar.org` Workspace domain.

B. The system SHALL bind elevated GCP roles for a finite duration not exceeding 24 hours, enforced by an IAM Condition expression evaluated at access time.

C. The system SHALL deny grants of privilege-escalation roles, including but not limited to `roles/owner`, roles matching `*.IamAdmin`, `*.RoleAdmin`, `*.organizationAdmin`, `*.serviceAccountUser`, and `*.serviceAccountTokenCreator`, without exception.

D. The system SHALL require approval by a second authorized reviewer before applying any binding that grants write or administrative roles.

E. The system SHALL prevent a requester from also acting as the approver for their own request.

F. The system SHALL emit an audit-grade record of every grant request, approval, denial, and revocation, retained for the sponsor's data retention SLA in tamper-evident storage.

G. The system SHALL verify that the requester's resolved Workspace identity exists in the `@anspar.org` Cloud Identity tenant before applying any elevated binding.

H. The system SHALL emit a contemporaneous notification to the DevOps Slack workspace for every grant, denial, and expiry-driven revocation.

I. The system SHALL identify expired or stale break-glass bindings by a stable marker (`condition.title` prefix `breakglass-`) and SHALL remove them on a recurring schedule.

J. The system SHALL self-validate provisioning state on demand and report any missing configuration with operator-actionable remediation guidance.

*End* *DevOps Break-Glass GCP Access* | **Hash**: 30792df1
