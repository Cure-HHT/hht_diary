# DIARY-BASE-sponsor-portal: Sponsor Portal

**Level**: BASE | **Status**: Draft | **Implements**: -
**Refines**: DIARY-BASE-compliant-diary-platform

## Overview

The staff-facing pillar of the platform: a web portal through which *Sponsor* and *Site* staff administer the study. It covers user-account lifecycle, *Participant* administration, and study settings, with every surface scoped to the staff member's *Role* and *Site* assignments. The specific administrative workflows and surfaces refine this pillar.

## Assertions

A. The System SHALL provide a staff-facing web portal for administering users, participants, and study settings.

B. Every portal surface SHALL be scoped to the authenticated staff member's *Role* and *Site* assignments.

## Rationale

*Sponsor* and *Site* staff need a controlled administrative surface distinct from the participant's device, and that surface must enforce least privilege: a staff member sees and acts on only what their *Role* and *Site* assignment permit. Stating this at the pillar level lets every administrative workflow inherit the scoping obligation rather than restating it.

*End* *Sponsor Portal* | **Hash**: 21494b63
