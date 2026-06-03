# DIARY-BASE-system-operator-role: System Operator Role

**Level**: BASE | **Status**: Draft | **Implements**: -
**Refines**: DIARY-PRD-rbac-customizable

## Assertions

A. The System SHALL recognize a System Operator *Role* for platform operations that are not part of any *Sponsor*'s clinical workflow.

B. The System Operator *Role* SHALL be excluded from all *Participant*-facing and clinical *Action* permissions.

C. Every System Operator capability SHALL be exercised as a dispatched, permission-gated, audited *Action*, not as an unaudited side-channel endpoint.

## Rationale

The System Operator is the platform-operations *Role* (the current name of the *Role* previously labelled "Developer Admin" in operational tooling and in `DIARY-OPS-rave-unwedge-authz`). It owns recovery and platform-administration capabilities — restoring a wedged EDC synchronization queue, provisioning other System Operators, and provisioning Administrators — that have no place in a *Sponsor*'s clinical-staff *Role* set. It is authored at the BASE level because it is platform-internal: a *Sponsor* may exclude it from their own requirements documentation, while the platform always recognizes it.

The *Role* carries no *Participant*-facing or clinical permission (assertion B): it cannot view, link, or survey *Participants*, because those are *Sponsor* clinical operations bound to RAVE-assigned sites, not platform operations. Every capability the *Role* does hold is realized as an *Action* dispatched through the same authorization and *Audit Trail* path as every other *Action* (assertion C); there are no privileged endpoints outside the dispatch model. This keeps the operational surface narrow, uniformly audited under *FDA 21 CFR Part 11*, and extensible by adding an *Action* plus a permission rather than new infrastructure.

*End* *System Operator Role* | **Hash**: e9d3432f
