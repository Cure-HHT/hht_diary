// IMPLEMENTS REQUIREMENTS:
//   REQ-CAL-p00063: EDC Patient Ingestion
//   REQ-CAL-p00073: Patient Status Definitions
//   REQ-CAL-p00019: Link New Patient Workflow
//   REQ-CAL-p00049: Mobile Linking Codes
//   REQ-p00024: Portal User Roles and Permissions
//   REQ-p70007: Linking Code Lifecycle Management
//   REQ-CAL-p00020: Patient Disconnection Workflow
//   REQ-CAL-p00021: Patient Reconnection Workflow
//   REQ-CAL-p00066: Status Change Reason Field
//   REQ-CAL-p00064: Mark Patient as Not Participating
//   REQ-CAL-p00079: Start Trial Workflow
//   REQ-CAL-p00023: Nose and Quality of Life Questionnaire Workflow
//
// Study Coordinator Patients Tab - site-scoped patient dashboard with
// search, status filtering, and contextual actions

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../widgets/link_participant_dialog.dart';
import '../../widgets/participant_actions_dialog.dart';
import '../../widgets/rave_sync_banner.dart';
import '../../widgets/reactivate_participant_dialog.dart';
import '../../widgets/manage_questionnaires_dialog.dart';
import '../../widgets/start_trial_dialog.dart';

/// Status filter for the participants tab
enum ParticipantStatusFilter {
  all('All'),
  notConnected('Not Connected'),
  active('Active'),
  inactive('Inactive');

  final String label;
  const ParticipantStatusFilter(this.label);
}

/// Model for a participant in the Study Coordinator view
class _ParticipantData {
  final String participantId;
  final String siteId;
  final String edcSubjectKey;
  final String mobileLinkingStatus;
  final DateTime? edcSyncedAt;
  final String siteName;
  final String siteNumber;
  final bool trialStarted;
  final bool hasActiveLinkingCode;

  _ParticipantData({
    required this.participantId,
    required this.siteId,
    required this.edcSubjectKey,
    required this.mobileLinkingStatus,
    this.edcSyncedAt,
    required this.siteName,
    required this.siteNumber,
    required this.trialStarted,
    required this.hasActiveLinkingCode,
  });

  factory _ParticipantData.fromJson(Map<String, dynamic> json) {
    return _ParticipantData(
      participantId: json['patient_id'] as String,
      siteId: json['site_id'] as String,
      edcSubjectKey: json['edc_subject_key'] as String,
      mobileLinkingStatus: json['mobile_linking_status'] as String,
      edcSyncedAt: json['edc_synced_at'] != null
          ? DateTime.parse(json['edc_synced_at'] as String)
          : null,
      siteName: json['site_name'] as String,
      siteNumber: json['site_number'] as String,
      trialStarted: json['trial_started'] as bool? ?? false,
      hasActiveLinkingCode: json['has_active_linking_code'] as bool? ?? false,
    );
  }

  /// Categorize the participant for filter tabs
  /// Per REQ-CAL-p00073:
  /// - Not Connected: not_connected, linking_in_progress (Pending)
  /// - Active: connected (both "Linked - Awaiting Start" and "Trial Active")
  /// - Inactive: disconnected, not_participating
  ParticipantStatusFilter get statusCategory {
    switch (mobileLinkingStatus) {
      case 'not_connected':
      case 'linking_in_progress': // "Pending" status belongs in Not Connected tab
        return ParticipantStatusFilter.notConnected;
      case 'connected':
        return ParticipantStatusFilter.active;
      case 'disconnected':
      case 'not_participating':
        return ParticipantStatusFilter.inactive;
      default:
        return ParticipantStatusFilter.notConnected;
    }
  }
}

/// Site info from assigned_sites response
class _SiteInfo {
  final String siteId;
  final String siteName;
  final String siteNumber;

  _SiteInfo({
    required this.siteId,
    required this.siteName,
    required this.siteNumber,
  });

  factory _SiteInfo.fromJson(Map<String, dynamic> json) {
    return _SiteInfo(
      siteId: json['site_id'] as String,
      siteName: json['site_name'] as String,
      siteNumber: json['site_number'] as String,
    );
  }
}

/// Study Coordinator Participants Tab widget
class StudyCoordinatorParticipantsTab extends StatefulWidget {
  /// Creates a StudyCoordinatorParticipantsTab.
  ///
  /// The [apiClient] parameter is optional and intended for testing.
  /// If not provided, a new ApiClient will be created internally.
  const StudyCoordinatorParticipantsTab({super.key, this.apiClient});

  /// Optional ApiClient for dependency injection (used in tests)
  final ApiClient? apiClient;

  @override
  State<StudyCoordinatorParticipantsTab> createState() =>
      _StudyCoordinatorParticipantsTabState();
}

