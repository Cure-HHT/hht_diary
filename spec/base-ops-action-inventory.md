# DIARY-BASE-ops-action-inventory: Operations Action Inventory

**Level**: BASE | **Status**: Draft | **Implements**: -
**Refines**: DIARY-BASE-audit-trail

## Assertions

A. The System SHALL enforce *Role*-based access control for every operations *Action* in this inventory, identically to the *Sponsor* *Action* Inventory.

B. The System SHALL recognize the following operations Actions: *Unwedge* EDC Synchronization (ACT-OPS-001), Create System Operator (ACT-OPS-002), and Create *Administrator* (ACT-OPS-003).

C. The System SHALL restrict each operations *Action* to the roles granted its permission, and SHALL record an authorization denial as an event when an unpermitted *Role* attempts it.

## Rationale

Some platform operations are privileged and audited but are not part of any *Sponsor*'s *Action* set: restoring a wedged EDC (RAVE) synchronization queue, and provisioning the most-privileged account types (System Operator, *Administrator*). Cataloguing them here — at the BASE level, *Sponsor*-excludable — keeps the *Sponsor*-facing `DIARY-PRD-action-inventory` focused on operations while still giving every operations capability a stable, named, access-controlled *Action* id.

Realizing these as Actions (rather than as bespoke privileged endpoints) means each is parsed, validated, authorized, executed, and recorded through the one dispatch path, so "who restored the sync queue, when, and was it permitted" is reconstructable from the same *Audit Trail* as every operation. ACT-OPS-002 and ACT-OPS-003 split account provisioning by the privilege of the account created: an *Administrator* provisions Administrators (ACT-OPS-003) and roles, while only a System Operator provisions other System Operators (ACT-OPS-002). This encodes the account-creation authority ladder as ordinary permissions.

*End* *Operations Action Inventory* | **Hash**: a1baca2c
