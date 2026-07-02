# DIARY-DEV-portal-resolver: Neutral Diary-Portal Resolution

**Level**: DEV | **Status**: Draft | **Implements**: -
**Refines**: DIARY-PRD-participant-link-new
**Integrates**: HHT-OPS-portal-resolver

## Assertions

A. The *Diary* app SHALL resolve the *Sponsor Portal* hostname for an entered *Linking Code* by querying its neutral discovery endpoint, and SHALL direct the subsequent link request to the returned hostname.

B. The *Diary* app SHALL hold no static *Sponsor*-prefix-to-hostname mapping; the only sponsor-routing input compiled into the public build is the per-environment neutral discovery endpoint.

C. The *Diary* app SHALL treat any non-success discovery outcome — unknown prefix or failed check — as a single generic "invalid code" condition, indistinguishable to the *User*, and SHALL treat an unreachable discovery endpoint as a distinct retryable condition.

D. The *Diary* app SHALL resolve its discovery endpoint per environment from the bundled environment pointer, not a compile-time constant.

## Rationale

The public *Diary* app must resolve a *Participant*'s *Sponsor Portal* from the entered *Linking Code* without compiling in any *Sponsor* instance, so the public build holds zero *Sponsor* routing data and de-branding can complete. The discovery endpoint is the only sponsor-routing input baked into the build; all *Sponsor* literals (prefix-to-hostname map, per-sponsor keys) remain private, injected at runtime into the org-operated discovery service. Treating all non-success discovery outcomes as a single generic user-facing condition prevents enumeration of valid prefixes or sponsors. An unreachable discovery service is a transient infrastructure failure and must be surfaced as a retryable condition rather than conflated with an invalid code.

*End* *Neutral Diary-Portal Resolution* | **Hash**: 6b973bcf
