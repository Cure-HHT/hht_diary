# EDC Audit Event Requirements

**Version**: 1.0
**Audience**: Product Requirements
**Status**: Roadmap (Future EDC capability)

---

## Overview

Audit event types required if the Diary Platform evolves into a full Electronic Data Capture (EDC) system. Currently handled by Medidata RAVE.

---

## REQ-p90001: Electronic Signature Audit Events

**Level**: PRD | **Status**: Roadmap

The system SHALL capture audit events for all electronic signature operations.

Signature events SHALL include:
- Signature applied (entity signed by authorized user)
- Signature invalidated (data changed after signature)

Each signature event SHALL capture:
- Entity type and identifier being signed
- Signer identity, role, and timestamp
- Invalidation reason (if applicable)

**Rationale**: FDA 21 CFR Part 11 requires signatures to be linked to signed records with complete attribution.

*End* *Electronic Signature Audit Events*

---

## REQ-p90002: Study Visit Status Events

**Level**: PRD | **Status**: Roadmap

The system SHALL capture audit events for study visit lifecycle transitions.

Visit events SHALL include:
- Visit scheduled
- Visit started (first data entered)
- Visit completed (all data entered)
- Visit signed (e-signature applied)
- Visit locked (no further changes allowed)

Each event SHALL capture visit identifier, patient, timestamp, and responsible user.

**Rationale**: Clinical trials require tracking of visit status for protocol compliance and data lock procedures.

*End* *Study Visit Status Events*

---

## REQ-p90003: Source Data Verification Events

**Level**: PRD | **Status**: Roadmap

The system SHALL capture audit events for source data verification (SDV) activities.

SDV events SHALL include:
- SDV completed (monitor verified data against source)
- SDV status changed

Each event SHALL capture entity verified, verifier identity, and verification date.

**Rationale**: SDV provides documented evidence that electronic data matches source documents. Less relevant for ePRO where patient entry is the source.

*End* *Source Data Verification Events*

---

## REQ-p90004: Data Query Lifecycle Events

**Level**: PRD | **Status**: Roadmap

The system SHALL capture audit events for data query (discrepancy note) workflows.

Query events SHALL include:
- Query created
- Query responded
- Query resolution proposed
- Query closed

Each event SHALL capture query identifier, entity reference, user attribution, and timestamps.

**Rationale**: Data queries provide auditable evidence of data clarification and correction workflows.

*End* *Data Query Lifecycle Events*

---

## REQ-p90005: Study Configuration Events

**Level**: PRD | **Status**: Roadmap

The system SHALL capture audit events for study configuration changes.

Configuration events SHALL include:
- Study created
- Study status changed (phase transitions)
- Study locked (database lock)
- Form version published

Each event SHALL capture study identifier, configuration change, and responsible user.

**Rationale**: Study configuration changes affect data collection and must be auditable.

*End* *Study Configuration Events*

---

## REQ-p90006: Randomization Events

**Level**: PRD | **Status**: Roadmap

The system SHALL capture audit events for patient randomization operations.

Randomization events SHALL include:
- Randomization assigned (patient assigned to treatment arm)
- Randomization unblinded (treatment revealed)

Each event SHALL capture patient identifier, treatment arm, and authorization.

**Rationale**: Randomization is a critical trial integrity control requiring complete audit trail.

*End* *Randomization Events*

---

## References

- FDA 21 CFR Part 11 (Electronic Records)
- OpenClinica audit event taxonomy (43 event types)
