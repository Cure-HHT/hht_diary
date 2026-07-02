# DIARY-BASE-mobile-diary-application: Participant Mobile Diary Application

**Level**: BASE | **Status**: Draft | **Implements**: -
**Refines**: DIARY-BASE-compliant-diary-platform

## Overview

The participant-facing pillar of the platform: a *Mobile Application* through which an enrolled *Participant* records their daily *Diary*. It functions *Offline-First* — capture never depends on connectivity — and reconciles its data when connectivity returns. The application presents only the participant's own data and the study surfaces relevant to their participation. The specific entry rules, instruments, and on-device experiences refine this pillar.

## Assertions

A. The System SHALL provide a participant-facing *Mobile Application* for daily *Diary* capture that functions offline and reconciles recorded data when connectivity returns.

B. The *Mobile Application* SHALL present to a *Participant* only their own data and the study surfaces relevant to their participation.

## Rationale

An eDiary is only trustworthy if a *Participant* can record an event the moment it happens, regardless of network state, so *Offline-First* capture with later reconciliation is foundational rather than an optimization. Scoping the application to the participant's own data keeps the device a personal instrument and avoids exposing other participants' information, consistent with the platform's isolation and privacy obligations.

*End* *Participant Mobile Diary Application* | **Hash**: a4ac9b0b
