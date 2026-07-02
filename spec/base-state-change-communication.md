# DIARY-BASE-state-change-communication: User-Facing State-Change Communication

**Level**: BASE | **Status**: Draft | **Implements**: -
**Refines**: DIARY-BASE-compliant-diary-platform

## Overview

A platform-wide contract for how the system communicates when a *User*'s *Action* or in-progress work cannot be accepted because another actor changed the target's state — for example a *Study Coordinator* deleting, calling back, or reassigning a resource a *Participant* is actively working on, or a protocol change invalidating an open task. In a multi-user clinical system these collisions are inherent; without a common rule each surface invents its own handling, producing inconsistent messaging, silent data loss, or error text that blames the *User* for something they did not do.

## Assertions

A. When a *User*'s *Action* is rejected because the target resource was modified or removed by another actor, the system SHALL display a clear, specific message explaining that the resource is no longer available.

B. Messages for server-side state changes SHALL NOT imply the *User* made an error or did anything wrong.

C. When a *User*'s in-progress work cannot be accepted due to a server-side state change, the system SHALL explicitly acknowledge that the *User*'s work was not saved.

D. After displaying a state-change message, the system SHALL return the *User* to a navigable screen on which the invalidated resource no longer appears as actionable.

## Rationale

Multi-user clinical systems allow staff actions (deletion, reassignment, call-back, protocol changes) that can invalidate work a *Participant* or another *User* is actively performing. A platform-wide contract keeps that moment clear, respectful, and free of navigational dead-ends: the *User* is told plainly that the resource is gone, is not blamed for a collision they could not foresee, is told their work was not saved rather than left to guess, and is returned to a screen that reflects the new reality. Stating this once at the BASE level prevents each feature from reinventing state-change handling and closes the silent-data-loss and user-blaming failure modes that ad-hoc error handling tends to produce.

*End* *User-Facing State-Change Communication* | **Hash**: 6419ab0b
