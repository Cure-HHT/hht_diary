# Evidence Records and Data Provenance

**Version**: 1.1
**Audience**: Product Requirements
**Last Updated**: 2025-12-03
**Status**: Draft

---

## Executive Summary

Rigorous clinical trials require proof of the validity of the data used. This includes:
- **When** the data was collected
- **Who** collected the data
- **How** the data was collected

This specification defines the evidence collection mechanisms that establish data provenance for clinical trial diary entries. The system combines blockchain-based timestamp attestation with device fingerprinting, patient authentication, and identity verification to create a complete chain of evidence.

**Business Value**:
- **Regulatory Defense**: Evidence records provide proof that cannot be forged or backdated, strengthening the defensibility of clinical trial data in FDA audits
- **Long-Term Archival**: Clinical trial data must be retained for 15-25 years; evidence must remain verifiable throughout this period
- **Trust Amplification**: Self-asserted claims can be questioned; independent attestation removes doubt about data authenticity

**Key Capabilities**:
- Independent proof of data existence at time of recording (WHEN)
- Device fingerprinting to establish collection method (HOW)
- Patient authentication and identity verification (WHO)
- Cryptographic verification that data has not been modified
- Long-term non-repudiation surviving cryptographic algorithm evolution

---

## Regulatory Context

FDA 21 CFR Part 11 requires audit trails that are:
- Secure and computer-generated
- Time-stamped in chronological order
- Available for agency review and copying

Third-party timestamps strengthen compliance by providing evidence that:
- Timestamps cannot be forged even by system administrators
- Data existence proofs are independently verifiable by regulators
- Historical records remain authentic throughout retention periods

---

## Blockchain-Based Timestamps

### Why Blockchain

| Property | Blockchain | Traditional TSA (RFC 3161) |
| -------- | ---------------------- | -------------------------- |
| Attack cost | $5-20 billion | ~$100,000 |
| Backdating possible? | Mathematically impossible | Yes, if TSA compromised |
| Historical breaches | Zero in 16+ years | Multiple (DigiNotar, Comodo) |
| Failure mode | Public (blockchain visible) | Silent (undetectable) |
| Single point of failure | None | TSA operator |
| Annual cost | $0 | $0.02-0.40 per timestamp |
| Longevity (2040+ availability) | Highest (nation-state adoption) | Depends on TSA business |

### How It Works

1. **Aggregate**: Daily diary entries are hashed together into a single digest
2. **Submit**: The digest is submitted to public OpenTimestamps calendar servers
3. **Anchor**: Calendar servers aggregate multiple submissions and commit to Bitcoin blockchain
4. **Confirm**: Bitcoin network confirms the transaction (~60 minutes)
5. **Store**: Proof file stored with diary data, enabling independent verification

### Key Benefits

**Zero Attack Surface**: Backdating requires $5-20 billion to execute a 51% attack on Bitcoin—far exceeding the value of any clinical trial data. In contrast, traditional timestamp authorities have been compromised for ~$100K.

**Mathematical Guarantee**: Unlike policy-based security, Bitcoin timestamps are mathematically impossible to forge. There is no "trusted party" that could be coerced or compromised.

**Public Failure Mode**: Any attack attempt on Bitcoin would be immediately visible to the entire network. Traditional TSA breaches can remain undetected for years.

**Zero Marginal Cost**: OpenTimestamps aggregation makes unlimited timestamps free. Calendar server operators cover Bitcoin transaction fees.

**Superior Longevity**: Bitcoin has the highest probability of existing in 2040 due to nation-state adoption (El Salvador, Central African Republic) and institutional investment (ETFs, corporate treasuries).

---

# Requirements

---

## REQ-p01025: Third-Party Timestamp Attestation Capability

**Level**: PRD | **Implements**: p00010, p00011 | **Status**: Draft

The system SHALL provide third-party timestamp attestation for clinical trial diary data, creating independently verifiable proof that data existed at the time of recording.

