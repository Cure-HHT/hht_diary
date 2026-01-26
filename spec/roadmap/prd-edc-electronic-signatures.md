# Electronic Signature Requirements

**Version**: 1.0
**Audience**: Product Requirements
**Status**: Roadmap (Future EDC capability)

---

## Overview

Electronic signature workflow requirements for FDA 21 CFR Part 11 compliance. Required if the Diary Platform evolves into a full EDC, replacing Medidata RAVE.

---

## REQ-p90010: Signature Precondition Validation

**Level**: PRD | **Status**: Roadmap

The system SHALL validate preconditions before permitting electronic signatures.

Preconditions SHALL include:
- All required data entry complete
- Double-entry validation complete (if required by study)
- No forms in "data being entered" state
- Subject not withdrawn or removed

Signing SHALL be blocked with clear messaging if preconditions are not met.

**Rationale**: Signatures must only apply to complete, validated data sets to ensure regulatory integrity.

*End* *Signature Precondition Validation*

---

## REQ-p90011: Signature Re-Authentication

**Level**: PRD | **Status**: Roadmap

The system SHALL require credential re-entry at time of signing, regardless of existing session.

Re-authentication SHALL ensure:
- User enters username and password
- Credentials match current session user
- Authentication timestamp captured separately from signature timestamp

**Rationale**: FDA 21 CFR Part 11.200 requires signatures to be under sole control of signer at time of execution.

*End* *Signature Re-Authentication*

---

## REQ-p90012: Legal Agreement Acknowledgment

**Level**: PRD | **Status**: Roadmap

The system SHALL display and require acknowledgment of legal text before signature execution.

Legal agreement SHALL:
- State the meaning of the signature (review, approval, responsibility)
- Confirm intent for electronic signature to be legally binding
- Note that date/time will be system-recorded
- Be versioned with hash for audit purposes

**Rationale**: FDA 21 CFR Part 11.50 requires signatures to include meaning and printed name.

*End* *Legal Agreement Acknowledgment*

---

## REQ-p90013: Signature Attribution Capture

**Level**: PRD | **Status**: Roadmap

The system SHALL capture complete attribution at time of signature.

Attribution SHALL include:
- Signer user identifier
- Signer full name (at time of signature)
- Signer role
- Signature timestamp (server-authoritative)
- Authentication timestamp

**Rationale**: Complete attribution supports audit trail and regulatory inspection requirements.

*End* *Signature Attribution Capture*

---

## REQ-p90014: Signature-Record Binding

**Level**: PRD | **Status**: Roadmap

The system SHALL create tamper-evident binding between signature and signed data.

Binding SHALL include:
- Entity type and identifier
- Cryptographic hash of entity state at signature time
- Reference enabling verification that data has not changed

**Rationale**: FDA 21 CFR Part 11.70 requires signatures to be linked to their respective records.

*End* *Signature-Record Binding*

---

## REQ-p90015: Signature Invalidation

**Level**: PRD | **Status**: Roadmap

The system SHALL automatically invalidate signatures when signed data is modified.

Invalidation SHALL:
- Detect any modification to signed entity
- Create invalidation record referencing original signature
- Capture triggering modification event
- Require re-signature for data to return to signed state

**Rationale**: Signatures must accurately reflect current data state; modifications break this linkage.

*End* *Signature Invalidation*

---

## REQ-p90016: Role-Based Signing Permissions

**Level**: PRD | **Status**: Roadmap

The system SHALL restrict signing capability to authorized roles.

Authorized roles SHALL include:
- Investigator (primary signing role)
- Study Director
- Coordinator
- System Administrator

Non-signing roles:
- Research Assistant (data entry only)
- Monitor (read-only)
- Auditor (read-only)

**Rationale**: Only qualified personnel with appropriate authority may sign clinical data.

*End* *Role-Based Signing Permissions*

---

## Signature Workflow Summary

```
1. Precondition Check
   ↓ (all conditions met)
2. Display Legal Agreement
   ↓ (user acknowledges)
3. Re-Authentication Challenge
   ↓ (credentials verified)
4. Confirmation Summary
   ↓ (user confirms)
5. Signature Execution
   ↓ (event created, hash computed)
6. Confirmation Display
```

---

## References

- FDA 21 CFR Part 11.50: Signature manifestations
- FDA 21 CFR Part 11.70: Signature/record linking
- FDA 21 CFR Part 11.200: Electronic signature components
