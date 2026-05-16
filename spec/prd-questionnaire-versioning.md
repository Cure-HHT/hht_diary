# Questionnaire Versioning, Localization, and Sponsor Eligibility

This file holds the clinical-domain obligations governing how the Diary Platform versions questionnaires (schema, content, GUI), localizes them across languages, and how each sponsor configures which questionnaires their study uses. These obligations were carved out of the legacy `prd-event-sourcing-system.md` during the URS-v1 migration on 2026-05-15: they are domain-specific to clinical questionnaires and did not belong alongside generic event-sourcing requirements (those are now owned by the `event_sourcing` repo as `EVS-PRD-*`).

The URS v1.0 §5.3 (Questionnaire Management) will refine and supersede portions of these obligations in a subsequent migration phase; until then this file is the active source.

## DIARY-PRD-questionnaire-versioning: Questionnaire Versioning Model

**Level**: prd | **Status**: Legacy | **Implements**: -

### Rationale

Clinical questionnaires evolve across multiple independent dimensions. Structural changes add or remove data fields requiring database schema updates. Content changes refine question wording to improve clarity or address translation issues without altering the underlying data structure. Presentation changes enhance user experience through visual redesign without modifying what questions are asked. Conflating these three evolution paths into a single version number creates unnecessary coupling: wording improvements would trigger schema migrations, UI redesigns would invalidate validated instrument versions, and the audit trail would obscure which dimension actually changed. By tracking schema, content, and GUI versions independently, clinical teams can refine instrument language without engineering involvement, UX teams can improve presentation without affecting clinical validation, and regulatory audits can reconstruct the exact patient experience across all three dimensions.

Once a version is deployed and used to capture patient data, it becomes an immutable artifact. Modifying a deployed version would silently alter the instrument for patients already using it, breaking the ability to reconstruct what the patient experienced (assertions M, N) and severing audit traceability (assertion S). Any change — whether bug fix or improvement — must produce a new version. The prior version remains frozen and available for sponsors that have not opted into the update. This immutability applies to all three dimensions independently: a GUI can be frozen at v1.0 for one sponsor while another adopts v1.1, without affecting the content or schema versions either sponsor uses.

### Assertions

A. The platform SHALL support independent versioning of questionnaire schema, content, and presentation.

B. The system SHALL distinguish between schema version, content version, and GUI version as separate versioning dimensions.

C. Schema version SHALL identify the data structure and field types stored in the database.

D. Schema version SHALL change when fields are added, removed, or restructured.

E. Schema version SHALL determine validation rules and migration requirements.

F. Content version SHALL identify the source language question text, option labels, help text, and scoring rules.

G. Content version SHALL change when wording is clarified or questions are refined, independent of schema changes.

H. GUI version SHALL identify the presentation and rendering of the questionnaire in client applications.

I. GUI version SHALL change when user interface is redesigned or user experience is improved, independent of content or schema.

J. Each questionnaire response SHALL record the schema version identifier.

K. Each questionnaire response SHALL record the content version identifier.

L. Each questionnaire response SHALL record the GUI version identifier.

M. The system SHALL enable complete reconstruction of what the patient saw using the recorded version identifiers.

N. The system SHALL enable complete reconstruction of how the data was captured using the recorded version identifiers.

O. Wording changes SHALL create a new content version without requiring schema migration.

P. UI redesigns SHALL create a new GUI version without requiring content version changes.

Q. UI redesigns SHALL create a new GUI version without requiring schema version changes.

R. The system SHALL enable retrieval of historical responses with exact version context for all three version dimensions.

S. The platform SHALL maintain complete audit traceability across all three versioning dimensions.

T. Once a questionnaire version has been used to capture patient data, that version SHALL be immutable.

*End* *Questionnaire Versioning Model* | **Hash**: 6d08845d

---

## DIARY-PRD-questionnaire-localization: Questionnaire Localization and Translation Tracking

**Level**: prd | **Status**: Legacy | **Implements**: -
**Refines**: DIARY-PRD-questionnaire-versioning

### Rationale

International clinical trials require validated translations of instruments, where each translation has its own validation status and version lifecycle independent of the source content. For ALCOA+ compliance, the audit trail must show exactly what question text the patient saw in their language. For analysis purposes, responses must be normalized to a common language. Storing both the original patient response and canonical normalized response preserves the complete audit trail while enabling consistent cross-site analysis.

### Assertions

A. The platform SHALL support localized questionnaires with independent translation versioning.

B. The system SHALL store the language identifier showing the specific language and locale presented to the patient (e.g., es-MX for Spanish-Mexico).

C. The system SHALL store the translation version for each language, independent of the source content version.

D. The system SHALL store the source content reference indicating which source language content version each translation is based upon.

E. The system SHALL capture the original response as the exact value the patient entered or selected in their language.

F. The system SHALL capture the canonical response as the normalized value used for study analysis.

G. The system SHALL store the translation method for free-text translations, indicating whether the canonical value was auto-translated, manually translated, or verified by a human translator.

H. The system SHALL record patient language preference at enrollment.

I. The system SHALL present questionnaires in the patient's configured language.

J. The system SHALL track translation version per language per questionnaire.

K. The system SHALL enable reconstruction of the audit trail showing the exact localized content shown to each patient.

L. The system SHALL support management of translation versions independently of source content versions.

*End* *Questionnaire Localization and Translation Tracking* | **Hash**: 4218237c

---

## DIARY-PRD-questionnaire-sponsor-eligibility: Sponsor Questionnaire Eligibility Configuration

**Level**: prd | **Status**: Legacy | **Implements**: -
**Refines**: DIARY-PRD-questionnaire-versioning

### Rationale

Multi-sponsor deployments require sponsor-specific questionnaire portfolios to accommodate varying study designs. One sponsor may use only epistaxis tracking while another includes quality-of-life assessments. Version constraints enable patients in ongoing studies to continue using validated instrument versions while new enrollments can use updated versions, ensuring data consistency within study cohorts. Language enablement ensures only properly validated translations are offered to participants. This configuration-driven approach allows questionnaire changes to be managed deliberately, preventing unintended mid-study modifications that could impact response patterns and data quality. The platform enforces these constraints at data capture time to maintain study protocol compliance and data integrity across the multi-sponsor environment.

### Assertions

A. The system SHALL allow each sponsor to configure which questionnaire types are enabled for their clinical trial.

B. The system SHALL allow each sponsor to configure which questionnaire versions are enabled for their clinical trial.

C. The system SHALL allow each sponsor to configure which questionnaire languages are enabled for their clinical trial.

D. Sponsor questionnaire configuration SHALL specify the current version for new entries.

E. Sponsor questionnaire configuration SHALL specify the minimum accepted version for historical data.

F. Sponsor questionnaire configuration SHALL designate the source language for each enabled questionnaire.

G. The system SHALL present only sponsor-enabled questionnaires in client applications.

H. The system SHALL use the configured current version when capturing new questionnaire data.

I. The system SHALL accept historical questionnaire data from any version between the minimum version and the current version inclusive.

J. The system SHALL restrict language options to sponsor-enabled translations during data capture.

K. The system SHALL validate questionnaire responses against the rules defined in the appropriate questionnaire version.

L. The system SHALL enforce sponsor eligibility constraints during all data capture operations.

M. Configuration changes SHALL NOT invalidate existing historical questionnaire data.

N. The system SHALL support addition of new questionnaire types whose content conforms to an existing renderer class through catalog entry creation and sponsor configuration update, without requiring renderer code changes.

*End* *Sponsor Questionnaire Eligibility Configuration* | **Hash**: ac2f2aac
