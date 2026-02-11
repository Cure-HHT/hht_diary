# Evidence Records and Data Provenance

**Version**: 1.1
**Audience**: Product Requirements
**Last Updated**: 2025-12-27
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

# REQ-p01025: Third-Party Timestamp Attestation Capability

**Level**: PRD | **Status**: Draft | **Implements**: p00011, p80030

## Rationale

Self-asserted timestamps can be questioned during regulatory audits. Independent third-party attestation provides incontrovertible evidence of when data was recorded, strengthening FDA 21 CFR Part 11 compliance and trial defensibility. This requirement establishes the framework for creating tamper-evident temporal proofs that remain verifiable throughout the mandated 15-25 year data retention period for clinical trial records.

## Assertions

A. The system SHALL provide third-party timestamp attestation for clinical trial diary data.
B. Timestamp attestation SHALL create independently verifiable proof that data existed at the time of recording.
C. Timestamps SHALL be issued by entities independent of the clinical trial system.
D. Timestamp proofs SHALL be cryptographically verifiable.
E. Timestamp verification SHALL NOT require trust in any single party.
F. Timestamps SHALL NOT be forgeable or backdatable.
G. Timestamp proofs SHALL remain valid throughout the data retention period of 15-25 years.
H. The system SHALL enable any timestamp to be independently verified by third parties.
I. Timestamp verification SHALL produce cryptographic proof of minimum timestamp age.
J. Timestamps SHALL be bound to specific data content such that any data modification invalidates the proof.
K. Timestamp proof files SHALL be self-contained for regulatory review.
L. Timestamp proof files SHALL be portable for regulatory review.

*End* *Third-Party Timestamp Attestation Capability* | **Hash**: f2ab1f17
---

---

# REQ-p01026: Bitcoin-Based Timestamp Implementation

**Level**: PRD | **Status**: Draft | **Implements**: p01025

## Rationale

This requirement establishes Bitcoin blockchain as the cryptographic timestamp mechanism for clinical trial data integrity. The OpenTimestamps protocol leverages Bitcoin's immutability and security properties to create tamper-evident proof of data existence at specific points in time. Bitcoin's substantial attack cost ($5-20 billion) and absence of historical breaches provide the strongest available guarantee for regulatory compliance. The aggregation mechanism minimizes operational overhead while maintaining cryptographic proof of all diary entries. Offline verification ensures regulatory audits can proceed without dependency on external services, and proof portability supports long-term archival requirements under FDA 21 CFR Part 11.

## Assertions

A. The system SHALL use Bitcoin blockchain via OpenTimestamps protocol as the primary third-party timestamp mechanism.
B. The system SHALL aggregate daily diary entries into single timestamp proofs.
C. The system SHALL submit timestamp proofs to multiple independent calendar servers for redundancy.
D. The system SHALL automatically complete timestamp proofs after Bitcoin confirmation.
E. The system SHALL store timestamp proof files locally associated with timestamped data.
F. The system SHALL support offline verification of timestamp proofs without network access.
G. The system SHALL create daily aggregated proofs for all diary entries.
H. Timestamp proofs SHALL complete within 24 hours of submission.
I. Timestamp proof verification SHALL succeed without external network access.
J. Timestamp proof files SHALL be portable for independent regulatory verification.

*End* *Bitcoin-Based Timestamp Implementation* | **Hash**: 94499ad5
---

---

# REQ-p01027: Timestamp Verification Interface

**Level**: PRD | **Status**: Draft | **Implements**: p01025

## Rationale

Timestamp proofs provide cryptographic evidence of when data existed, but this evidence is only valuable if stakeholders can independently verify it. FDA 21 CFR Part 11 requires that electronic records be readily retrievable and verifiable by regulatory inspectors. This requirement ensures that users, auditors, and regulators can confirm the integrity and timing of timestamped data without requiring specialized blockchain expertise. The verification interface bridges the gap between complex cryptographic proofs and regulatory accessibility requirements.

## Assertions

