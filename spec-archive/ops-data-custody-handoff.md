# Data Custody Transfer and Destruction Protocol

**Version**: 1.0
**Audience**: Operations / Sponsors / Compliance
**Last Updated**: 2025-11-28
**Status**: Draft

> **Scope**: End-of-trial data custody transfer to sponsors and compliant data destruction
>
> **See**: dev-evidence-records.md for Evidence Record implementation details
> **See**: prd-clinical-trials.md for FDA 21 CFR Part 11 compliance requirements
> **See**: dev-compliance-practices.md for ALCOA+ implementation guidance
> **See**: prd-architecture-multi-sponsor.md for multi-sponsor deployment model

---

## Executive Summary

This document defines the operational protocol for transferring data custody to sponsors at trial completion and the subsequent compliant destruction of data under our control. The protocol ensures:

- **Regulatory compliance** with FDA 21 CFR Part 11, ICH E6(R3) GCP, and HIPAA
- **Data integrity** through certified copy validation and Evidence Records
- **Clean separation** of responsibility at trial end
- **Audit-ready documentation** for regulatory inspections
- **NIST 800-88 compliant** data destruction

**Key Principle**: Sponsors have the regulatory obligation to retain trial data. Our role is to generate standards-compliant Evidence Records and certified copies that sponsors (or their archival providers) can maintain for the required retention period.

---

## Tiered Architecture for Long-Term Archival

Given the multi-sponsor model, we adopt a **handoff model** where Evidence Record renewal responsibility transfers to sponsors at trial completion:

```
┌─────────────────────────────────────────────────────────────────┐
│                    During Trial (Our System)                     │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  • Event sourcing with hash chain                          │  │
│  │  • Periodic RFC 3161 timestamps (e.g., daily/weekly)       │  │
│  │  • Generate ERS at key milestones (quarterly, trial end)   │  │
│  └───────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼ Trial Completion
┌─────────────────────────────────────────────────────────────────┐
│                    Handoff Package                               │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  • Complete event store export                             │  │
│  │  • Evidence Records (RFC 4998 format)                      │  │
│  │  • TSA certificates and OCSP responses                     │  │
│  │  • Verification tools / documentation                      │  │
│  └───────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼ Sponsor's Choice
┌─────────────────────────────────────────────────────────────────┐
│               Sponsor Long-Term Archival Options                 │
│                                                                  │
│  Option A: In-house        Option B: Commercial    Option C:     │
│  ┌─────────────────┐      ┌─────────────────┐     Qualified TSP  │
│  │ IT manages      │      │ Veeva/Preservica│     ┌───────────┐  │
│  │ renewals        │      │ handles it      │     │ Swisscom  │  │
│  └─────────────────┘      └─────────────────┘     │ InfoCert  │  │
│                                                    └───────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

### Scope Implications

This handoff model simplifies our implementation scope:

| Component | Our Responsibility | Sponsor's Responsibility |
| ----------- | ------------------- | ------------------------- |
| Merkle tree implementation | ✅ Build and use | Verify at handoff |
| TSA client (RFC 3161) | ✅ Integrate and use | N/A |
| ArchiveTimeStamp codec | ✅ Generate | Consume/verify |
| EvidenceRecord codec | ✅ Generate | Consume/verify |
| **Renewal scheduler** | ❌ Not needed | ✅ Their problem |
| **Long-term monitoring** | ❌ Not needed | ✅ Their problem |
| CMS/PKCS#7 verification | ✅ For validation | ✅ For ongoing verification |
| XMLERS (RFC 6283) | ❌ Unless required | Per sponsor's archival system |

---

## Regulatory Framework

### Applicable Standards

| Standard | Relevance | Key Requirements |
| ---------- | ----------- | ----------------- |
| [FDA 21 CFR Part 11](https://www.fda.gov/regulatory-information/search-fda-guidance-documents/part-11-electronic-records-electronic-signatures-scope-and-application) | Electronic records | Audit trail for deletions; authorized personnel only |
| [ICH E6(R3) GCP](https://ichgcp.net/4-data-governance-investigator-and-sponsor-ich-e6-r3) | Clinical trials | Written transfer agreements; sponsor retains ultimate responsibility |
| [NIST 800-88 Rev. 1](https://csrc.nist.gov/pubs/sp/800/88/r1/final) | Data sanitization | Clear/Purge/Destroy methods; Certificate of Destruction |
| [HIPAA](https://www.hhs.gov/hipaa/index.html) | PHI protection | References NIST 800-88 for PHI destruction |
| [RFC 4998](https://datatracker.ietf.org/doc/html/rfc4998) | Evidence Records | Long-term data integrity proof |

### Key Regulatory Principles

**ICH E6(R3) Section 5.2.1**:
> "A sponsor may transfer any or all of the sponsor's trial-related duties and functions to a CRO, but the ultimate responsibility for the quality and integrity of the trial data always resides with the sponsor."

**21 CFR 11.10(e)**:
> Audit trails must document "actions that create, modify, or delete electronic records" and be "secure, computer-generated, time-stamped."

**NIST 800-88**:
> Certificate of Destruction required; verification procedures per media type.

---

## Gap Analysis: Proposed vs. Industry Standard

### Our Initial Proposal

| Phase | Description |
| ------- | ------------- |
| **1. Trial Completion** | Conclude involvement in study |
| **2. Data Transfer** | Transfer custody of data to sponsor |
| **3. Receipt Verification** | Sponsor verifies receipt |
| **4. Validation Period** | Pre-specified period for sponsor to verify functionality |
| **5. Destruction Order** | Sponsor signs data-destruction order |
| **6. Data Destruction** | Permanently and irrevocably delete all copies |
| **7. Archive Handling** | Transfer or delete long-term archives (Glacier, DR backups) per sponsor choice |

**Assumption**: Sponsor received real-time data during trial (already has full copy)

### Industry Standard Process

Per [ICH GCP](https://ichgcp.net/3-sponsor-ich-e6-r3) and [FDA guidance](https://www.fda.gov/media/83801/download):

```
1. Closeout Planning
   └─ Establish transfer plan early with CRO (before trial end)
   └─ Define retention periods per regulatory requirements
   └─ Agree on format and validation criteria

