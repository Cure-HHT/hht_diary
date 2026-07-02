# *Questionnaire* Management

The platform's **Questionnaire** system rests on a *Questionnaire* foundation, *Sponsor*-specific configuration surfaces, a controlled *Submission* gate that enforces approved structures, and change-control discipline that keeps questionnaires stable within a *Trial*.

## DIARY-PRD-questionnaire-system: Questionnaire System

**Level**: PRD | **Status**: Draft | **Implements**: -
**Refines**: DIARY-BASE-questionnaires

### Overview

Clinical trials use structured questionnaires to collect reliable data in a consistent and compliant way. The questionnaires are carefully built to ensure accuracy and a good *Participant* experience. New questionnaires can be added as needed, and the content always comes from approved documents, not edited directly in the app.


Questionnaire
: A structured data-collection form presented to a participant to capture self-reported outcomes at protocol-defined points in a clinical trial. A *Questionnaire* may be a validated instrument, an informal survey, or an instrument undergoing validation; the platform handles all of them uniformly.

Questionnaire Type
: A named category of **Questionnaire**. Each **Questionnaire Type** is implemented as an individual coded component.

Trial Start
: The event that formally begins a participant's active trial participation. The trigger and label for **Trial Start** are sponsor-configurable.

Completion Status
: The current state of a **Questionnaire** instance for a given participant. Valid values are defined per **Questionnaire** workflow.

Diary Data Synchronization
: The continuous transmission of participant diary entries from the participant's mobile application to the **Sponsor Portal** and **Rave EDC**.

Questionnaire Display Name
: The participant-facing name of a **Questionnaire** as presented in the mobile application. Distinct from the instrument name used for internal identification and clinical reference.

Trial
: A clinical study conducted under a Sponsor's protocol in which **Participants** are enrolled to capture self-reported outcomes through the **Mobile Application**. The **Trial** begins at **Trial Start**.

### Assertions

**Questionnaire Registry**

A. The System SHALL allow implementation of multiple **Questionnaire Types**, each as an individual coded component.

B. The System SHALL track **Completion Status** for each **Questionnaire** instance.

**Data Synchronization**

C. The System SHALL activate **Diary Data Synchronization** upon **Trial Start**.

D. The System SHALL deactivate **Diary Data Synchronization** when a *Participant* is disconnected or is marked as Not Participating.

**Configuration**

E. The System SHALL support *Sponsor*-configurable configuration of the trigger and workflow that activates **Trial Start**.

F. Each **Questionnaire** SHALL have a **Questionnaire Display Name**.

### Rationale

The *Questionnaire* subsystem is the principal source of *Trial*-grade data in the platform, and its design choices reflect that *Role*. Implementing each **Questionnaire Type** as an individual coded component is a defense against ad hoc content: every *Questionnaire* that ships is a deliberate engineering artifact reviewed against an approved source document, not a configuration table that a *Sponsor* could edit without change control. **Completion Status** tracking is the foundation for the workflow rules that govern how a *Questionnaire* moves from sent to answered to finalized; without per-instance status the platform could not distinguish "answered but not finalized" from "answered and locked", which is a clinical and regulatory distinction. **Trial Start** is the gate at which **Diary Data Synchronization** activates because pre-*Trial* *Diary* data is *Participant*-private and must not be promoted to the *Sponsor* portal or Rave EDC until the *Sponsor* has acknowledged that the *Participant* is in *Trial*; making the trigger *Sponsor*-configurable keeps the platform protocol-neutral.

*End* *Questionnaire System* | **Hash**: 5d99cd12

## DIARY-PRD-questionnaire-sponsor-configuration: Sponsor Questionnaire Configuration

**Level**: PRD | **Status**: Draft | **Implements**: -
**Refines**: DIARY-PRD-questionnaire-system

### Overview

A configuration-driven approach allows the *Sponsor* to tailor *Questionnaire* behavior to their study protocol without requiring platform code changes, ensuring that mid-study modifications are managed deliberately and do not unintentionally affect data collection.

### Assertions

A. The System SHALL support *Sponsor*-specific configuration of which **Questionnaires** are enabled per study.

B. The System SHALL support *Sponsor*-specific configuration of *Participant* reminder behavior for each enabled **Questionnaire**.

