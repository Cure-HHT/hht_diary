# Score Calculation

The platform's score-calculation obligations comprise the general rule that scores are computed per a validated algorithm and stored with the *Questionnaire* record, plus the specific algorithm bindings for the **HHT-QoL** and **NOSE HHT** instruments.

## DIARY-PRD-questionnaire-score-calculation: Questionnaire Score Calculation

**Level**: PRD | **Status**: Draft | **Implements**: -
**Refines**: DIARY-BASE-questionnaires

### Overview

Validated questionnaires require scoring according to published, protocol-defined algorithms to ensure data integrity and comparability across participants and studies. Storing scores with survey records ensures traceability and supports downstream *Rave EDC* synchronization and analysis.

### Assertions

A. The System SHALL calculate **Questionnaire** scores according to the validated algorithm defined for each **Questionnaire**.

B. The System SHALL store the calculated score with the associated *Questionnaire* record.

C. The scoring algorithm SHALL be traceable to its source definition for each **Questionnaire Type**.

### Rationale

Scores are the analytical artifact downstream research derives outcomes from — frequency, severity, quality-of-life impact. Computing scores per the validated published algorithm rather than per a platform-local re-derivation is what gives the resulting numbers their interpretive validity: a *NOSE HHT* score from this platform is comparable to a *NOSE HHT* score from any other study only because both implement the published JAMA Otolaryngology algorithm faithfully. Storing the score with the *Questionnaire* record (rather than recomputing on demand) preserves the value the *Participant*'s answers actually produced at the time of *Submission* — even if the algorithm reference is later updated, the historical record reflects what was computed and shipped to **Rave EDC** for that *Participant*. Traceability to source for each **Questionnaire Type** is the audit-trail counterpart of the *True Copy* obligation on the *Questionnaire* definitions: any auditor must be able to follow the chain from a stored score back to the published algorithm that produced it.

*End* *Questionnaire Score Calculation* | **Hash**: 807ef589

## DIARY-PRD-score-hht-qol: HHT-QoL Score Calculation

**Level**: PRD | **Status**: Draft | **Implements**: -
**Refines**: DIARY-PRD-questionnaire-score-calculation

### Assertions

A. The System SHALL calculate the **HHT-QoL** *Questionnaire* score according to the algorithm defined in: Development and performance of a hereditary hemorrhagic telangiectasia-specific quality-of-life instrument, Blood Advances, 26 July 2022, Volume 6, Number 14, DOI 10.1182/bloodadvances.2022007748.

### Rationale

The **HHT-QoL** scoring algorithm is fully specified by the cited Blood Advances 2022 publication; the platform's *Role* is to implement that algorithm faithfully against the *Questionnaire*'s four answer fields. Anchoring the requirement to the DOI rather than restating the algorithm here preserves the property that the published reference is the single source of truth — any platform-side restatement would create a second authority that could drift from the original. The DOI is stable across editorial revisions, so an auditor can retrieve exactly the version the platform's implementation was checked against.

*End* *HHT-QoL Score Calculation* | **Hash**: 67ca87e3

## DIARY-PRD-score-nose-hht: NOSE HHT Score Calculation

**Level**: PRD | **Status**: Draft | **Implements**: -
**Refines**: DIARY-PRD-questionnaire-score-calculation

### Assertions

A. The System SHALL calculate the **NOSE HHT** *Questionnaire* score according to the algorithm defined in: Development and Validation of the Nasal Outcome Score for Epistaxis in Hereditary Hemorrhagic Telangiectasia (*NOSE HHT*), JAMA Otolaryngology – Head & Neck Surgery, November 1, 2020, Volume 146, Number 11, DOI 10.1001/jamaoto.2020.3040.

### Rationale

The **NOSE HHT** scoring algorithm is fully specified by the cited JAMA Otolaryngology 2020 publication, which is the same publication the *Questionnaire* definition itself cites for the question and answer choices. Anchoring the score requirement to the same DOI keeps the *Questionnaire* and its score on a single source-of-truth chain: the published instrument defines what to ask and how to score the answers, and the platform's two requirements (one for the *Questionnaire* content, one for the score) both reference it. As with **HHT-QoL**, the DOI is the stable retrieval handle an auditor uses to confirm the platform's implementation matches the validated reference.

*End* *NOSE HHT Score Calculation* | **Hash**: 634f9daf