2. Monitor Closeout Visit
   └─ Verify all documents in appropriate files
   └─ Confirm retention arrangements
   └─ Final investigational product accountability

3. Certified Copy Generation
   └─ Generate certified copies through validated process
   └─ Verify copies preserve context, content, structure
   └─ Document certification (dated signature or validated process)

4. Transfer Execution
   └─ Transfer via secure, validated channel
   └─ Maintain chain of custody documentation
   └─ Report transfer of ownership of essential records

5. Receipt & Validation
   └─ Receiving party validates integrity
   └─ Confirms usability in target system
   └─ Signs acceptance documentation

6. Retention Period
   └─ Originating party may retain copies during transition
   └─ Per ICH: until sponsor confirms records no longer needed
   └─ Minimum regulatory retention periods apply

7. Destruction (if applicable)
   └─ Only after written authorization
   └─ NIST 800-88 compliant sanitization
   └─ Certificate of Destruction generated
   └─ Destruction audit trail retained permanently
```

---

## Detailed Gap Analysis

### Gap 1: Certified Copy Validation

| Aspect | Our Proposal | Industry Standard |
| -------- | -------------- | ------------------- |
| **Copy validation** | "Verify receipt" | [Certified copy](https://www.octalsoft.com/certified-copies-a-guide-to-fda-ema-and-more/) with dated signature or validated process |
| **What's verified** | Unspecified | Context, content, structure, ALCOA attributes |
| **Evidence** | Unspecified | Certification documentation per ICH GCP |

**Risk**: Without certified copy process, sponsor cannot demonstrate data integrity to regulators. FDA may question whether transferred data equals source data.

**Recommendation**: Define certified copy validation criteria:
- Hash verification of all records
- Evidence Record verification
- Schema/structure validation
- Sample audit of randomly selected records
- Documented certification signed by both parties

---

### Gap 2: NIST 800-88 Data Sanitization

| Aspect | Our Proposal | Industry Standard |
| -------- | -------------- | ------------------- |
| **Destruction method** | "Permanently and irrevocably delete" | [NIST 800-88](https://nvlpubs.nist.gov/nistpubs/SpecialPublications/NIST.SP.800-88r1.pdf) Clear/Purge/Destroy |
| **Verification** | Unspecified | Verification per media type |
| **Certificate** | Unspecified | Certificate of Destruction/Disposition required |
| **Cloud data** | Glacier, backups mentioned | Cryptographic erasure or provider attestation |

**Risk**: Without NIST 800-88 compliance, deletion may be incomplete or unverifiable. Regulatory inspection could reveal inadequate destruction process.

**Recommendation**: Specify destruction method per media type (see Section: NIST 800-88 Implementation).

---

### Gap 3: Destruction Audit Trail Retention

| Aspect | Our Proposal | Industry Standard |
| -------- | -------------- | ------------------- |
| **Audit trail** | Not mentioned | [21 CFR 11.10(e)](https://www.fda.gov/regulatory-information/search-fda-guidance-documents/part-11-electronic-records-electronic-signatures-scope-and-application): retained as long as original records |
| **Retention** | Not specified | Same as regulatory retention period |
| **Access** | Not specified | Available for agency review and copying |

**Risk**: If audit trail of destruction is not retained, we cannot prove compliant destruction during regulatory inspection years later.

**Recommendation**: Retain permanently:
- Data destruction order (signed by sponsor)
- Certificate of Destruction (NIST 800-88)
- Audit log of deletion operations
- Evidence that data existed and was properly handled
- Transfer documentation (what was handed off)

---

### Gap 4: Validation Period Definition

| Aspect | Our Proposal | Industry Standard |
| -------- | -------------- | ------------------- |
| **Duration** | "Pre-specified period" | Per contractual agreement; typically 30-90 days |
| **Criteria** | "Verify functionality" | Defined acceptance criteria |
| **Dispute resolution** | Not mentioned | Should be specified |

**Risk**: Vague validation period could lead to disputes. Sponsor might claim issues after extended period.

**Recommendation**: Define explicitly:
- **Duration**: 30/60/90 days (contractually agreed)
- **Acceptance criteria**: Specific tests sponsor must pass
- **Default acceptance**: Auto-accept if no objection within period
- **Dispute process**: Escalation path for issues
- **Extension terms**: Conditions for extending validation period

---

### Gap 5: Post-Destruction Regulatory Response

| Aspect | Our Proposal | Industry Standard |
| -------- | -------------- | ------------------- |
| **Inspection support** | Not addressed | Sponsor may need CRO assistance |
| **Access to personnel** | Not addressed | May need access to personnel with system knowledge |
| **Documentation** | Not addressed | System documentation should be transferred |

**Risk**: If FDA inspects sponsor post-destruction and questions arise about the data system, sponsor may need our assistance but we've destroyed everything.

**Recommendation**: Include in handoff:
- Complete system documentation
- Validation documentation
- SOPs for data handling
- Contact information for key personnel (time-limited)
- Contractual terms for post-destruction support (optional, paid)

---

### Gap 6: Real-Time Sync as Primary vs. Handoff Copy

| Aspect | Our Proposal | Industry Standard |
| -------- | -------------- | ------------------- |
| **Assumption** | Sponsor "already has full copy" via real-time sync | Real-time sync ≠ certified copy |
| **Certification** | Not specified | Real-time sync should produce certified copies |
| **Discrepancy handling** | Not addressed | What if handoff differs from real-time? |

**Risk**: Real-time sync may have had failures, gaps, or timing issues. If handoff package differs from sponsor's copy, which is authoritative?

**Recommendation**:
- Real-time sync should be validated as certified copy process
- Handoff package is reconciliation, not replacement
- Define discrepancy resolution procedure
- Both copies should have identical Evidence Records

---

### Gap 7: Sponsor Responsibility Acknowledgment

| Aspect | Our Proposal | Industry Standard |
| -------- | -------------- | ------------------- |
| **Ongoing responsibility** | Implied by handoff | [ICH GCP 5.2.1](https://ichgcp.net/5-sponsor): Sponsor retains ultimate responsibility |
| **Written acknowledgment** | "Data-destruction order" | Should include responsibility transfer |
| **Future renewals** | Not addressed | Evidence Record maintenance becomes sponsor's duty |

**Risk**: Unclear responsibility boundary could lead to regulatory compliance gaps.

**Recommendation**: Destruction order should include:
- Acknowledgment of receipt of certified copies
- Assumption of responsibility for data integrity
- Assumption of responsibility for Evidence Record renewal
- Release of CRO from further data stewardship obligations

---

## Risk Analysis Summary

### Risks of Original Proposal

| Risk | Severity | Likelihood | Mitigation |
| ------ | ---------- | ------------ | ------------ |
| Incomplete destruction proven | High | Low | NIST 800-88 certification |
| Sponsor claims data corruption | High | Medium | Certified copy validation |
| Regulatory inspection post-destruction | Medium | Medium | Retain audit trail + docs |
| Dispute over validation period | Medium | Medium | Clear contractual terms |
| Evidence Records become unverifiable | High | Medium | Clear handoff of renewal responsibility |

### Advantages of Original Proposal

| Advantage | Benefit |
| ----------- | --------- |
| Clean separation | Clear end of data stewardship responsibility |
| Reduced liability | No ongoing data breach exposure |
| Cost reduction | No ongoing storage costs post-handoff |
| Regulatory clarity | Sponsor is single point of contact for regulators |
| Simplified operations | No long-term archival infrastructure needed |

---

## Enhanced Protocol

Based on gap analysis, the following protocol addresses all identified gaps:

### Phase 1: Pre-Closeout Planning (T-60 to T-30 days)

**Trigger**: 60 days before anticipated trial completion

**Activities**:
- [ ] Notify sponsor of upcoming closeout
- [ ] Schedule closeout planning meeting
- [ ] Agree on handoff package contents and format
- [ ] Agree on validation period duration (recommend 60 days)
- [ ] Agree on destruction method (NIST 800-88 level)
- [ ] Confirm sponsor's target archive system
- [ ] Identify sponsor personnel for validation
- [ ] Document all agreements in Closeout Agreement (see Template A)

**Deliverable**: Signed Closeout Agreement

---

### Phase 2: Certified Copy Generation (T-30 to T-14 days)

**Trigger**: Closeout Agreement signed

**Activities**:
- [ ] Freeze production system (read-only mode)
- [ ] Generate final Evidence Records for all data
- [ ] Export complete event store with Evidence Records
- [ ] Generate hash manifest of all records
- [ ] Package TSA certificates and OCSP responses
- [ ] Include system documentation and validation records
- [ ] Include verification tools (standalone validator)
- [ ] Create certification documentation
- [ ] Internal QA review of handoff package

**Handoff Package Contents**:
```
trial_archive_<sponsor>_<trial_id>_<date>/
├── README.md                           # Human-readable guide
├── manifest.json                       # Machine-readable inventory
├── CERTIFICATION.md                    # Certification statement
│
├── data/
│   ├── events.jsonl                    # All events (JSON Lines format)
│   ├── events.jsonl.sha256             # Hash of events file
│   └── schema_version.json             # Schema version info
│
├── evidence_records/
│   ├── er_<period>.ers                 # Periodic Evidence Records (ASN.1 DER)
│   ├── er_final.ers                    # Trial completion Evidence Record
│   ├── ers_manifest.json               # Index of all Evidence Records
│   └── README.md                       # ERS verification instructions
│
├── certificates/
│   ├── tsa_certificates.pem            # TSA certificate chain
│   ├── ocsp_responses/                 # Archived OCSP responses
│   │   └── <cert_serial>_<date>.ocsp
│   └── certificate_inventory.json      # Certificate metadata
│
├── verification/
│   ├── verify_tool/                    # Standalone verification tool
│   │   ├── pubspec.yaml
│   │   ├── bin/verify.dart
│   │   └── README.md
│   ├── validation_suite.json           # Validation test definitions
│   └── expected_hashes.json            # Expected hash values
│
├── documentation/
│   ├── data_dictionary.md              # Field definitions
│   ├── schema_versions/                # All schema versions used
│   ├── system_validation.pdf           # System validation documentation
│   ├── sops/                           # Relevant SOPs
│   └── user_guide.pdf                  # System user guide
│
└── audit/
    ├── export_audit_log.jsonl          # Audit trail of export process
    ├── hash_verification_report.json   # Pre-transfer hash verification
    └── qc_checklist.pdf                # QA review checklist (signed)
