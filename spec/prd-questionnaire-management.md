# Questionnaire Management

This file groups the platform-side requirements that establish the **Questionnaire** system: the clinical questionnaire foundation, sponsor-specific configuration surfaces, the controlled submission gate that enforces approved structures, and the change-control discipline that keeps questionnaires stable within a trial. Sponsor-specific workflows (Start Trial, NOSE HHT and HHT-QoL administration, cycle tracking, session timing) live in the corresponding `hht_diary_callisto` file (`spec/prd-questionnaire-management.md`) and reference the foundation defined here.

## DIARY-PRD-questionnaire-system: Clinical Questionnaire System

**Level**: prd | **Status**: Legacy | **Implements**: -

### Overview

Clinical trials use structured questionnaires to collect reliable data in a consistent and compliant way. The questionnaires are carefully built to ensure accuracy and a good participant experience. New questionnaires can be added as needed, and the content always comes from approved documents, not edited directly in the app. This requirement is the foundation that all other questionnaire-handling requirements refine.

### Definitions

**Questionnaire**: A validated data collection instrument presented to a participant to capture self-reported clinical outcomes at protocol-defined points in a clinical trial.

**Questionnaire Type**: A named category of **Questionnaire**. Each **Questionnaire Type** is implemented as an individual coded component.

**Trial Start**: The event that formally begins a participant's active trial participation. The trigger and label for **Trial Start** are sponsor-configurable.

**Completion Status**: The current state of a **Questionnaire** instance for a given participant. Valid values are defined per **Questionnaire** workflow.

**Diary Data Synchronization**: The continuous transmission of participant diary entries from the participant's mobile application to the **Sponsor Portal** and **Rave EDC**.

**Questionnaire Display Name**: The participant-facing name of a **Questionnaire** as presented in the mobile application. Distinct from the instrument name used for internal identification and clinical reference.

**Trial**: A clinical study conducted under a Sponsor's protocol in which **Participants** are enrolled to capture self-reported clinical outcomes through the **Mobile Application**. The **Trial** begins at **Trial Start**.

### Assertions

**Questionnaire Registry**

A. The System SHALL allow implementation of multiple **Questionnaire Types**, each as an individual coded component.

B. The System SHALL track **Completion Status** for each **Questionnaire** instance.

**Data Synchronization**

C. The System SHALL activate **Diary Data Synchronization** upon **Trial Start**.

D. The System SHALL deactivate **Diary Data Synchronization** when a participant is disconnected or is marked as Not Participating.

**Configuration**

E. The System SHALL support sponsor-configurable configuration of the trigger and workflow that activates **Trial Start**.

F. Each **Questionnaire** SHALL have a **Questionnaire Display Name**.

### Rationale

The questionnaire subsystem is the principal source of trial-grade clinical data in the platform, and its design choices reflect that role. Implementing each **Questionnaire Type** as an individual coded component is a defense against ad hoc clinical content: every questionnaire that ships is a deliberate engineering artifact reviewed against an approved source document, not a configuration table that a sponsor could edit without change control. **Completion Status** tracking is the foundation for the workflow rules that govern how a questionnaire moves from sent to answered to finalized; without per-instance status the platform could not distinguish "answered but not finalized" from "answered and locked", which is a clinical and regulatory distinction. **Trial Start** is the gate at which **Diary Data Synchronization** activates because pre-trial diary data is participant-private and must not be promoted to the sponsor portal or Rave EDC until the sponsor has acknowledged that the participant is in trial; making the trigger sponsor-configurable keeps the platform protocol-neutral.

*End* *Clinical Questionnaire System* | **Hash**: 306eeb1a

## DIARY-PRD-questionnaire-sponsor-configuration: Sponsor Questionnaire Configuration

**Level**: prd | **Status**: Legacy | **Implements**: -
**Refines**: DIARY-PRD-questionnaire-system

### Overview

A configuration-driven approach allows the sponsor to tailor questionnaire behavior to their study protocol without requiring platform code changes, ensuring that mid-study modifications are managed deliberately and do not unintentionally affect data collection.

### Assertions

A. The System SHALL support sponsor-specific configuration of which **Questionnaires** are enabled per deployment.

