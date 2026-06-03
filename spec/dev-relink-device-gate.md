# DIARY-DEV-relink-device-gate: Relink Device Gate

**Level**: DEV | **Status**: Draft | **Implements**: -
**Refines**: DIARY-PRD-participant-reconnection

## Assertions

A. When a *Participant* is currently linked to a device, the *Participant*-link endpoint SHALL reject a redemption that presents a different device identity.

B. The *Participant*-link endpoint SHALL allow re-link after the *Participant* has been disconnected.

C. The *Participant*-link endpoint SHALL recognize the same device re-presenting as continuity and allow it.

## Rationale

The relink gate is the owner of what the legacy device identifier enforced: it binds a connected *Participant* to one device and admits a new device only after an explicit disconnect, while treating a re-presenting same-device identity (for example after a factory reset) as continuity. The gate reads the *Participant*'s materialized link state — the mobile linking status and the bound device identity — inside the redemption transaction; the binding is released only by a `participant_disconnected` event that carries the disconnected status, never by a benign code re-issue (which leaves the device binding intact while it re-issues a fresh code).

*End* *Relink Device Gate* | **Hash**: d82aa19c
