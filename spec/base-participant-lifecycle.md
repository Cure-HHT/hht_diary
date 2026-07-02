# DIARY-BASE-participant-lifecycle: Participant Lifecycle

**Level**: BASE | **Status**: Draft | **Implements**: -
**Refines**: DIARY-BASE-sponsor-portal

## Overview

The lifecycle of a study *Participant* as a set of auditable, staff-coordinated workflows: enrollment, device linking, disconnection, reconnection, and end-of-participation. The portal initiates and records these transitions; the participant's device performs the on-device steps (such as entering a *Linking Code*). The specific lifecycle workflows and the on-device linking surface refine this requirement.

## Assertions

A. The System SHALL manage the *Participant* lifecycle — enrollment, device linking, disconnection, and reconnection — as auditable workflows.

B. Each lifecycle transition SHALL be attributable to the staff member or *Participant* who initiated it and recorded in the audit history.

## Rationale

A participant's relationship to a study changes over time, and each change has regulatory weight, so the transitions must be explicit, attributable workflows rather than implicit state edits. Grouping them under one requirement keeps enrollment, linking, and status changes coherent and ensures every transition carries the same auditability obligation.

*End* *Participant Lifecycle* | **Hash**: 28004eef
