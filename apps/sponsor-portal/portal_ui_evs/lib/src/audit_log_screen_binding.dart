import 'package:event_sourcing/event_sourcing.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:portal_screens/portal_screens.dart';
import 'package:reaction/reaction.dart';
import 'package:reaction_widgets/reaction_widgets.dart';

import 'audit_format.dart';

/// Thin wrapper that feeds [AuditLogsScreen] a snapshot of audit
/// entries fetched from `GET /audit`.
///
/// All the HTTP / credential / parse logic from the legacy
/// `AuditLogScreen` lives here (it never belonged in the presentation
/// layer); the new design-system screen just receives a list of
/// [AuditEntryView]s + `isLoading` + `errorMessage` and emits
/// [AuditLogsScreen.onRefresh] back here when the user triggers a
/// refetch.
///
/// Self-gates on `portal.audit.view`.
class AuditLogScreenBinding extends StatefulWidget {
  const AuditLogScreenBinding({
    super.key,
    required this.identityCredential,
    required this.serverUrl,
  });

  /// Bare identity credential — session token in session mode, userId
  /// in dev mode. The active-role claim is appended at fetch time.
  final String identityCredential;

  /// Portal server base URL, resolved at runtime by the app shell.
  final String serverUrl;

  static const String viewAuditPermission = 'portal.audit.view';

  @override
  State<AuditLogScreenBinding> createState() => _AuditLogScreenBindingState();
}

class _AuditLogScreenBindingState extends State<AuditLogScreenBinding> {
  bool _started = false;
  bool _loading = false;
  String? _error;
  List<AuditEntryView> _entries = const <AuditEntryView>[];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Fetch exactly once on first build. Refresh is manual (driven by
    // AuditLogsScreen.onRefresh). Permission errors are harmless — the
    // PermissionGate in build() suppresses the body and the server
    // enforces portal.audit.view independently.
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
      final status = ReActionScope.of(context).authSession.current;
      if (status is! Authenticated || status.principal is! UserPrincipal) {
        if (!mounted) return;
        setState(() {
          _error = 'Not authenticated.';
          _loading = false;
        });
        return;
      }
      final p = status.principal as UserPrincipal;
      // `<identityCredential>|<activeRole>` — same Bearer shape the
      // legacy AuditLogScreen used. The server reads the role claim to
      // authorize the request under the active role.
      final cred = '${widget.identityCredential}|${p.activeRole}';
      final resp = await http.get(
        Uri.parse('${widget.serverUrl}/audit?limit=200'),
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
      final rawRows = parseAuditRows(resp.body);
      setState(() {
        _entries = <AuditEntryView>[
          for (final row in rawRows) _toEntryView(row),
        ];
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
  Widget build(BuildContext context) => PermissionGate(
    permission: AuditLogScreenBinding.viewAuditPermission,
    fallback: const Center(
      child: Text("You don't have permission to view the audit log."),
    ),
    child: AuditLogsScreen(
      entries: _entries,
      isLoading: _loading,
      errorMessage: _error,
      onRefresh: _fetch,
    ),
  );
}

// -----------------------------------------------------------------------------
// Mapping: raw audit row Map → AuditEntryView. Pre-parses the scalar
// fields the row + expansion panel display, but keeps the full raw map
// on `AuditEntryView.raw` so the JSON dump in the expansion panel
// renders against the original shape (no round-trip loss).
// -----------------------------------------------------------------------------

AuditEntryView _toEntryView(Map<String, Object?> row) {
  final tsString = row['timestamp']?.toString() ?? '';
  final timestamp = DateTime.tryParse(tsString)?.toUtc() ?? DateTime.utc(1970);

  // Initiator. Only user-kind initiators have a human actor name; for
  // automation / anonymous the screen renders "Automation" + blank role
  // (see audit_log_row.dart's _UserCell branch).
  final initiator = row['initiator'];
  String actorName = '';
  String actorRole = '';
  if (initiator is Map) {
    final kind = initiator['kind'];
    final label = initiator['label']?.toString() ?? '';
    if (kind == 'user') {
      actorName = label;
      // The raw row carries the actor's role under various keys
      // depending on the entry type; cheapest reliable source is the
      // request's authorization claim, surfaced as `actor_role` when
      // the server records it. Falls back blank if absent — the User
      // cell collapses the role line gracefully.
      actorRole = row['actor_role']?.toString() ?? '';
    }
  }

  // Activity label. The server-side audit row doesn't currently carry
  // a pre-rendered prose summary, so we synthesize one here from the
  // existing humanizer helpers. The expanded panel renders its own
  // headline + metadata from `raw`, so this label only needs to give
  // the collapsed row a recognisable summary.
  final entryType = (row['entry_type'] as String?) ?? '';
  final activity = humanizeEntryType(entryType);

  return AuditEntryView(
    id: (row['event_id'] as String?) ?? (row['aggregateId'] as String?) ?? '?',
    timestamp: timestamp,
    actorName: actorName,
    actorRole: actorRole,
    activityLabel: activity,
    raw: row,
  );
}
