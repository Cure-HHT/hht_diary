// Authenticated HTTP client lifecycle for FCM. Uses Application Default
// Credentials (Workload Identity Federation on Cloud Run; gcloud
// `application-default login` locally). Caches the client and rotates
// before the token's hour-long lifetime expires so a long-running
// process never sends with an about-to-expire bearer.
//
// FcmChannel calls [AdcClient.getClient] on every dispatch — refresh is
// transparent. Tests inject a custom `authFactory` and `clock` to
// exercise the rotation logic without a live ADC environment.

import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;

/// Caches and rotates an ADC-authenticated HTTP client.
// Implements: DIARY-OPS-fcm-project-routing/A — ADC resolves the FCM sender project
class AdcClient {
  AdcClient({
    Future<http.Client> Function()? authFactory,
    DateTime Function()? clock,
  }) : _authFactory = authFactory ?? _defaultAuthFactory,
       _clock = clock ?? DateTime.now;

  /// FCM scopes only — no domain-wide delegation or signJwt needed.
  /// The Cloud Run SA already has fcmSender on cure-hht-admin, so the
  /// minimal cloud-platform scope is sufficient.
  static const List<String> _scopes = <String>[
    'https://www.googleapis.com/auth/cloud-platform',
  ];

  /// Google's bearer tokens are valid for one hour.
  static const Duration _tokenLifetime = Duration(hours: 1);

  /// Refresh window — a request that lands inside the last 5 minutes
  /// of a token's life triggers proactive rotation so it never expires
  /// mid-flight.
  static const Duration _refreshBuffer = Duration(minutes: 5);

  final Future<http.Client> Function() _authFactory;
  final DateTime Function() _clock;

  http.Client? _client;
  DateTime? _createdAt;

  /// Returns the current authenticated client, creating or rotating as
  /// needed. Callers MUST NOT cache the returned client across awaits
  /// — always re-resolve via [getClient] so a refresh is picked up.
  Future<http.Client> getClient() async {
    if (_client == null || _needsRefresh()) {
      _client?.close();
      _client = await _authFactory();
      _createdAt = _clock();
    }
    return _client!;
  }

  /// True when the cached token is close enough to expiry that a
  /// dispatched request might race the refresh window.
  bool _needsRefresh() {
    if (_createdAt == null) return true;
    final age = _clock().difference(_createdAt!);
    return age >= (_tokenLifetime - _refreshBuffer);
  }

  /// Releases the cached client. Safe to call multiple times.
  void dispose() {
    _client?.close();
    _client = null;
    _createdAt = null;
  }

  static Future<http.Client> _defaultAuthFactory() {
    return clientViaApplicationDefaultCredentials(scopes: _scopes);
  }
}
