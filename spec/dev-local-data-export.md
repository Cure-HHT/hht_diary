# DIARY-DEV-local-data-export: Local Data Export and Import

**Level**: DEV | **Status**: Draft | **Implements**: -
**Refines**: DIARY-BASE-mobile-diary-application

## Overview

An on-device, offline capability for a *Participant* to export their local *Diary* data to a structured, machine-readable file and to import such a file back, supporting data-portability and device-migration scenarios without depending on network or server availability. Export carries *Diary* content only, omitting sync-bookkeeping state; import merges without duplicating records.

## Assertions

A. The *Mobile Application* SHALL export the local *Diary* store to a structured, machine-readable file that includes *Diary* entries, their timestamps, event types, and *User*-entered values.

B. The *Mobile Application* SHALL import a previously exported file, validating its structure and integrity before inserting any records and rejecting a malformed or incompatible file with a clear error.

C. Import SHALL merge without duplication, skipping records already present (identified by their stable event identifier) and inserting only new records.

D. Export and import SHALL operate entirely offline, requiring no network connectivity.

E. Exported files SHALL carry a schema-version header so a later import can detect compatibility.

F. Export SHALL exclude synchronization-bookkeeping state (sync status, device identity, and pending-event queues) from the exported file.

G. The *Mobile Application* SHALL let the *User* choose where an exported file is saved or share it through the device's standard sharing facilities, and SHALL indicate progress for large export or import operations.

## Rationale

Data portability is a *Participant* right and a practical need (device change, personal backup), and it must work regardless of server reachability — hence a fully offline, on-device operation. A schema-versioned, content-only file keeps exports portable and meaningful while omitting device-local sync bookkeeping that would be meaningless or harmful on another device. Duplicate-skipping merge on a stable event identifier makes import idempotent and safe to re-run, and up-front validation prevents a malformed file from corrupting the local store.

*End* *Local Data Export and Import* | **Hash**: f9fbc978
