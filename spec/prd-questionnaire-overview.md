# Questionnaires Overview

The platform implements three questionnaires: the **Daily Epistaxis Record** (the daily eDiary instrument), the **NOSE HHT** survey, and the **HHT-QoL** survey. Each requirement binds the instrument to its validated source document and to the computer-readable data file that is the single implementation reference.

## DIARY-PRD-questionnaire-daily-epistaxis: Daily Epistaxis Record Questionnaire

**Level**: PRD | **Status**: Draft | **Implements**: -
**Refines**: DIARY-BASE-questionnaires

### Overview

Daily epistaxis tracking is the core data collection activity in HHT clinical trials because nosebleed frequency, duration, and severity are the primary outcome measures for evaluating treatment efficacy. *Participant* self-reporting captures events as they occur rather than relying on retrospective recall during clinical visits, supporting the Contemporaneous principle of ALCOA+. "No nosebleeds" and "Don't remember" entries are valid daily summaries that distinguish between confirmed absence of events and missing data, which is critical for data integrity in regulatory submissions.


Daily Epistaxis Record
: The primary nosebleed tracking instrument used in the HHT Diary, derived from Clark et al. (2018) with modifications.

Epistaxis Event
: A single nosebleed occurrence recorded by the participant with timing, duration, and intensity data.

### Assertions

A. The system SHALL implement the **Daily Epistaxis Record** *Questionnaire* for capturing *Participant*-reported nosebleed events.

B. The source instrument SHALL be documented with citation: Clark et al. "Nosebleeds in hereditary hemorrhagic telangiectasia: Development of a *Participant*-completed daily eDiary." Laryngoscope Investig Otolaryngol. 2018. doi:10.1002/lio2.211.

C. All modifications to the source instrument SHALL be documented and traceable to their justification.

D. The instrument content, field definitions, and validation rules SHALL be implemented in a computer-readable data file that has been manually checked for accuracy.

### Rationale

The **Daily Epistaxis Record** is the primary instrument the *Diary* platform exists to capture; every other surface (*Calendar*, *Day View*, recording flow, notifications, score calculations) is in service of getting reliable instances of this record into the dataset. Binding the requirement to the Clark et al. (2018) source instrument anchors the *Diary* content to a validated reference so the platform's implementation can be audited against an external definition rather than re-derived locally. Any modification to the source is required to carry its own documented justification because clinical instruments derive their interpretive validity from the published version; undocumented deviations would break the chain back to the validated source and undermine the dataset's regulatory standing. The single computer-readable data file is the implementation reference — the same artifact the application loads and the specification references — which prevents drift between what the spec says and what the application runs.

*End* *Daily Epistaxis Record Questionnaire* | **Hash**: f248d7d8

## DIARY-PRD-questionnaire-nose-hht: NOSE HHT Questionnaire

**Level**: PRD | **Status**: Draft | **Implements**: -
**Refines**: DIARY-BASE-questionnaires

### Overview

The *NOSE HHT* (Nasal Outcome Score for Epistaxis in Hereditary Hemorrhagic Telangiectasia) is a validated 29-question *Participant*-reported outcome measure assessing the physical, functional, and emotional impact of nosebleeds on HHT participants. The platform implements this instrument faithfully from the validated source. *Questionnaire* content is defined in the source document and transcribed once into a computer-readable data file — the data file is the single implementation reference, eliminating duplication and ensuring the application and the specification never diverge.


NOSE HHT
: The Nasal Outcome Score for Epistaxis in Hereditary Hemorrhagic Telangiectasia, a validated clinical instrument published in JAMA Otolaryngology — Head and Neck Surgery, 2020.

True Copy
: A complete, unaltered reproduction of the source document obtained directly from the original publisher URL.

### Assertions

A. The system SHALL implement the **NOSE HHT** *Questionnaire* as defined in the source document referenced in assertion B.

B. A **True Copy** of the source document SHALL have been obtained from: https://jamanetwork.com/journals/jamaotolaryngology/fullarticle/2771847

C. The **True Copy** SHALL be referenced by the computer-readable data file that implements this *Questionnaire*.

D. The source document SHALL be transcribed into a computer-readable data file that has been manually checked for accuracy. This transcribed version will serve as the official reference for all questions, answer choices, and scoring rules used in the system.

E. The System SHALL present the 29 **NOSE HHT** questions organized into the three categories defined in the source instrument: Physical, Functional, and Emotional.

F. The *Questionnaire* Display Name for the *NOSE HHT* *Questionnaire* SHALL be "*NOSE HHT* Survey".

### Rationale

The **NOSE HHT** is a validated clinical instrument; its interpretive validity depends on faithful reproduction of the published questions, answer choices, and scoring rules. The *True Copy* obligation anchors the platform's implementation to the publisher's authoritative version — the same document any auditor can independently retrieve from the cited URL — and removes any ambiguity about which variant of the instrument the platform uses. Transcription into a computer-readable data file is the bridge between the human-readable source and the running application: the application loads the data file directly, so the spec's reference to the data file and the application's runtime behavior are guaranteed to match. The three-category presentation (Physical, Functional, Emotional) matches the source instrument's structure and is required for *Participant* comprehension and downstream score interpretation.

*End* *NOSE HHT Questionnaire* | **Hash**: cc3f89c7

## DIARY-PRD-questionnaire-hht-qol: HHT-QoL Questionnaire

**Level**: PRD | **Status**: Draft | **Implements**: -
**Refines**: DIARY-BASE-questionnaires

### Overview

The *HHT-QoL* *Questionnaire* is a validated 4-question *Participant*-reported outcome measure assessing how nosebleeds and HHT-related problems affect participants' daily activities and social engagement. The platform implements this instrument faithfully from the validated source. *Questionnaire* content is defined in the source document and transcribed once into a computer-readable data file — the data file is the single implementation reference, eliminating duplication and ensuring the application and the specification never diverge.


HHT-QoL
: A validated clinical instrument published in Blood Advances, 2022, measuring the impact of HHT symptoms on participants' daily and social activities.

### Assertions

A. The system SHALL implement the **HHT-QoL** *Questionnaire* as defined in the source document referenced in assertion B.

B. A **True Copy** of the source document SHALL have been obtained from: https://ashpublications.org/bloodadvances/article/6/14/4301/484568

C. The **True Copy** SHALL be referenced by the computer-readable data file that implements this *Questionnaire*.

D. The source document SHALL be transcribed into a computer-readable data file that has been manually checked for accuracy. This transcribed version will serve as the official reference for all questions, answer choices, and scoring rules used in the system.

E. The system SHALL emphasize the key phrases — interrupted, avoided, had to miss, and other than nosebleeds — in the **HHT-QoL** questions, matching the formatting of the original validated instrument.

F. The *Questionnaire* Display Name for the *HHT-QoL* *Questionnaire* SHALL be "HHT Quality of Life Survey".

### Rationale

The **HHT-QoL** is a short (4-question) validated quality-of-life instrument complementing the *NOSE HHT*'s symptom focus with an activities-and-engagement perspective. The *True Copy* and transcription requirements track the same faithfulness obligation that applies to the *NOSE HHT* (assertion-for-assertion): the published source defines the instrument, and the platform's data file is the single reference the application consumes. The key-phrase emphasis (italics on "interrupted", "avoided", "had to miss", "other than nosebleeds") is a substantive part of the published instrument's wording — these emphases are how the original instrument signals which words the *Participant* should be asked to weigh most carefully — and dropping them would silently re-engineer the question stems away from the validated form. Preserving them keeps the platform's rendering aligned with the source.

*End* *HHT-QoL Questionnaire* | **Hash**: e45af717