```

**Deliverable**: Complete handoff package, QA-verified

---

### Phase 3: Data Transfer (T-14 to T-7 days)

**Trigger**: Handoff package QA complete

**Activities**:
- [ ] Encrypt handoff package for transfer
- [ ] Transfer via secure channel (options below)
- [ ] Maintain chain of custody log
- [ ] Sponsor acknowledges receipt
- [ ] Verify transfer integrity (hash comparison)

**Transfer Methods** (in order of preference):
1. **Direct secure upload** to sponsor's archive system
2. **Encrypted cloud transfer** (AWS S3 with pre-signed URLs, customer-managed keys)
3. **Physical media** (encrypted drive, courier with chain of custody)

**Deliverable**: Signed Transfer Receipt (see Template B)

---

### Phase 4: Validation Period (T-7 to T+53 days)

**Trigger**: Transfer Receipt signed

**Duration**: 60 days (configurable per Closeout Agreement)

**Sponsor Activities**:
- [ ] Import data to target archive system
- [ ] Run provided validation suite
- [ ] Verify Evidence Record integrity
- [ ] Verify hash manifest matches received data
- [ ] Sample 1% of records for manual verification
- [ ] Verify documentation completeness
- [ ] Report any discrepancies within validation period

**Discrepancy Resolution**:
- Discrepancies reported within validation period: investigate and resolve
- Resolution may extend validation period by up to 30 days
- Unresolved discrepancies escalate to management

**Automatic Acceptance**:
- If no discrepancies reported by validation period end, acceptance is automatic
- Sponsor receives 7-day warning before automatic acceptance

**Deliverable**: Signed Acceptance Certificate (see Template C) or Discrepancy Report

---

### Phase 5: Destruction Authorization (T+53 to T+60 days)

**Trigger**: Acceptance Certificate signed (or automatic acceptance)

**Activities**:
- [ ] Sponsor completes Data Destruction Order (see Template D)
- [ ] Order includes all required acknowledgments:
  - Acknowledgment of certified copy receipt
  - Assumption of data stewardship responsibility
  - Assumption of Evidence Record renewal responsibility
  - Release of CRO from data obligations
  - Authorization for destruction per NIST 800-88
- [ ] We countersign acknowledging destruction obligation
- [ ] Legal review (if required by contract)

**Deliverable**: Signed Data Destruction Order

---

### Phase 6: Data Destruction (T+60 to T+67 days)

**Trigger**: Data Destruction Order fully executed

**Activities**:
- [ ] Execute destruction per NIST 800-88 (see Section: NIST 800-88 Implementation)
- [ ] Primary database: Cryptographic erasure + verification
- [ ] Cloud archives (Glacier): Delete + key destruction
- [ ] Backup systems: Key destruction or purge
- [ ] Logs: Purge operational logs (retain destruction audit trail)
- [ ] Verify destruction per NIST requirements
- [ ] Generate Certificate of Destruction (see Template E)

**Deliverable**: Certificate of Destruction with verification evidence

---

### Phase 7: Documentation Retention (Permanent)

**Trigger**: Certificate of Destruction issued

**Retained Permanently**:
- [ ] Closeout Agreement
- [ ] Transfer Receipt
- [ ] Acceptance Certificate
- [ ] Data Destruction Order
- [ ] Certificate of Destruction
- [ ] Audit trail of destruction operations
- [ ] Handoff package manifest (not data)
- [ ] Evidence Record hashes (not full ERs)

**Purpose**: Enable response to regulatory inquiries about data handling

**Storage**: Secure, access-controlled archive separate from trial data systems

---

## NIST 800-88 Implementation

### Sanitization Methods by Media Type

| Media Type | Location | NIST Method | Procedure | Verification |
| ------------ | ---------- | ------------- | ----------- | -------------- |
| **PostgreSQL Database** | Cloud SQL | Purge | Cryptographic erasure via key rotation | Query returns no data |
| **Cloud Object Storage** | GCS/S3 | Purge | Delete objects + delete encryption keys | List returns empty |
| **AWS Glacier** | AWS | Purge | Delete archives + vault + encryption keys | Vault deletion confirmed |
| **Cloud SQL Backups** | GCP | Purge | Delete all backups + disable automated backups | Backup list empty |
| **Disaster Recovery** | Secondary region | Purge | Same as primary | Same as primary |
| **Application Logs** | Cloud Logging | Clear | Delete log buckets (retain destruction audit) | Logs unavailable |
| **Local Dev Copies** | Developer machines | Clear | Secure delete + verify | Spot check |

### Cryptographic Erasure Process

For cloud-hosted encrypted data, cryptographic erasure is the recommended method:

```
1. Verify encryption status
   └─ Confirm all data encrypted with customer-managed keys (CMEK)
   └─ Document key identifiers

