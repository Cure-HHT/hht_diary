# DIARY-DEV-outgoing-intent-correlation: Outgoing Intent and Flow Correlation

**Level**: DEV | **Status**: Draft | **Implements**: -
**Refines**: DIARY-BASE-audit-trail
**Integrates**: EVS-DEV-flow-token, EVS-PRD-destinations

## Assertions

A. An outgoing staff intent, such as assigning a *Questionnaire*, SHALL be recorded as a durable audited event in the *Sponsor Portal* event chain before any delivery is attempted.

B. Delivery to the *Participant*'s device SHALL ride the existing push-notification and notification-envelope path; the recorded intent event SHALL NOT itself be the delivery mechanism.

C. The platform SHALL mint a correlation token on the intent event and carry that token in the notification-envelope payload across the non-event-sourced delivery gap.

D. Device-side events that result from the flow, such as the side-band delivery acknowledgement, SHALL echo the same correlation token so the round trip is reconstructable from the event log.

## Rationale

The outgoing path is audited intent plus existing delivery plus a side-band acknowledgement: the portal records what it intends to do as a durable event, the actual push rides the existing notification path, and the device's resulting events echo a correlation token so the whole flow can be traced end to end despite the non-event-sourced push hop. The correlation-token primitive itself is a library obligation (referenced via the `**Integrates**` edge on the event_sourcing flow-token requirement); this requirement states the *Diary*/portal-specific obligations: record-intent-before-deliver, reuse the existing envelope path, mint-and-carry the token, and echo it on the device side. The no-cleartext-secrets constraint on the token is reinforced locally by `DIARY-DEV-shared-events-catalog` assertion D.

*End* *Outgoing Intent and Flow Correlation* | **Hash**: 108441a8
