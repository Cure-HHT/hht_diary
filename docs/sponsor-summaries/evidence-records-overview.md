# Evidence Records: Ensuring Regulatory-Ready Clinical Trial Data

## Introduction

Regulatory review of clinical trial data goes beyond the data itself—it examines whether the data can be proven trustworthy. This requires demonstrating *when* data was collected, *who* collected it, and *how* it was captured.

The Evidence Records system addresses these requirements through independent, cryptographically-verified proof rather than relying solely on internal system timestamps. Each patient diary entry is anchored to a tamper-proof record that can be independently verified during regulatory audits.

---

## Key Features

### Independent Timestamp Verification

Every diary entry receives a timestamp that is mathematically impossible to forge or backdate. This timestamp is anchored to a public, independently verifiable source—the same technology trusted by nation-states and major financial institutions. No system administrator, no database access, no insider threat can alter these timestamps after the fact.

**What this means for your trial**: When an auditor asks "How do you know this entry wasn't created after the fact?", you can provide cryptographic proof, not just policy documentation.

### Complete Chain of Evidence

Each data submission automatically captures:

- **When**: Independent third-party timestamp proving data existed at the claimed time
- **Who**: Patient identity verification linking data to a specific enrolled participant
- **How**: Device identification establishing the collection method and context

These elements are cryptographically bound together, meaning any modification to any component would be immediately detectable.

### Patient-Friendly Authentication

The system leverages the security patients already use daily—their device's built-in authentication (fingerprint, face recognition, or PIN). This approach:

- Minimizes patient burden
- Maximizes compliance with authentication requirements
- Provides strong assurance that the person entering data has privileged access to the enrolled device

### Privacy-Preserving Design

Patient identity verification uses one-way cryptographic hashing. The system stores proof of identity without storing actual personal information. During an audit, the Sponsor provides the original email to the auditor, who can independently verify it matches the stored hash and contact the patient directly if needed.

---

## Regulatory Assurance

### FDA 21 CFR Part 11 Alignment

The Evidence Records system directly supports key Part 11 requirements:

| Requirement | How Evidence Records Supports Compliance |
| ----------- | ---------------------------------------- |
| **Audit Trail** (§11.10(e)) | Every entry has an independent, unforgeable timestamp |
| **Tamper Detection** (§11.10(c)) | Any data modification invalidates the cryptographic proof |
| **Record Integrity** (§11.10(e)) | Third-party attestation confirms data state at time of capture |

### ALCOA+ Principles

Our evidence records are designed around the FDA's ALCOA+ data integrity framework:

- **Attributable**: Each entry is linked to a verified patient identity
- **Contemporaneous**: Third-party timestamps prove data was recorded when claimed
- **Original**: Cryptographic hashes prove data hasn't changed since capture
- **Complete**: All evidence components are recorded together
- **Enduring**: Proofs remain valid throughout the 15-25 year retention period

---

## Traceability: From Entry to Audit

Our system provides complete bidirectional traceability:

**Forward Traceability** (Data Entry → Audit)
- Patient enters diary data on their device
- System captures authentication status, device fingerprint, and timestamps
- Data receives independent third-party timestamp attestation
- All evidence components stored together in the audit trail
- Proof files available for export and regulatory review

**Backward Traceability** (Audit → Patient)
- Auditor receives evidence record with cryptographic proofs
- Timestamps verified against independent public records
- Device consistency verified across patient's submissions
- If needed, auditor can contact patient directly via Sponsor-provided email
- Patient can confirm their participation and data authenticity

This complete chain means that every piece of clinical trial data can be traced from the moment of collection through to regulatory submission, with mathematical proof at every step.

---

## Long-Term Reliability

Clinical trial data must often be retained for 15-25 years. Our evidence system is designed for this reality:

- **Technology Independence**: Proofs can be verified without our platform
- **Documented Formats**: All proof structures use open, documented standards
- **Portable Evidence**: Proof files are self-contained and exportable
- **Algorithm Evolution**: System designed to remain verifiable as cryptographic standards evolve

---

## Summary

The Evidence Records system transforms your audit trail from a defensive liability into a regulatory asset. Instead of explaining why your internal timestamps should be trusted, you present independently verifiable proof that cannot be disputed.

When the FDA asks how you know your data is trustworthy, the answer is straightforward: independently verifiable proof.

---

## Frequently Asked Questions

**What if a patient doesn't have a password set on their device?**

The system detects whether the device has a lock screen enabled. If not, the patient is prompted to set an in-app PIN before entering data. This ensures authentication is always in place, regardless of the patient's device settings.

**What happens if a patient loses their device or gets a new one?**

Device fingerprints are recorded with each submission, so auditors can see when a device change occurred. The patient re-enrolls on the new device, and the audit trail clearly shows the transition. Historical data remains linked to the original device fingerprint, maintaining the integrity of the evidence chain.

**Can site coordinators access patient PINs?**

No. Site coordinators can send PIN reset notifications to patients, but they cannot view or retrieve patient PINs. This separation ensures that authentication credentials remain under patient control.

**How long are evidence records retained?**

Evidence records are preserved alongside clinical trial data for the full retention period (typically 15-25 years). The proof formats are designed to remain verifiable throughout this period, independent of the platform itself.

**What if a patient denies entering data during an audit?**

The evidence record provides multiple layers of verification: the device fingerprint confirms which device was used, the authentication status confirms privileged access was verified, and the hashed email links to the enrolled patient. The auditor can contact the patient directly using the Sponsor-provided email to resolve any discrepancies.

**Is patient location always tracked?**

No. Geolocation is disabled by default and only collected when explicitly enabled by the Sponsor for a specific trial. When enabled, patients are clearly informed that location data is being collected, and they can deny location permissions without affecting their ability to enter diary data.

**What technologies are used for timestamp verification?**

Timestamps are anchored using the Bitcoin blockchain via the OpenTimestamps protocol. Bitcoin was selected because it provides the highest security guarantees available: in over 16 years of operation, there have been zero successful attacks on its timestamp integrity. Backdating a timestamp would require controlling more than half of the global Bitcoin network—an attack estimated to cost $5-20 billion, far exceeding any conceivable benefit from falsifying clinical trial data.

**How do I know these technologies are sufficient for FDA requirements?**

The system is designed around FDA 21 CFR Part 11 requirements and ALCOA+ data integrity principles. Traditional timestamp authorities (RFC 3161) have historically been compromised for relatively modest costs (~$100,000), and such breaches can go undetected for years. Bitcoin-based timestamps eliminate this risk: any attack attempt would be publicly visible to the entire network immediately. The mathematical guarantees provided by cryptographic hashing and blockchain anchoring exceed the security properties of traditional approaches that regulators have accepted for decades.