Third-party timestamp attestation SHALL ensure:
- Timestamps are issued by entities independent of the clinical trial system
- Proof of data existence is cryptographically verifiable
- Verification does not require trust in any single party
- Timestamps cannot be forged or backdated
- Proofs remain valid throughout the data retention period (15-25 years)

**Rationale**: Self-asserted timestamps can be questioned during regulatory audits. Independent third-party attestation provides incontrovertible evidence of when data was recorded, strengthening FDA 21 CFR Part 11 compliance and trial defensibility.

**Acceptance Criteria**:
- Any timestamp can be independently verified by third parties
- Verification produces cryptographic proof of minimum timestamp age
- Timestamps bound to specific data content (any modification invalidates proof)
- Proof files are self-contained and portable for regulatory review

*End* *Third-Party Timestamp Attestation Capability* | **Hash**: 5aef2ec0
---

---

## REQ-p01026: Bitcoin-Based Timestamp Implementation

**Level**: PRD | **Implements**: p01025 | **Status**: Draft

The system SHALL use Bitcoin blockchain via OpenTimestamps protocol as the primary third-party timestamp mechanism.

Bitcoin-based timestamps SHALL provide:
- Aggregation of daily diary entries into single timestamp proofs
- Submission to multiple independent calendar servers for redundancy
- Automatic proof completion after Bitcoin confirmation
- Local proof storage associated with timestamped data
- Offline verification capability without network access

**Rationale**: Bitcoin provides the highest security guarantees at zero marginal cost. The $5-20 billion attack cost and zero historical breaches make it the most defensible choice for regulated healthcare data.

**Acceptance Criteria**:
- Daily aggregated proofs created for all diary entries
- Proofs complete within 24 hours of submission
- Verification succeeds without external network access
- Proof files portable for independent regulatory verification

*End* *Bitcoin-Based Timestamp Implementation* | **Hash**: 634732d7
---

---

## REQ-p01027: Timestamp Verification Interface

**Level**: PRD | **Implements**: p01025 | **Status**: Draft

The system SHALL provide verification capability for all timestamp proofs, enabling users and regulators to confirm data integrity.

Verification interface SHALL support:
- On-demand verification of any timestamped data
- Clear indication of verification result (valid/invalid/pending)
- Display of attested timestamp (Bitcoin block time)
- Verification without specialized technical knowledge
- Export of verification evidence for regulatory submissions

**Rationale**: Timestamp proofs are only valuable if they can be verified. A user-friendly verification interface ensures that regulators and auditors can confirm data integrity without specialized blockchain knowledge.

**Acceptance Criteria**:
- Verification available for any diary entry with timestamp proof
- Results clearly communicated to non-technical users
- Verification report exportable for regulatory documentation
- Failed verification clearly indicates reason for failure

*End* *Timestamp Verification Interface* | **Hash**: 7582f435
---

---

## REQ-p01028: Timestamp Proof Archival

**Level**: PRD | **Implements**: p01025, p00012 | **Status**: Draft

The system SHALL archive all timestamp proofs alongside clinical trial data for the required retention period.

Proof archival SHALL ensure:
- Proofs stored durably with associated diary data
- Proofs included in data exports and backups
- Proofs remain valid independent of system availability
- Proofs retrievable for regulatory review at any time
- Proofs preserved through system migrations and upgrades

**Rationale**: Clinical trial data must be retained for 15-25 years. Timestamp proofs must be preserved alongside data to maintain verifiability throughout the retention period.

**Acceptance Criteria**:
- All timestamp proofs included in data backups
- Proofs survive database migrations without corruption
- Proofs retrievable independently of application availability
- Proof format documented for long-term interpretation

*End* *Timestamp Proof Archival* | **Hash**: 64a9c3ec
---

---

## REQ-p01029: Device Fingerprinting

**Level**: PRD | **Implements**: p01025 | **Status**: Draft

The system SHALL record a device fingerprint with each data submission to establish the collection method and enable traceability to the originating device.

