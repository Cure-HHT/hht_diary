# CDISC Implementation Guide

**Version**: 1.0
**Audience**: Software Developers
**Last Updated**: 2025-11-28
**Status**: Draft

> **Scope**: CDISC standards implementation, data mapping, EDC synchronization
>
> **See**: prd-standards.md for high-level CDISC requirements (REQ-p00041)
> **See**: dev-data-models-jsonb.md for internal data schemas
> **See**: dev-architecture-multi-sponsor.md for EDC proxy mode architecture
> **See**: dev-database.md for database implementation

---

## Executive Summary

This guide covers **how to implement CDISC standards** for the Clinical Diary Platform. CDISC compliance enables regulatory submission, EDC integration, and data interoperability.

**Implementation Areas**:
- Field-level mapping to CDASH standards
- Data transformation to SDTM domains
- ODM-XML export for data interchange
- Define-XML metadata generation
- EDC synchronization data transformation

---

## CDISC Standards Overview

| Standard               | Purpose                        | Implementation Priority          |
| ---------------------- | ------------------------------ | -------------------------------- |
| CDASH                  | Data collection field naming   | HIGH - Affects data capture      |
| SDTM                   | Data tabulation for submission | HIGH - Required for FDA          |
| ODM                    | XML interchange format         | HIGH - Required for EDC sync     |
| Define-XML             | Metadata definitions           | MEDIUM - Required for submission |
| Controlled Terminology | Standardized code lists        | HIGH - Ensures consistency       |

---

## Requirements Status Summary

### Satisfied by Existing Requirements

The following CDISC-related needs are **already satisfied** by existing platform requirements:

| CDISC Need               | Satisfied By             | Notes                                                     |
| ------------------------ | ------------------------ | --------------------------------------------------------- |
| Audit Trail              | REQ-p00004, REQ-p01003   | Immutable event sourcing provides complete audit trail    |
| Data Integrity (ALCOA+)  | REQ-p00011               | ALCOA+ principles embedded in data model                  |
| Schema Versioning        | REQ-p01004               | Versioned event types support schema evolution            |
| Data Retention           | REQ-p00012               | 7+ year retention meets regulatory requirements           |
| Access Control           | REQ-p00005, REQ-p00015   | RBAC and RLS enforce proper data access                   |
| Data Export Architecture | REQ-p00029               | Portal export capability (requires format implementation) |

### Gap Requirements

The following requirements address CDISC gaps identified in the platform:

---

## Data Collection Requirements

# REQ-d00070: CDASH Field Mapping Implementation

**Level**: Dev | **Implements**: p00041 | **Status**: Draft

Internal diary data fields SHALL be mapped to CDASH (Clinical Data Acquisition Standards Harmonization) variable names and definitions to ensure data collection aligns with industry standards.

Implementation SHALL include:
- Mapping document linking internal field names to CDASH variable names
- CDASH-compliant variable naming in export transformations
- Controlled terminology codes for categorical fields (intensity, response types)
- Sponsor-configurable mapping overrides for study-specific requirements
- Validation rules based on CDASH implementation guides

**Field Mapping Examples**:

| Internal Field | CDASH Variable | CDASH Domain | Description                        |
| -------------- | -------------- | ------------ | ---------------------------------- |
| `startTime`    | `CESTDTC`      | CE           | Clinical Event Start Date/Time     |
| `endTime`      | `CEENDTC`      | CE           | Clinical Event End Date/Time       |
| `intensity`    | `CESEV`        | CE           | Clinical Event Severity/Intensity  |
| `user_notes`   | `CETERM`       | CE           | Reported Term for Clinical Event   |
| `completedAt`  | `QSDTC`        | QS           | Date/Time of Survey                |
| `response`     | `QSORRES`      | QS           | Original Survey Response           |
| `score.total`  | `QSSTRESN`     | QS           | Numeric Survey Result              |

**Note**: Epistaxis events use CE (Clinical Events) domain, NOT AE (Adverse Events), because nosebleeds are the disease manifestation being tracked as study endpoints in HHT trials, not unintended adverse reactions to treatment.

