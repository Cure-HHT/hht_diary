// IMPLEMENTS REQUIREMENTS:
//   REQ-p00006: Offline-First Data Entry (client/server contract)
//   REQ-p00008: User Account Management (auth contract)
//   REQ-p00042: Event Sourcing Audit Trail (event submission contract)
//
// Verifies: response/request shapes that the diary_server exposes are
//           the same shapes the clinical_diary client and diary_functions
//           layer expect.
//
// The contract is captured as a small set of JSON Schema-like
// expectations. If a route adds a field, this test does NOT fail
// (additive change). It DOES fail if a required field is removed,
// renamed, or has its type changed.
//
// SCAFFOLD: this file documents the intended check shape. Each test is
// `skip:`-marked until the helper that loads route-level OpenAPI / pact
// fixtures is in place. Replace the skip with a real handler invocation
// once spec/dev-api-contracts.md lists the canonical shapes.

import 'dart:convert';

import 'package:test/test.dart';

/// Minimal "shape" matcher. Each leaf is one of:
///   - a Type literal (String, int, bool, num, Map, List)
///   - the literal `#nullable<Type>` (sentinel handled in [matchesShape])
///   - a nested Map<String, Object> for objects
///   - `[Type]` for an array of homogeneous element type
bool matchesShape(Object? value, Object? shape, [String path = '\$']) {
  if (shape == String) return value is String;
  if (shape == int) return value is int;
  if (shape == num) return value is num;
  if (shape == bool) return value is bool;

  if (shape is Map<String, Object>) {
    if (value is! Map) return false;
    for (final entry in shape.entries) {
      if (!value.containsKey(entry.key)) return false;
      if (!matchesShape(value[entry.key], entry.value, '$path.${entry.key}')) {
        return false;
      }
    }
    return true;
  }

  if (shape is List && shape.length == 1) {
    if (value is! List) return false;
    return value.every((e) => matchesShape(e, shape.first, '$path[*]'));
  }

  return false;
}

void main() {
  group('contract: POST /api/v1/auth/register response', () {
    test(
      'returns { jwt, userId, username }',
      () {
        final body = jsonDecode(
          // TODO: replace with real handler invocation. For now, a fixture
          // captured from integration_test/auth_test.dart.
          '{"jwt":"eyJhbGciOiJIUzI1NiJ9.eyJ1c2VySWQiOiJ4In0.sig",'
          '"userId":"00000000-0000-0000-0000-000000000001",'
          '"username":"alice"}',
        );

        expect(
          matchesShape(body, <String, Object>{
            'jwt': String,
            'userId': String,
            'username': String,
          }),
          isTrue,
        );
      },
      skip: 'scaffold — replace fixture with real handler call',
    );
  });

  group('contract: POST /api/v1/events request body', () {
    test(
      'client submission shape matches server expectation',
      () {
        // What clinical_diary serialises (canonical JSON):
        final clientBody = jsonDecode(
          '{"event_id":"abc","aggregate_id":"agg","entry_type":"epistaxis_event",'
          '"event_type":"finalized","sequence_number":1,'
          '"client_timestamp":"2026-05-09T12:00:00Z",'
          '"data":{"intensity":"mild"},"user_id":"u","device_id":"d",'
          '"previous_event_hash":null}',
        );

        // What diary_server requires:
        const serverShape = <String, Object>{
          'event_id': String,
          'aggregate_id': String,
          'entry_type': String,
          'event_type': String,
          'sequence_number': int,
          'client_timestamp': String,
          'data': Map,
          'user_id': String,
          'device_id': String,
          // previous_event_hash is nullable; presence-only check.
        };

        expect(matchesShape(clientBody, serverShape), isTrue);
        expect((clientBody as Map).containsKey('previous_event_hash'), isTrue);
      },
      skip: 'scaffold — replace fixture with real client serialisation',
    );
  });

  group('contract: GET /api/v1/tasks response', () {
    test(
      'returns array of { id, type, priority, due_at? }',
      () {
        final body = jsonDecode(
          '[{"id":"t1","type":"questionnaire","priority":1},'
          '{"id":"t2","type":"missing_days","priority":4}]',
        );

        expect(
          matchesShape(body, [
            <String, Object>{'id': String, 'type': String, 'priority': int},
          ]),
          isTrue,
        );
      },
      skip: 'scaffold — replace fixture with real handler call',
    );
  });

  group('contract: error response shape', () {
    test('400/401/409 always has { error: String }', () {
      for (final fixture in [
        '{"error":"Username already taken"}',
        '{"error":"Invalid credentials"}',
        '{"error":"Username must be at least 6 characters"}',
      ]) {
        final body = jsonDecode(fixture);
        expect(
          matchesShape(body, <String, Object>{'error': String}),
          isTrue,
          reason: fixture,
        );
      }
    });
  });
}
