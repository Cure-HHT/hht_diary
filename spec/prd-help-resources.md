# DIARY-PRD-help-resources: Help and Resources

**Level**: PRD | **Status**: Draft | **Implements**: -
**Refines**: DIARY-BASE-mobile-diary-application

## Overview

The **Sponsor Portal** provides users with access to in-portal help materials including video tutorials, frequently asked questions, an interactive guided tour, and a downloadable *User* guide. The materials surfaced are *Role*-aware so that each *User* is presented with content relevant to their responsibilities. The detailed inventory of materials, tour content, and FAQ entries is maintained in internal documentation; this requirement defines only the platform-level expectation that the help affordance exists and is available to all **Sponsor Portal** roles.

## Definitions

**Help and Resources**: The collection of in-portal help materials available to **Sponsor Portal** users, comprising video tutorials, frequently asked questions, an Interactive Tour, and a downloadable *User* guide.

**Interactive Tour**: A guided walkthrough of the **Sponsor Portal** interface presented to a *User* on first login and replayable on demand from **Help and Resources**.

## Assertions

**Availability**

A. The **System** SHALL make **Help and Resources** available to every **Administrator**, **Clinical Research Associate**, and **Study Coordinator** from any screen of the **Sponsor Portal**.

**Content**

B. The **System** SHALL present **Help and Resources** content scoped to the *User*'s active **Role**.

C. **Help and Resources** SHALL include video tutorials, frequently asked questions, the **Interactive Tour**, and a downloadable *User* guide.

**Interactive Tour**

D. The **System** SHALL present the **Interactive Tour** to a *User* on their first successful login to the **Sponsor Portal**.

E. The **System** SHALL allow a *User* to replay the **Interactive Tour** on demand from **Help and Resources**.

## Rationale

Staff using the **Sponsor Portal** are not full-time users of the system — they engage with it intermittently during their *Participant*-facing workday. In-portal, always-available help is essential to keep training overhead low and to support correct use without external documentation lookups. *Role*-aware content keeps each *User*'s help surface focused on what they can actually do (a *Study Coordinator* should not have to filter through *Administrator* topics, and vice versa). The **Interactive Tour** on first login bootstraps new users into the portal's primary surfaces; replayability supports occasional refreshers without rerunning onboarding. This requirement deliberately defines only the affordance and the major content categories — the precise tour script, FAQ entries, and tutorial inventory are operational artifacts maintained in internal documentation, since they evolve continuously with the product.

*End* *Help and Resources* | **Hash**: caeb1334
