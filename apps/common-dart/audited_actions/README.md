# audited_actions

Trusted-boundary command/intent layer for the unified event-sourced architecture.

This package is the trusted-boundary gatekeeper between untrusted callers
(browsers, future mobile-portal API) and the events lib
(`append_only_datastore`). Every state-change reaching the host from an
untrusted source flows through one library-defined pipeline that:

1. Authenticates the caller (via the supplied `Principal`)
2. Authorizes the operation (via a pluggable `AuthorizationPolicy`)
3. Validates the input
4. Executes the action
5. Persists the resulting events atomically via the events lib
6. Records every denial as a typed event in the same log

See `docs/superpowers/specs/2026-04-22-events-and-actions-libs-design.md`
(Sub-project A) for the full design.

## Quick start

```dart
import 'package:audited_actions/audited_actions.dart';

final dispatcher = bootstrapAuditedActions(
  events: myEventsApi,
  authorization: TableBackedAuthorizationPolicy(myMatrixReader),
  idempotency: InMemoryIdempotencyStore(),
  actions: [InviteUserAction(), DeactivateUserAction(), ...],
);

final result = await dispatcher.dispatch(
  'invite_user',
  rawInput,
  ctx,
  idempotencyKey: requestId,
  flowToken: 'invite:ABC123',
);
```

## Out of scope

- Concrete actions (which actions exist) — defined per-area in cutover tickets.
- PostgreSQL `IdempotencyStore` impl — separate "port to portal" ticket.
- HTTP-edge concerns (rate limiting, token verification) — middleware.
- OpenTelemetry stamping — future enhancement.
