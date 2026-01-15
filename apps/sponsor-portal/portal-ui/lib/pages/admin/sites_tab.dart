// IMPLEMENTS REQUIREMENTS:
//   REQ-d00035: Admin Dashboard Implementation
//   REQ-CAL-p00010: Schema-Driven Data Validation (EDC site display)
//
// Sites tab for Admin Dashboard - displays sites synced from EDC (RAVE)

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../services/api_client.dart';
import '../../services/auth_service.dart';

/// Model for a clinical trial site
class Site {
  final String siteId;
  final String siteName;
  final String siteNumber;
  final DateTime? edcSyncedAt;

  Site({
    required this.siteId,
    required this.siteName,
    required this.siteNumber,
    this.edcSyncedAt,
  });

  factory Site.fromJson(Map<String, dynamic> json) {
    return Site(
      siteId: json['site_id'] as String,
      siteName: json['site_name'] as String,
      siteNumber: json['site_number'] as String,
      edcSyncedAt: json['edc_synced_at'] != null
          ? DateTime.parse(json['edc_synced_at'] as String)
          : null,
    );
  }
}

/// Sites tab widget for Admin Dashboard
class SitesTab extends StatefulWidget {
  const SitesTab({super.key});

  @override
  State<SitesTab> createState() => _SitesTabState();
}

class _SitesTabState extends State<SitesTab> {
  List<Site>? _sites;
  Map<String, dynamic>? _syncInfo;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSites();
  }

  Future<void> _loadSites() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final authService = context.read<AuthService>();
    final apiClient = ApiClient(authService);

    final response = await apiClient.get('/api/v1/portal/sites');

    if (!mounted) return;

    if (response.isSuccess && response.data != null) {
      final data = response.data as Map<String, dynamic>;
      final sitesJson = data['sites'] as List<dynamic>? ?? [];
      final sites = sitesJson
          .map((s) => Site.fromJson(s as Map<String, dynamic>))
          .toList();

      setState(() {
        _sites = sites;
        _syncInfo = data['sync'] as Map<String, dynamic>?;
        _isLoading = false;
      });
    } else {
      setState(() {
        _error = response.error ?? 'Failed to load sites';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text('Error loading sites', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _loadSites,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final sites = _sites ?? [];

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with sync info
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Clinical Sites',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Sites synced from Medidata RAVE EDC',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              // Sync status chip
              if (_syncInfo != null) _buildSyncChip(theme),
              const SizedBox(width: 8),
              // Refresh button
              IconButton.filled(
                onPressed: _loadSites,
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh sites',
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Sites table
          if (sites.isEmpty)
            _buildEmptyState(theme)
          else
            Expanded(
              child: Card(
                child: SingleChildScrollView(
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(
                      theme.colorScheme.surfaceContainerHighest,
                    ),
                    columns: const [
                      DataColumn(label: Text('Site Number')),
                      DataColumn(label: Text('Site Name')),
                      DataColumn(label: Text('Site ID')),
                      DataColumn(label: Text('Last Synced')),
                    ],
                    rows: sites
                        .map((site) => _buildSiteRow(site, theme))
                        .toList(),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSyncChip(ThemeData theme) {
    final syncInfo = _syncInfo!;
    final hasError = syncInfo['error'] != null;
    final created = syncInfo['sites_created'] as int? ?? 0;
    final updated = syncInfo['sites_updated'] as int? ?? 0;

    if (hasError) {
      return Tooltip(
        message: syncInfo['error'] as String,
        child: Chip(
          avatar: Icon(
            Icons.warning_amber,
            size: 18,
            color: theme.colorScheme.error,
          ),
          label: const Text('Sync warning'),
          backgroundColor: theme.colorScheme.errorContainer,
        ),
      );
    }

    if (created > 0 || updated > 0) {
      return Chip(
        avatar: Icon(
          Icons.check_circle,
          size: 18,
          color: theme.colorScheme.primary,
        ),
        label: Text('Synced: $created new, $updated updated'),
        backgroundColor: theme.colorScheme.primaryContainer,
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.location_city_outlined,
              size: 64,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text('No Sites Available', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'Sites will appear here once synced from the EDC system.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (_syncInfo?['error'] != null) ...[
              const SizedBox(height: 16),
              Text(
                'Sync error: ${_syncInfo!['error']}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  DataRow _buildSiteRow(Site site, ThemeData theme) {
    final dateFormat = DateFormat('MMM d, yyyy h:mm a');

    return DataRow(
      cells: [
        DataCell(
          Text(
            site.siteNumber,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        DataCell(Text(site.siteName)),
        DataCell(
          Text(
            site.siteId,
            style: TextStyle(
              fontFamily: 'monospace',
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        DataCell(
          Text(
            site.edcSyncedAt != null
                ? dateFormat.format(site.edcSyncedAt!.toLocal())
                : 'Never',
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}
