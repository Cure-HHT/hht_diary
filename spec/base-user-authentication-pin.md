# *Diary User* Authentication — In-Application *PIN* Mechanism (BASE)

## DIARY-BASE-user-authentication-pin: Diary User Authentication — In-Application PIN Mechanism

**Level**: BASE | **Status**: Draft | **Implements**: -
**Refines**: DIARY-PRD-user-authentication

### Overview

This requirement defines the **In-application PIN** as an additional **Active Authentication Path** for **Diary User Authentication**, available to studies that require a knowledge-factor alternative to **Device Authentication** and the **Application Biometric Lock**. When the **Active Authentication Path** is **In-application PIN**, the **Participant** authenticates by entering a numeric secret within the *Mobile Application*. This requirement covers initial **PIN** setup, **PIN** entry to satisfy authentication, **PIN** change from settings, lockout on repeated failed entries, and *Sponsor*-initiated **PIN Reset** for recovery.


PIN
: A numeric secret of configurable length set by the **Participant** and used to satisfy **Diary User Authentication** when the in-application **PIN** mechanism is the active path.

PIN Reset
: A *Sponsor*-initiated command that clears the **Participant**'s **PIN** and returns the **Participant** to the **PIN** setup state on next access.

Failed Attempt Threshold
: The configurable number of consecutive failed **PIN** entry attempts that triggers a **Participant** lockout pending **PIN Reset**.

### Assertions

**PIN Entry**

A. The **System** SHALL satisfy **Diary User Authentication** upon successful **PIN** entry by the **Participant**.

**PIN Setup**

B. When the **Participant** has not yet set a **PIN**, the **System** SHALL require the **Participant** to set a **PIN** before any **Participant** data is accessible.

C. The **System** SHALL require the **Participant** to enter the **PIN** twice during setup and SHALL reject the setup when the two entries do not match.

**PIN Change**

D. The **System** SHALL allow the **Participant** to change their **PIN** from the **Mobile Application** settings, after first authenticating with their existing **PIN**.

**Failed Attempts and PIN Reset**

E. The **System** SHALL track consecutive failed **PIN** entry attempts.

F. When the number of consecutive failed **PIN** entry attempts reaches the configured **Failed Attempt Threshold**, the **System** SHALL prevent **Participant** access to the **Mobile Application** until a **PIN Reset** is received.

G. The **System** SHALL accept a **PIN Reset** issued by the *Sponsor* for the **Participant** and SHALL clear the **Participant**'s **PIN**.

H. Following a **PIN Reset**, the **System** SHALL require the **Participant** to set a new **PIN** before any **Participant** data is accessible.

I. The **System** SHALL reset the failed attempt counter upon successful **PIN** entry.

**Configuration**

J. The **System** SHALL support *Sponsor*-configurable **PIN** length per study.

K. The **System** SHALL support *Sponsor*-configurable **Failed Attempt Threshold** per study.

### Rationale

The in-application **PIN** mechanism is the **Diary User Authentication** path engaged when a study enables **In-application PIN** as the **Active Authentication Path**. Because its implementation is deferred and it is not used in the initial deployment, this requirement is authored at the BASE level and excluded from the generated URS, while still defining the platform behavior for studies that adopt it. The double-entry rule at **PIN** setup catches mistyped secrets before they become a lock-out risk. The **PIN** change path is gated by re-entry of the existing **PIN** to prevent an unattended *Mobile Application* from being trivially repurposed by another person. The **Failed Attempt Threshold** bounds the brute-force surface: on reaching it, the **Participant** is held in a locked state until the *Sponsor* issues a **PIN Reset**, restoring continuity of access through a controlled, attributable channel rather than an in-application self-recovery that would re-open the brute-force surface. Failed-attempt counter reset on success prevents accumulated rare typos from compounding into a lockout over normal use. The trigger timing for **Diary User Authentication** (open, return, **Idle Timeout** of inactivity) is governed by the parent REQ and applies uniformly across paths.

*End* *Diary User Authentication — In-Application PIN Mechanism* | **Hash**: 1119836b
