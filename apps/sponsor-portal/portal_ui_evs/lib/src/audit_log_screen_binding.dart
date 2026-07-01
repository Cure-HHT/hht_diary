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
    this.siteId,
    this.adminActionsOnly = false,
    this.studyCoordinatorView = false,
    this.title,
    this.subtitle,
    this.onBack,
    this.backLabel,
  });

  /// Bare identity credential — session token in session mode, userId
  /// in dev mode. The active-role claim is appended at fetch time.
  final String identityCredential;

  /// Portal server base URL, resolved at runtime by the app shell.
  final String serverUrl;

  /// Injection point for tests; production uses a real client.
  final http.Client? httpClient;

  /// When set, every fetch carries `site=<siteId>` so the server narrows
  /// the log to that site (site events + the site's participants' events)
  /// — the Sites page drill-in. Search and paging compose with it.
  final String? siteId;

  /// The Administrator audit tab: scope the log to Administrator actions —
  /// the fetch carries `view=admin`, so the server excludes system/automation
  /// events (sessions, OTP, EDC sync). False for the Sites drill-in, which
  /// shows site/participant activity. Search and paging compose with it.
  // Implements: DIARY-DEV-audit-log-read/A
  final bool adminActionsOnly;

  /// The Study Coordinator audit view: scope the log to the Coordinator's OWN
  /// participant/questionnaire actions (the fetch carries `view=mine`), render
  /// the Participant ID column, and route the search box to a Participant ID
  /// filter (`participant=`) rather than the generic email/action `q`.
  // Implements: DIARY-GUI-audit-log-study-coordinator/A+B
  final bool studyCoordinatorView;

  /// Optional header overrides for the scoped instance; null keeps the
  /// top-level Audit Logs defaults.
  final String? title;
  final String? subtitle;
  final VoidCallback? onBack;
  final String? backLabel;

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

  /// Lazily-created client owned by this state when none is injected —
  /// one client for the binding's lifetime (keep-alive across page
  /// flips, no socket churn), closed in [dispose]. An injected client
  /// is the owner's to close.
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
      final site = widget.siteId?.trim() ?? '';
      final uri = Uri.parse('${widget.serverUrl}/audit').replace(
        queryParameters: <String, String>{
          'limit': '$_pageSize',
          'offset': '${(_page - 1) * _pageSize}',
          // The Study Coordinator view routes the search box to the
          // Participant ID filter; every other view routes it to the generic
          // email/action query.
          // Implements: DIARY-GUI-audit-log-study-coordinator/B
          if (q.isNotEmpty)
            (widget.studyCoordinatorView ? 'participant' : 'q'): q,
          if (site.isNotEmpty) 'site': site,
          // Implements: DIARY-DEV-audit-log-read/A
          if (widget.adminActionsOnly) 'view': 'admin',
          // The Study Coordinator's own-actions scope.
          // Implements: DIARY-DEV-audit-log-read/A
          if (widget.studyCoordinatorView) 'view': 'mine',
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
      title: widget.title ?? 'Audit Logs',
      subtitle: widget.subtitle ?? 'View system activity and changes.',
      onBack: widget.onBack,
      backLabel: widget.backLabel ?? 'Back to Sites',
      // Implements: DIARY-GUI-audit-log-study-coordinator/A+B
      showParticipantId: widget.studyCoordinatorView,
      searchHint: widget.studyCoordinatorView
          ? 'Search by Participant ID'
          : 'Search by email or action',
      searchSemanticId: widget.studyCoordinatorView
          ? 'audit-participant-search'
          : 'audit-search',
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

  // Initiator. Only user-kind initiators have a human actor name; the User
  // cell shows the server-resolved display name (else the email), and
  // renders "Automation" for non-user initiators (blank actorName).
  final initiator = row['initiator'];
  final initiatorMap = initiator is Map
      ? initiator.cast<String, Object?>()
      : null;
  final actorName = auditActorName(initiatorMap);
  final actorEmail = auditActorEmail(initiatorMap);
  // The actor's role at the time of the action — surfaced as `actor_role`
  // when the server records it; blank otherwise (the User cell collapses
  // the role line gracefully).
  final actorRole = actorName.isEmpty
      ? ''
      : (row['actor_role']?.toString() ?? '');

  return AuditEntryView(
    id: (row['event_id'] as String?) ?? (row['aggregateId'] as String?) ?? '?',
    timestamp: timestamp,
    actorName: actorName,
    actorRole: actorRole,
    actorEmail: actorEmail,
    // Activity column: the Action-Inventory name plus the affected account's
    // email (the user the action was performed on).
    activityLabel: auditActivityLabel(row),
    // Participant ID column (Study Coordinator view); empty for rows with no
    // participant association.
    participantId: auditParticipantId(row),
    raw: row,
  );
}
