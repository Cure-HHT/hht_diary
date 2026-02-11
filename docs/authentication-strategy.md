# A Risk-Based Authentication Strategy for Early-Phase BYOD ePRO Applications: The Cure HHT Tracker

## Executive Summary

For this study, the primary regulatory risk considered in the design of the Cure HHT Tracker relates to data validity for acute epistaxis event capture. The Cure HHT Tracker already enforces device-level authentication and a one-device–per-subject binding at the backend. Adding application-level authentication would not materially improve access control, but would introduce a foreseeable risk of delayed, missed, or retrospective event recording. From a Sponsor-risk perspective, that tradeoff increases, rather than decreases, regulatory exposure.

This document describes the authentication and access-control approach used by the **Cure HHT Tracker**, a Bring Your Own Device (BYOD) ePRO application designed to support clinical research in hereditary hemorrhagic telangiectasia (HHT). The primary purpose of the application is to capture epistaxis (nosebleed) events as close to real time as possible in real-world settings.

The Cure HHT Tracker employs a risk-based design in which **mandatory device-level locking**, enforced by the mobile operating system, serves as the primary technical access control. In its current implementation, a subject can unlock their device using biometric authentication, launch the application, and record the onset of a nosebleed in under **10 seconds**. This interaction flow was selected to support contemporaneous recording of acute events while maintaining appropriate access control.

This paper documents the regulatory rationale for this approach, describes how it supports FDA expectations for data integrity and user attribution in early-phase studies, and summarizes relevant human-factors evidence informing the design. The intended audience is FDA compliance consultants, quality professionals, and clinical technology reviewers evaluating the Cure HHT Tracker for early-phase use.

---

## 1. Regulatory Context and Scope

The authentication and access-control approach described in this document was informed by applicable FDA regulations and guidance, including 21 CFR Part 11 (Electronic Records; Electronic Signatures), FDA guidance on Electronic Source Data in Clinical Investigations, and ICH E6(R2) Good Clinical Practice. These frameworks emphasize protection of electronic records, reliable user attribution, auditability, and the application of controls commensurate with system risk and intended use.

Within this regulatory context, the Cure HHT Tracker has been designed to support exploratory data collection related to epistaxis events in early-phase clinical studies. The access-control mechanisms described herein reflect a risk-based design determination aligned with this intended use.

As part of a lifecycle approach to system development and validation, authentication controls, procedural safeguards, and technical features will be re-assessed prior to use in later-phase or registrational studies, with additional controls implemented as appropriate to the evolving risk profile.

---

## 2. Reframing the Question: Authentication and Identity Assurance

In ePRO system design, *authentication* and *identity assurance* address related but distinct questions.

- **Authentication** addresses whether a user can access the system.
- **Identity assurance** addresses who entered the data.

Application-level login mechanisms primarily address authentication. In clinical research settings, identity assurance is additionally supported through procedural, operational, and contextual controls. This distinction is relevant when evaluating the necessity and proportionality of technical authentication mechanisms in early-phase BYOD deployments.

---

## 3. Device-Level Locking as a Primary Technical Control

Modern mobile operating systems provide hardware-backed authentication mechanisms, including biometric and PIN-based unlocking, which are enforced consistently at the device level across all applications. These mechanisms are integrated with secure hardware components and are not dependent on application-specific implementations.

The Cure HHT Tracker requires that device-level authentication be enabled and validates the presence of an active lock screen at application launch and during runtime. Use of the application is prevented if device-level authentication is disabled. This establishes a baseline access-control standard across BYOD devices without introducing additional authentication steps within the application itself.

---

## 4. Device-Level Locking as a Primary Access Control

The Cure HHT Tracker relies on mandatory device-level authentication, enforced by the mobile operating system, as its primary technical access control. A risk-based assessment was performed to evaluate whether additional application-level authentication would materially improve access control for the intended use of the system.

For this use, device-level authentication and application-level authentication would address the same access vector—casual or opportunistic access to the device. Consistent with the canonical risk–tradeoff rationale described in the Executive Summary, application-level authentication was evaluated and not implemented due to its adverse impact on timely capture of acute epistaxis events relative to its limited incremental access-control benefit beyond enforced device-level locking.

Based on the intended use of the Cure HHT Tracker, the exploratory nature of the data collected, and the emphasis on contemporaneous event recording, enforced device-level locking was determined to provide access control appropriate to the intended use of the system for this phase. Authentication controls will be re-evaluated and may be augmented for later-phase or registrational studies as part of the system’s lifecycle risk management activities.

---

## 5. Human Factors and Data Integrity

