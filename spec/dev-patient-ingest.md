# DIARY-DEV-patient-ingest: Patient Clinical-Record Ingest Edge

**Level**: DEV | **Status**: Draft | **Implements**: -
**Refines**: DIARY-BASE-audit-trail

<!-- satisfied-by: EVS-PRD-ingest -->
<!-- satisfied-by: EVS-PRD-provenance -->

## Assertions

A. The System SHALL expose a public ingest edge that admits a signed `esd/batch@1` batch originated on a *Participant*'s device.

B. The ingest edge SHALL authenticate the caller with a bearer *Participant* token and reject an absent, malformed, or expired token before ingest.

C. The ingest edge SHALL admit a batch through the substrate's idempotent, hash-chain-verifying ingest path, and the receiving node SHALL append its receiver provenance hop.

D. The cross-wire *Participant* identity key SHALL be `participantId`, carried inside the batch's *Participant*-scoped aggregate ids; the ingest edge SHALL NOT require it as a separate field.

## Rationale

The clinical record flows device to server as native `esd/batch@1` sync. This requirement pins the server's obligations at the *Patient*-facing ingest edge: a public endpoint, a bearer-token gate ahead of ingest, idempotent hash-chain-verifying admission with a receiver provenance hop, and the `participantId` cross-wire key carried inside aggregate ids rather than as a separate field. It is worded node-neutrally: this phase realizes the edge on the *Sponsor Portal* server (device to portal direct); the deferred edge/core split relocates the same edge to a dedicated *Diary*-server without changing the contract.

*End* *Patient Clinical-Record Ingest Edge* | **Hash**: fea6f77a
