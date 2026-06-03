import 'dart:convert';

import 'package:event_sourcing/event_sourcing.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:reaction/reaction.dart';
import 'package:reaction_widgets/reaction_widgets.dart';

import 'audit_format.dart';

const String _serverUrl = String.fromEnvironment(
  'PORTAL_SERVER_URL',
  defaultValue: 'http://localhost:8084',
);

/// Read-only audit table over the server's `GET /audit` endpoint.
///
/// Unlike the reactive screens, the audit log is fetched over plain HTTP
/// and rendered as a static table that the user can refresh.
/// The Bearer credential is `<identityCredential>|<activeRole>` — where
/// [identityCredential] is the session token (session mode) or userId (dev
/// mode). The `|`-separated role claim is appended so the server authorizes
/// the request under the current active role. Self-gates on
/// `portal.audit.view`.
class AuditLogScreen extends StatefulWidget {
  const AuditLogScreen({super.key, required this.identityCredential});

  /// The bare identity credential — session token in session mode, userId in
  /// dev mode. The active-role claim is appended at fetch time.
  final String identityCredential;

  @override
  State<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends State<AuditLogScreen> {
  bool _started = false;
  bool _loading = false;
  String? _error;
  List<Map<String, Object?>> _rows = const <Map<String, Object?>>[];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Fetch exactly once on first build (we need a BuildContext for the
    // auth session, so this can't go in initState). Refresh is manual.
    //
    // No pre-fetch permission check is needed: an unauthorized user's fetch is
    // harmless. The server enforces `portal.audit.view` and returns 403, and
    // the PermissionGate in build() suppresses the table body regardless, so
    // there is no information leak in firing this request.
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
        setState(() {
          _error = 'Not authenticated.';
          _loading = false;
        });
        return;
      }
      final p = status.principal as UserPrincipal;
      // Use identityCredential|activeRole: identityCredential is the session
      // token (session mode) or bare userId (dev mode), so this produces
      // token|role or userId|role respectively — both accepted by the server.
      final cred = '${widget.identityCredential}|${p.activeRole}';
      final resp = await http.get(
        Uri.parse('$_serverUrl/audit?limit=200'),
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
      final rows = parseAuditRows(resp.body);
      setState(() {
        _rows = rows;
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

  // Implements: DIARY-GUI-audit-log-administrator/A — the audit log is presented on its
  //   own dashboard surface (mounted as the Administrator dashboard's audit tab), gated on
  //   portal.audit.view.
  @override
  Widget build(BuildContext context) => PermissionGate(
    permission: 'portal.audit.view',
    fallback: const Center(
      child: Text("You don't have permission to view the audit log."),
    ),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                'Audit Log',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Refresh',
                icon: const Icon(Icons.refresh),
                onPressed: _loading ? null : _fetch,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(child: _body()),
        ],
      ),
    ),
  );

  // Implements: DIARY-GUI-audit-log-common/A+B+E+H — renders the audit table (Timestamp,
  //   Action, User, Details), in reverse-chronological order as served by the endpoint,
  //   with the empty-state message and the per-row "More details" raw-record expansion.
  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(_error!),
            const SizedBox(height: 8),
            TextButton(onPressed: _fetch, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_rows.isEmpty) {
      return const Center(child: Text('No audit entries.'));
    }
    return ListView(
      children: <Widget>[
        for (final r in _rows)
          ExpansionTile(
            title: Text(humanizeEntryType((r['entry_type'] as String?) ?? '')),
            subtitle: Text(
              '${r['timestamp']} · '
              '${initiatorLabel(r['initiator'] as Map<String, Object?>?)} · '
              '${detailsSummary(r)}',
            ),
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(8),
                child: SelectableText(
                  const JsonEncoder.withIndent('  ').convert(r),
                ),
              ),
            ],
          ),
      ],
    );
  }
}