B. The System SHALL support sponsor-specific configuration of participant reminder behavior for each enabled **Questionnaire**.

C. The System SHALL support sponsor-specific configuration of the processing steps that occur between participant submission and **Rave EDC** synchronization for each **Questionnaire**.

D. The System SHALL support sponsor-specific configuration of whether a participant may edit their answers after submission and under what conditions.

E. The System SHALL support sponsor-specific configuration of which languages are enabled per **Questionnaire**.

### Rationale

The five configuration axes named here — enablement, reminder behavior, post-submission processing, post-submission editability, and language — are the dimensions along which clinical protocols typically vary between sponsors using the same underlying **Questionnaire Type**. Encoding them as sponsor configuration rather than platform code keeps the platform's questionnaire library stable across deployments while letting each sponsor express the protocol-specific decisions that their IRB and operations teams require. The configuration approach is bounded — sponsors choose from the offered axes, they do not edit questionnaire content — which preserves the change-control discipline established in the foundation requirement.

*End* *Sponsor Questionnaire Configuration* | **Hash**: 1c0e5f61

## DIARY-PRD-questionnaire-submission-control: Clinical Data Submission Control

**Level**: prd | **Status**: Legacy | **Implements**: -
**Refines**: DIARY-PRD-questionnaire-system

### Overview

Clinical data integrity requires that the system only accepts data conforming to approved, predefined structures. A controlled registry of approved data collection instruments ensures that unrecognized or malformed data is rejected at the point of entry, supporting audit trail integrity and validation requirements under 21 CFR Part 11.

### Assertions

A. The System SHALL maintain a controlled list of approved **Questionnaire** definitions.

B. The System SHALL reject any data submission that does not conform to an approved **Questionnaire** definition.

### Rationale

A clinical trial's evidence chain begins at the data-ingest boundary: every submission that reaches the sponsor portal or **Rave EDC** must be traceable to an approved **Questionnaire** definition, because data that does not conform to a known instrument has no defensible interpretation and corrupts the trial's analyzability. The controlled registry is the platform's enforcement point — submissions are matched against it at the point of entry and rejected if they do not conform, so malformed or unrecognized data never enters the data store. This is a structural prerequisite for 21 CFR Part 11 audit trail integrity: every data point in the audit trail must reference a definition that existed at the time the data was submitted.

*End* *Clinical Data Submission Control* | **Hash**: 62ccbb18

## DIARY-PRD-questionnaire-change-control: Questionnaire Change Control

**Level**: prd | **Status**: Legacy | **Implements**: -
**Refines**: DIARY-PRD-questionnaire-system

### Overview

Questionnaires must stay the same throughout an active trial so the data remain consistent and traceable. Any updates must follow a formal change process to protect the integrity of the system.

### Assertions

A. The System SHALL use predefined **Questionnaires** for all clinical data collection.

B. The System SHALL NOT allow **Questionnaires** to be created, modified, or deleted during trial operation. If any new **Questionnaire** is required, a new **Questionnaire Type** will be implemented. Modifications for an existing **Questionnaire** will follow the process outlined in the below two assertions.

C. Changes to **Questionnaires** SHALL be subject to formal change control procedures before deployment.

D. The System SHALL maintain backward compatibility to allow viewing of data collected with previous **Questionnaire** versions.

### Rationale

Mid-trial **Questionnaire** changes would silently alter the meaning of the data being collected: a question reworded between Day 30 and Day 60 of a participant's enrollment produces two non-comparable answer streams under the same instrument name. The change-control discipline encoded here prevents that class of error by treating every **Questionnaire** modification as a deliberate engineering act subject to review and approval. The new-Questionnaire-Type rule (rather than in-place edit) keeps the data semantics for any given **Questionnaire Type** stable for the lifetime of any trial that uses it. Backward-compatible viewing is essential because trials regularly span multiple **Questionnaire** versions when long-running studies adopt updated instruments part-way through; reviewers must be able to inspect historical data captured under the previous version without that data being silently re-interpreted under the new version's rules.

*End* *Questionnaire Change Control* | **Hash**: e1e119e4