Device fingerprinting SHALL:
- Capture a unique, non-reversible identifier derived from device hardware attributes
- Include the fingerprint in the timestamped evidence record
- Enable independent verification that data originated from a specific device
- Preserve privacy by using one-way hash functions

**Rationale**: Device fingerprinting establishes *how* data was collected by binding each submission to a specific device. Combined with timestamp attestation (*when*) and patient authentication (*who*), this completes the chain of evidence required for ALCOA+ compliance.

**Acceptance Criteria**:
- Each data submission includes a hashed device fingerprint
- Fingerprints are consistent across sessions on the same device
- No raw device identifiers are stored or transmitted
- Auditors can verify fingerprint consistency across a patient's submissions

*End* *Device Fingerprinting* | **Hash**: 57a2d038
---

---

## REQ-p01030: Patient Authentication for Data Attribution

**Level**: PRD | **Implements**: p01025 | **Status**: Draft

The system SHALL authenticate patients before data entry to establish that the person entering data had privileged access to the enrolled device.

Patient authentication SHALL:
- Rely on the device's native lock screen as the primary authentication mechanism
- Require an in-app PIN as a fallback when device lock screen is not enabled
- Detect whether the device has a lock screen enabled
- Allow Site Coordinators to send PIN reset notifications to patients
- Ensure Site Coordinators cannot view patient PINs

**Rationale**: The patient's personal device with an active lock screen represents the most secure authentication mechanism available in a clinical trial context. By verifying privileged device access, the system establishes reasonable assurance that the authenticated user is the enrolled patient.

**Acceptance Criteria**:
- App detects device lock screen status at enrollment and periodically thereafter
- Patients without device lock screen are prompted to set an in-app PIN
- PIN reset workflow available to Site Coordinators without PIN visibility
- Authentication status recorded with each data submission
- Failed authentication attempts logged for audit purposes

*End* *Patient Authentication for Data Attribution* | **Hash**: e5dd3d06
---

---

## REQ-p01031: Optional Geolocation Tagging

**Level**: PRD | **Implements**: p01025 | **Status**: Draft

The system SHALL support optional geolocation tagging of data submissions when enabled by the Sponsor and permitted by the device.

Geolocation tagging SHALL:
- Be disabled by default and require explicit Sponsor enablement per trial
- Depend on device location services being available and permitted by the patient
- Record location coordinates with each data submission when enabled
- Include geolocation data in the timestamped evidence record
- Clearly inform patients when geolocation is being collected

**Rationale**: Geolocation provides additional evidence of data collection context, strengthening provenance claims. However, location data is potential PII and must only be collected with Sponsor approval and patient awareness.

**Acceptance Criteria**:
- Geolocation collection configurable at the trial/Sponsor level
- App requests location permission with clear explanation when enabled
- Location data included in evidence record only when all conditions met
- Missing location (permission denied, services unavailable) does not block data entry
- Patient informed of geolocation collection status in app settings

*End* *Optional Geolocation Tagging* | **Hash**: 034c9479
---

---

## REQ-p01032: Hashed Email Identity Verification

**Level**: PRD | **Implements**: p01025 | **Status**: Draft

The system SHALL record a hashed patient email address as an identity fingerprint to enable upstream traceability without exposing PII.

Hashed email verification SHALL:
- Store a one-way hash of the patient's email address with enrollment data
- Include the hashed email in the evidence record for each data submission
- Enable Sponsors to provide the original email to auditors for verification
- Allow auditors to independently hash the email and confirm it matches the stored value
- Support auditor contact with the patient via the verified email address

**Rationale**: A hashed email provides a verifiable link between data and a contactable individual without storing PII in the evidence record. Auditors can trace data provenance upstream by contacting the patient directly to confirm their participation and data authenticity.

**Acceptance Criteria**:
- Patient email hashed using a standard, documented algorithm
- Hashed email recorded at enrollment and verifiable against submissions
- Sponsor can retrieve original email for auditor disclosure (separate from evidence record)
- Auditor can independently verify hash matches provided email
- Hash algorithm documented for long-term reproducibility

