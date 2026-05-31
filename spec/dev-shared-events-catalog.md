# DIARY-DEV-shared-events-catalog: Shared Cross-Wire Event Catalog

**Level**: DEV | **Status**: Draft | **Implements**: -
**Refines**: DIARY-BASE-audit-trail

## Assertions

A. The platform SHALL maintain a single shared catalog that declares every cross-wire event entry type with a snake_case identifier and a registered schema version.

B. Each cross-wire event entry type SHALL record the originating node as one of portal, *Diary*, or edge.

C. Lifecycle and permission changes SHALL be recorded as durable state-change events, and communication and access-audit occurrences SHALL each be recorded as a distinct event.

D. Event payloads and correlation tokens SHALL exclude cleartext one-time passwords, recovery tokens, and *Session* tokens.

E. Each cross-wire event identifier SHALL be defined in exactly one specification and SHALL be implemented in exactly one catalog package.

## Rationale

The mobile *Diary*, the *Diary* server, and the portal server fold one append-only event log into the same canonical state. A single shared declaration of the cross-wire event types is what keeps the three nodes from drifting: a snake_case identifier plus a registered schema version (A) gives every node one stable key and one agreed version per entry type, and recording the originating node (B) preserves attribution for the *Audit Trail* and tells each consumer which side authors a given type.

The granularity rule (C) reconciles signal with audit completeness. Lifecycle and permission state changes are durable facts whose current value is reconstructed by folding the log, so one state-change event per transition is sufficient. Communication and access-audit occurrences — message dispatch, delivery acknowledgement, credential and emergency-access activity — are themselves the regulated *Audit Trail* under ALCOA+, so each occurrence is its own immutable event rather than a value derived from a projection.

The no-secrets constraint (D) keeps short-lived credentials out of the immutable log and out of the cross-flow correlation token, reconciling the forever-immutable event record with bounded retention of sensitive material. The single-definition, single-implementation rule (E) is the anti-drift invariant: an identifier owned by one specification and realized in one package cannot diverge between the apps that share it; cross-wire types live in the shared package, and node-private types live in that node's own package.

The cross-wire event and payload surface this catalog governs was reconciled and frozen jointly with the *Diary* effort; the *Participant*, *Questionnaire*, and mobile-notification product requirements define the lifecycles the catalog's events make traceable.

*End* *Shared Cross-Wire Event Catalog* | **Hash**: b157403e