class _StudyCoordinatorParticipantsTabState
    extends State<StudyCoordinatorParticipantsTab> {
  List<_ParticipantData>? _participants;
  List<_SiteInfo> _assignedSites = [];
  bool _isLoading = true;
  String? _error;
  ParticipantStatusFilter _activeFilter = ParticipantStatusFilter.all;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  // Rave sync lockout banner state (CUR-1361 / DIARY-GUI-rave-sync-paused-banner).
  // Parsed from the `rave_sync` block on the /participants response.
  String _raveSyncState = 'ok';
  DateTime? _ravePausedUntil;
  DateTime? _raveSince;

  @override
  void initState() {
    super.initState();
    _loadParticipants();
    // Warm the MaterialIcons font cache so the dialog's icons render
    // immediately when the user opens it (web release builds load this
    // font lazily).
    ManageQuestionnairesDialog.precacheIconFont();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadParticipants() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final authService = context.read<AuthService>();
    final apiClient = widget.apiClient ?? ApiClient(authService);

    final response = await apiClient.get('/api/v1/portal/participants');

    if (!mounted) return;

    if (response.isSuccess && response.data != null) {
      final data = response.data as Map<String, dynamic>;
      final participantsJson = data['patients'] as List<dynamic>? ?? [];
      final participants = participantsJson
          .map((p) => _ParticipantData.fromJson(p as Map<String, dynamic>))
          .toList();

      // Parse assigned sites if present
      final sitesJson = data['assigned_sites'] as List<dynamic>? ?? [];
      final sites = sitesJson
          .map((s) => _SiteInfo.fromJson(s as Map<String, dynamic>))
          .toList();

      // Parse the Rave sync lockout block (CUR-1361). Backend omits the
      // block entirely if the lookup fails — treat missing as 'ok'.
      final raveSync = data['rave_sync'] as Map<String, dynamic>?;
      final raveState = raveSync?['state'] as String? ?? 'ok';
      final pausedUntilRaw = raveSync?['paused_until'] as String?;
      final sinceRaw = raveSync?['since'] as String?;

      setState(() {
        _participants = participants;
        _assignedSites = sites;
        _raveSyncState = raveState;
        _ravePausedUntil = pausedUntilRaw != null
            ? DateTime.tryParse(pausedUntilRaw)
            : null;
        _raveSince = sinceRaw != null ? DateTime.tryParse(sinceRaw) : null;
        _isLoading = false;
      });
    } else {
      setState(() {
        _error = response.error ?? 'Failed to load participants';
        _isLoading = false;
      });
    }
  }

  /// Get participants filtered by current status filter and search query
  List<_ParticipantData> get _filteredParticipants {
    if (_participants == null) return [];
    var filtered = _participants!.toList();

    // Apply status filter
    if (_activeFilter != ParticipantStatusFilter.all) {
      filtered = filtered
          .where((p) => p.statusCategory == _activeFilter)
          .toList();
    }

    // Apply search query
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((p) {
        return p.participantId.toLowerCase().contains(query) ||
            p.siteName.toLowerCase().contains(query) ||
            p.siteNumber.toLowerCase().contains(query);
      }).toList();
    }

    return filtered;
  }

  /// Count participants by status category
  int _countByStatus(ParticipantStatusFilter filter) {
    if (_participants == null) return 0;
    if (filter == ParticipantStatusFilter.all) return _participants!.length;
    return _participants!.where((p) => p.statusCategory == filter).length;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _buildErrorState(theme);
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Rave sync lockout banner (CUR-1361). Renders nothing when
          // state == 'ok'. Sits above the data so paused/locked state is
          // visible before the cached table.
          // Implements: DIARY-GUI-rave-sync-paused-banner/A
          RaveSyncBanner(
            state: _raveSyncState,
            pausedUntil: _ravePausedUntil,
            since: _raveSince,
          ),
          // Gate the spacer on the same states the banner actually renders.
          // RaveSyncBanner returns SizedBox.shrink() for unknown states; if
          // we keyed off `!= 'ok'`, an unknown backend value would still
          // insert a blank 16px gap above the table.
          if (_raveSyncState == 'cooldown' || _raveSyncState == 'locked')
            const SizedBox(height: 16),

          // My Sites section
          if (_assignedSites.isNotEmpty) ...[
            _buildMySitesSection(theme),
            const SizedBox(height: 24),
          ],

          // Participant Summary header with search
          _buildParticipantSummaryHeader(theme),
          const SizedBox(height: 16),

          // Status filter tabs
          _buildStatusFilterTabs(theme),
          const SizedBox(height: 16),

          // Participant data table
          Expanded(child: _buildParticipantTable(theme)),
        ],
      ),
    );
  }

  Widget _buildErrorState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
          const SizedBox(height: 16),
          Text(
            'Error loading participants',
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            _error!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _loadParticipants,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildMySitesSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'My Sites',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _assignedSites.map((site) {
            return Chip(
              avatar: Icon(
                Icons.location_city,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              label: Text('${site.siteNumber} - ${site.siteName}'),
              side: BorderSide(
                color: theme.colorScheme.primary.withValues(alpha: 0.3),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildParticipantSummaryHeader(ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Participant Summary',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${_participants?.length ?? 0} participants across ${_assignedSites.length} sites',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        // Search bar
        SizedBox(
          width: 300,
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search participants...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              isDense: true,
            ),
            onChanged: (value) {
              setState(() => _searchQuery = value);
            },
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filled(
          onPressed: _loadParticipants,
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh participants',
        ),
      ],
    );
  }

  Widget _buildStatusFilterTabs(ThemeData theme) {
    return Row(
      children: ParticipantStatusFilter.values.map((filter) {
        final count = _countByStatus(filter);
        final isActive = _activeFilter == filter;

        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: FilterChip(
            selected: isActive,
            label: Text('${filter.label} ($count)'),
            onSelected: (_) {
              setState(() => _activeFilter = filter);
            },
            selectedColor: theme.colorScheme.primaryContainer,
            checkmarkColor: theme.colorScheme.primary,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildParticipantTable(ThemeData theme) {
    final filtered = _filteredParticipants;

    if (filtered.isEmpty) {
      return _buildEmptyFilterState(theme);
    }

    return Card(
      child: SingleChildScrollView(
        child: SizedBox(
          width: double.infinity,
          child: DataTable(
            showCheckboxColumn: false,
            headingRowColor: WidgetStateProperty.all(
              theme.colorScheme.surfaceContainerHighest,
            ),
            columns: const [
              DataColumn(label: Text('Participant ID')),
              DataColumn(label: Text('Site')),
              DataColumn(label: Text('Mobile Linking')),
              DataColumn(label: Text('Actions')),
            ],
            rows: filtered
                .map((participant) => _buildParticipantRow(participant, theme))
                .toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyFilterState(ThemeData theme) {
    final hasParticipants = _participants != null && _participants!.isNotEmpty;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            hasParticipants ? Icons.filter_list_off : Icons.person_outline,
            size: 64,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            hasParticipants
                ? 'No Matching Participants'
                : 'No Participants Available',
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            hasParticipants
                ? 'Try adjusting your search or filter criteria.'
                : 'Participants will appear here once synced from the EDC system.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  DataRow _buildParticipantRow(_ParticipantData participant, ThemeData theme) {
    final authService = context.read<AuthService>();
    final apiClient = widget.apiClient ?? ApiClient(authService);

    return DataRow(
      onSelectChanged: (_) => _openParticipantActions(participant, apiClient),
      cells: [
        // Participant ID
        DataCell(
          Text(
            participant.participantId,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        // Site
        DataCell(Text('${participant.siteNumber} - ${participant.siteName}')),
        // Mobile Linking Status
        DataCell(_buildLinkingStatusChip(participant, theme)),
        // Actions
        DataCell(_buildActionButton(participant, theme)),
      ],
    );
  }

  Widget _buildLinkingStatusChip(
    _ParticipantData participant,
    ThemeData theme,
  ) {
    final status = participant.mobileLinkingStatus;

    // For connected participants, show different status based on trial_started
    final (label, color, icon) = switch (status) {
      'connected' =>
        participant.trialStarted
            ? ('Trial Active', theme.colorScheme.primary, Icons.check_circle)
            : (
                'Linked - Awaiting Start',
                theme.colorScheme.tertiary,
                Icons.hourglass_top,
              ),
      'linking_in_progress' =>
        participant.hasActiveLinkingCode
            ? ('Pending', theme.colorScheme.tertiary, Icons.hourglass_top)
            : ('Expired', theme.colorScheme.error, Icons.schedule),
      'disconnected' => (
        'Disconnected',
        theme.colorScheme.error,
        Icons.link_off,
      ),
      'not_participating' => (
        'Not Participating',
        theme.colorScheme.outline,
        Icons.person_off,
      ),
      _ => (
        'Not Connected',
        theme.colorScheme.outline,
        Icons.remove_circle_outline,
      ),
    };

    return Chip(
      avatar: Icon(icon, size: 16, color: color),
      label: Text(label, style: TextStyle(fontSize: 12, color: color)),
      side: BorderSide(color: color.withValues(alpha: 0.3)),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildActionButton(_ParticipantData participant, ThemeData theme) {
    final authService = context.read<AuthService>();
    final apiClient = ApiClient(authService);

    switch (participant.mobileLinkingStatus) {
      case 'not_connected':
        return TextButton.icon(
          onPressed: () => _linkParticipant(participant, apiClient),
          icon: const Icon(Icons.link, size: 16),
          label: const Text('Link Participant'),
          style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
        );
      case 'linking_in_progress':
        if (participant.hasActiveLinkingCode) {
          return TextButton.icon(
            onPressed: () => _showLinkingCode(participant, apiClient),
            icon: const Icon(Icons.qr_code, size: 16),
            label: const Text('Show Code'),
            style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
          );
        }
        return TextButton.icon(
          onPressed: () => _linkParticipant(participant, apiClient),
          icon: const Icon(Icons.refresh, size: 16),
          label: const Text('Generate New Code'),
          style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
        );
      case 'connected':
        // REQ-CAL-p00079: Show Start Trial for connected participants with !trialStarted
        // REQ-CAL-p00073: Show Disconnect for connected participants with trialStarted
        if (!participant.trialStarted) {
          return TextButton.icon(
            onPressed: () => _startTrial(participant, apiClient),
            icon: const Icon(Icons.play_arrow, size: 16),
            label: const Text('Start Trial'),
            style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
          );
        }
        // Trial already started - manage questionnaires
        return TextButton.icon(
          onPressed: () => _manageQuestionnaires(participant, apiClient),
          icon: const Icon(Icons.assignment, size: 16),
          label: const Text('Manage Questionnaires'),
          style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
        );
      case 'disconnected':
        return TextButton.icon(
          onPressed: () => _openParticipantActions(participant, apiClient),
          icon: const Icon(Icons.more_horiz, size: 16),
          label: const Text('Actions'),
          style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
        );
      case 'not_participating':
        return TextButton.icon(
          onPressed: () => _reactivateParticipant(participant, apiClient),
          icon: const Icon(Icons.refresh, size: 16),
          label: const Text('Reactivate'),
          style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  /// Opens the LinkParticipantDialog to generate a new linking code
  Future<void> _linkParticipant(
    _ParticipantData participant,
    ApiClient apiClient,
  ) async {
    final success = await LinkParticipantDialog.show(
      context: context,
      participantId: participant.participantId,
      participantDisplayId: participant.edcSubjectKey,
      apiClient: apiClient,
    );

    // Refresh the participant list if a code was generated
    if (success && mounted) {
      await _loadParticipants();
    }
  }

  /// Opens the ShowLinkingCodeDialog to display an existing code
  Future<void> _showLinkingCode(
    _ParticipantData participant,
    ApiClient apiClient,
  ) async {
    await ShowLinkingCodeDialog.show(
      context: context,
      participantId: participant.participantId,
      participantDisplayId: participant.edcSubjectKey,
      apiClient: apiClient,
    );
  }

  /// Opens the StartTrialDialog to start trial for a participant
  Future<void> _startTrial(
    _ParticipantData participant,
    ApiClient apiClient,
  ) async {
    final success = await StartTrialDialog.show(
      context: context,
      participantId: participant.participantId,
      participantDisplayId: participant.edcSubjectKey,
      apiClient: apiClient,
    );

    // Refresh the participant list if trial was started
    if (success && mounted) {
      await _loadParticipants();
    }
  }

  /// Opens the ParticipantActionsDialog for disconnected participants
  Future<void> _openParticipantActions(
    _ParticipantData participant,
    ApiClient apiClient,
  ) async {
    final authService = context.read<AuthService>();
    final result = await ParticipantActionsDialog.show(
      context: context,
      participantId: participant.participantId,
      participantDisplayId: participant.edcSubjectKey,
      mobileLinkingStatus: participant.mobileLinkingStatus,
      apiClient: apiClient,
      disconnectReasonDropdown: authService.disconnectReasonDropdown,
    );

    // Refresh the participant list if an action was taken
    if (result == ParticipantActionResult.actionTaken && mounted) {
      await _loadParticipants();
    }
  }

  /// Opens the ManageQuestionnairesDialog for trial-active participants
  Future<void> _manageQuestionnaires(
    _ParticipantData participant,
    ApiClient apiClient,
  ) async {
    await ManageQuestionnairesDialog.show(
      context: context,
      participantId: participant.participantId,
      participantDisplayId: participant.edcSubjectKey,
      apiClient: apiClient,
    );
  }

  /// Opens the ReactivateParticipantDialog to reactivate a not_participating participant
  Future<void> _reactivateParticipant(
    _ParticipantData participant,
    ApiClient apiClient,
  ) async {
    final success = await ReactivateParticipantDialog.show(
      context: context,
      participantId: participant.participantId,
      participantDisplayId: participant.edcSubjectKey,
      apiClient: apiClient,
    );

    // Refresh the participant list if reactivation was successful
    if (success && mounted) {
      await _loadParticipants();
    }
  }
}
