# DIARY-DEV-linking-code-lifecycle: Linking-Code Lifecycle and Uniqueness

**Level**: DEV | **Status**: Draft | **Implements**: -
**Refines**: DIARY-PRD-linking-code-lifecycle

## Assertions

A. The System SHALL generate a *Linking Code* server-side with sufficient entropy — a *Sponsor* prefix followed by six random characters followed by two check characters drawn from a non-ambiguous character set — set a 72-hour expiry, and issue it as a `participant_linking_code_issued` event carrying the plaintext code.

B. When a new code is issued for a *Participant*, the System SHALL auto-revoke that *Participant*'s prior active code, so a *Participant* holds at most one active code.

C. The System SHALL materialize the linking-code lifecycle as a single per-code status — active on issue, used on redemption, revoked on revocation — keyed by the normalized code.

D. The System SHALL detect a duplicate active code held by a different *Participant* and revoke the just-issued code and re-issue a fresh, collision-checked code, so active codes are effectively unique.

E. On issuance the System SHALL compute the two check characters of a *Linking Code* as a keyed message authentication code (HMAC-SHA256) over the prefix-and-random portion using the per-*Sponsor* routing key, so the code carries an offline-verifiable check independent of redemption.

## Rationale

Issuance is a read-free dispatched *Action*: the actions layer cannot read projections, so the code and its expiry are generated in the *Action*'s execution and emitted as an event, preserving authorization, *Site*-scope, idempotency, audit, and catalog registration. Obligations that require read-before-write — auto-revoking a prior active code (B) and healing a cross-*Participant* code collision (D) — live in a post-commit reactor, which (unlike an *Action*) may read projections and append follow-on events. The per-code status (C) is a materialized view keyed by the normalized code; the per-*Participant* status is folded separately.

**Risk Assessment.** The plaintext *Linking Code* persists in the immutable event log (full parity with the legacy linking flow). Residual risk: an *active, unused* code disclosed from the log could link a device to that *Participant* within its 72-hour window. Mitigations: the code is single-use (consumed on redemption), expires in 72 hours, and is gated by the relink/device check (*Diary*-DEV-relink-device-gate). This is accepted as a bounded, documented risk rather than hash-only storage; a *Linking Code* is consciously scoped outside the OTP/recovery/*Session* no-secrets-enumerated set. The uniqueness residual (D) is the millisecond self-heal window multiplied by the already-negligible collision rate of an eight-character draw multiplied by a concurrent redemption of that exact code — effectively unattainable, documented rather than engineered around.

*End* *Linking-Code Lifecycle and Uniqueness* | **Hash**: 213bfdd0