FDA guidance emphasizes data quality and reliability over formalistic control implementations. For clinical studies involving acute or episodic events, timely data capture is an important contributor to data integrity.

Published mobile health and ecological momentary assessment (EMA) studies report that interaction burden, platform characteristics, and timing of prompts influence compliance and data completeness in real-time data capture contexts. These effects are particularly relevant when events occur unexpectedly or outside controlled settings, as is common for acute epistaxis events.² ³

Consistent with these findings, the Cure HHT Tracker was designed to minimize the number of steps required to record an epistaxis event. In its current implementation, a subject can unlock their device using biometric authentication, launch the application, and record the onset of a nosebleed in under 10 seconds. This design is intended to support contemporaneous recording and reduce reliance on delayed or retrospective entry.

Longitudinal mobile health studies report a gradual decline in engagement over time, underscoring the importance of minimizing avoidable interaction burden to maintain data completeness over the duration of an early-phase study.⁴

---

## 6. Identity Assurance Through Procedural and Contextual Controls

Identity assurance for data collected using the Cure HHT Tracker is supported through a combination of technical, procedural, and contextual controls.

From a technical perspective, the application generates a unique device-specific identifier (UUID) at installation. This identifier is stored in hardware-secured device memory and is not accessible to other applications. During initial study setup, the application also obtains a server-issued token derived from a one-time code. The UUID and server-issued token are used together to authenticate data submissions to the backend system.

This mechanism enforces a one-to-one association between a subject and a single device for the duration of the study. Data submissions from additional installations or devices are rejected by the server, preventing the same subject from linking multiple devices to the study.

In addition to these technical controls, identity assurance can be supported through procedural and contextual measures implemented by the Sponsor or its designated CRO, depending on the study design. These may include subject identity verification at enrollment, explicit prohibition of device sharing, subject training and attestation, and site oversight. The Cure HHT Tracker captures usage metadata and timestamps and makes these data available to support sponsor- or CRO-led monitoring and review activities. The system provides technical features and audit data that enable Sponsor- or CRO-led user attribution activities consistent with the intended use and risk profile of the system.

---

## 7. Alignment With Risk-Based Validation Principles

GAMP 5 supports tailoring controls to system risk and intended use. For early-phase BYOD ePRO systems, from a system design perspective, the primary risks addressed relate to missing, delayed, or poor-quality data rather than malicious system access.

Accordingly, validation and security controls for the Cure HHT Tracker prioritize reliability, usability, and consistency, with mandatory device-level locking and procedural controls selected to align with this risk profile.

---

## 8. Anticipating FDA Inspection Questions

A defensible system design requires both appropriate controls and clear documentation of the rationale for those controls. Examples of anticipated inspection questions include:

**Why is application-level authentication not implemented?**  
Application-level authentication was evaluated and not implemented based on the canonical risk–tradeoff rationale described in the Executive Summary. For this study, the design rationale prioritizes support for timely and complete capture of acute epistaxis events, and application-level authentication was assessed as increasing the risk of delayed, missed, or retrospective recording without a commensurate access-control benefit beyond enforced device-level locking.

**How is user attribution supported?**  
User attribution is supported through enrollment verification, subject training, device–subject pairing, procedural controls, and ongoing data review.

**Would this approach be appropriate for later-phase studies?**  
Authentication and access-control mechanisms would be re-evaluated and augmented as appropriate prior to use in later-phase or registrational studies.

---



## 9. Conclusion

For early-phase BYOD use, mandatory device-level locking provides a proportionate primary access control consistent with the intended use of the system for the Cure HHT Tracker. When combined with documented procedural and monitoring controls, this approach supports data integrity and user attribution while minimizing avoidable barriers to timely data capture.

The goal of regulatory compliance is not maximal control, but appropriate control aligned with system risk and intended use. The design described in this document reflects that principle.

---



## References

1. FDA. *Electronic Source Data in Clinical Investigations*; ISPE. *GAMP 5: A Risk-Based Approach to Compliant GxP Computerized Systems*, Second Edition.
2. Wen CKF et al. *Contextual Factors Influencing Compliance With Ecological Momentary Assessment in Mobile Health Studies.* JMIR mHealth and uHealth, 2025.
3. Shiffman S, Stone AA, Hufford MR. *Ecological Momentary Assessment.* Annual Review of Clinical Psychology, 2008.
4. Jones SM et al. *Design and Implementation Considerations for Electronic Patient-Reported Outcome Measures in Clinical Research.* JMIR Journal of Patient-Reported Outcomes, 2025.

---

*Document version: v1.0 | Date: 9 Feb 2026*

