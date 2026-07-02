# DIARY-BASE-questionnaires: Questionnaires

**Level**: BASE | **Status**: Draft | **Implements**: -
**Refines**: DIARY-BASE-compliant-diary-platform

## Overview

The pillar covering *Questionnaire*s and their full lifecycle: definition, versioning, assignment, *Participant* completion, and scoring. A *Questionnaire* may be a validated instrument, an informal survey, or an instrument undergoing validation — the system administers all of them through the same lifecycle. *Questionnaire* handling spans both the portal (definition, assignment, review) and the *Mobile Application* (completion), and must behave consistently across them. The specific instruments, assignment rules, versioning model, and scoring algorithms refine this pillar.

## Assertions

A. The System SHALL administer *Questionnaire*s through their lifecycle — definition, versioning, assignment, completion, and scoring — regardless of whether a given *Questionnaire* is a validated instrument, an informal survey, or undergoing validation.

B. *Questionnaire* definition and scoring SHALL behave consistently across the portal and the *Mobile Application* for a given *Questionnaire* version.

## Rationale

Questionnaires are a primary structured-data input the *Trial* depends on, so their integrity across versions and across surfaces is a correctness obligation: a given *Questionnaire* version must mean the same thing wherever it is presented or scored. Treating questionnaires as a pillar lets the instruments, assignment rules, and scoring all inherit that consistency obligation. The pillar is deliberately agnostic to validation status — a validated instrument, an informal survey, and an instrument mid-validation are all served by the same machinery; whether a particular *Questionnaire* is validated is a property of that *Questionnaire*, not of the system.

*End* *Questionnaires* | **Hash**: 1c3f421a
