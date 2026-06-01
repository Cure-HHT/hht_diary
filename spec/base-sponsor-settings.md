# DIARY-BASE-sponsor-requested-settings: Portal-Requested Settings Are Applied, Locked, and Observable

**Level**: BASE | **Status**: Draft | **Implements**: -
**Refines**: DIARY-PRD-mobile-offline-first

## Overview

A *Sponsor* cannot enforce settings on a *Participant*'s device. It *requests* them; the *Diary* applies a requested setting through the same path a *Participant* uses, records the result as events, and locks the setting so the *Participant* cannot change it while participating. The *Participant* still sees the locked value, read-only, and the portal observes compliance from the synced event stream rather than by controlling the device. When the *Participant* is no longer participating, *Sponsor*-applied settings unlock. This behavior is authored at the BASE level because it is real, traceable product behavior that a *Sponsor* may opt to exclude from its own requirements documentation set.

## Assertions

A. The System SHALL apply a *Sponsor* settings request through the same settings-apply path a *Participant* uses, producing settings events.

B. The System SHALL record a *Sponsor*-applied setting with its source identified as the *Sponsor* and in a locked state.

C. While a setting is locked, the interface SHALL NOT permit the *Participant* to change it.

D. The System SHALL keep a locked setting visible to the *Participant* in a read-only state rather than hidden.

E. When the *Participant* is marked not participating in the linked study, the System SHALL unlock *Sponsor*-applied settings.

F. The System SHALL keep settings state reconstructible from the event log, holding no authoritative state outside it.

## Rationale

The device is the *Participant*'s, so a *Sponsor*'s settings are a request, not an enforcement: the honest model is that the *Diary* applies the request locally through the same code path a *Participant* uses and records what it did as events, which the portal then reads to judge compliance. Marking the source as *Sponsor* and locking the setting distinguishes a *Sponsor*-imposed value from a *Participant*'s own choice and prevents the *Participant* from overriding it during participation, while showing the value read-only keeps the *Participant* informed rather than confused by a silently-hidden control. Unlocking on end-of-participation returns control to the *Participant* once the study's claim on the device ends. Keeping all settings state in the event log means there is one reconstructible source of truth, consistent with the platform's correctness guardrail.

*End* *Portal-Requested Settings Are Applied, Locked, and Observable* | **Hash**: a8de6e0a
