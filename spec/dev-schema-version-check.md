# DIARY-DEV-schema-version-check: Runtime Schema Version Check

**Level**: DEV | **Status**: Draft | **Implements**: -
**Refines**: DIARY-PRD-platform-operations-monitoring

## Assertions

A. Each server image SHALL carry, fixed at build time, the minimum *Database* schema version the code requires.

B. On startup each server SHALL compare the *Database*'s recorded schema version against that minimum.

C. When the *Database* version is below the required minimum, the server SHALL raise an operator alert once and respond to all requests with HTTP 503 indicating the schema is behind, while keeping its health probe reporting healthy.

D. The operator alert raised under assertion C SHALL identify the originating deployment — at minimum the environment, and where available the *Sponsor* and the deploy event (deploy sequence and commit) — so a responder can attribute the alert without consulting external context.

## Rationale

The 2026-05-10 UAT incident occurred because a newly deployed application revision began serving traffic while the *Database* was still at an earlier schema version. A runtime version check (assertion B) catches this mismatch even if the pre-traffic migration step is bypassed or fails silently. Embedding the required minimum at build time (assertion A) makes the check reproducible and auditable: the version contract is part of the image artifact and cannot be altered at runtime. Returning HTTP 503 (assertion C) signals the mismatch to load balancers and upstream health checkers without obscuring the root cause; the single alert avoids alert storms on repeated health checks. Keeping the health probe healthy during the 503 condition preserves the infrastructure's ability to drain and reroute traffic — crashing the process would prevent clean shutdown and complicate operator diagnosis. Identifying the originating deployment in the alert text (assertion D) lets on-call triage a multi-environment fleet at a glance: the same image runs in dev/qa/uat, so a bare alert forces a manual hunt for which environment and revision fired it. The deployment identity (*Sponsor*, environment, deploy sequence, commit) is already present in the runtime as environment variables, so surfacing it is free and best-effort — a local run with none of those variables set falls back to the bare server tag.

*End* *Runtime Schema Version Check* | **Hash**: cf57d093
