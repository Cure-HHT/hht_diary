import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:portal_screens/portal_screens.dart';

import 'study_settings_format.dart';

/// Thin wrapper that feeds [StudySettingsScreen] the study-configuration
/// snapshot fetched from `GET /config/study`.
///
/// The server reports only parameters the platform actually enforces
/// (resolved through the same code paths their consumers use);
/// [buildStudySettingsSections] lays them into the Figma's full section
/// structure, rendering "Not yet implemented" for the rows with no
/// backing reality. No PermissionGate: any authenticated portal user may
/// view study settings, and the server rejects unauthenticated reads.
class StudySettingsBinding extends StatefulWidget {
  const StudySettingsBinding({
    super.key,
    required this.identityCredential,
    required this.serverUrl,
    required this.activeRole,
    this.httpClient,
  });

  /// Bare identity credential — session token in session mode, userId in
  /// dev mode. The active-role claim is appended at fetch time.
  final String identityCredential;

  /// Portal server base URL, resolved at runtime by the app shell.
  final String serverUrl;

  /// Active-role claim appended to the Bearer (`<credential>|<role>`).
  final String? activeRole;

  /// Injection point for tests; production uses a real client.
  final http.Client? httpClient;

  @override
  State<StudySettingsBinding> createState() => _StudySettingsBindingState();
}

class _StudySettingsBindingState extends State<StudySettingsBinding> {
  bool _started = false;
  bool _loading = false;
  String? _error;
  List<StudySettingsSectionView> _sections = const <StudySettingsSectionView>[];

  /// Lazily-created client owned by this state when none is injected —
  /// closed in [dispose]. An injected client is the owner's to close.
  http.Client? _ownedClient;

  http.Client get _http =>
      widget.httpClient ?? (_ownedClient ??= http.Client());

  @override
  void dispose() {
    _ownedClient?.close();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _fetch();
    }
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final role = widget.activeRole;
      final cred = role == null
          ? widget.identityCredential
          : '${widget.identityCredential}|$role';
      final resp = await _http.get(
        Uri.parse('${widget.serverUrl}/config/study'),
        headers: <String, String>{'Authorization': 'Bearer $cred'},
      );
      if (!mounted) return;
      if (resp.statusCode != 200) {
        setState(() {
          _error = 'HTTP ${resp.statusCode}';
          _loading = false;
        });
        return;
      }
      setState(() {
        _sections = buildStudySettingsSections(resp.body);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => StudySettingsScreen(
    sections: _sections,
    isLoading: _loading,
    errorMessage: _error,
    onRetry: _fetch,
    // SystemOperator developer affordance: hover shows each parameter's
    // true source identifier, click copies it.
    showVariableNames:
        widget.activeRole == PortalRole.systemOperator.systemName,
  );
}
