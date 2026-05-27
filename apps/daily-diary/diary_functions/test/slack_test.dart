// Verifies: DIARY-OPS-db-schema-version-check/C (Slack notifier contract)
//
// Unit tests for the diary slack notifier using MockClient — no network required.

import 'package:diary_functions/diary_functions.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;
import 'package:test/test.dart';

void main() {
  group('notifySlackWith', () {
    test('no-op when webhookUrl is null', () async {
      var called = false;
      final client = http_testing.MockClient((_) async {
        called = true;
        return http.Response('', 200);
      });
      await notifySlackWith(client: client, webhookUrl: null, text: 'ping');
      expect(called, isFalse);
    });

    test('no-op when webhookUrl is empty', () async {
      var called = false;
      final client = http_testing.MockClient((_) async {
        called = true;
        return http.Response('', 200);
      });
      await notifySlackWith(client: client, webhookUrl: '', text: 'ping');
      expect(called, isFalse);
    });

    test('posts JSON body to webhook URL', () async {
      Uri? capturedUri;
      String? capturedBody;
      final client = http_testing.MockClient((req) async {
        capturedUri = req.url;
        capturedBody = req.body;
        return http.Response('ok', 200);
      });
      await notifySlackWith(
        client: client,
        webhookUrl: 'https://hooks.example/T/B/X',
        text: 'hello world',
      );
      expect(capturedUri.toString(), 'https://hooks.example/T/B/X');
      expect(capturedBody, contains('"text":"hello world"'));
    });

    test('non-2xx response is swallowed (does not throw)', () async {
      final client = http_testing.MockClient(
        (_) async => http.Response('nope', 500),
      );
      // Must NOT throw.
      await expectLater(
        notifySlackWith(
          client: client,
          webhookUrl: 'https://hooks.example/T/B/X',
          text: 'hi',
        ),
        completes,
      );
    });

    test('client exception is swallowed (does not throw)', () async {
      final client = http_testing.MockClient(
        (_) async => throw http.ClientException('boom'),
      );
      await expectLater(
        notifySlackWith(
          client: client,
          webhookUrl: 'https://hooks.example/T/B/X',
          text: 'hi',
        ),
        completes,
      );
    });
  });
}