*End* *Hashed Email Identity Verification* | **Hash**: 769f35e0
---

---


## Operational Parameters

### Timestamp Frequency

| Parameter | Value | Rationale |
| --------- | ----- | --------- |
| Aggregation period | Daily | Balances proof efficiency with timestamp granularity |
| Target completion | < 24 hours | Ensures proofs complete before next aggregation cycle |
| Entries per proof | Unlimited | Aggregation makes volume irrelevant to cost |

### Time Precision

| Parameter | Bitcoin/OTS | Impact |
| --------- | ----------- | ------ |
| Precision | ±2 hours | Sufficient for day-level diary entries |
| Finality | ~60 minutes | Acceptable for diary use case |

**Note**: Internal timestamps (client + server) provide sub-second precision. Bitcoin timestamps provide independent third-party attestation, not high precision.

### Cost Structure

| Item | Bitcoin/OpenTimestamps | RFC 3161 TSA |
| ---- | ---------------------- | ------------ |
| Per-timestamp | $0 | $0.02-0.40 |
| Annual (1000 users × 365 days) | $0 | $7,300-146,000 |
| Proof storage | ~1KB/day | ~2KB/timestamp |

---

## Compliance Mapping

### FDA 21 CFR Part 11

| Requirement | Section | Evidence Records Contribution |
| ----------- | ------- | ----------------------------- |
| Audit Trail | §11.10(e) | Independent timestamp proof of record creation |
| Tamper Detection | §11.10(c) | Cryptographic binding—any modification invalidates proof |
| Record Integrity | §11.10(e) | Third-party attestation of data state at timestamp |

### ALCOA+ Principles

| Principle | Evidence Records Contribution |
| --- | --- |
| Attributable | Patient authentication + hashed email links data to individual |
| Legible | Evidence records exportable in standard, documented formats |
| Contemporaneous | Third-party blockchain timestamp proves data existed at claimed time |
| Original | Hash binding proves data unchanged since timestamp; device fingerprint proves collection method |
| Accurate | Cryptographic verification ensures accuracy |
| Complete | All evidence components (timestamp, device, auth, identity) recorded together |
| Consistent | Same evidence structure across all submissions |
| Enduring | Proofs valid for 15-25+ year retention periods |
| Available | Proofs retrievable for regulatory review at any time |

---

## Data Provenance Traceability

The following diagram illustrates the complete chain of evidence from data collection to audit verification, showing how each evidence component establishes the **when**, **how**, and **who** of data provenance.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        DATA PROVENANCE CHAIN                                │
│                                                                             │
│  ALCOA+ Principles:  Attributable (WHO) │ Contemporaneous (WHEN) │         │
│                      Original (HOW)                                         │
└─────────────────────────────────────────────────────────────────────────────┘

                              UPSTREAM TRACE
                          (Auditor → Data Source)
                                    │
┌───────────────────────────────────▼───────────────────────────────────────┐
│                            AUDITOR                                         │
│  Receives: Evidence Record + Sponsor-provided email                        │
│  Verifies: Hash(email) matches stored value                                │
│  Action:   Contacts patient directly to confirm participation              │
└───────────────────────────────────┬───────────────────────────────────────┘
                                    │
                                    ▼
┌───────────────────────────────────────────────────────────────────────────┐
│                     EVENT DATA STORE (EDS)                                 │
│                                                                            │
│  Evidence Record Contains:                                                 │
│  ┌─────────────────────────────────────────────────────────────────────┐  │
│  │  • Clinical data hash ─────────────────── ORIGINAL (data integrity) │  │
│  │  • Blockchain timestamp proof ─────────── CONTEMPORANEOUS (when)    │  │
│  │  • Device fingerprint (hashed) ────────── HOW (collection method)   │  │
│  │  • Hashed patient email ───────────────── ATTRIBUTABLE (who)        │  │
│  │  • Geolocation (if enabled) ───────────── Additional context        │  │
│  │  • Authentication status ──────────────── WHO (privileged access)   │  │
│  └─────────────────────────────────────────────────────────────────────┘  │
└───────────────────────────────────┬───────────────────────────────────────┘
                                    │
                                    ▼
