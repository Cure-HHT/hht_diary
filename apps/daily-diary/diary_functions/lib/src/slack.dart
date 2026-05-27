// Fire-and-forget Slack notifier for the diary server.
// Per CLAUDE.md §1: per-function Implements: annotations only — no file-header
// IMPLEMENTS block.

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Fire-and-forget Slack notifier.
/// Reads SLACK_INCIDENT_WEBHOOK_URL from the process environment.
/// No-op if the variable is unset or empty.
Future<void> notifySlack(String text) async {
  await notifySlackWith(
    client: http.Client(),
    webhookUrl: Platform.environment['SLACK_INCIDENT_WEBHOOK_URL'],
    text: text,
    closeClient: true,
  );
}

/// Testable variant: explicit client + webhook URL.
/// POSTs `{"text": <text>}` JSON with a 5-second timeout.
/// Non-2xx responses and all exceptions are logged and swallowed;
/// this function never throws.
Future<void> notifySlackWith({
  required http.Client client,
  required String? webhookUrl,
  required String text,
  bool closeClient = false,
}) async {
  try {
    if (webhookUrl == null || webhookUrl.isEmpty) {
      // ignore: avoid_print
      print('[INFO] SLACK_INCIDENT_WEBHOOK_URL unset — skipping Slack alert');
      return;
    }
    try {
      final response = await client
          .post(
            Uri.parse(webhookUrl),
            headers: {'content-type': 'application/json'},
            body: jsonEncode({'text': text}),
          )
          .timeout(const Duration(seconds: 5));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        // ignore: avoid_print
        print(
          '[WARN] Slack notify non-2xx ${response.statusCode}: '
          '${response.body}',
        );
      }
    } catch (e) {
      // ignore: avoid_print
      print('[WARN] Slack notify failed (non-fatal): $e');
    }
  } finally {
    if (closeClient) client.close();
  }
}
