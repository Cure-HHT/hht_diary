# DIARY-PRD-configuration-precedence: Configuration Precedence

**Level**: PRD | **Status**: Draft | **Implements**: - | **Template**

## Overview

The platform defines a baseline set of behaviors and default values that apply to every study. Each *Sponsor* may, where the platform requirement explicitly permits configuration, override those defaults with values appropriate to that study's protocol. This requirement establishes the precedence rule that resolves any apparent conflict between a platform requirement and a *Sponsor* configuration: when both apply to the same behavior, the *Sponsor* configuration governs. The rule is structural — it ensures that *Sponsor*-specific values such as thresholds, reason lists, reminder times, and enabled features take effect deterministically without requiring each individual platform requirement to restate the precedence relationship. The rule applies only within the bounds set by the platform requirement itself; *Sponsor* configuration cannot grant capabilities the platform does not expose, and cannot override platform behavior that is not declared as configurable.

## Definitions

**Platform Requirement**: A requirement that defines behavior, structure, or default values applicable to every study of the **System**. Identified by a requirement ID prefixed with `DIARY-PRD-` or `DIARY-GUI-`.

**Sponsor Configuration Requirement**: A requirement that specifies the values applied to a configurable parameter exposed by a **Platform Requirement** for a specific study. Identified by a requirement ID in the *Sponsor*'s own configuration namespace, with a distinct namespace prefix per *Sponsor*.

**Configurable Parameter**: A value, threshold, list, label, enablement flag, or option that a **Platform Requirement** explicitly declares as configurable per study.

**Configuration Conflict**: A state in which a **Sponsor Configuration Requirement** specifies a value for a **Configurable Parameter** that differs from the default value or behavior described in the corresponding **Platform Requirement**.

## Assertions

A. The **System** SHALL apply the value specified in a **Sponsor Configuration Requirement** in place of the default value or behavior described in the corresponding **Platform Requirement** when a **Configuration Conflict** exists.

B. The **System** SHALL apply a **Sponsor Configuration Requirement** only to a **Configurable Parameter** that is explicitly declared as configurable by a **Platform Requirement**.

C. The **System** SHALL NOT permit a **Sponsor Configuration Requirement** to override behavior of a **Platform Requirement** that is not declared as configurable.

D. The **System** SHALL NOT permit a **Sponsor Configuration Requirement** to grant a capability that is not defined by a **Platform Requirement**.

E. When no **Sponsor Configuration Requirement** exists for a given **Configurable Parameter**, the **System** SHALL apply the default value or behavior described in the corresponding **Platform Requirement**.

F. When a **Platform Requirement** specifies that a behavior takes effect only if a corresponding **Configurable Parameter** is configured, and no **Sponsor Configuration Requirement** configures it, the **System** SHALL NOT apply that behavior.

## Rationale

A multi-*Sponsor* platform must absorb deployment-specific differences (reason lists, reminder cadences, lock thresholds, enabled feature flags) without forking the codebase or rewriting platform requirements per *Sponsor*. The conventional pattern — a single config file silently overrides defaults — is unsuitable for an FDA-regulated platform because it loses traceability: when a behavior is wrong in production, the auditor cannot reconstruct from the requirements which value the *Sponsor* actually configured and why. This requirement encodes a structural precedence rule so every *Sponsor* overlay (each in its own *Sponsor*-namespaced requirement) becomes a first-class, citable artifact. The two-way containment — *Sponsor* configuration cannot exceed the platform's exposed configurability, and cannot grant capabilities the platform does not implement — keeps the platform requirements authoritative for the set of behaviors that exist at all, and keeps *Sponsor* requirements authoritative for the specific values within that set. The absence-of-configuration rules (E, F) make the default-vs-opt-in semantics explicit so that a missing *Sponsor* requirement is never ambiguous.

*End* *Configuration Precedence* | **Hash**: f5372beb