C. The System SHALL support *Sponsor*-specific configuration of the processing steps that occur between *Participant* *Submission* and **Rave EDC** synchronization for each **Questionnaire**.

D. The System SHALL support *Sponsor*-specific configuration of whether a *Participant* may edit their answers after *Submission* and under what conditions.

E. The System SHALL support *Sponsor*-specific configuration of which languages are enabled per **Questionnaire**.

### Rationale

The five configuration axes named here — enablement, reminder behavior, post-*Submission* processing, post-*Submission* editability, and language — are the dimensions along which clinical protocols typically vary between sponsors using the same underlying **Questionnaire Type**. Encoding them as *Sponsor* configuration rather than platform code keeps the platform's *Questionnaire* library stable across deployments while letting each *Sponsor* express the protocol-specific decisions that their IRB and operations teams require. The configuration approach is bounded — sponsors choose from the offered axes, they do not edit *Questionnaire* content — which preserves the change-control discipline established in the foundation requirement.

*End* *Sponsor Questionnaire Configuration* | **Hash**: 1dab5997

## DIARY-PRD-questionnaire-submission-control: Data Submission Control

**Level**: PRD | **Status**: Draft | **Implements**: -
**Refines**: DIARY-PRD-questionnaire-system

### Overview

Data integrity requires that the system only accepts data conforming to approved, predefined structures. A controlled registry of approved data collection instruments ensures that unrecognized or malformed data is rejected at the point of entry, supporting *Audit Trail* integrity and validation requirements under 21 CFR Part 11.

### Assertions

A. The System SHALL maintain a controlled list of approved **Questionnaire** definitions.

B. The System SHALL reject any data *Submission* that does not conform to an approved **Questionnaire** definition.

### Rationale

A clinical *Trial*'s evidence chain begins at the data-ingest boundary: every *Submission* that reaches the *Sponsor* portal or **Rave EDC** must be traceable to an approved **Questionnaire** definition, because data that does not conform to a known instrument has no defensible interpretation and corrupts the *Trial*'s analyzability. The controlled registry is the platform's enforcement point — submissions are matched against it at the point of entry and rejected if they do not conform, so malformed or unrecognized data never enters the data store. This is a structural prerequisite for 21 CFR Part 11 *Audit Trail* integrity: every data point in the *Audit Trail* must reference a definition that existed at the time the data was submitted.

*End* *Data Submission Control* | **Hash**: 7642d0e2

## DIARY-PRD-questionnaire-change-control: Questionnaire Change Control

**Level**: PRD | **Status**: Draft | **Implements**: -
**Refines**: DIARY-PRD-questionnaire-system

### Overview

Questionnaires must stay the same throughout an active *Trial* so the data remain consistent and traceable. Any updates must follow a formal change process to protect the integrity of the system.

### Assertions

A. The System SHALL use predefined **Questionnaires** for all data collection.

B. The System SHALL NOT allow **Questionnaires** to be created, modified, or deleted during *Trial* operation. If any new **Questionnaire** is required, a new **Questionnaire Type** will be implemented. Modifications for an existing **Questionnaire** will follow the process outlined in the below two assertions.

C. Changes to **Questionnaires** SHALL be subject to formal change control procedures before release.

D. The System SHALL maintain backward compatibility to allow viewing of data collected with previous **Questionnaire** versions.

### Rationale

Mid-*Trial* **Questionnaire** changes would silently alter the meaning of the data being collected: a question reworded between Day 30 and Day 60 of a *Participant*'s enrollment produces two non-comparable answer streams under the same instrument name. The change-control discipline encoded here prevents that class of error by treating every **Questionnaire** modification as a deliberate engineering act subject to review and approval. The new-*Questionnaire*-Type rule (rather than in-place edit) keeps the data semantics for any given **Questionnaire Type** stable for the lifetime of any *Trial* that uses it. Backward-compatible viewing is essential because trials regularly span multiple **Questionnaire** versions when long-running studies adopt updated instruments part-way through; reviewers must be able to inspect historical data captured under the previous version without that data being silently re-interpreted under the new version's rules.

*End* *Questionnaire Change Control* | **Hash**: b8f507d9
