# DIARY-DEV-node-sync-topology: Two-Node Native-Sync Topology

**Level**: DEV | **Status**: Draft | **Implements**: -
**Refines**: DIARY-BASE-audit-trail

<!-- satisfied-by: EVS-PRD-destinations -->
<!-- satisfied-by: EVS-PRD-ingest -->
<!-- satisfied-by: EVS-PRD-provenance -->

## Assertions

A. The platform SHALL deploy as exactly two server nodes — the *Diary* server (edge and ingest) and the *Sponsor Portal* server (staff-facing) — each the single writer to its own *Event Store*, with no shared event *Database* between them.

B. The *Diary* server SHALL relay clinical and side-band events to the *Sponsor Portal* server through a named "portal" destination, and the *Sponsor Portal* server SHALL admit them through its ingest path.

C. The provenance hop sequence SHALL be the *Participant*'s device first, the *Diary* server second, and the *Sponsor Portal* server third.

D. Each cross-node batch SHALL carry a wire-format identifier so a receiver can reject a batch whose format it does not recognize.

## Rationale

The event_sourcing library provides the generic outbound-destination and inbound-ingest mechanism and the provenance hop chain; this requirement pins the concrete *Diary*/portal topology that uses them. The "Beta" two-node design — two independent single-writer stores coupled by the library's native destination-to-ingest sync rather than a shared *Database* — is what makes change-notification intrinsic to ingest and keeps each node's hash chain its own. Naming the "portal" destination, fixing the device-to-*Diary*-to-*Sponsor Portal* hop order, and requiring a per-batch wire-format identifier are the *Diary*-specific obligations that CUR-1410 (transport) and CUR-1411 (*Diary* server) implement. The substrate guarantees this requirement relies on — durable FIFO destination queues, idempotent hash-chain-verifying ingest, and provenance-hop extension on ingest — are referenced via the `satisfied-by` annotations above rather than restated.

*End* *Two-Node Native-Sync Topology* | **Hash**: d2cc0577
