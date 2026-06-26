# *Questionnaire* Versioning, Localization, and *Sponsor* Eligibility

This file holds the clinical-domain obligations governing how the *Diary* Platform versions questionnaires (schema, content, GUI), localizes them across languages, and how each *Sponsor* configures which questionnaires their study uses. These obligations were carved out of the legacy `prd-event-sourcing-system.md` during the URS-v1 migration on 2026-05-15: they are domain-specific to clinical questionnaires and did not belong alongside generic event-sourcing requirements (those are now owned by the `event_sourcing` repo as `EVS-PRD-*`).

The URS v1.0 §5.3 (*Questionnaire* Management) will refine and supersede portions of these obligations in a subsequent migration phase; until then this file is the active source.

## DIARY-PRD-questionnaire-versioning: Questionnaire Versioning Model

**Level**: PRD | **Status**: Legacy | **Implements**: -
**Refines**: DIARY-BASE-clinical-questionnaires

### Rationale

Clinical questionnaires evolve across multiple independent dimensions. Structural changes add or remove data fields requiring *Database* schema updates. Content changes refine question wording to improve clarity or address translation issues without altering the underlying data structure. Presentation changes enhance *User* experience through visual redesign without modifying what questions are asked. Conflating these three evolution paths into a single version number creates unnecessary coupling: wording improvements would trigger schema migrations, UI redesigns would invalidate validated instrument versions, and the *Audit Trail* would obscure which dimension actually changed. By tracking schema, content, and GUI versions independently, clinical teams can refine instrument language without engineering involvement, UX teams can improve presentation without affecting clinical validation, and regulatory audits can reconstruct the exact *Patient* experience across all three dimensions.

Once a version is deployed and used to capture *Patient* data, it becomes an immutable artifact. Modifying a deployed version would silently alter the instrument for patients already using it, breaking the ability to reconstruct what the *Patient* experienced (assertions M, N) and severing audit traceability (assertion S). Any change — whether bug fix or improvement — must produce a new version. The prior version remains frozen and available for sponsors that have not opted into the update. This immutability applies to all three dimensions independently: a GUI can be frozen at v1.0 for one *Sponsor* while another adopts v1.1, without affecting the content or schema versions either *Sponsor* uses.

### Assertions

A. The platform SHALL support independent versioning of *Questionnaire* schema, content, and presentation.

B. The system SHALL distinguish between schema version, content version, and GUI version as separate versioning dimensions.

C. Schema version SHALL identify the data structure and field types stored in the *Database*.

D. Schema version SHALL change when fields are added, removed, or restructured.

E. Schema version SHALL determine validation rules and migration requirements.

F. Content version SHALL identify the source language question text, option labels, help text, and scoring rules.

G. Content version SHALL change when wording is clarified or questions are refined, independent of schema changes.

H. GUI version SHALL identify the presentation and rendering of the *Questionnaire* in client applications.

I. GUI version SHALL change when *User* interface is redesigned or *User* experience is improved, independent of content or schema.

J. Each *Questionnaire* response SHALL record the schema version identifier.

K. Each *Questionnaire* response SHALL record the content version identifier.

L. Each *Questionnaire* response SHALL record the GUI version identifier.

M. The system SHALL enable complete reconstruction of what the *Patient* saw using the recorded version identifiers.

N. The system SHALL enable complete reconstruction of how the data was captured using the recorded version identifiers.

O. Wording changes SHALL create a new content version without requiring schema migration.

P. UI redesigns SHALL create a new GUI version without requiring content version changes.

Q. UI redesigns SHALL create a new GUI version without requiring schema version changes.

R. The system SHALL enable retrieval of historical responses with exact version context for all three version dimensions.

S. The platform SHALL maintain complete audit traceability across all three versioning dimensions.

T. Once a *Questionnaire* version has been used to capture *Patient* data, that version SHALL be immutable.

*End* *Questionnaire Versioning Model* | **Hash**: cba3b718

---

## DIARY-PRD-questionnaire-localization: Questionnaire Localization and Translation Tracking