2. Create destruction audit entry
   └─ Timestamp, operator, authorization reference
   └─ List of resources to be destroyed

3. Delete data objects
   └─ Delete all data from storage
   └─ Empty and delete storage containers/buckets

4. Destroy encryption keys
   └─ Schedule key destruction in Cloud KMS (24-hour delay typical)
   └─ After delay, key material is irrecoverable
   └─ Document key destruction confirmation

5. Verify destruction
   └─ Attempt to access data (should fail)
   └─ Attempt to use keys (should fail)
   └─ Document verification results

6. Generate Certificate of Destruction
   └─ Include all verification evidence
   └─ Sign by authorized personnel
```

### Cloud Provider Attestations

For managed services where we don't control physical media:

| Provider | Attestation Type | How to Obtain |
| ---------- | ----------------- | --------------- |
| GCP | Data deletion confirmation | Cloud Console audit logs |
| AWS | S3 deletion markers, Glacier vault deletion | CloudTrail logs |
| Azure | Soft-delete disabled, purge confirmed | Activity logs |

**Note**: Cloud providers do not issue NIST 800-88 certificates directly. Our Certificate of Destruction documents the cryptographic erasure process and cloud provider confirmations.

---

## Template Documents

### Template A: Closeout Agreement

```markdown
# CLOSEOUT AGREEMENT