**Rationale**: CDASH provides standardized variable names and definitions for clinical data collection. Mapping internal fields to CDASH ensures data is captured in a form that can be easily transformed to SDTM for regulatory submission.

**Acceptance Criteria**:
- All diary event fields mapped to appropriate CDASH variables
- Mapping document maintained in `spec/` or `docs/`
- Export functions use CDASH variable names
- Controlled terminology codes applied to categorical fields
- Validation warns when data values don't match controlled terminology

*End* *CDASH Field Mapping Implementation* | **Hash**: 7ff9716c

---

# REQ-d00074: CDISC Controlled Terminology Implementation

**Level**: Dev | **Implements**: p00041 | **Status**: Draft

The system SHALL implement CDISC Controlled Terminology for categorical data fields to ensure standardized vocabulary across the platform.

Implementation SHALL include:
- Terminology mapping from internal values to CDISC code list values
- Intensity mapping to CDISC Severity/Intensity Scale (C66769) - applicable to CE domain
- Response type mapping to applicable CDISC code lists
- Version tracking for controlled terminology (CDISC publishes quarterly updates)
- Extensible code list support for sponsor-specific terminology

**Intensity Mapping Example** (for CE domain epistaxis events):

**Note**: The actual mapping is provided in the Sponsor-specific requirements.

| Internal Value     | CDISC Code | CDISC Preferred Term | Code List | HHT Description             |
| ------------------ | ---------- | -------------------- | --------- | --------------------------- |
| `spotting`         | C41338     | MILD                 | C66769    | Minimal blood, occasional   |
| `dripping_slowly`  | C41338     | MILD                 | C66769    | Slow, intermittent drips    |
| `dripping_quickly` | C41339     | MODERATE             | C66769    | Frequent, rapid drips       |
| `steady_stream`    | C41339     | MODERATE             | C66769    | Continuous flow             |
| `pouring`          | C41340     | SEVERE               | C66769    | Heavy continuous flow       |
| `gushing`          | C41340     | SEVERE               | C66769    | Severe, uncontrolled flow   |

**Note**: The Severity/Intensity Scale (C66769) is used for both AE and CE domains. The HHT-specific 6-level intensity scale (see prd-epistaxis-terminology.md, REQ-p00042) maps to CDISC's 3-level scale (MILD, MODERATE, SEVERE).

**Rationale**: CDISC Controlled Terminology ensures consistent vocabulary across studies and sponsors. Regulators expect standardized terms in submissions. Mapping internal values to CDISC codes enables automated validation and comparison.

**Acceptance Criteria**:
- All categorical fields mapped to CDISC controlled terminology
- Terminology version tracked in system metadata
- Export includes both internal and CDISC-coded values
- Sponsor can extend code lists for study-specific terms
- Validation identifies non-standard values

*End* *CDISC Controlled Terminology Implementation* | **Hash**: 772bf977

---

## Data Transformation Requirements

# REQ-d00071: SDTM Domain Transformation Implementation

**Level**: Dev | **Implements**: p00041 | **Status**: Draft

The system SHALL implement transformation logic to convert internal diary data to SDTM (Study Data Tabulation Model) domain format for regulatory submission.

Implementation SHALL include:
- Domain identification for each diary event type
- SDTM variable derivation rules
- Record-level and dataset-level metadata generation
- Subject identifier (USUBJID) construction per sponsor conventions
- Domain-specific validation against SDTM Implementation Guides

**Domain Mapping**:

| Event Type      | Primary SDTM Domain   | Secondary Domains     | Rationale                                                                                   |
| --------------- | --------------------- | --------------------- | ------------------------------------------------------------------------------------------- |
| epistaxis-v1.0  | CE (Clinical Events)  | CM (Concomitant Meds) | Nosebleeds are disease manifestations/efficacy endpoints in HHT studies, NOT adverse events |
| survey-v1.0     | QS (Questionnaires)   | -                     | Surveys map to QS domain per SDTM-IG                                                        |
| medication-v1.0 | CM (Concomitant Meds) | -                     | Medication tracking                                                                         |
| symptom-v1.0    | FA (Findings About)   | -                     | General symptom observations                                                                |

