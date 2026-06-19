import 'package:flutter/material.dart';

/// Wraps [child] and renders a non-blocking "a new version is available" strip
/// above it when [visible] is true, with a Reload control that invokes
/// [onReload]. Unlike the transport-status banner this never blocks input — the
/// User can keep working and reload when ready (e.g. after finishing a form).
///
/// Shown to an authenticated User when the deployed server reports a newer
/// portal UI version than the running bundle. On the login screen the app
/// auto-reloads instead, so the banner there is only a fallback when an
/// automatic reload returned a still-stale bundle (the loop guard).
// Implements: DIARY-BASE-portal-stale-client-reload/A
class UpdateAvailableBanner extends StatelessWidget {
  const UpdateAvailableBanner({
    super.key,
    required this.visible,
    required this.onReload,
    required this.child,
  });

  /// Whether the update strip is shown above [child].
  final bool visible;

  /// Invoked when the User taps Reload — wired to a full-document reload.
  final VoidCallback onReload;

  /// Content rendered below the strip (the app's normal home).
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        if (visible) _banner(context),
        Expanded(child: child),
      ],
    );
  }

  Widget _banner(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      key: const Key('update-available-banner'),
      identifier: 'update-available-banner',
      liveRegion: true,
      child: Material(
        color: scheme.primaryContainer,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: <Widget>[
              Icon(
                Icons.system_update_alt,
                size: 18,
                color: scheme.onPrimaryContainer,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'A new version is available.',
                  style: TextStyle(color: scheme.onPrimaryContainer),
                ),
              ),
              TextButton(onPressed: onReload, child: const Text('Reload')),
            ],
          ),
        ),
      ),
    );
  }
}
