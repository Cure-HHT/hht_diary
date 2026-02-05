# CUR-774 Specifications Gap Analysis

**Ticket**: CUR-774 - Define Mobile App Implementation Specifications for Iteration 2
**Date**: 2026-01-27
**Status**: Gap analysis complete

---

## Summary

| Topic | Status | Coverage |
| ----- | ------ | -------- |
| Linking Code Entry | ✅ Complete | Full product + dev specs |
| Study Start Questionnaire | ✅ Complete | Comprehensive specs |
| Portal Linking API | ✅ Complete | Full API spec (REQ-d00109-d00111) |
| Diary-Sponsor Lifecycle | ✅ Complete | State machine (REQ-d00101-d00105) |
| Token Lifecycle Management | ✅ Complete | Full spec (REQ-d00096-d00098) |
| Diary Linking Error Scenarios | ✅ Complete | Security-conscious design (REQ-d00099-d00100, REQ-d00110) |

---

## ✅ Complete (2 of 6)

### 1. Linking Code Entry

**Key Files**:
- `spec/prd-portal.md`
- `spec/dev-linking.md`

**Main REQs**:
- REQ-p70007 (Linking Code Lifecycle Management)
- REQ-p70009 (Link New Patient Workflow)
- REQ-d00078 (Linking Code Validation)
- REQ-d00079 (Linking Code Pattern Matching)
- REQ-d00081 (Linked Device Records)

**Coverage**: All aspects covered from product through implementation - code generation, 72-hour expiration, single-use, secure format, audit logging, prefix-based sponsor identification.

---

### 6. Study Start Questionnaire

**Key Files**:
- `spec/prd-questionnaire-system.md`
- `spec/prd-questionnaire-approval.md`
- `spec/prd-questionnaire-epistaxis.md`
- `spec/prd-questionnaire-nose-hht.md`
- `spec/prd-questionnaire-qol.md`

**Main REQs**:
- REQ-p01064 (Investigator Questionnaire Approval Workflow)
- REQ-p01065 (Clinical Questionnaire System)
- REQ-p01066 (Daily Epistaxis Record Questionnaire)
- REQ-p01067 (NOSE HHT Questionnaire)
- REQ-p01068 (HHT Quality of Life Questionnaire)

**Coverage**: Complete - questionnaire framework, versioning, localization, user journeys, approval process, status state machine, audit trail, data sync gating.

---

## ✅ Now Complete (Previously Partial/Incomplete)

### 2. Portal Linking API Definition

**Status**: ✅ Complete (2026-01-30)

**New Specification**: `spec/dev-portal-api.md`
- REQ-d00109: Portal Linking Code Validation Endpoint
- REQ-d00110: Linking API Error Response Strategy
- REQ-d00111: Linking API Audit Trail

**Covers**:
- Formal endpoint definition (`POST /api/v1/linking/validate`)
- Request/response schemas
- Security-conscious error design (two categories: CODE, SVC)
- Support reference codes for troubleshooting
- Comprehensive audit logging

---

### 3. Token Lifecycle Management

**Status**: ✅ Complete (2026-01-27)

**Specification**: `spec/dev-diary-app-linking.md`
- REQ-d00096: Enrollment Token Secure Storage
- REQ-d00097: Token Refresh and Expiration Handling
- REQ-d00098: Token Invalidation on Disconnection

---

### 4. Diary Linking Error Scenarios

**Status**: ✅ Complete (2026-01-30)

**Specifications**:
- `spec/dev-diary-app-linking.md` (client-side)
  - REQ-d00099: Linking Code Error Handling
  - REQ-d00100: Network Failure Handling During Linking
- `spec/dev-portal-api.md` (server-side)
  - REQ-d00110: Linking API Error Response Strategy

**Design Decision**: Two-category error responses (CODE/SVC) with support references. Detailed reasons logged server-side only per REQ-p70007-G security principle.

---

### 5. Diary-Sponsor Lifecycle Definition

**Status**: ✅ Complete (2026-01-27)

**Specification**: `spec/dev-diary-app-linking.md`
- REQ-d00101: Enrollment State Machine
- REQ-d00102: Enrollment State Behaviors
- REQ-d00103: Disconnection Detection
- REQ-d00104: Contact Study Coordinator Screen
- REQ-d00105: Reconnection Recovery Path

---

## Action Items

**CUR-774 Gap Analysis: ALL GAPS CLOSED**

All six topics now have complete specifications:

| Topic | Specification File | Requirements |
| ----- | ------------------ | ------------ |
| Linking Code Entry | dev-diary-app-linking.md | REQ-d00094, REQ-d00095 |
| Study Start Questionnaire | dev-diary-app-linking.md | REQ-d00106, REQ-d00107, REQ-d00108 |
| Portal Linking API | dev-portal-api.md | REQ-d00109, REQ-d00110, REQ-d00111 |
| Diary-Sponsor Lifecycle | dev-diary-app-linking.md | REQ-d00101-REQ-d00105 |
| Token Lifecycle Management | dev-diary-app-linking.md | REQ-d00096, REQ-d00097, REQ-d00098 |
| Diary Linking Error Scenarios | dev-diary-app-linking.md + dev-portal-api.md | REQ-d00099, REQ-d00100, REQ-d00110 |

**Next Steps**:
1. Commit the new specifications
2. Update spec/INDEX.md with new requirements
3. Create implementation tickets for REQ-d00109-d00111