**Trial ID**: _______________
**Sponsor**: _______________
**CRO**: [Our Company Name]
**Effective Date**: _______________

## 1. Scope

This agreement governs the closeout activities for the above-referenced
clinical trial, including data custody transfer and subsequent data destruction.

## 2. Handoff Package

CRO shall provide a handoff package containing:
- [ ] Complete event store export (JSON Lines format)
- [ ] Evidence Records per RFC 4998
- [ ] TSA certificates and OCSP responses
- [ ] Verification tools and documentation
- [ ] System documentation and validation records

## 3. Transfer Method

Data shall be transferred via: [  ] Secure upload  [  ] Cloud transfer  [  ] Physical media

## 4. Validation Period

Sponsor shall have ____ days (default: 60) from Transfer Receipt to:
- Import and validate data in target system
- Report any discrepancies
- Sign Acceptance Certificate or Discrepancy Report

Automatic acceptance occurs if no response within validation period.

## 5. Destruction Method

Upon signed Data Destruction Order, CRO shall destroy data per NIST 800-88:
- Method: [  ] Clear  [  ] Purge  [  ] Destroy
- Applies to: All primary, backup, and archived copies

## 6. Responsibility Transfer

Upon signing Acceptance Certificate, Sponsor assumes:
- Full responsibility for data integrity
- Responsibility for Evidence Record renewal
- Compliance with regulatory retention requirements

