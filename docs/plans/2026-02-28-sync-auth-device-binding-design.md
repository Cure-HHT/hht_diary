# Sync Authentication Device Binding — Design

**Ticket**: CUR-113 — Diary to Portal sync authentication respects device UUID
**Date**: 2026-02-28
**Status**: Approved

## Problem

The existing specs define UUID generation (REQ-d00013) and token issuance at enrollment (REQ-d00109), but no requirement mandates that the server verify the device UUID in sync requests matches the UUID registered at enrollment. Without this enforcement, the UUID is informational only and provides no authentication value.

This gap matters because device UUID binding is a core part of the regulatory justification for not requiring an in-app login (see `docs/authentication-strategy.md`). The combination of mandatory device-level lock screen + device UUID binding is treated as equivalent to application-level credentials for patient identity assurance. That equivalency must be formally traceable in the spec.

## Design

### 1. PRD Assertions — REQ-p01030 (Patient Authentication for Data Attribution)

Add two assertions to `spec/prd-evidence-records.md`:

**L.** The system SHALL use device-specific UUID binding as an identity assurance control, establishing a one-to-one association between the enrolled patient and a single application instance.

**M.** The system SHALL treat the combination of mandatory device-level lock screen authentication and device UUID binding as equivalent to application-level login credentials for the purpose of patient identity assurance during data submission.

### 2. New DEV Requirement — Sync Request Device Binding Verification

New requirement in `spec/dev-portal-api.md` (Section 5, after Token Revocation). Implements REQ-p01030.

**Rationale:** Server-side verification that the device UUID presented in each sync request matches the device UUID registered at enrollment. This enforcement is the technical mechanism that makes device UUID binding an effective identity assurance control per REQ-p01030-L. Without server-side verification, the UUID is informational only and provides no authentication value.

**Assertions:**

A. The server SHALL verify that the device UUID included in each sync request matches the device UUID recorded at enrollment for the presenting token.

B. The server SHALL reject sync requests where the device UUID does not match the enrolled device UUID.

C. The server SHALL return HTTP 403 with error code `DEVICE_MISMATCH` for rejected device UUID mismatch requests.

D. The server SHALL NOT disclose the expected device UUID in the error response.

E. The server SHALL log all device UUID mismatch events to the audit trail, including the presented device UUID, the expected device UUID, the token identifier, and the request timestamp.

F. The server SHALL enforce device UUID verification independently of token validity checks.

## Traceability

```
REQ-p01030-M (auth equivalency: lock screen + UUID binding)
  +-- REQ-p01030-L (UUID binding as identity assurance)
        +-- New DEV req (server-side UUID verification at sync time)
              +-- REQ-d00013 (UUID generation & inclusion in sync requests)
              +-- REQ-d00109 (UUID recorded at enrollment)
```

## What We Are NOT Changing

- **REQ-d00013** — already covers client-side UUID generation and inclusion in sync records
- **REQ-d00109** — already covers enrollment-time UUID recording
- **REQ-d00112** — token revocation remains separate (different error code, different trigger)
- **docs/authentication-strategy.md** — the regulatory narrative doc stands as-is; the new assertions make it formally traceable

## Requirement ID

The new DEV requirement needs a REQ-d##### ID. Per project conventions, new IDs are generated via GitHub Actions.
