# Provenance

Chain-of-custody provenance types for cross-system event flow. Pure Dart; no Flutter dependencies.

Each hop that receives an event (mobile device, diary server, portal server, EDC) appends exactly one `ProvenanceEntry` to `event.metadata.provenance`. Prior entries are never modified. The resulting chain is a complete, immutable record of the event's journey across systems, directly supporting the ALCOA+ *Attributable* and *Contemporaneous* principles.

## References

- Spec: `spec/dev-event-sourcing-mobile.md` — REQ-d00115 (6 assertions A-F)
- Design: `docs/superpowers/2026-04-21-mobile-event-sourcing-refactor-design.md` §6.5
- Implementation plan: `docs/superpowers/plans/2026-04-21-mobile-event-sourcing-refactor/` (CUR-1154)

## Exports

This package exports:

- `ProvenanceEntry` — immutable value type with fields `hop`, `receivedAt`, `identifier`, `softwareVersion`, and optional `transformVersion`.
- `appendHop(chain, entry)` — pure function returning a new unmodifiable list with `entry` appended; does not mutate input.

## Installation

Add to a downstream package's `pubspec.yaml`:

```yaml
dependencies:
  provenance:
    path: ../common-dart/provenance
```

## Usage

```dart
import 'package:provenance/provenance.dart';

final firstHop = ProvenanceEntry(
  hop: 'mobile-device',
  receivedAt: DateTime.now().toUtc(),
  identifier: deviceUuid,
  softwareVersion: 'clinical_diary@1.2.3+45',
);

final chain = appendHop(const [], firstHop);
```