## 7. Post-Destruction Support

[  ] No post-destruction support included
[  ] Post-destruction support available at $____ per hour for ____ months

## Signatures

Sponsor: _________________________ Date: _____________
CRO:     _________________________ Date: _____________
```

---

### Template B: Transfer Receipt

```markdown
# TRANSFER RECEIPT

**Trial ID**: _______________
**Transfer Date**: _______________
**Transfer Method**: _______________

## Package Contents

| Item | File Count | Total Size | SHA-256 (manifest) |
| ------ | ------------ | ------------ | ------------------- |
| Events | ___ | ___ GB | _________________________ |
| Evidence Records | ___ | ___ MB | _________________________ |
| Certificates | ___ | ___ KB | _________________________ |
| Documentation | ___ | ___ MB | _________________________ |

**Total Package Hash (SHA-256)**: _________________________________

## Chain of Custody

| Step | Timestamp | Personnel | Action |
| ------ | ----------- | ----------- | -------- |
| 1 | ___ | ___ | Package created |
| 2 | ___ | ___ | Transfer initiated |
| 3 | ___ | ___ | Transfer completed |
| 4 | ___ | ___ | Receipt confirmed |

## Acknowledgment

Sponsor acknowledges receipt of the above package and confirms:
- [ ] Package received intact
- [ ] Package hash verified
- [ ] Validation period begins on this date

Sponsor: _________________________ Date: _____________
CRO:     _________________________ Date: _____________
```

---

### Template C: Acceptance Certificate

```markdown
# ACCEPTANCE CERTIFICATE

**Trial ID**: _______________
**Validation Period**: _______________ to _______________

## Validation Results

| Check | Result | Notes |
| ------- | -------- | ------- |
| Data import successful | [  ] Pass [  ] Fail | |
| Hash verification | [  ] Pass [  ] Fail | |
| Evidence Record verification | [  ] Pass [  ] Fail | |
| Sample record audit (1%) | [  ] Pass [  ] Fail | |
| Documentation complete | [  ] Pass [  ] Fail | |

## Certification

Sponsor certifies that:

1. The handoff package has been received and validated
2. Data has been successfully imported to Sponsor's archive system
3. Evidence Records have been verified and are intact
4. All documentation is complete and accessible
5. Sponsor accepts responsibility for:
   - Ongoing data integrity
   - Evidence Record renewal per RFC 4998
   - Regulatory retention compliance
   - Response to regulatory inquiries

## Acceptance

Sponsor: _________________________ Date: _____________
Title:   _________________________
```

---

### Template D: Data Destruction Order

```markdown
# DATA DESTRUCTION ORDER

**Trial ID**: _______________
**Order Date**: _______________
**Acceptance Certificate Date**: _______________

## Authorization

Sponsor authorizes CRO to permanently destroy all copies of trial data
under CRO's control, including but not limited to:

- [ ] Primary database (Cloud SQL)
- [ ] Cloud object storage (GCS/S3)
- [ ] Long-term archives (Glacier)
- [ ] Backup systems
- [ ] Disaster recovery copies
- [ ] Application logs (excluding destruction audit trail)

## Destruction Method

Destruction shall be performed per NIST 800-88 Rev. 1:
- Method: Purge (cryptographic erasure)
- Verification: Per NIST 800-88 requirements
- Certificate: CRO shall provide Certificate of Destruction

## Acknowledgments

Sponsor acknowledges and agrees:

1. **Receipt Confirmed**: Sponsor has received certified copies of all data
2. **Validation Complete**: Data has been validated per Acceptance Certificate
3. **Responsibility Assumed**: Sponsor assumes full responsibility for:
   - Data integrity and retention
   - Evidence Record maintenance and renewal
   - Regulatory compliance
