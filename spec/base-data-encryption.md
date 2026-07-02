# DIARY-BASE-data-encryption: Data Encryption

**Level**: BASE | **Status**: Draft | **Implements**: -
**Refines**: DIARY-BASE-compliance-data-integrity

## Overview

Confidentiality protection for regulated *Diary* data wherever it is stored or moves: encrypted at rest in every persistent store, encrypted in transit over every network hop, keyed per *Sponsor* so a compromise of one deployment cannot decrypt another's, and never disableable. This is the highest-priority 21 CFR Part 11 confidentiality control and sits under Compliance and Data Integrity because it protects electronic records independent of any single feature.

## Assertions

A. The System SHALL encrypt regulated data at rest in every persistent store, including the clinical *Database* and any backup or archival copy.

B. The System SHALL encrypt regulated data in transit over every network channel and SHALL transmit over encrypted channels only.

C. The System SHALL negotiate transport encryption at TLS 1.2 or higher for all network communication.

D. The *Mobile Application* SHALL protect *Diary* data held in its local on-device store, including any offline outbound queue awaiting synchronization, such that the data is unreadable to another process or a party with physical access to the device.

E. The System SHALL encrypt each *Sponsor*'s data at rest under encryption keys unique to that *Sponsor*, so that keys for one deployment cannot decrypt another's data.

F. The System SHALL manage encryption keys in accordance with industry key-management practices and SHALL support rotation of encryption keys under the governing security policy.

G. The System SHALL NOT provide any configuration or runtime path that disables encryption of regulated data at rest or in transit.

## Rationale

Encryption is the confidentiality layer that survives when access controls or physical custody fail — an intercepted channel, a stolen backup, or a lost device must still yield no readable regulated data. Per-*Sponsor* keys extend *Multi-Sponsor Isolation* to the cryptographic layer so that one deployment's compromise cannot cascade. The local-store and offline-queue obligation closes the gap that an *Offline-First* application necessarily accumulates data on the device before it can sync. Making encryption non-disableable removes the most common source of accidental exposure — a misconfiguration that silently ships plaintext.

*End* *Data Encryption* | **Hash**: 40392cb7