**Important**: The CE (Clinical Events) domain is specifically designed for "clinical events of interest other than adverse events." In HHT trials, epistaxis is the primary disease symptom being measured as an efficacy endpoint, not an unintended adverse reaction. Only treatment-related worsening of epistaxis would be classified as AE.

**SDTM CE Domain Example** (for epistaxis):

```
STUDYID  DOMAIN  USUBJID         CESEQ  CETERM     CESTDTC              CEENDTC              CESEV
HHT001   CE      HHT001-001-101  1      Epistaxis  2025-10-15T14:30:00  2025-10-15T14:45:00  MODERATE
```

**Rationale**: SDTM is the FDA-required format for clinical data submissions. Transformation logic must accurately convert diary events to appropriate SDTM domains while preserving data integrity and audit trail linkage.

**Acceptance Criteria**:
- All diary event types mapped to SDTM domains
- Transformation produces valid SDTM datasets
- USUBJID generated per sponsor conventions
- Transformation is reversible (audit trail linkage preserved)
- Output validated against SDTM Implementation Guide rules

*End* *SDTM Domain Transformation Implementation* | **Hash**: 1286bfd8

---

## Data Export Requirements

# REQ-d00072: ODM-XML Export Implementation

**Level**: Dev | **Implements**: p00041 | **Status**: Draft

The system SHALL implement ODM (Operational Data Model) XML export capability for data interchange with EDC systems and regulatory authorities.

Implementation SHALL include:
- ODM-XML 1.3.2 compliant document generation
- ClinicalData element with ItemGroupData for diary records
- AuditRecord elements preserving audit trail
- MetaDataVersion reference for schema definitions
- Incremental export capability (events since last sync)
- Full study export capability

**ODM Structure**:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<ODM xmlns="http://www.cdisc.org/ns/odm/v1.3"
     ODMVersion="1.3.2"
     FileType="Transactional"
     CreationDateTime="2025-10-15T15:00:00"
     FileOID="HHT001.Export.20251015">

  <Study OID="HHT001">
    <MetaDataVersion OID="HHT001.v1.0">
      <!-- Define-XML reference -->
    </MetaDataVersion>
  </Study>

  <ClinicalData StudyOID="HHT001" MetaDataVersionOID="HHT001.v1.0">
    <SubjectData SubjectKey="HHT001-001-101">
      <StudyEventData StudyEventOID="SE.DIARY">
        <FormData FormOID="EPISTAXIS">
          <ItemGroupData ItemGroupOID="IG.EPISTAXIS">
            <ItemData ItemOID="IT.AESTDTC" Value="2025-10-15T14:30:00"/>
            <ItemData ItemOID="IT.AEENDTC" Value="2025-10-15T14:45:00"/>
            <ItemData ItemOID="IT.AESEV" Value="MODERATE"/>
            <AuditRecord>
              <UserRef UserOID="U.patient101"/>
              <DateTimeStamp>2025-10-15T14:50:00</DateTimeStamp>
              <ReasonForChange>Initial entry</ReasonForChange>
            </AuditRecord>
          </ItemGroupData>
        </FormData>
      </StudyEventData>
    </SubjectData>
  </ClinicalData>