4. **Release**: Sponsor releases CRO from further data stewardship obligations
5. **Irreversibility**: Data destruction is permanent and irreversible
6. **No Copies**: After destruction, CRO will retain no copies of trial data
   (CRO retains destruction documentation only)

## Signatures

**Sponsor Authorized Representative**:

Signature: _________________________ Date: _____________
Name:      _________________________
Title:     _________________________

**CRO Authorized Representative**:

Signature: _________________________ Date: _____________
Name:      _________________________
Title:     _________________________
```

---

### Template E: Certificate of Destruction

```markdown
# CERTIFICATE OF DESTRUCTION

**Certificate Number**: COD-_______________
**Trial ID**: _______________
**Destruction Date**: _______________
**Destruction Order Reference**: _______________

## Destruction Summary

| Media Type | Location | Method | Verification | Completed |
| ------------ | ---------- | -------- | -------------- | ----------- |
| PostgreSQL Database | Cloud SQL | Cryptographic Erasure | Query test | [  ] |
| Object Storage | GCS | Delete + Key Destruction | List test | [  ] |
| Glacier Archives | AWS | Vault Deletion | API confirmation | [  ] |
| Backups | GCP | Backup Deletion | List empty | [  ] |
| DR Copies | Secondary Region | Same as primary | Same as primary | [  ] |
| Logs | Cloud Logging | Bucket Deletion | Unavailable | [  ] |

## Encryption Key Destruction

| Key ID | Key Type | Destruction Method | Confirmed |
| -------- | ---------- | ------------------- | ----------- |
| ___ | Database encryption | KMS scheduled destruction | [  ] |
| ___ | Storage encryption | KMS scheduled destruction | [  ] |
| ___ | Backup encryption | KMS scheduled destruction | [  ] |

## Verification Evidence

- [ ] Data access attempts failed (attached: verification_log.json)
- [ ] Key usage attempts failed (attached: key_verification.json)
- [ ] Cloud provider audit logs confirm deletion (attached)
- [ ] No data recoverable by any known method

## Retained Documentation

The following documentation is retained per regulatory requirements:
- Closeout Agreement
- Transfer Receipt
- Acceptance Certificate
- Data Destruction Order
- This Certificate of Destruction
- Destruction audit trail

**No trial data is retained.**

## Certification

I certify that the data destruction described above has been performed
in accordance with NIST 800-88 Rev. 1 guidelines and the Data Destruction
Order referenced above.

**Destruction Operator**:
Signature: _________________________ Date: _____________
Name:      _________________________

**Verification Witness**:
Signature: _________________________ Date: _____________
Name:      _________________________

**Authorized Representative**:
Signature: _________________________ Date: _____________
Name:      _________________________
Title:     _________________________
```

---

## Validation Suite Requirements

The handoff package includes a validation suite that sponsors can run to verify data integrity:

### Validation Tests

```json
{
  "validation_suite": {
    "version": "1.0",
    "tests": [
      {
        "id": "HASH-001",
        "name": "Event file hash verification",
        "description": "Verify SHA-256 hash of events.jsonl matches manifest",
        "type": "hash_verification",
        "target": "data/events.jsonl",
        "expected_hash_file": "data/events.jsonl.sha256"
      },
      {
        "id": "ER-001",
        "name": "Evidence Record integrity",
        "description": "Verify all Evidence Records are valid and verifiable",
        "type": "evidence_record_verification",
        "target": "evidence_records/*.ers"
      },
      {
        "id": "ER-002",
        "name": "Evidence Record coverage",
        "description": "Verify all events are covered by Evidence Records",
        "type": "evidence_record_coverage",
        "events_file": "data/events.jsonl",
        "ers_manifest": "evidence_records/ers_manifest.json"
      },
      {
        "id": "CERT-001",
        "name": "TSA certificate chain",
        "description": "Verify TSA certificates form valid chain",
        "type": "certificate_chain_verification",
        "target": "certificates/tsa_certificates.pem"
      },
      {
        "id": "SCHEMA-001",
        "name": "Event schema validation",
        "description": "Verify all events conform to documented schema",
        "type": "schema_validation",
        "events_file": "data/events.jsonl",
        "schema_file": "documentation/schema_versions/current.json"
      },
      {
        "id": "SAMPLE-001",
        "name": "Random sample audit",
        "description": "Select 1% of events for manual review",
        "type": "sample_selection",
        "sample_percentage": 1,
        "output_file": "validation_results/sample_for_review.json"
      }
    ]
  }
}
```

### Standalone Verification Tool

```dart
// bin/verify.dart - Standalone verification tool included in handoff package

import 'dart:io';
import 'package:crypto/crypto.dart';

