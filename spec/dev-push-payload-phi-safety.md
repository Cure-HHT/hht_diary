# DIARY-DEV-push-payload-phi-safety: PHI-Safe Push Payloads

**Level**: DEV | **Status**: Draft | **Implements**: -
**Refines**: DIARY-BASE-compliance-data-integrity

## Overview

A *Push Notification* travels through third-party transports (FCM, APNs) and may surface on a locked device, so its payload must never carry protected information. The platform enforces this with a payload guard: a single checkpoint that every outbound push payload passes through, carrying only opaque identifiers the *Mobile Application* later resolves from authenticated state. The guard runs both before a payload leaves the system and before any payload is persisted, so a non-conforming payload can neither be sent nor stored.

## Assertions

A. A *Push Notification* payload SHALL carry only opaque identifiers; it SHALL NOT contain *PHI*, *Participant* identifiers, *Questionnaire* content, or other clinical content.

B. The System SHALL validate every push payload against the prohibited-content patterns at a single payload guard, both before the payload is transmitted to a transport and before the payload is persisted.

C. The payload guard SHALL fail closed: a payload that matches a prohibited pattern SHALL be rejected rather than sent or stored.

D. The guard SHALL be bypassable only through an explicit test-only flag, never in a production build.

## Rationale

Push transports are outside the platform's trust boundary and notifications routinely render on lock screens and in OS notification mirrors, so treating the payload as public is the only safe assumption — hence opaque-identifier-only payloads that are meaningless without the authenticated app context. Placing the check at one guard rather than in every caller makes the invariant enforceable and auditable: there is a single place to prove no PHI escapes. Running the guard before persistence as well as before egress closes the gap where a non-conforming payload could be written to a store and later replayed to a transport. Failing closed makes a guard error deny-by-default, and confining the bypass to a test-only flag keeps the contract intact in every shipping build.

*End* *PHI-Safe Push Payloads* | **Hash**: 03063ec0
