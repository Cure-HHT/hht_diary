# Third-Party Timestamp Attestation

**Version**: 1.0
**Audience**: Product Requirements
**Last Updated**: 2025-12-02
**Status**: Active

---

## Executive Summary

Third-party timestamp attestation provides **independent, cryptographic proof** that clinical trial diary data existed at a specific point in time. This capability is essential for FDA 21 CFR Part 11 compliance, where audit trails must be tamper-evident and independently verifiable.

**Business Value**:
- **Regulatory Defense**: Third-party timestamps provide evidence that cannot be forged or backdated, strengthening the defensibility of clinical trial data in FDA audits
- **Long-Term Archival**: Clinical trial data must be retained for 15-25 years; timestamps must remain verifiable throughout this period
- **Trust Amplification**: Self-asserted timestamps can be questioned; third-party attestation removes doubt about when data was recorded

**Key Capabilities**:
- Independent proof of data existence at time of recording
- Cryptographic verification that data has not been modified since timestamping
- Long-term non-repudiation surviving cryptographic algorithm evolution
- Data can be traced to its origin

Third-party timestamp attestation is an essential component in providing evidence 
that data was collected in the manner and time which is claimed. However, TPTA alone 
cannot prove that data was created by a specific individual. That can only be 
done by the individual in question. To achieve the highest level of confidence 
in the authenticity of the data, that individual must provide proof of their 
identity as well as proof of having the key necessary to generate the data 
referenced in the timestamp. 

---

### Regulatory Context

FDA 21 CFR Part 11 requires audit trails that are:
- Secure and computer-generated
- Time-stamped in chronological order
- Available for agency review and copying

Third-party timestamps strengthen compliance by providing evidence that:
- Timestamps cannot be forged even by system administrators
- Data existence proofs are independently verifiable by regulators
- Historical records remain authentic throughout retention periods

---

## Blockchain locked timestamps

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

**Level**: PRD | **Implements**: REQ-p00010, REQ-p00011 | **Status**: Active

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

# REQ-p01026: Bitcoin-Based Timestamp Implementation

**Level**: PRD | **Implements**: REQ-p01025 | **Status**: Active

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

# REQ-p01027: Timestamp Verification Interface

**Level**: PRD | **Implements**: REQ-p01025 | **Status**: Active

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

# REQ-p01028: Timestamp Proof Archival

**Level**: PRD | **Implements**: REQ-p01025, REQ-p00012 | **Status**: Active

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

# REQ-p01029: Timestamped Record Contents

**Level**: PRD | **Implements**: REQ-p01025, REQ-p00012 | **Status**: Active

The system SHALL record information in the timestamp attestation sufficient to verify that the following data was recorded before the date of the block to which it is tied:
- The clinical trial data
- The source of the data

The system SHALL use a de-identified unique identifier that can be independently verified. This identifier MAY be based on a device ID or patient ID.

De-identification SHALL use a non-reversible algorithm to transform the identifier into a new unique value.

**Rationale**: Timestamps prove data existence at a point in time, but do not inherently prove data origin. Including a verifiable source identifier in the timestamped record enables attribution while preserving privacy through de-identification.

**Acceptance Criteria**:
- Timestamped records include both clinical data hash and source identifier
- Source identifiers are de-identified using a one-way hash function
- De-identified identifiers can be independently verified by the data source
- No personally identifiable information is exposed in the timestamp proof

*End* *Timestamped Record Contents* | **Hash**: 2589e604
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
| --------- | ----------------------------- |
| Attributable | Timestamp includes attestation source identity |
| Contemporaneous | Third-party proof that data existed at claimed time |
| Original | Hash binding proves data unchanged since timestamp |
| Accurate | Cryptographic verification ensures accuracy |
| Enduring | Proofs valid for 15-25+ year retention periods |

---

## References

- **Architecture Decision**: docs/adr/ADR-008-timestamp-attestation.md
- **Implementation**: dev-evidence-records.md
- **Event Sourcing**: prd-event-sourcing-system.md
- **Database Audit Trail**: prd-database.md
- **Clinical Compliance**: prd-clinical-trials.md

---

## Glossary

**Evidence Record**: Cryptographic proof structure binding data to a timestamp
**OpenTimestamps**: Open protocol for creating Bitcoin-anchored timestamps
**RFC 3161**: IETF standard for trusted timestamp protocol
**RFC 4998**: IETF standard for long-term evidence record syntax
**TSA**: Time-Stamp Authority—entity issuing RFC 3161 timestamps
**ALCOA+**: FDA data integrity principles (Attributable, Legible, Contemporaneous, Original, Accurate + Complete, Consistent, Enduring, Available)

---
