# DIARY-BASE-local-data-reset: Local Data Reset to First-Launch State

**Level**: BASE | **Status**: Draft | **Implements**: -
**Refines**: DIARY-PRD-mobile-offline-first

## Overview

The *Participant* can wipe all local data and return the *Diary* to its first-launch state — but not while participating in a *Trial*, where local data is contemporaneous evidence. A *Sponsor* may disable and lock the reset capability for the duration of participation; at end of participation that lock is released without changing the configured value. Reset is destructive and always requires explicit confirmation. This behavior is authored at the BASE level because it is real, traceable product behavior that a *Sponsor* may opt to exclude from its own requirements documentation set.

## Assertions

A. The System SHALL provide a reset that wipes all local *Diary* data, settings, enrollment, and device identity, returning the application to its first-launch state.

B. The System SHALL make reset unavailable while the *Participant* is participating in a *Trial*, requiring the *Participant* to end participation first.

C. The System SHALL allow a *Sponsor* to disable and lock the reset capability; at end of participation the System SHALL unlock that setting without changing its configured value.

D. The System SHALL require explicit confirmation before performing a reset.

## Rationale

A clean wipe to first-launch state is a legitimate need on a personal device — reassigning the device, clearing a test install, or starting over — but while a *Participant* is participating the local data is contemporaneous evidence, so reset is withheld until participation ends. Letting a *Sponsor* disable and lock the capability covers deployments that forbid local wipes outright; releasing that lock (without changing its value) at end of participation returns the choice to the *Participant* exactly as the other *Sponsor*-locked settings do. Destructive and irreversible, reset always requires explicit confirmation so it can never happen by accident.

*End* *Local Data Reset to First-Launch State* | **Hash**: 824fef24