</ODM>
```

**Rationale**: ODM-XML is the CDISC standard for clinical data interchange. EDC systems accept ODM format for data import. Regulatory authorities may request data in ODM format for inspection.

**Acceptance Criteria**:
- Export produces valid ODM-XML 1.3.2 documents
- All diary events included with appropriate metadata
- Audit trail preserved in AuditRecord elements
- Export can be filtered by date range, patient, event type
- Incremental export tracks last sync position
- Large exports handled efficiently (streaming/chunking)

*End* *ODM-XML Export Implementation* | **Hash**: f1b48f69

---

# REQ-d00073: Define-XML Metadata Generation

**Level**: Dev | **Implements**: p00041 | **Status**: Draft

The system SHALL generate Define-XML metadata documents describing dataset structure, variables, controlled terminology, and derivation methods.

Implementation SHALL include:
- Define-XML 2.1 compliant document generation
- Variable definitions for all exported fields
- Controlled terminology references (external code lists)
- Value domains for categorical variables
- Derivation methods for calculated fields
- Dataset structure and relationships

**Define-XML Elements**:

| Element        | Purpose                | Content                          |
| -------------- | ---------------------- | -------------------------------- |
| ItemDef        | Variable definition    | Name, label, data type, length   |
| CodeList       | Controlled terminology | Code values with decodes         |
| ValueListDef   | Value-level metadata   | Conditional variable definitions |
| MethodDef      | Derivation method      | Algorithm for derived variables  |
| WhereClauseDef | Conditional logic      | When variables apply             |

**Rationale**: Define-XML provides machine-readable metadata required for regulatory submissions. It describes what the data contains, enabling automated validation and review by regulators.

**Acceptance Criteria**:
- Define-XML 2.1 document generated for each export
- All variables documented with labels and data types
- Controlled terminology code lists referenced
- Derivation methods documented for calculated fields
- Document validates against Define-XML schema
- Generated alongside SDTM/ODM exports

*End* *Define-XML Metadata Generation* | **Hash**: 4a4d28cd

---

# REQ-d00076: Clinical Data Export Formats

**Level**: Dev | **Implements**: p00041, p00029 | **Status**: Draft

The portal export functionality SHALL support multiple output formats for clinical data including CDISC-compliant formats.

Implementation SHALL include:
- CSV export with CDASH/SDTM variable names
- SAS XPORT v5 format for FDA submission
- ODM-XML export (see REQ-d00072)
- JSON export for programmatic access
- Excel export for investigator review
- Export audit logging (who exported what, when)

**Export Options**:

| Format    | Use Case            | CDISC Compliance                     |
| --------- | ------------------- | ------------------------------------ |
| CSV       | General analysis    | Variable names follow CDASH          |
| SAS XPORT | FDA submission      | Required format for submission       |
| ODM-XML   | EDC integration     | Full CDISC compliance                |
| JSON      | API/programmatic    | Internal format with CDISC metadata  |
| Excel     | Investigator review | Human-readable with labels           |

**Rationale**: Different stakeholders require data in different formats. Regulatory submission requires specific formats (SAS XPORT). EDC integration requires ODM. Investigators need human-readable formats.

**Acceptance Criteria**:
- Portal export supports all listed formats
- Export includes date range and filter options
- Large exports handled without timeout
- Export logged in audit trail
- SAS XPORT validated for FDA compatibility
- Format documentation provided for each export type

*End* *Clinical Data Export Formats* | **Hash**: 718bd3af

---

## EDC Synchronization Requirements

# REQ-d00075: EDC Data Transformation Specification

**Level**: Dev | **Implements**: p00041 | **Status**: Draft

The EdcSync.transformEvent() method SHALL implement documented transformation logic converting internal diary events to EDC-compatible format for proxy mode synchronization.

Implementation SHALL include:
- Transformation specification document per EDC vendor
- Field mapping from internal → EDC API payload
- CDISC-compliant intermediate format (ODM-based)
- Error handling for transformation failures
- Validation of transformed payload before sync
- Sponsor-configurable field mapping overrides

**EdcSync Interface**:

```dart
abstract class EdcSync {
  /// Transform internal event to EDC-compatible format
  /// Returns ODM-based payload for EDC API
  Future<EdcPayload> transformEvent(DiaryEvent event);

  /// Sync transformed event to EDC system
  Future<SyncResult> sync(EdcPayload payload);

  /// Validate payload before sync
  Future<ValidationResult> validate(EdcPayload payload);
}
```

**Transformation Flow**:

```
Internal Event (epistaxis-v1.0)
    ↓
Apply CDASH field mapping (REQ-d00070)
    ↓
Apply controlled terminology (REQ-d00074)
    ↓
Generate ODM-based payload
    ↓
Apply sponsor-specific transformations
    ↓
Validate against EDC schema
    ↓
