# DIARY-BASE-portal-data-acceptance: Portal Data Acceptance and Rejection

**Level**: BASE | **Status**: Draft | **Implements**: -
**Refines**: DIARY-BASE-participant-lifecycle

## Overview

The portal's obligation when it receives synchronized data from a *Participant* who is not in a sync-eligible status — for example when a link is revoked mid-session, or when a device delivers offline-queued data after a disconnection. The portal validates eligibility before accepting, rejects cleanly without persisting rejected data, records the rejection for audit, and gives the device an unambiguous, dated rejection so both sides agree on the outcome and the device can later re-sync the disconnected period.

## Assertions

A. The portal SHALL validate a *Participant*'s link status before accepting any synchronized data, and SHALL reject data from a *Participant* not in a sync-eligible status.

B. The portal SHALL NOT store or persist rejected synchronized data in the clinical *Database*.

C. The portal SHALL record every rejected sync attempt in the *Audit Trail*, including the *Participant* identifier, timestamp, rejection reason, and the volume of data rejected.

D. When a link is revoked during an active sync *Session*, the portal SHALL reject the in-transit data and return a rejection response so that sender and receiver hold a consistent view of the outcome.

E. The portal's rejection response SHALL distinguish rejection from other error types and SHALL include the revocation timestamp, so the device can identify the boundary between pre-disconnection and post-disconnection entries.

F. Data successfully synced before a disconnection SHALL remain unchanged in the clinical *Database*.

G. Upon reconnection under a new valid link, the portal SHALL accept re-synced data from the disconnected period, including entries created while the *Participant* was disconnected.

## Rationale

The device stops syncing on disconnection, but data can still be in transit, queued from offline capture, or delayed by the network — leaving clinical-data handling undefined without an explicit portal-side rule. Rejecting at time of receipt, rather than silently dropping or half-accepting, gives both ends an unambiguous outcome; not persisting rejected data keeps the clinical store clean; and auditing the rejection (including volume) preserves the ALCOA+ record of what was refused and why. Returning the revocation timestamp lets the device mark the disconnection boundary so that, on reconnection, the full period re-syncs and remains identifiable for review under sponsor-specific rules.

*End* *Portal Data Acceptance and Rejection* | **Hash**: e040dc7d
