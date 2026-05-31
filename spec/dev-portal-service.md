# Portal Service — Implementation Requirements

## DIARY-DEV-participant-site-index: Participant-Site Index Materializer

**Level**: DEV | **Status**: Draft | **Implements**: -
**Refines**: DIARY-PRD-action-inventory

### Overview

The portal authorization policy resolves *Participant*-scoped permissions through a
*Participant*-contained-in-*Site* hierarchy. The `participant_site_index` projection
supplies the containment data: the current RAVE-assigned *Site* for each *Participant*.
It is materialized from RAVE-sourced `participant_synced_from_edc` events
(`<!-- satisfied-by: EVS-PRD-scoped-permissions -->`, the substrate's app-supplied
`ContainmentReference` projection contract). RAVE is authoritative; the portal never
writes the mapping except by folding the edge event.

### Assertions

A. The portal SHALL materialize a `participant_site_index` view keyed by
`participant_id` carrying the current `site_id`, by folding
`participant_synced_from_edc` events; a later sync for the same *Participant* SHALL
overwrite the row (the *Participant*'s *Site* is the latest RAVE-sourced value).

B. The portal SHALL register `participant_site_index` when opening its *Event Store*,
so the authorization policy's containment resolver reads it within the dispatch
transaction.

### Rationale

Participants and sites are RAVE-sourced, first-class facts in the single auditable
event stream, ingested as events. The index is the read model the containment
resolver consults so a *Site*-bound *Role* assignment covers *Participant*-scoped requests
at the *Participant*'s RAVE *Site*, fail-closed when no mapping row exists.

*End* *Participant-Site Index Materializer* | **Hash**: 76e68990
