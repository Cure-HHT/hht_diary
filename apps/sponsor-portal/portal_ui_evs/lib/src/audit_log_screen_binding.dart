import 'package:event_sourcing/event_sourcing.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:portal_screens/portal_screens.dart';
import 'package:reaction/reaction.dart';
import 'package:reaction_widgets/reaction_widgets.dart';

import 'audit_format.dart';

/// Thin wrapper that feeds [AuditLogsScreen] one PAGE of audit entries
/// fetched from `GET /audit?limit=&offset=&q=`.
///
/// All the HTTP / credential / parse logic lives here (it never
/// belonged in the presentation layer). The binding owns the paging
/// state — current page, page size, search query, and the server's
/// true total — and refetches whenever [AuditLogsScreen] reports a
/// page flip, page-size change, or settled search input. Search is
/// evaluated SERVER-SIDE over the whole log (the screen's search box
/// debounces internally), so a match on the oldest entry is found even
/// when it isn't loaded.
///
/// Self-gates on `portal.audit.view`.
class AuditLogScreenBinding extends StatefulWidget {
  const AuditLogScreenBinding({
    super.key,
    required this.identityCredential,
    required this.serverUrl,
    this.httpClient,
  });

  /// Bare identity credential — session token in session mode, userId
  /// in dev mode. The active-role claim is appended at fetch time.
  final String identityCredential;

  /// Portal server base URL, resolved at runtime by the app shell.
  final String serverUrl;

  /// Injection point for tests; production uses a real client.
  final http.Client? httpClient;

  static const String viewAuditPermission = 'portal.audit.view';

  @override
  State<AuditLogScreenBinding> createState() => _AuditLogScreenBindingState();
}

class _AuditLogScreenBindingState extends State<AuditLogScreenBinding> {
  bool _started = false;
  bool _loading = false;
  String? _error;
  List<AuditEntryView> _entries = const <AuditEntryView>[];
  int _page = 1;
  int _pageSize = 8;
  String _query = '';
  int _total = 0;

  /// Monotonic fetch token: a response is applied only if no newer
  /// fetch started after it (rapid page flips would otherwise let a
  /// slow page-2 response clobber the already-rendered page 3).
  int _fetchSeq = 0;

  http.Client get _http => widget.httpClient ?? http.Client();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Fetch exactly once on first build; later fetches are driven by
    // the screen's paging/search callbacks. Permission errors are
    // harmless — the PermissionGate in build() suppresses the body and
    // the server enforces portal.audit.view independently.
    if (!_started) {
      _started = true;
      _fetch();
    }
  }

  Future<void> _fetch() async {
    final seq = ++_fetchSeq;
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
      final q = _query.trim();
      final uri = Uri.parse('${widget.serverUrl}/audit').replace(
        queryParameters: <String, String>{
          'limit': '$_pageSize',
          'offset': '${(_page - 1) * _pageSize}',
          if (q.isNotEmpty) 'q': q,
        },
      );
      final resp = await _http.get(
        uri,
        headers: <String, String>{'Authorization': 'Bearer $cred'},
      );
      if (!mounted || seq != _fetchSeq) return;
      if (resp.statusCode != 200) {
        setState(() {
          _error = 'HTTP ${resp.statusCode}';
          _loading = false;
        });
        return;
      }
      final page = parseAuditPage(resp.body);
      setState(() {
        _entries = <AuditEntryView>[
          for (final row in page.rows) _toEntryView(row),
        ];
        _total = page.total;
        _loading = false;
      });
      // The requested page can fall off the end — e.g. the match set
      // shrank while searching. Snap to the last page that exists.
      final maxPage = _total == 0 ? 1 : ((_total - 1) ~/ _pageSize) + 1;
      if (_page > maxPage) {
        setState(() => _page = maxPage);
        await _fetch();
      }
    } catch (e) {
      if (!mounted || seq != _fetchSeq) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  void _onPageChanged(int page) {
    setState(() => _page = page);
    _fetch();
  }

  void _onPageSizeChanged(int size) {
    setState(() {
      _pageSize = size;
      _page = 1;
    });
    _fetch();
  }

  void _onSearchChanged(String query) {
    setState(() {
      _query = query;
      _page = 1;
    });
    _fetch();
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
      page: _page,
      pageSize: _pageSize,
      totalCount: _total,
      searchQuery: _query,
      onPageChanged: _onPageChanged,
      onPageSizeChanged: _onPageSizeChanged,
      onSearchChanged: _onSearchChanged,
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
