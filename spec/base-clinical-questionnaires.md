# DIARY-BASE-clinical-questionnaires: Clinical Questionnaire System

**Level**: BASE | **Status**: Draft | **Implements**: -
**Refines**: DIARY-BASE-compliant-diary-platform

## Overview

The pillar covering clinically-validated *Questionnaire* instruments and their full lifecycle: definition, versioning, assignment, *Participant* completion, and scoring. *Questionnaire* handling spans both the portal (definition, assignment, review) and the *Mobile Application* (completion), and must behave consistently across them. The specific instruments, assignment rules, versioning model, and scoring algorithms refine this pillar.

## Assertions

A. The System SHALL administer clinically-validated *Questionnaire* instruments through their lifecycle — definition, versioning, assignment, completion, and scoring.

B. *Questionnaire* definition and scoring SHALL behave consistently across the portal and the *Mobile Application* for a given instrument version.

## Rationale

Questionnaires are the structured clinical measurements the *Trial* depends on, so their integrity across versions and across surfaces is a correctness obligation: a given instrument version must mean the same thing wherever it is presented or scored. Treating the *Questionnaire* system as a pillar lets the instruments, assignment rules, and scoring all inherit that consistency obligation.

*End* *Clinical Questionnaire System* | **Hash**: 621cfd03
