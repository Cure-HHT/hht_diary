# Portal Linking API Specification

**Version**: 1.0
**Audience**: Development
**Last Updated**: 2026-01-30
**Status**: Draft

> **See**: prd-portal.md for linking code lifecycle (REQ-p70007)
> **See**: dev-linking.md for linking code validation logic (REQ-d00078, REQ-d00079)
> **See**: dev-diary-app-linking.md for mobile app client implementation (REQ-d00094-d00108)

---

## Executive Summary

This specification defines the Portal Linking API endpoint that mobile apps call to validate linking codes and receive enrollment tokens. It covers the HTTP interface, request/response schemas, error handling strategy, and audit logging requirements.

**Security Principle**: Client responses are intentionally minimal to prevent information disclosure. Detailed error reasons are recorded server-side in the audit log for support troubleshooting.

---

## Section 1: Linking API Endpoint

# REQ-d00109: Portal Linking Code Validation Endpoint

**Level**: Dev | **Status**: Draft | **Implements**: REQ-p70007 | **Refines**: REQ-d00078

Addresses: JNY-Portal-Enrollment-01

## Rationale

The Portal Linking API is the server-side endpoint that mobile apps call to validate linking codes and establish enrollment. This endpoint bridges the mobile app (REQ-d00094-d00108) and the server-side linking code validation logic (REQ-d00078). The API design prioritizes security through minimal information disclosure while providing sufficient data for successful enrollment.

## Assertions

A. The system SHALL expose a linking code validation endpoint at `POST /api/v1/linking/validate`.

B. The system SHALL accept a JSON request body containing `linkingCode` (string, required) and `deviceUuid` (string, required).

C. The system SHALL accept optional `deviceInfo` object containing `platform`, `osVersion`, and `appVersion` fields.

D. The system SHALL validate the linking code per REQ-d00078 (format, expiration, usage status).

E. The system SHALL return HTTP 200 with enrollment tokens on successful validation.

F. The successful response SHALL include `accessToken`, `sponsorConfig`, and `patientId` fields.

G. The `sponsorConfig` object SHALL include `sponsorName`, `sponsorUrl`, and `branding` configuration.

H. The system SHALL mark the linking code as used per REQ-d00078-D upon successful validation.

I. The system SHALL record the device UUID association per REQ-d00078-E upon successful validation.

J. The system SHALL enforce rate limiting per REQ-d00078-F on the endpoint.

K. The system SHALL require HTTPS for all requests to the linking endpoint.

L. The system SHALL validate Content-Type header is `application/json`.

M. The system SHALL reject requests with missing or malformed JSON body with HTTP 400.

N. The system SHALL set response timeout to 30 seconds maximum.

O. The system SHALL issue enrollment tokens as perpetual (no expiration date).

P. The system SHALL NOT include an expiration timestamp in the token response.

Q. The system SHALL maintain token validity until explicitly revoked through portal administrative actions.

*End* *Portal Linking Code Validation Endpoint* | **Hash**: bac91a72

---

## Section 2: Error Response Design

# REQ-d00110: Linking API Error Response Strategy

**Level**: Dev | **Status**: Draft | **Implements**: REQ-p70007 | **Refines**: REQ-d00078

## Rationale

Per REQ-p70007-G, the system returns generic error messages to prevent information disclosure about code validity. Attackers cannot distinguish between expired, used, or non-existent codes. However, users need a reference code to provide to support staff, enabling support to look up the detailed reason in the audit log. This balances security with usability.

## Assertions

A. The system SHALL return exactly two categories of error responses: code validation errors and service errors.

B. For any linking code validation failure (invalid, expired, used, unknown prefix, rate limited), the system SHALL return HTTP 401 with response body `{"error": "Unable to verify code", "ref": "{reference}"}`.

C. For service unavailability or internal errors, the system SHALL return HTTP 503 with response body `{"error": "Service unavailable", "ref": "{reference}"}`.

D. The system SHALL NOT return different HTTP status codes or error messages for different code validation failure reasons.

E. The `ref` field SHALL contain a support reference in the format `{category}-{timestamp_base36}` where category is `CODE` or `SVC`.

F. The support reference timestamp SHALL be the Unix timestamp of the error occurrence encoded in base36.

G. The system SHALL NOT include in client responses: the reason for code rejection, whether the code exists, expiration status, or usage status.

H. For malformed requests (invalid JSON, missing fields), the system SHALL return HTTP 400 with response body `{"error": "Invalid request", "ref": "CODE-{timestamp_base36}"}`.

I. The system SHALL include `Content-Type: application/json` header in all error responses.

J. The system SHALL NOT include stack traces, internal error codes, or debugging information in client-facing responses.

