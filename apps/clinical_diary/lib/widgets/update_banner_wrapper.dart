// IMPLEMENTS REQUIREMENTS:
//   REQ-d00006: Mobile App Build and Release Process

import 'package:clinical_diary/services/version_check_service.dart';
import 'package:clinical_diary/utils/web_update_helper.dart';
import 'package:clinical_diary/widgets/update_banner.dart';
import 'package:clinical_diary/widgets/update_dialog.dart';
import 'package:flutter/material.dart';

/// Wrapper widget that handles version checking and update notifications
///
/// Wraps the app content and displays update notifications:
/// - Shows [UpdateBanner] for optional updates (dismissible)
/// - Shows [UpdateDialog] for required updates (non-dismissible)
///
/// Version checks respect a 24-hour interval to avoid excessive network calls.
class UpdateBannerWrapper extends StatefulWidget {
  const UpdateBannerWrapper({
    required this.child,
    this.versionCheckService,
    super.key,
  });

  /// The app content to wrap
  final Widget child;

  /// Optional version check service (for testing)
  final VersionCheckService? versionCheckService;

  @override
  State<UpdateBannerWrapper> createState() => _UpdateBannerWrapperState();
}

class _UpdateBannerWrapperState extends State<UpdateBannerWrapper> {
  late final VersionCheckService _versionService;

  VersionCheckResult? _checkResult;
  bool _isDismissed = false;
  bool _hasShownRequiredDialog = false;

  @override
  void initState() {
    super.initState();
    _versionService = widget.versionCheckService ?? VersionCheckService();
    _checkForUpdates();
  }

  Future<void> _checkForUpdates() async {
    // Only check if we should (respects 24-hour interval)
    final shouldCheck = await _versionService.shouldCheckForUpdate();
    if (!shouldCheck) {
      debugPrint('UpdateBannerWrapper: Skipping check (within 24h interval)');
      return;
    }

    try {
      final result = await _versionService.checkForUpdate();

      if (mounted) {
        // Record check time
        await _versionService.recordCheckTime();

        // Check if this version was already dismissed
        if (result.remoteVersion != null) {
          final wasDismissed = await _versionService.isVersionDismissed(
            result.remoteVersion!,
          );
          _isDismissed = wasDismissed && !result.isRequired;
        }

        setState(() {
          _checkResult = result;
        });

        // Show required update dialog immediately
        if (result.isRequired && !_hasShownRequiredDialog && mounted) {
          _hasShownRequiredDialog = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _showRequiredUpdateDialog();
            }
          });
        }
      }
    } catch (e) {
      debugPrint('UpdateBannerWrapper: Check failed: $e');
    }
  }

  void _showRequiredUpdateDialog() {
    if (_checkResult == null) return;

    UpdateDialog.show(
      context,
      currentVersion: _checkResult!.localVersion ?? '0.0.0',
      requiredVersion: _checkResult!.remoteVersion ?? '0.0.0',
      onUpdate: _performUpdate,
      releaseNotes: _checkResult!.releaseNotes,
    );
  }

  void _performUpdate() {
    // On web, clear cache and reload
    // On native, this would open the appropriate store
    clearCacheAndReload();
  }

  void _dismissBanner() {
    if (_checkResult?.remoteVersion != null) {
      _versionService.dismissVersion(_checkResult!.remoteVersion!);
    }
    setState(() => _isDismissed = true);
  }

  @override
  Widget build(BuildContext context) {
    // Determine if we should show the banner
    // Don't show if localVersion is '0.0.0' (dev mode without dart-define)
    final showBanner =
        _checkResult != null &&
        _checkResult!.hasUpdate &&
        _checkResult!.localVersion != '0.0.0' &&
        !_checkResult!.isRequired && // Required updates show dialog, not banner
        !_isDismissed;

    if (!showBanner) {
      return widget.child;
    }

    return Stack(
      children: [
        // App content fills the space
        widget.child,
        // Update banner overlays at the top
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Material(
            elevation: 4,
            child: UpdateBanner(
              newVersion: _checkResult!.remoteVersion ?? '',
              releaseNotes: _checkResult!.releaseNotes,
              onUpdate: _performUpdate,
              onDismiss: _dismissBanner,
            ),
          ),
        ),
      ],
    );
  }
}
