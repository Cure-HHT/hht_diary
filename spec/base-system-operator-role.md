# DIARY-BASE-system-operator-role: System Operator Role

**Level**: BASE | **Status**: Draft | **Implements**: -
**Refines**: DIARY-PRD-rbac-customizable

## Rationale

The System Operator is the platform-operations *Role* (the current name of the *Role* previously labelled "Developer Admin" in operational tooling and in `DIARY-OPS-rave-unwedge-authz`). It owns recovery and platform-administration capabilities — restoring a wedged EDC synchronization queue, provisioning other System Operators, and provisioning Administrators — that have no place in a *Sponsor*'s staff *Role* set. It is authored at the BASE level because it is platform-internal: a *Sponsor* may exclude it from their own requirements documentation, while the platform always recognizes it.

The *Role* carries no *Participant*-facing or clinical permission (assertion B): it cannot view, link, or survey *Participants*, because those are *Sponsor* operations bound to RAVE-assigned sites, not platform operations. Every capability the *Role* does hold is realized as an *Action* dispatched through the same authorization and *Audit Trail* path as every other *Action* (assertion C); there are no privileged endpoints outside the dispatch model. This keeps the operational surface narrow, uniformly audited under *FDA 21 CFR Part 11*, and extensible by adding an *Action* plus a permission rather than new infrastructure.

## Assertions

D. A **User Account** holding the System Operator *Role* SHALL be modified or deactivated only by a requester that also holds the System Operator *Role*.

*End* *System Operator Role* | **Hash**: b876db52
