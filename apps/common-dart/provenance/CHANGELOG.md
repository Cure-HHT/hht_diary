## 0.1.0

First functional release. Implements REQ-d00115 (ProvenanceEntry Schema and Append Rules).

* `ProvenanceEntry` immutable value type with fields `hop`, `receivedAt`, `identifier`, `softwareVersion`, and optional `transformVersion`. JSON serialization uses snake_case keys. `fromJson` raises `FormatException` for missing or wrong-typed required fields, and rejects offsetless ISO 8601 `received_at` strings (the timezone-offset requirement is enforced to preserve ALCOA+ Contemporaneous across the audit chain). `toJson` emits a `transform_version: null` key rather than omitting the key when unset — wire consumers can distinguish *absent-because-null* from *absent-because-missing*. Value equality via `==` and `hashCode`. (REQ-d00115-C,D,E,F)
* `appendHop(chain, entry)` pure function returning a new `List.unmodifiable` with `entry` appended. Input chain is never mutated; returned list rejects further modification. (REQ-d00115-A,B)

This is the first release. Subsequent phases of CUR-1154 consume these types from within the event-sourcing pipeline; the package itself remains pure Dart with no Flutter dependency so the same code can be reused on the portal server.