Future<void> main(List<String> args) async {
  final packageDir = args.isNotEmpty ? args[0] : '.';

  print('Diary Data Package Verification Tool');
  print('=========================================\n');

  final results = <String, bool>{};

  // Test 1: Hash verification
  print('Verifying file hashes...');
  results['HASH-001'] = await verifyFileHash(
    '$packageDir/data/events.jsonl',
    '$packageDir/data/events.jsonl.sha256',
  );

  // Test 2: Evidence Record verification
  print('Verifying Evidence Records...');
  results['ER-001'] = await verifyEvidenceRecords(
    '$packageDir/evidence_records',
  );

  // Test 3: Certificate chain
  print('Verifying certificate chain...');
  results['CERT-001'] = await verifyCertificateChain(
    '$packageDir/certificates/tsa_certificates.pem',
  );

  // Print summary
  print('\n=========================================');
  print('VERIFICATION SUMMARY');
  print('=========================================');

  var allPassed = true;
  for (final entry in results.entries) {
    final status = entry.value ? 'PASS' : 'FAIL';
    print('${entry.key}: $status');
    if (!entry.value) allPassed = false;
  }

  print('\nOverall: ${allPassed ? "ALL TESTS PASSED" : "SOME TESTS FAILED"}');

  exit(allPassed ? 0 : 1);
}
```

---

## Commercial Archival Solutions for Sponsors

Sponsors may choose to use commercial solutions for long-term archival and Evidence Record maintenance:

### Long-Term Digital Preservation Platforms

| Solution | Focus | ERS Support | Notes |
| ---------- | ------- | ------------- | ------- |
| [Preservica](https://preservica.com) | Enterprise archival | Built-in | Used by pharma, government |
| [Arkivum](https://arkivum.com) | Regulated industries | Yes | Life sciences focus |
| [Veeva Vault](https://veeva.com) | Life sciences | Retention policies | eTMF, regulatory submissions |

### Qualified Trust Service Providers (eIDAS)

| Provider | Services | Region |
| ---------- | ---------- | -------- |
| [Swisscom Trust Services](https://trustservices.swisscom.com) | Qualified preservation | EU/CH |
| [InfoCert](https://infocert.it) | QTSP, long-term preservation | EU |
| [Entrust](https://entrust.com) | Timestamps, preservation | Global |

---

## Integration with Evidence Records

This custody transfer protocol integrates with the Evidence Records implementation (see dev-evidence-records.md):

### Evidence Records in Handoff

| ERS Component | Handoff Treatment |
| --------------- | ------------------- |
| Merkle trees | Fully included in .ers files |
| TimeStampTokens | Included with full TSA response |
| TSA certificates | Included in certificates/ directory |
| OCSP responses | Archived at time of timestamp creation |
| Verification code | Standalone tool in verification/ directory |

### Sponsor Renewal Responsibility

After handoff, sponsors are responsible for:
1. **Timestamp renewal**: Before TSA certificates expire
2. **Algorithm renewal**: Before hash algorithms become weak
3. **Verification**: Periodic verification of Evidence Record integrity

Sponsors may fulfill this through:
- In-house IT with ERS expertise
- Commercial archival platform (Preservica, etc.)
- Qualified Trust Service Provider (Swisscom, InfoCert, etc.)

---

## References

### Standards
- [FDA 21 CFR Part 11](https://www.fda.gov/regulatory-information/search-fda-guidance-documents/part-11-electronic-records-electronic-signatures-scope-and-application)
- [ICH E6(R3) GCP](https://database.ich.org/sites/default/files/ICH_E6(R3)_DraftGuideline_2023_0519.pdf)
- [NIST 800-88 Rev. 1](https://nvlpubs.nist.gov/nistpubs/SpecialPublications/NIST.SP.800-88r1.pdf)
- [RFC 4998 - Evidence Record Syntax](https://datatracker.ietf.org/doc/html/rfc4998)

### Guidance Documents
- [FDA Guidance on Computerized Systems in Clinical Trials](https://www.fda.gov/inspections-compliance-enforcement-and-criminal-investigations/fda-bioresearch-monitoring-information/guidance-industry-computerized-systems-used-clinical-trials)
- [FDA Guidance on Electronic Source Data](https://www.fda.gov/media/85183/download)

### Internal Documentation
- dev-evidence-records.md - Evidence Record implementation
- prd-clinical-trials.md - Clinical trial compliance requirements
- dev-compliance-practices.md - ALCOA+ implementation

---

## Revision History

| Version | Date | Changes | Author |
| --------- | ------ | --------- | -------- |
| 1.0 | 2025-11-28 | Initial draft | Development Team |

---

**Document Classification**: Internal Use - Operations
**Review Frequency**: Annually or when regulations change
**Owner**: Operations / Compliance Team
