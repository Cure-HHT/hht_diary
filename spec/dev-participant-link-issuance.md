# DIARY-DEV-participant-link-issuance: Participant Link Endpoint

**Level**: DEV | **Status**: Draft | **Implements**: -
**Refines**: DIARY-PRD-participant-link-new

## Assertions

A. The *Participant*-link endpoint SHALL validate a submitted *Linking Code* against the lifecycle projection and map an active, expired, used, revoked, or unknown code to a success, gone, conflict, gone, or bad-request outcome respectively.

B. On a valid code the endpoint SHALL issue a *Participant*-identity bearer token, where the `participantId` is the identity (there is no separate device-account aggregate).

C. The endpoint SHALL consume the code atomically within the same transaction as validation — appending `participant_linking_code_used` and transitioning the *Participant* to connected — giving single-use under concurrent redemption.

D. On success the endpoint SHALL return the documented response contract carrying the bearer token, the `participantId`, the redeemed code, and the *Participant*'s *Site* identification.

## Rationale

The endpoint is a public *Participant*-edge handler, mounted like the ingest edge outside the staff authorization pipeline with its own validation. Because validation reads the lifecycle projection and the consume appends an event, both run inside one substrate transaction so that a code cannot be redeemed twice: the read sees the active row, the append flips it to used, and a concurrent redemption observes the consumed state. The *Participant* is the identity — the issued token carries `participantId`, and the relink/device gate (*Diary*-DEV-relink-device-gate) governs which device may present a valid code.

*End* *Participant Link Endpoint* | **Hash**: 9e23e55d
