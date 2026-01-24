# Development Specification: Linking Codes and Auth Service

**Document Type**: Development Specification (Implementation Blueprint)
**Audience**: Software Engineers, Backend Developers, DevOps Engineers
**Status**: Draft
**Last Updated**: 2025-01-23

---

## Overview

This document specifies the technical implementation requirements for linking codes and the HHT Diary Auth Service. The auth service provides secure user authentication, linking code validation, and sponsor routing for the HHT Diary platform. The service is deployed on GCP Cloud Run and avoids GDPR concerns associated with third-party identity providers.

**Related Documents**:
- Product Requirements: `spec/prd-diary-web.md` (REQ-p01043: Web Diary Authentication via Linking Code)
- Portal Requirements: `spec/prd-portal.md`, `spec/dev-portal.md` (Linking code generation)
- Multi-Sponsor Architecture: `spec/prd-architecture-multi-sponsor.md` (REQ-p00009)

---

# REQ-d00078: HHT Diary Auth Service

**Level**: Dev | **Status**: Draft | **Implements**: p01043

## Rationale

A custom authentication service is needed to avoid GDPR concerns associated with Identity Platform while maintaining full control over the authentication flow. This service implements REQ-p01043 by providing secure user authentication, linking code validation, and sponsor routing for the HHT Diary platform. Cloud Run provides auto-scaling and managed infrastructure for the service deployment.

## Assertions

A. The system SHALL implement a custom authentication service on GCP Cloud Run.
B. The authentication service SHALL NOT use Identity Platform or Google Identity Platform.
C. The service SHALL be written in Dart using either shelf or dart_frog framework.
D. The system SHALL store user credentials in a Firestore collection.
E. The service SHALL generate and validate JWT tokens using the dart_jsonwebtoken package.
F. The service SHALL provide a POST /auth/register endpoint to create new user accounts.
G. The service SHALL provide a POST /auth/login endpoint to authenticate users and return JWT tokens.
H. The service SHALL provide a POST /auth/refresh endpoint to refresh JWT tokens.
I. The service SHALL provide a POST /auth/change-password endpoint to update user passwords.
J. The service SHALL provide a POST /auth/validate-linking-code endpoint to validate linking codes and return sponsor information.
K. JWT tokens SHALL include the following payload fields: sub (user document ID), username, sponsorId, sponsorUrl, appUuid, iat (issued at), and exp (expiration).
L. The service SHALL implement rate limiting to prevent brute force attacks.
M. The service SHALL limit failed login attempts to 5 attempts per minute.
N. The system SHALL log all authentication events as audit records.
O. All authentication events SHALL be logged to Cloud Logging.
P. The service SHALL be deployed to Cloud Run with an HTTPS endpoint.
Q. JWT tokens SHALL expire after 15 minutes.
R. The service SHALL support JWT token refresh capability.
S. The service SHALL respond within 500ms for all authentication operations.

*End* *HHT Diary Auth Service* | **Hash**: d484bab8

---

# REQ-d00079: Linking Code Pattern Matching

**Level**: Dev | **Status**: Draft | **Implements**: p01043

## Rationale

Pattern-based routing enables a single auth service to handle multiple sponsors without exposing sponsor selection to users. The prefix approach mirrors proven systems like credit card BIN ranges, allowing for scalable multi-sponsor deployments while maintaining a seamless user experience. This requirement implements the technical infrastructure for REQ-p01043's sponsor identification mechanism.

## Assertions

A. The system SHALL implement pattern-based sponsor identification from linking codes.
B. The system SHALL maintain a configurable mapping table for pattern-to-sponsor associations.
C. Each sponsor pattern record SHALL include patternPrefix, sponsorCodename, portalUrl, active status, createdAt timestamp, and optional decommissionedAt timestamp.
D. The system SHALL perform pattern matching using prefix comparison logic.
E. The system SHALL return the sponsorCodename when a linking code matches an active pattern prefix.
F. The system SHALL return a clear error message for unknown linking code patterns.
G. The system SHALL provide an admin API for pattern table management.
H. The admin API SHALL support adding new sponsor patterns.
I. The admin API SHALL support decommissioning sponsors.
J. The system SHALL allow addition of new patterns without requiring service restart.
K. Linking codes SHALL consist of a two-character sponsor prefix followed by an 8-character random alphanumeric identifier (10 characters total, no separators).
L. The system SHALL display linking codes in the format {SS}{XXX}-{XXXXX} where the dash is for readability only and not part of the stored code.
M. Linking codes SHALL use only uppercase letters A-Z and digits 0-9.
N. Linking codes SHALL NOT use visually ambiguous characters: I, 1, O, 0, S, 5, Z, 2.
O. Each sponsor deployment SHALL define a unique two-character sponsor prefix.

*End* *Linking Code Pattern Matching* | **Hash**: d7267507
---

# REQ-d00081: User Document Schema

**Level**: Dev | **Status**: Draft | **Implements**: p01046

## Rationale

This requirement defines the authentication data storage schema for the clinical trial platform. Storing authentication data in a dedicated Firestore collection separate from clinical data maintains separation of concerns and supports multi-sponsor isolation. The schema design enables account security features (lockout, rate limiting), audit trail compliance with FDA 21 CFR Part 11, and traceability back to the original enrollment linking process.

## Assertions

A. The system SHALL store user authentication data in a Firestore collection named 'web_users' in the HHT Diary Auth project.
B. The system SHALL generate document IDs as UUID v4.
C. The system SHALL enforce a compound index on 'sponsorId' and 'username' fields.
D. The system SHALL enforce uniqueness of the username and sponsorId combination.
E. The system SHALL store passwords as Argon2id hashes.
F. The system SHALL use secure parameters for Argon2id password hashing.
G. User documents SHALL include the following fields: id (UUID v4), username, passwordHash, sponsorId, linkingCode, appUuid, createdAt, lastLoginAt (nullable), failedAttempts, and lockedUntil (nullable).
H. The username field SHALL contain user-chosen usernames of 6 or more characters without the @ symbol.
I. The sponsorId field SHALL contain the sponsor identifier from the linking code.
J. The linkingCode field SHALL contain the original linking code used during registration.
K. The appUuid field SHALL contain the app instance UUID at registration time.
L. The createdAt field SHALL contain the account creation timestamp.
M. The system SHALL create a user document upon successful registration.
N. The system SHALL update the lastLoginAt field on each successful authentication.
O. The system SHALL track failed login attempts in the failedAttempts field.
P. The system SHALL reset the failedAttempts counter on successful login.
Q. The web_users collection SHALL be readable and writable only by the auth service account.
R. The system SHALL NOT allow client-side access to user documents.
S. The system SHALL enforce sponsor isolation through service logic.

*End* *User Document Schema* | **Hash**: b5b5f999

---

## Version History

| Version | Date       | Changes                                         | Ticket |
| ------- | ---------- | ----------------------------------------------- | ------ |
| 1.0     | 2025-01-23 | Initial creation, moved from dev-diary-web.md   | -      |