┌───────────────────────────────────────────────────────────────────────────┐
│                         REVERSE PROXY                                      │
│  Records: Source IP, TLS session, request timestamp                        │
│  Evidence: Server-side receipt confirmation                                │
└───────────────────────────────────┬───────────────────────────────────────┘
                                    │
                                    ▼
┌───────────────────────────────────────────────────────────────────────────┐
│                          PATIENT DEVICE                                    │
│                                                                            │
│  Authentication Layer:                                                     │
│  ┌─────────────────────────────────────────────────────────────────────┐  │
│  │  Device Lock Screen ───────── Primary auth (OS-level security)      │  │
│  │         OR                                                          │  │
│  │  In-App PIN ───────────────── Fallback (when lock screen disabled)  │  │
│  └─────────────────────────────────────────────────────────────────────┘  │
│                                                                            │
│  Device Fingerprint Sources:                                               │
│  ┌─────────────────────────────────────────────────────────────────────┐  │
│  │  • Hardware identifiers (hashed) ──────── Unique device binding     │  │
│  │  • Platform/OS version ────────────────── Collection context        │  │
│  │  • App installation ID ────────────────── Session continuity        │  │
│  └─────────────────────────────────────────────────────────────────────┘  │
└───────────────────────────────────┬───────────────────────────────────────┘
                                    │
                                    ▼
┌───────────────────────────────────────────────────────────────────────────┐
│                            PATIENT                                         │
│                                                                            │
│  Identity Verification:                                                    │
│  • Enrolled with email address (hashed in system)                          │
│  • Possesses device with privileged access                                 │
│  • Can be contacted by auditor via Sponsor-provided email                  │
│  • Can confirm participation and data authenticity                         │
└───────────────────────────────────────────────────────────────────────────┘


┌─────────────────────────────────────────────────────────────────────────────┐
│                    VERIFICATION SUMMARY                                     │
├─────────────────┬───────────────────────────────────────────────────────────┤
│ WHEN            │ Blockchain timestamp (Bitcoin block time ±2 hours)        │
│ (Contemporaneous)│ + Server timestamp (sub-second precision)                │
│                 │ + Client timestamp (device clock at entry)                │
├─────────────────┼───────────────────────────────────────────────────────────┤
│ HOW             │ Device fingerprint proves specific device used            │
│ (Original)      │ + Data hash proves content unchanged                      │
│                 │ + Geolocation (optional) confirms physical context        │
├─────────────────┼───────────────────────────────────────────────────────────┤
│ WHO             │ Authentication proves privileged device access            │
│ (Attributable)  │ + Hashed email links to contactable individual            │
│                 │ + Auditor can verify identity via direct contact          │
└─────────────────┴───────────────────────────────────────────────────────────┘
```

---

## References

- **Architecture Decision**: docs/adr/ADR-008-timestamp-attestation.md
- **Implementation**: dev-evidence-records.md
- **Event Sourcing**: prd-event-sourcing-system.md
- **Database Audit Trail**: prd-database.md
- **Clinical Compliance**: prd-clinical-trials.md

---

## Glossary

| Term | Definition |
| --- | --- |
| **ALCOA+** | FDA data integrity principles: Attributable, Legible, Contemporaneous, Original, Accurate + Complete, Consistent, Enduring, Available |
| **Device Fingerprint** | Hashed identifier derived from device hardware attributes, used to establish collection method |
| **Evidence Record** | Cryptographic proof structure binding data to timestamps, device, and identity verification |
| **OpenTimestamps** | Open protocol for creating Bitcoin-anchored timestamps |
| **RFC 3161** | IETF standard for trusted timestamp protocol |
| **RFC 4998** | IETF standard for long-term evidence record syntax |
| **TSA** | Time-Stamp Authority—entity issuing RFC 3161 timestamps |

---