A. The system SHALL provide verification capability for all timestamp proofs.
B. The system SHALL enable users to verify timestamp proofs on-demand for any timestamped data.
C. The system SHALL enable regulators to verify timestamp proofs on-demand for any timestamped data.
D. The verification interface SHALL clearly indicate verification results as valid, invalid, or pending.
E. The verification interface SHALL display the attested timestamp using Bitcoin block time.
F. The verification interface SHALL enable verification without requiring specialized technical knowledge.
G. The system SHALL provide export capability for verification evidence suitable for regulatory submissions.
H. The system SHALL make verification available for any diary entry with timestamp proof.
I. The verification interface SHALL communicate results clearly to non-technical users.
J. The system SHALL generate verification reports that are exportable for regulatory documentation.
K. The system SHALL clearly indicate the reason for failure when verification fails.

*End* *Timestamp Verification Interface* | **Hash**: 9956bd94
---

---

# REQ-p01028: Timestamp Proof Archival

**Level**: PRD | **Status**: Draft | **Implements**: p01025, p00012

## Rationale

Clinical trial data must be retained for 15-25 years per regulatory requirements. Timestamp proofs serve as cryptographic evidence of data integrity and must be preserved alongside the data they verify to maintain verifiability throughout the entire retention period. This requirement ensures that timestamp proofs remain accessible and valid for regulatory review, even as systems evolve through migrations and upgrades. The proofs must be self-contained and interpretable independent of the original system to support long-term audit and compliance verification.

## Assertions

A. The system SHALL archive all timestamp proofs alongside clinical trial data for the required retention period.
B. The system SHALL store timestamp proofs durably with their associated diary data.
C. The system SHALL include all timestamp proofs in data exports.
D. The system SHALL include all timestamp proofs in data backups.
E. Timestamp proofs SHALL remain valid independent of system availability.
F. The system SHALL ensure timestamp proofs are retrievable for regulatory review at any time.
G. The system SHALL preserve timestamp proofs through system migrations without corruption.
H. The system SHALL preserve timestamp proofs through system upgrades without corruption.
I. The system SHALL support retrieval of timestamp proofs independently of application availability.
J. The system SHALL document the timestamp proof format to enable long-term interpretation.

*End* *Timestamp Proof Archival* | **Hash**: 69a49395
---

---

# REQ-p01029: Device Fingerprinting

**Level**: PRD | **Status**: Draft | **Implements**: p01025

## Rationale

Device fingerprinting establishes how data was collected by binding each submission to a specific device. Combined with timestamp attestation (when) and patient authentication (who), this completes the chain of evidence required for ALCOA+ compliance. This requirement supports FDA 21 CFR Part 11 by providing attributable evidence of the data collection method and enables verification that submissions originated from authenticated devices throughout the trial period.

## Assertions

A. The system SHALL record a device fingerprint with each data submission.
B. The system SHALL derive device fingerprints from device hardware attributes as unique, non-reversible identifiers.
C. The system SHALL use one-way hash functions to generate device fingerprints.
D. The system SHALL include the device fingerprint in the timestamped evidence record for each submission.
E. The system SHALL generate consistent fingerprints across multiple sessions on the same device.
F. The system SHALL enable independent verification that data originated from a specific device.
G. The system SHALL NOT store raw device identifiers.
H. The system SHALL NOT transmit raw device identifiers.
I. Auditors SHALL be able to verify fingerprint consistency across a patient's submissions.

*End* *Device Fingerprinting* | **Hash**: 8e10b85a
---

---

# REQ-p01030: Patient Authentication for Data Attribution

**Level**: PRD | **Status**: Draft | **Implements**: p01025

## Rationale

This requirement establishes the authentication framework for attributing clinical trial data to the correct enrolled patient. In a bring-your-own-device (BYOD) clinical trial context, the patient's personal device with an active lock screen provides the strongest available authentication mechanism. By verifying privileged access to the enrolled device, the system creates reasonable assurance that data entries originate from the enrolled patient rather than an unauthorized user. This approach balances FDA 21 CFR Part 11 identity verification requirements with the practical constraints of mobile clinical trials. The fallback PIN mechanism ensures authentication is possible even when patients choose not to enable device-level security, while the PIN reset workflow maintains security without creating support burden for site staff.

