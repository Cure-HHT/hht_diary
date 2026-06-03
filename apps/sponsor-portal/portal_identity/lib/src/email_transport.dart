import 'dart:convert';
import 'package:googleapis/gmail/v1.dart' as gmail;
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;

import 'email_config.dart';
import 'email_render.dart';

// Implements: DIARY-DEV-portal-activation-email-delivery/A
abstract interface class EmailTransport {
  Future<void> send(RenderedEmail email, {required String to});

  /// Console transport when not configured for live send, else Gmail-over-WIF.
  static EmailTransport fromConfig(EmailConfig config) {
    if (config.consoleMode || !config.isConfigured) return ConsoleTransport();
    return GmailWifTransport(config);
  }
}

/// Logs the rendered email to [out] (defaults to print) instead of sending.
class ConsoleTransport implements EmailTransport {
  ConsoleTransport({void Function(String) out = print}) : _out = out;
  final void Function(String) _out;

  @override
  Future<void> send(RenderedEmail email, {required String to}) async {
    _out('=' * 60);
    _out('[EMAIL CONSOLE MODE] To: $to');
    _out('Subject: ${email.subject}');
    _out('-' * 60);
    _out(email.text);
    _out('=' * 60);
  }
}

/// Sends via Gmail with workload-identity federation + domain-wide delegation.
/// JWT-signs as the Gmail SA impersonating the sender, exchanges for an access
/// token, and sends a MIME multipart/alternative message.
class GmailWifTransport implements EmailTransport {
  GmailWifTransport(this.config);
  final EmailConfig config;
  gmail.GmailApi? _api;

  Future<gmail.GmailApi> _gmail() async {
    if (_api != null) return _api!;
    final adcClient = await clientViaApplicationDefaultCredentials(
      scopes: const ['https://www.googleapis.com/auth/cloud-platform'],
    );
    final targetSa = config.gmailServiceAccountEmail!;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final jwtClaims = jsonEncode({
      'iss': targetSa,
      'sub': config.senderEmail,
      'scope': gmail.GmailApi.gmailSendScope,
      'aud': 'https://oauth2.googleapis.com/token',
      'iat': now,
      'exp': now + 3600,
    });
    final signRes = await adcClient.post(
      Uri.parse(
          'https://iamcredentials.googleapis.com/v1/projects/-/serviceAccounts/$targetSa:signJwt'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'payload': jwtClaims}),
    );
    if (signRes.statusCode != 200) {
      throw Exception('signJwt failed: ${signRes.statusCode} ${signRes.body}');
    }
    final signedJwt = (jsonDecode(signRes.body)
        as Map<String, dynamic>)['signedJwt'] as String;
    final tokenRes = await http.post(
      Uri.parse('https://oauth2.googleapis.com/token'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body:
          'grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=$signedJwt',
    );
    if (tokenRes.statusCode != 200) {
      throw Exception(
          'token exchange failed: ${tokenRes.statusCode} ${tokenRes.body}');
    }
    final accessToken = (jsonDecode(tokenRes.body)
        as Map<String, dynamic>)['access_token'] as String;
    _api = gmail.GmailApi(authenticatedClient(
      http.Client(),
      AccessCredentials(
        AccessToken('Bearer', accessToken,
            DateTime.now().add(const Duration(hours: 1)).toUtc()),
        null,
        [gmail.GmailApi.gmailSendScope],
      ),
    ));
    return _api!;
  }

  @override
  Future<void> send(RenderedEmail email, {required String to}) async {
    final api = await _gmail();
    final from = '${EmailConfig.senderName} <${config.senderEmail}>';
    final boundary = 'b_${DateTime.now().millisecondsSinceEpoch}';
    final mime = 'From: $from\r\nTo: $to\r\nSubject: ${email.subject}\r\n'
        'MIME-Version: 1.0\r\n'
        'Content-Type: multipart/alternative; boundary="$boundary"\r\n\r\n'
        '--$boundary\r\nContent-Type: text/plain; charset=utf-8\r\n\r\n${email.text}\r\n'
        '--$boundary\r\nContent-Type: text/html; charset=utf-8\r\n\r\n${email.html}\r\n'
        '--$boundary--';
    final message = gmail.Message()..raw = base64Url.encode(utf8.encode(mime));
    await api.users.messages.send(message, config.senderEmail);
  }
}