**Level**: PRD | **Status**: Legacy | **Implements**: -
**Refines**: DIARY-PRD-questionnaire-versioning

### Rationale

International clinical trials require validated translations of instruments, where each translation has its own validation status and version lifecycle independent of the source content. For ALCOA+ compliance, the *Audit Trail* must show exactly what question text the *Patient* saw in their language. For analysis purposes, responses must be normalized to a common language. Storing both the original *Patient* response and canonical normalized response preserves the complete *Audit Trail* while enabling consistent cross-*Site* analysis.

### Assertions

A. The platform SHALL support localized questionnaires with independent translation versioning.

B. The system SHALL store the language identifier showing the specific language and locale presented to the *Patient* (e.g., es-MX for Spanish-Mexico).

C. The system SHALL store the translation version for each language, independent of the source content version.

D. The system SHALL store the source content reference indicating which source language content version each translation is based upon.

E. The system SHALL capture the original response as the exact value the *Patient* entered or selected in their language.

F. The system SHALL capture the canonical response as the normalized value used for study analysis.

G. The system SHALL store the translation method for free-text translations, indicating whether the canonical value was auto-translated, manually translated, or verified by a human translator.

H. The system SHALL record *Patient* language preference at enrollment.

I. The system SHALL present questionnaires in the *Patient*'s configured language.

J. The system SHALL track translation version per language per *Questionnaire*.

K. The system SHALL enable reconstruction of the *Audit Trail* showing the exact localized content shown to each *Patient*.

L. The system SHALL support management of translation versions independently of source content versions.

*End* *Questionnaire Localization and Translation Tracking* | **Hash**: 21f3e967

---

## DIARY-PRD-questionnaire-sponsor-eligibility: Sponsor Questionnaire Eligibility Configuration

**Level**: PRD | **Status**: Legacy | **Implements**: -
**Refines**: DIARY-PRD-questionnaire-versioning

### Rationale

Multi-*Sponsor* deployments require *Sponsor*-specific *Questionnaire* portfolios to accommodate varying study designs. One *Sponsor* may use only epistaxis tracking while another includes quality-of-life assessments. Version constraints enable patients in ongoing studies to continue using validated instrument versions while new enrollments can use updated versions, ensuring data consistency within study cohorts. Language enablement ensures only properly validated translations are offered to participants. This configuration-driven approach allows *Questionnaire* changes to be managed deliberately, preventing unintended mid-study modifications that could impact response patterns and data quality. The platform enforces these constraints at data capture time to maintain study protocol compliance and data integrity across the multi-*Sponsor* environment.

### Assertions

A. The system SHALL allow each *Sponsor* to configure which *Questionnaire* types are enabled for their clinical *Trial*.

B. The system SHALL allow each *Sponsor* to configure which *Questionnaire* versions are enabled for their clinical *Trial*.

C. The system SHALL allow each *Sponsor* to configure which *Questionnaire* languages are enabled for their clinical *Trial*.

D. *Sponsor* *Questionnaire* configuration SHALL specify the current version for new entries.

E. *Sponsor* *Questionnaire* configuration SHALL specify the minimum accepted version for historical data.

F. *Sponsor* *Questionnaire* configuration SHALL designate the source language for each enabled *Questionnaire*.

G. The system SHALL present only *Sponsor*-enabled questionnaires in client applications.

H. The system SHALL use the configured current version when capturing new *Questionnaire* data.

I. The system SHALL accept historical *Questionnaire* data from any version between the minimum version and the current version inclusive.

J. The system SHALL restrict language options to *Sponsor*-enabled translations during data capture.

K. The system SHALL validate *Questionnaire* responses against the rules defined in the appropriate *Questionnaire* version.

L. The system SHALL enforce *Sponsor* eligibility constraints during all data capture operations.

M. Configuration changes SHALL NOT invalidate existing historical *Questionnaire* data.

N. The system SHALL support addition of new *Questionnaire* types whose content conforms to an existing renderer class through catalog entry creation and *Sponsor* configuration update, without requiring renderer code changes.

*End* *Sponsor Questionnaire Eligibility Configuration* | **Hash**: 2872607b