Sync to EDC API
```

**Vendor-Specific Considerations**:

| EDC Platform  | API Format | Authentication | Notes                        |
| ------------- | ---------- | -------------- | ---------------------------- |
| Medidata Rave | ODM-XML    | OAuth 2.0      | Uses RWS (Rave Web Services) |
| Oracle InForm | REST/JSON  | API Key        | InForm Cloud API             |
| Veeva Vault   | REST/JSON  | OAuth 2.0      | Vault CDMS API               |

**Rationale**: EdcSync is currently an abstract interface without implementation guidance. Documenting the transformation specification enables consistent implementation across sponsors and EDC platforms.

**Acceptance Criteria**:
- Transformation specification documented for each supported EDC
- Field mapping covers all diary event types
- Transformed payload is ODM-compliant
- Validation catches mapping errors before sync
- Error messages identify specific transformation failures
- Sponsor can override default mappings

*End* *EDC Data Transformation Specification* | **Hash**: cd5b72f1

---

## Already Satisfied Requirements

The following CDISC-related needs are already addressed by existing platform requirements. No additional implementation is required.

### Audit Trail and Data Integrity

**CDISC Need**: Complete audit trail for all data changes

**Satisfied By**:
- **REQ-p00004**: Immutable Audit Trail via Event Sourcing (prd-database.md)
- **REQ-p01003**: Immutable Event Storage with Audit Trail (prd-event-sourcing-system.md)
- **REQ-p00011**: ALCOA+ Data Integrity Principles (prd-clinical-trials.md)

**Implementation**: Event sourcing architecture captures all changes as immutable events. Each event includes timestamp, user attribution, and complete state snapshot. This exceeds CDISC audit trail requirements.

---

### Schema Versioning

**CDISC Need**: Data structure versioning for schema evolution

**Satisfied By**:
- **REQ-p01004**: Schema Version Management (prd-event-sourcing-system.md)

**Implementation**: Event types include version numbers (e.g., `epistaxis-v1.0`). Schema evolution follows semantic versioning. Migration rules documented in dev-data-models-jsonb.md.

---

### Data Retention

**CDISC Need**: Long-term data retention for regulatory requirements

**Satisfied By**:
- **REQ-p00012**: Clinical Data Retention Requirements (prd-clinical-trials.md)

**Implementation**: 7+ year retention policy with S3/Glacier archival. Data integrity maintained via SHA-256 checksums.

---

### Access Control

**CDISC Need**: Controlled access to clinical data

**Satisfied By**:
- **REQ-p00005**: Role-Based Access Control (prd-security-RBAC.md)
- **REQ-p00015**: Database-Level Access Enforcement (prd-security-RLS.md)

**Implementation**: RBAC roles (patient, investigator, analyst, sponsor, auditor, admin) with RLS policies enforcing data isolation.

---

## Implementation Roadmap

| Phase | Requirements                | Priority | Dependencies |
| ----- | --------------------------- | -------- | ------------ |
| 1     | REQ-d00074 (Terminology)    | HIGH     | None         |
| 2     | REQ-d00070 (CDASH Mapping)  | HIGH     | REQ-d00074   |
| 3     | REQ-d00071 (SDTM Transform) | HIGH     | REQ-d00070   |
| 4     | REQ-d00072 (ODM Export)     | HIGH     | REQ-d00071   |
| 5     | REQ-d00073 (Define-XML)     | MEDIUM   | REQ-d00071   |
| 6     | REQ-d00076 (Export Formats) | MEDIUM   | REQ-d00072   |
| 7     | REQ-d00075 (EDC Transform)  | HIGH     | REQ-d00072   |

---

## References

- **CDISC CDASH**: https://www.cdisc.org/standards/foundational/cdash
- **CDISC SDTM**: https://www.cdisc.org/standards/foundational/sdtm
- **CDISC ODM**: https://www.cdisc.org/standards/data-exchange/odm
- **CDISC Define-XML**: https://www.cdisc.org/standards/data-exchange/define-xml
- **CDISC Controlled Terminology**: https://www.cdisc.org/standards/terminology
- **Internal Data Models**: dev-data-models-jsonb.md
- **EDC Architecture**: dev-architecture-multi-sponsor.md

---

*End of Document*