## Assertions

A. The system SHALL authenticate patients before data entry to establish privileged access to the enrolled device.
B. The system SHALL use the device's native lock screen as the primary authentication mechanism.
C. The system SHALL require an in-app PIN as a fallback authentication mechanism when the device lock screen is not enabled.
D. The system SHALL detect whether the device has a lock screen enabled.
E. The system SHALL detect device lock screen status at patient enrollment.
F. The system SHALL periodically detect device lock screen status after enrollment.
G. The system SHALL prompt patients to set an in-app PIN when the device lock screen is not enabled.
H. The system SHALL allow Site Coordinators to send PIN reset notifications to patients.
I. The system SHALL NOT allow Site Coordinators to view patient PINs.
J. The system SHALL record authentication status with each data submission.
K. The system SHALL log failed authentication attempts for audit purposes.

*End* *Patient Authentication for Data Attribution* | **Hash**: da907239
---

---

# REQ-p01031: Optional Geolocation Tagging

**Level**: PRD | **Status**: Draft | **Implements**: p01025

## Rationale

Geolocation provides additional evidence of data collection context, strengthening provenance claims and supporting data integrity verification. Location data is considered potential PII under privacy regulations, requiring explicit consent and transparency. This requirement balances the evidentiary value of geolocation with privacy protection and regulatory compliance by implementing a multi-layered consent model (Sponsor enablement, device permissions, patient awareness).

## Assertions

A. The system SHALL support optional geolocation tagging of data submissions.
B. Geolocation tagging SHALL be disabled by default for all trials.
C. Geolocation tagging SHALL require explicit Sponsor enablement on a per-trial basis.
D. The system SHALL only collect geolocation data when device location services are available.
E. The system SHALL only collect geolocation data when the patient has granted location permissions to the app.
F. The system SHALL record location coordinates with each data submission when geolocation is enabled and permitted.
G. Geolocation data SHALL be included in the timestamped evidence record when collected.
H. The app SHALL request location permission from the patient with a clear explanation when geolocation is enabled for a trial.
I. The system SHALL clearly inform patients when geolocation is being collected.
J. The app SHALL display the geolocation collection status in the settings interface.
K. The system SHALL allow data entry to proceed successfully when location data is unavailable due to denied permissions.
L. The system SHALL allow data entry to proceed successfully when location data is unavailable due to disabled location services.
M. Geolocation collection settings SHALL be configurable at the trial level.
N. Geolocation collection settings SHALL be configurable at the Sponsor level.

*End* *Optional Geolocation Tagging* | **Hash**: f9a69607
---

---

# REQ-p01032: Hashed Email Identity Verification

**Level**: PRD | **Status**: Draft | **Implements**: p01025

## Rationale

This requirement establishes a privacy-preserving identity verification mechanism for clinical trial data by using cryptographically hashed email addresses. The hash serves as a tamper-evident fingerprint that links data submissions to a specific patient without exposing personally identifiable information (PII) in the evidence record. This approach enables auditors to independently verify data provenance by contacting patients directly through their verified email address, supporting FDA 21 CFR Part 11 audit trail requirements while maintaining HIPAA compliance. The sponsor maintains the original email separately for auditor disclosure when needed, allowing independent hash verification while keeping PII out of the main evidence chain.

## Assertions

A. The system SHALL record a hashed patient email address as an identity fingerprint with enrollment data.
B. The system SHALL include the hashed email in the evidence record for each data submission.
C. The system SHALL hash patient email using a standard, documented algorithm.
D. The hashed email SHALL be recorded at enrollment and verifiable against submissions.
E. The system SHALL enable Sponsors to retrieve the original email for auditor disclosure separate from the evidence record.
F. The system SHALL allow auditors to independently hash a provided email and confirm it matches the stored hash value.
G. The system SHALL support auditor contact with the patient via the verified email address.
H. The hash algorithm SHALL be documented for long-term reproducibility.

*End* *Hashed Email Identity Verification* | **Hash**: 0ba2d208
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
