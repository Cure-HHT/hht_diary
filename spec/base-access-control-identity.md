# DIARY-BASE-access-control-identity: Access Control and Identity

**Level**: BASE | **Status**: Draft | **Implements**: -
**Refines**: DIARY-BASE-compliance-data-integrity

## Overview

The cross-cutting authentication and authorization foundation that governs every surface of the platform: portal staff credentials, second factors, and sessions; the participant's on-device authentication; and the customizable role-based access control that decides which actions each actor may perform. Because the same access-control patterns recur on both the portal and the *Mobile Application*, the reusable contracts here are intended to be expressed as templates that the *Diary*- and portal-side requirements satisfy, rather than duplicated. This requirement sits under Compliance and Data Integrity because access control is a core 21 CFR Part 11 control.

## Assertions

A. The System SHALL authenticate every actor before granting access and SHALL authorize every access-controlled *Action* against the actor's *Role*, failing closed when authority cannot be established.

B. Access control SHALL be governed by a customizable *Role* model applied consistently across the portal and the *Mobile Application*.

## Rationale

Authentication and authorization are the gate in front of all clinical data, so they belong to compliance rather than to any one feature, and they must fail closed: absence of established authority denies access rather than allowing it. Stating the *Role* model as a single customizable foundation — reused via templates across surfaces — keeps the access rules consistent and lets a contract be written once and satisfied everywhere it applies.

*End* *Access Control and Identity* | **Hash**: af73cdd0