*End* *Linking API Error Response Strategy* | **Hash**: 39ae2a18

---

## Section 3: Audit Logging

# REQ-d00111: Linking API Audit Trail

**Level**: Dev | **Status**: Draft | **Implements**: REQ-p00010 | **Refines**: REQ-d00078

## Rationale

FDA 21 CFR Part 11 requires complete audit trails for electronic records. The linking API audit log captures detailed information about each validation attempt, enabling support troubleshooting and regulatory compliance. The audit log contains the security-sensitive details intentionally omitted from client responses.

## Assertions

A. The system SHALL create an audit log entry for every linking code validation request.

B. Each audit log entry SHALL include: `timestamp`, `event_type`, `result`, `support_ref`, `device_uuid`, `client_ip_hash`, and `request_id`.

C. For failed validations, the audit log entry SHALL include a `reason` field with the specific failure cause.

D. The `reason` field SHALL use one of the following values: `CODE_NOT_FOUND`, `CODE_EXPIRED`, `CODE_ALREADY_USED`, `SPONSOR_PREFIX_UNKNOWN`, `RATE_LIMIT_EXCEEDED`, `FORMAT_INVALID`, `REQUEST_MALFORMED`.

E. The system SHALL NOT store the actual linking code value in audit logs; instead it SHALL store a SHA-256 hash of the code.

F. The system SHALL NOT store the actual client IP address; instead it SHALL store a SHA-256 hash of the IP.

G. For successful validations, the audit log entry SHALL include the `patient_id` and `sponsor_codename`.

H. The `support_ref` in the audit log SHALL match the `ref` value returned to the client, enabling support lookup.

I. Audit log entries SHALL be immutable once written per REQ-p00010.

J. The system SHALL retain linking audit logs for the duration specified in REQ-p00012 (Clinical Data Retention Requirements).

K. The system SHALL index audit logs by `support_ref` and `timestamp` for efficient support queries.

L. The system SHALL log the `request_id` as a UUID v7 for correlation with other system logs.

*End* *Linking API Audit Trail* | **Hash**: 90a41f24

---

## Section 4: Token Revocation

# REQ-d00112: Enrollment Token Revocation

**Level**: Dev | **Status**: Draft | **Implements**: REQ-p70010 | **Refines**: REQ-d00078

## Rationale

Enrollment tokens are perpetual and remain valid until explicitly revoked through portal administrative actions. Revocation is the sole mechanism for invalidating a patient's access to synchronization. This approach simplifies client implementation while maintaining security through server-side control. All revocation actions are logged for audit compliance.

## Assertions

A. The system SHALL revoke enrollment tokens only through explicit portal administrative actions.

B. The system SHALL support token revocation through the following portal actions: patient disconnection, lost device reported, and administrative revocation.

C. The system SHALL immediately invalidate all API requests using a revoked token.

D. The system SHALL return HTTP 401 for any authenticated request using a revoked token.

E. The system SHALL include error code `TOKEN_REVOKED` in the response body for revoked token requests.

F. The system SHALL NOT automatically expire or revoke tokens based on time elapsed.

G. The system SHALL NOT automatically revoke tokens based on inactivity.

H. The system SHALL maintain a revocation record including: `patient_id`, `device_uuid`, `revoked_at`, `revoked_by`, and `revocation_reason`.

I. The system SHALL log all token revocation events to the audit trail per REQ-p00010.

J. The system SHALL support revoking all tokens for a patient (multi-device scenario) through a single administrative action.

K. The system SHALL allow issuing a new linking code after token revocation to enable patient re-enrollment.

L. The system SHALL NOT delete historical data when revoking tokens; revocation only prevents future synchronization.

*End* *Enrollment Token Revocation* | **Hash**: e8863441

---

## References

- **Portal Requirements**: prd-portal.md (REQ-p70007, REQ-p70009, REQ-p70010, REQ-p70011)
- **Linking Code Validation**: dev-linking.md (REQ-d00078, REQ-d00079, REQ-d00081)
- **Mobile App Client**: dev-diary-app-linking.md (REQ-d00094-d00108)
- **FDA Compliance**: prd-clinical-trials.md (REQ-p00010)
- **Data Retention**: prd-clinical-trials.md (REQ-p00012)

---

## Revision History

| Version | Date | Changes | Ticket |
| --- | --- | --- | --- |
| 1.0 | 2026-01-30 | Initial Portal Linking API specification | CUR-774 |
| 1.1 | 2026-02-02 | Added perpetual token policy (REQ-d00109 O-Q), token revocation (REQ-d00112) | CUR-495 |

---

**Document Classification**: Internal Use - Development Specification
**Review Frequency**: Quarterly or when modifying Portal Linking API
**Owner**: Development Team
