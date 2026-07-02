# DIARY-BASE-audit-trail: Audit Trail Foundation

**Level**: BASE | **Status**: Draft | **Implements**: -
**Integrates**: EVS-PRD-library-charter, EVS-PRD-regulatory-alignment

## Assertions

A. The System SHALL maintain a complete, attributable record of every state-changing operation, recording who performed it, what changed, and when.

B. The System SHALL keep the audit record tamper-evident, such that any alteration of a recorded entry is detectable.

C. The System SHALL check and record the authority under which each operation was performed.

D. The System SHALL retain the audit record and keep it retrievable for the regulatory data-retention period.

E. The System SHALL realize this audit record on the event_sourcing substrate as one append-only event chain spanning the *Participant*'s device and the *Sponsor Portal* server — coupled by substrate-native event flow rather than a shared *Database* — and SHALL derive every portal and *Diary* read view from that event log by deterministic materialization.

## Rationale

The *Diary*/portal platform's foundational data-integrity commitment: a complete, attributable, tamper-evident, authority-checked, durable *Audit Trail* aligned with the ALCOA+ data-integrity attributes and *FDA 21 CFR Part 11*. Assertions A-D state the regulatory obligation independent of any implementation; assertion E records the architectural decision that realizes it — the platform is built on the event_sourcing substrate as one event-sourced chain, coupled by native event flow with all read state derived from the log. The chain currently spans the *Participant*'s device and the *Sponsor Portal* server (device-to-portal direct); it may extend through an additional intermediate node in a future deployment topology (the deferred two-node split, `DIARY-DEV-node-sync-topology`) without changing this obligation.

This requirement is authored at the BASE level because the realization detail (E) is the kind of platform-internal architecture a *Sponsor* may opt to exclude from their own requirements documentation, while the audit obligations (A-D) remain the foundation every access-controlled *Action* and recorded event refines. The substrate mechanics that make A-E achievable are provided by the event_sourcing library and are not restated here; they are referenced via the `**Integrates**` edges above (the library charter and its regulatory-alignment requirement), which record the cross-repo dependency in the federated graph.

*End* *Audit Trail Foundation* | **Hash**: 1f28ed43
