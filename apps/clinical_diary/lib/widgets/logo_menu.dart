// IMPLEMENTS REQUIREMENTS:
//   REQ-p00008: Mobile App Diary Entry
//   REQ-d00006: Mobile App Build and Release Process

import 'package:clinical_diary/l10n/app_localizations.dart';
import 'package:clinical_diary/services/version_check_service.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Logo menu widget with data management and clinical trial options
class LogoMenu extends StatefulWidget {
  const LogoMenu({
    required this.onExportData,
    required this.onImportData,
    required this.onResetAllData,
    required this.onFeatureFlags,
    required this.onEndClinicalTrial,
    required this.onInstructionsAndFeedback,
    this.showDevTools = true,
    super.key,
  });

  final VoidCallback onExportData;
  final VoidCallback onImportData;
  final VoidCallback onResetAllData;
  final VoidCallback onFeatureFlags;
  final VoidCallback? onEndClinicalTrial;
  final VoidCallback onInstructionsAndFeedback;

  /// Whether to show developer tools (Reset All Data, Import/Export Data, Feature Flags).
  /// Should be false in production and UAT environments.
  final bool showDevTools;

  @override
  State<LogoMenu> createState() => _LogoMenuState();
}

class _LogoMenuState extends State<LogoMenu> {
  String _version = '';
  bool _hasUpdate = false;
  bool _isCheckingForUpdates = false;
  late final VersionCheckService _versionService;

  @override
  void initState() {
    super.initState();
    _versionService = VersionCheckService();
    _loadVersion();
    _checkForUpdates();
  }

  Future<void> _loadVersion() async {
    // Use package_info_plus for display (works in dev and prod on all platforms)
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _version = packageInfo.version;
        });
      }
    } catch (e) {
      debugPrint('PackageInfo error: $e');
    }
  }

  Future<void> _checkForUpdates() async {
    try {
      // Check if we should check (respects 24-hour interval)
      final shouldCheck = await _versionService.shouldCheckForUpdate();
      if (!shouldCheck) return;

      final result = await _versionService.checkForUpdate();

      // Don't show update indicator if local version is '0.0.0' (dev mode)
      // or if this version was dismissed
      if (result.hasUpdate &&
          result.remoteVersion != null &&
          result.localVersion != '0.0.0') {
        final wasDismissed = await _versionService.isVersionDismissed(
          result.remoteVersion!,
        );
        if (mounted && !wasDismissed) {
          setState(() {
            _hasUpdate = true;
          });
        }
      }
    } catch (e) {
      debugPrint('Update check error: $e');
    }
  }

  /// Manually check for updates (bypasses 24-hour interval)
  Future<void> _manualCheckForUpdates(BuildContext context) async {
    if (_isCheckingForUpdates) return;

    // Capture these before any async gaps
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);

    setState(() {
      _isCheckingForUpdates = true;
    });

    try {
      final result = await _versionService.checkForUpdate();
      await _versionService.recordCheckTime();

      if (!mounted) return;

      if (result.hasUpdate &&
          result.remoteVersion != null &&
          result.localVersion != '0.0.0') {
        // Clear any previous dismissal so the update shows
        await _versionService.clearDismissedVersion();
        if (!mounted) return;
        setState(() {
          _hasUpdate = true;
        });
        // Show snackbar that update is available
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(l10n.newVersionAvailable(result.remoteVersion!)),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        setState(() {
          _hasUpdate = false;
        });
        // Show snackbar that no update is available
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(l10n.youAreUpToDate),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('Manual update check error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingForUpdates = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PopupMenuButton<String>(
      tooltip: l10n.appMenu,
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            ColorFiltered(
              colorFilter: ColorFilter.mode(
                Colors.grey.withValues(alpha: 0.5),
                BlendMode.srcATop,
              ),
              child: Image.asset(
                'assets/images/cure-hht-grey.png',
                width: 100,
                height: 40,
                fit: BoxFit.contain,
              ),
            ),
            // Update indicator dot
            if (_hasUpdate)
              Positioned(
                right: -2,
                top: -2,
                child: Tooltip(
                  message: l10n.updateAvailable,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Theme.of(context).colorScheme.surface,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      onSelected: (value) {
        switch (value) {
          case 'export_data':
            widget.onExportData();
          case 'import_data':
            widget.onImportData();
          case 'reset_all_data':
            widget.onResetAllData();
          case 'feature_flags':
            widget.onFeatureFlags();
          case 'end_clinical_trial':
            widget.onEndClinicalTrial?.call();
          case 'instructions_feedback':
            widget.onInstructionsAndFeedback();
          case 'check_for_updates':
            _manualCheckForUpdates(context);
        }
      },
      itemBuilder: (context) => [
        // Data Management section header (only shown in dev/test environments)
        if (widget.showDevTools) ...[
          PopupMenuItem<String>(
            enabled: false,
            child: Text(
              l10n.dataManagement,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          PopupMenuItem<String>(
            value: 'export_data',
            child: Row(
              children: [
                Icon(
                  Icons.upload_outlined,
                  size: 20,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                const SizedBox(width: 12),
                Flexible(child: Text(l10n.exportData)),
              ],
            ),
          ),
          PopupMenuItem<String>(
            value: 'import_data',
            child: Row(
              children: [
                Icon(
                  Icons.download_outlined,
                  size: 20,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                const SizedBox(width: 12),
                Flexible(child: Text(l10n.importData)),
              ],
            ),
          ),
          PopupMenuItem<String>(
            value: 'reset_all_data',
            child: Row(
              children: [
                Icon(
                  Icons.delete_outline,
                  size: 20,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    l10n.resetAllData,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ],
            ),
          ),
          PopupMenuItem<String>(
            value: 'feature_flags',
            child: Row(
              children: [
                Icon(
                  Icons.science_outlined,
                  size: 20,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                const SizedBox(width: 12),
                Flexible(child: Text(l10n.featureFlagsTitle)),
              ],
            ),
          ),
        ],

        // Clinical Trial section (only if enrolled)
        if (widget.onEndClinicalTrial != null) ...[
          // Only add divider if dev tools section was shown
          if (widget.showDevTools) const PopupMenuDivider(),
          PopupMenuItem<String>(
            enabled: false,
            child: Text(
              l10n.clinicalTrialLabel,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          PopupMenuItem<String>(
            value: 'end_clinical_trial',
            child: Row(
              children: [
                Icon(
                  Icons.exit_to_app,
                  size: 20,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                const SizedBox(width: 12),
                Flexible(child: Text(l10n.endClinicalTrial)),
              ],
            ),
          ),
        ],

        // External links section
        // Only add divider if there was content above
        if (widget.showDevTools || widget.onEndClinicalTrial != null)
          const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'instructions_feedback',
          child: Row(
            children: [
              Icon(
                Icons.open_in_new,
                size: 20,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              const SizedBox(width: 12),
              Flexible(child: Text(l10n.instructionsAndFeedback)),
            ],
          ),
        ),

        // Version info at bottom
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'check_for_updates',
          child: Row(
            children: [
              if (_isCheckingForUpdates)
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                )
              else
                Icon(
                  _hasUpdate ? Icons.system_update : Icons.refresh,
                  size: 20,
                  color: _hasUpdate
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurface,
                ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  l10n.checkForUpdates,
                  style: _hasUpdate
                      ? TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        )
                      : null,
                ),
              ),
              if (_hasUpdate) ...[
                const SizedBox(width: 8),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        ),
        PopupMenuItem<String>(
          enabled: false,
          height: 32,
          child: Center(
            child: Text(
              _version.isNotEmpty ? 'v$_version' : '',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
