# DIARY-BASE-linking-history: Mobile Linking Status and History

**Level**: BASE | **Status**: Draft | **Implements**: -
**Refines**: DIARY-BASE-participant-lifecycle

## Overview

A *Participant*'s visibility into their own data-sharing relationships: the current link status for each active link, plus a history of every system the *Mobile Application* has ever shared data with. This supports participants who join multiple studies over time or whose link state changes through device loss, reconnection, or study completion, and it makes the participant's record of data-sharing relationships explicit. A *Sponsor* may configure which history fields are shown.

## Assertions

A. The *Mobile Application* SHALL display, for each active link, the current *Linking Code* and the current link status (for example: active, pending, unreachable).

B. The *Mobile Application* SHALL provide a linking-history view that lists every system with which the application has shared data.

C. Each linking-history entry SHALL identify the *Sponsor* or system, the link start date, and the link end date where applicable.

D. Each linking-history entry SHALL show the most recent *Linking Code* associated with that link and the entry's current status (for example: active, ended, invalid *Linking Code*, unreachable).

E. The System SHALL allow a *Sponsor* to configure which linking-history fields are visible to a *Participant*.

## Rationale

A *Participant* needs to confirm independently that their link is active and to troubleshoot when it is not, and — across a research lifetime that may span several studies and devices — to see a durable record of who they have shared data with. Surfacing current status where the *Participant* already looks, and keeping a history reachable from their profile, builds trust and reduces support burden. The *Sponsor*-visibility control lets a deployment tailor how much of that history a *Participant* sees without changing the underlying record.

## Follow-up — configurability

> The visible-field set (assertion E) currently encodes the field list a
> *Sponsor* may toggle. If future deployments need a different history
> schema or field semantics, introduce a configurable seam on the
> *Sponsor*-overlay parent rather than widening this assertion.

*End* *Mobile Linking Status and History* | **Hash**: 16c508fe
