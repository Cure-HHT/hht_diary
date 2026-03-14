# REQ-d80301: Domain Overlay — ePRO

**Level**: Dev | **Status**: Draft | **Refines**: REQ-p80004-AH, REQ-p80004-AX, REQ-p80004-AY, REQ-p80005-W

## Rationale

This overlay applies to action template instances involving ePRO data capture or correction. It adds ePRO-specific audit trail and data transmission requirements.

## Assertions

A. For ePRO systems that allow data correction, the system SHALL document data corrections and the audit trail SHALL record if data saved on the device are changed before the data are submitted.

B. The system SHALL NOT permit direct PRO data transmission from the collection device to the sponsor or third party without an electronic audit trail documenting all changes after the data leaves the collection device.

C. The system SHALL maintain an audit trail to capture any changes made to electronic PRO data at any point after it leaves the patient's device, enabling the clinical investigator to confirm data accuracy.

*End* *Domain Overlay — ePRO* | **Hash**: 3eb94b63

---

# REQ-d80302: Domain Overlay — eConsent

**Level**: Dev | **Status**: Draft | **Refines**: REQ-p80004-AI

## Rationale

This overlay applies to action template instances involving electronic informed consent workflows. It adds consent-specific timestamp and signature integrity requirements.

## Assertions

A. The system SHALL use timestamps for the audit trail for signing actions by trial participants and investigators, which cannot be manipulated by system settings.

B. Any alterations to the consent document SHALL invalidate the electronic signature, requiring re-signing.

*End* *Domain Overlay — eConsent* | **Hash**: d008df34

---

# REQ-d80303: Domain Overlay — CRF

**Level**: Dev | **Status**: Draft | **Refines**: REQ-p80004-N, REQ-p80004-P, REQ-p80004-AL, REQ-p80005-X

## Rationale

This overlay applies to action template instances involving CRF data entry or correction. It adds CRF-specific authorization and audit trail requirements.

## Assertions

A. The system SHALL maintain an audit trail for any change or correction to data reported on a CRF, which SHALL be dated, explained if necessary, and SHALL not obscure the original entry.

B. The system SHALL ensure that corrections, additions, or deletions to CRFs are made only by the principal investigator or authorized designee; monitors SHALL NOT make corrections to CRFs.

C. The system SHALL ensure that if changes are made to the eCRF after the clinical investigator has signed, the changes are reviewed and electronically signed by the clinical investigator.

D. The system SHALL limit the ability to change eCRF data to the investigator or delegated clinical study staff only.

*End* *Domain Overlay — CRF* | **Hash**: e4c3af30

---

# REQ-d80304: Domain Overlay — DHT (Digital Health Technology)

**Level**: Dev | **Status**: Draft | **Refines**: REQ-p80004-AW

## Rationale

This overlay applies to action template instances involving DHT data capture, transmission, or processing. This overlay absorbs content from REQ-d80063 (being retired).

## Assertions

A. The system SHALL capture data from digital health technologies with metadata including device identifier, subject identifier, timestamp, and data collection context.

B. The system SHALL maintain the audit trail for DHT-captured data from the point of capture through all transformations and transfers.

C. The system SHALL validate DHT data upon receipt to detect transmission errors or data corruption.

D. The system SHALL preserve the original DHT data in its native format or as a certified copy.

E. The system SHALL synchronize DHT timestamps with a reliable time source to ensure temporal accuracy.

F. The system SHALL include the date and time data are transferred from a DHT to the electronic data repository in the audit trail.

G. The system SHALL document the algorithm or method used to process or derive values from raw DHT data.

*End* *Domain Overlay — DHT (Digital Health Technology)* | **Hash**: 3d12a4b2

---

# REQ-d80305: Domain Overlay — Post-Unblinding

**Level**: Dev | **Status**: Draft | **Refines**: REQ-p80004-L

## Rationale

This overlay applies to action template instances where data modifications occur after the trial has been unblinded. It adds additional documentation and authorization requirements.

## Assertions

A. The system SHALL ensure that data changes made after trial unblinding are clearly documented in the audit trail.

B. The system SHALL ensure that post-unblinding data changes are justified and authorized by the investigator.

*End* *Domain Overlay — Post-Unblinding* | **Hash**: 99c7de55
