# PHASE 4 TASK 7 — drain() loop

## What landed

`drain(destination, {backend, clock?})` — strict-FIFO drain loop per REQ-d00124.

Algorithm (matches design doc §8.3 pseudocode):

1. `readFifoHead(destination.id)` — returns null when the FIFO is empty or wedged (previous head exhausted); the caller treats both as "nothing to do now".
2. Check backoff: if the head has prior attempts and `now - attempts.last.attempted_at < SyncPolicy.backoffFor(attempts.length)`, return without sending.
3. Reconstruct a `WirePayload` from the head's stored `wire_payload` (Map) + `wire_format` (String) + `transform_version` (String?) by re-encoding the Map to bytes via JSON.
4. Call `destination.send(payload)`. Any thrown exception is categorized as `SendTransient` — the drain-loop contract treats a thrown exception the same as an explicit transient (same append-attempt + retry semantics).
5. Append an `AttemptResult` to the entry's `attempts[]` via `backend.appendAttempt`, regardless of outcome (REQ-d00124-G).
6. Route the `SendResult`:
   - `SendOk` → `markFinal(sent)`, continue the loop to the next head.
   - `SendPermanent` → `markFinal(exhausted)`, return (wedge).
   - `SendTransient`:
     - If `attempts.length + 1 >= SyncPolicy.maxAttempts` → `markFinal(exhausted)`.
     - Otherwise: leave pending; return (next drain gates on backoff).

### Design notes

- **Clock injection** via a `typedef ClockFn = DateTime Function()`. The plan suggested a `Clock?` parameter — a function type is lighter-weight than introducing `package:clock`. Production passes `null` and picks up `DateTime.now().toUtc()`.
- **Exception = SendTransient:** the plan's REQ-d00124-G says "every call to destination.send records an attempt." A thrown exception IS a call-that-happened, so the contract applies. Treating it as transient also preserves the retry opportunity for flaky destinations that throw on network hiccups instead of returning a result.
- **Payload reconstruction via JSON re-encode:** `FifoEntry.wire_payload` is `Map<String, Object?>` (Phase-2 schema); `WirePayload.bytes` is `Uint8List` (Phase-4 transport). The drain loop bridges them by `utf8.encode(jsonEncode(map))`. This is deterministic because Dart Map preserves insertion order, and JSON-encoded destinations recover the exact bytes they'd get from `transform(event)` run on the original event. Non-JSON destinations (binary protocols) would store their bytes inside the Map wrapper (e.g., `{"base64": "..."}`) and unwrap in `send()`.
- **Retry of thrown exceptions:** reconstruction of the WirePayload happens BEFORE `send`, and WirePayload construction itself can't throw on a well-formed FifoEntry. So the only caught path is `destination.send` throwing.

### Minor corollary — WirePayload.transformVersion nullable

The Task-3 `WirePayload` had `transformVersion: String`, but `FifoEntry.transformVersion` is `String?` (null = identity/pass-through per REQ-d00115-F). Changed `WirePayload.transformVersion` to nullable in this task so the drain's reconstruction doesn't need a sentinel. Task 3's WirePayload tests continue to pass (they all supply a non-null value).

## Test double — `FakeDestination`

`test/test_support/fake_destination.dart`:

- `script: List<SendResult>` — popped one per `send` call; throws if exhausted.
- `sent: List<WirePayload>` — recorded payloads, in call order.
- `returned: List<SendResult>` — what the destination returned per call, in order.
- `blockBeforeSend: Future<void> Function()?` — optional hook that awaits a completer; used by Task-8 sync-cycle tests to simulate in-flight overlap.
- `enqueueScript(result)` — extend the script mid-run.

Concrete `_ThrowingDestination` in drain_test.dart overrides `send` to always throw `StateError`, exercising the "exception = transient" contract.

## Tests (11)

- `REQ-d00124-A: empty FIFO returns without calling send`
- `REQ-d00124-C: SendOk marks head sent and advances to the next head`
- `REQ-d00124-C: drain loops across multiple SendOks in one call`
- `REQ-d00124-D: SendPermanent wedges the FIFO; subsequent drain is a no-op`
- `REQ-d00124-F+B: SendTransient appends attempt; next drain honors backoff and does not call send again`
- `REQ-d00124-B: after backoff elapses, drain calls send again`
- `REQ-d00124-E: SendTransient at maxAttempts marks entry exhausted`
- `REQ-d00124-G: every send call appends an AttemptResult`
- `REQ-d00124-H: strict FIFO — wedge on e1 prevents attempting e2/e3`
- `multi-destination independence: wedge on d1 does not block d2`
- `drain treats a thrown exception as SendTransient and records an attempt`

## Verification

- `flutter test test/sync/drain_test.dart`: 11 passed.
- `flutter test` full suite: 292 passed.
- `flutter analyze`: No issues found.

## Files changed

- `apps/common-dart/append_only_datastore/lib/src/sync/drain.dart` (new, 120 lines)
- `apps/common-dart/append_only_datastore/lib/src/destinations/wire_payload.dart` (transformVersion → `String?`)
- `apps/common-dart/append_only_datastore/test/test_support/fake_destination.dart` (new, 80 lines)
- `apps/common-dart/append_only_datastore/test/sync/drain_test.dart` (new, 11 tests)
