# Evidence Records

Data-provenance commitments establishing the **when**, **how**, and **who** of clinical trial diary entries through third-party timestamp attestation, device fingerprinting, patient authentication, and identity verification. These obligations are sponsor-visible (PRD-level audience) and provide the cryptographic basis for regulatory defensibility of long-retention clinical records.

## DIARY-PRD-evidence-timestamp-attestation: Third-Party Timestamp Attestation Capability

**Level**: prd | **Status**: Draft | **Implements**: -

> **TODO (URS-Phase-3 reconciliation):** Original Refines target REQ-p01085 (Compliance Systems) is in URS-replaced prd-clinical-trials.md. Re-parent to the URS-derived compliance REQ when that lands.

### Assertions

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

### Rationale

Self-asserted timestamps can be questioned during regulatory audits. Independent third-party attestation provides incontrovertible evidence of when data was recorded, strengthening FDA 21 CFR Part 11 compliance and trial defensibility. This requirement establishes the framework for creating tamper-evident temporal proofs that remain verifiable throughout the mandated 15-25 year data retention period for clinical trial records.

*End* *Third-Party Timestamp Attestation Capability* | **Hash**: f2ab1f17

## DIARY-PRD-evidence-bitcoin-timestamp: Bitcoin-Based Timestamp Implementation

**Level**: prd | **Status**: Draft | **Implements**: -
**Refines**: DIARY-PRD-evidence-timestamp-attestation-A+B+F

### Assertions

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

### Rationale

This requirement establishes Bitcoin blockchain as the cryptographic timestamp mechanism for clinical trial data integrity. The OpenTimestamps protocol leverages Bitcoin's immutability and security properties to create tamper-evident proof of data existence at specific points in time. Bitcoin's substantial attack cost ($5-20 billion) and absence of historical breaches provide the strongest available guarantee for regulatory compliance. The aggregation mechanism minimizes operational overhead while maintaining cryptographic proof of all diary entries. Offline verification ensures regulatory audits can proceed without dependency on external services, and proof portability supports long-term archival requirements under FDA 21 CFR Part 11.

*End* *Bitcoin-Based Timestamp Implementation* | **Hash**: 94499ad5

## DIARY-PRD-evidence-timestamp-verification: Timestamp Verification Interface

**Level**: prd | **Status**: Draft | **Implements**: -
**Refines**: DIARY-PRD-evidence-timestamp-attestation-H+K

### Assertions

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

### Rationale

Timestamp proofs provide cryptographic evidence of when data existed, but this evidence is only valuable if stakeholders can independently verify it. FDA 21 CFR Part 11 requires that electronic records be readily retrievable and verifiable by regulatory inspectors. This requirement ensures that users, auditors, and regulators can confirm the integrity and timing of timestamped data without requiring specialized blockchain expertise. The verification interface bridges the gap between complex cryptographic proofs and regulatory accessibility requirements.

*End* *Timestamp Verification Interface* | **Hash**: 9956bd94

## DIARY-PRD-evidence-timestamp-archival: Timestamp Proof Archival

**Level**: prd | **Status**: Draft | **Implements**: -
**Refines**: DIARY-PRD-evidence-timestamp-attestation-G

> **TODO (URS-Phase-3 reconciliation):** Additional Refines targets REQ-p00012-C, REQ-p00012-E, REQ-p00012-F (Clinical Data Retention Requirements) were in URS-replaced prd-clinical-trials.md. Re-parent to the URS-derived clinical-data-retention REQ when that lands.

### Assertions

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

### Rationale

Clinical trial data must be retained for 15-25 years per regulatory requirements. Timestamp proofs serve as cryptographic evidence of data integrity and must be preserved alongside the data they verify to maintain verifiability throughout the entire retention period. This requirement ensures that timestamp proofs remain accessible and valid for regulatory review, even as systems evolve through migrations and upgrades. The proofs must be self-contained and interpretable independent of the original system to support long-term audit and compliance verification.

*End* *Timestamp Proof Archival* | **Hash**: 69a49395

## DIARY-PRD-evidence-device-fingerprint: Device Fingerprinting

**Level**: prd | **Status**: Draft | **Implements**: -
**Refines**: DIARY-PRD-evidence-timestamp-attestation-B

### Assertions

A. The system SHALL record a device fingerprint with each data submission.

B. The system SHALL derive device fingerprints from device hardware attributes as unique, non-reversible identifiers.

C. The system SHALL use one-way hash functions to generate device fingerprints.

D. The system SHALL include the device fingerprint in the timestamped evidence record for each submission.

E. The system SHALL generate consistent fingerprints across multiple sessions on the same device.

F. The system SHALL enable independent verification that data originated from a specific device.

G. The system SHALL NOT store raw device identifiers.

H. The system SHALL NOT transmit raw device identifiers.

I. Auditors SHALL be able to verify fingerprint consistency across a patient's submissions.

### Rationale

Device fingerprinting establishes how data was collected by binding each submission to a specific device. Combined with timestamp attestation (when) and patient authentication (who), this completes the chain of evidence required for ALCOA+ compliance. This requirement supports FDA 21 CFR Part 11 by providing attributable evidence of the data collection method and enables verification that submissions originated from authenticated devices throughout the trial period.

*End* *Device Fingerprinting* | **Hash**: 8e10b85a

## DIARY-PRD-evidence-patient-authentication: Patient Authentication for Data Attribution

**Level**: prd | **Status**: Draft | **Implements**: -
**Refines**: DIARY-PRD-evidence-timestamp-attestation-B

### Assertions

A. The system SHALL authenticate patients before data entry to establish privileged access to the enrolled device.

B. The system SHALL use the device's native lock screen as the primary authentication mechanism.

C. When enabled by Sponsor configuration, the system SHALL require an in-app PIN as a fallback authentication mechanism when the device lock screen is not enabled.

D. The system SHALL detect whether the device has a lock screen enabled.

E. The system SHALL detect device lock screen status at patient enrollment.

F. The system SHALL periodically detect device lock screen status after enrollment.

G. When the in-app PIN fallback is enabled, the system SHALL prompt patients to set a PIN when the device lock screen is not enabled.

H. When the in-app PIN fallback is enabled, the system SHALL allow Site Coordinators to send PIN reset notifications to patients.

I. When the in-app PIN fallback is enabled, the system SHALL NOT allow Site Coordinators to view patient PINs.

J. The system SHALL record authentication status with each data submission.

K. The system SHALL log failed authentication attempts for audit purposes.

L. The system SHALL use device-specific UUID binding as an identity assurance control, establishing a controlled association between the enrolled patient and registered application instances.

M. The system SHALL treat the combination of mandatory device-level lock screen authentication and device UUID binding as equivalent to application-level login credentials for the purpose of patient identity assurance during data submission.

### Rationale

This requirement establishes the authentication framework for attributing clinical trial data to the correct enrolled patient. In a bring-your-own-device (BYOD) clinical trial context, the patient's personal device with an active lock screen provides the strongest available authentication mechanism. By verifying privileged access to the enrolled device, the system creates reasonable assurance that data entries originate from the enrolled patient rather than an unauthorized user. This approach balances FDA 21 CFR Part 11 identity verification requirements with the practical constraints of mobile clinical trials. The fallback PIN mechanism ensures authentication is possible even when patients choose not to enable device-level security, while the PIN reset workflow maintains security without creating support burden for site staff. For the full regulatory rationale supporting the risk-based authentication design, see [docs/position-app-auth.md](../docs/position-app-auth.md).

*End* *Patient Authentication for Data Attribution* | **Hash**: fc02cd59

## DIARY-PRD-evidence-geolocation: Optional Geolocation Tagging

**Level**: prd | **Status**: Draft | **Implements**: -
**Refines**: DIARY-PRD-evidence-timestamp-attestation-B

### Assertions

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

### Rationale

Geolocation provides additional evidence of data collection context, strengthening provenance claims and supporting data integrity verification. Location data is considered potential PII under privacy regulations, requiring explicit consent and transparency. This requirement balances the evidentiary value of geolocation with privacy protection and regulatory compliance by implementing a multi-layered consent model (Sponsor enablement, device permissions, patient awareness).

*End* *Optional Geolocation Tagging* | **Hash**: f9a69607

## DIARY-PRD-evidence-email-identity: Hashed Email Identity Verification

**Level**: prd | **Status**: Draft | **Implements**: -
**Refines**: DIARY-PRD-evidence-timestamp-attestation-B

### Assertions

A. The system SHALL record a hashed patient *Email Address* as an identity fingerprint with enrollment data.

B. The system SHALL include the hashed email in the evidence record for each data submission.

C. The system SHALL hash patient email using a standard, documented algorithm.

D. The hashed email SHALL be recorded at enrollment and verifiable against submissions.

E. The system SHALL enable Sponsors to retrieve the original email for auditor disclosure separate from the evidence record.

F. The system SHALL allow auditors to independently hash a provided email and confirm it matches the stored hash value.

G. The system SHALL support auditor contact with the patient via the verified *Email Address*.

H. The hash algorithm SHALL be documented for long-term reproducibility.

### Rationale

This requirement establishes a privacy-preserving identity verification mechanism for clinical trial data by using cryptographically hashed email addresses. The hash serves as a tamper-evident fingerprint that links data submissions to a specific patient without exposing personally identifiable information (PII) in the evidence record. This approach enables auditors to independently verify data provenance by contacting patients directly through their verified *Email Address*, supporting FDA 21 CFR Part 11 audit trail requirements while maintaining HIPAA compliance. The sponsor maintains the original email separately for auditor disclosure when needed, allowing independent hash verification while keeping PII out of the main evidence chain.

*End* *Hashed Email Identity Verification* | **Hash**: 92c5e2b7
