import 'package:clinical_diary/services/task_service.dart';
import 'package:clinical_diary/widgets/task_list_widget.dart';
import 'package:flutter/material.dart';
import 'package:trial_data_types/trial_data_types.dart';

/// A single alert presented as a row on the [ImportantScreen] (and used to
/// derive the home-screen "N more important items" summary count).
///
/// This is the page-row projection of a home alert: just enough to render a
/// tappable row. The home screen keeps the richer, bespoke inline banner for
/// whichever alert it shows in the top slot.
class ImportantAlert {
  const ImportantAlert({
    required this.icon,
    required this.color,
    required this.title,
    this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;

  /// Action invoked when the row is tapped. Null for purely informational
  /// alerts (e.g. the non-dismissible disconnection notice). The screen pops
  /// itself before invoking, so the action runs in the home context.
  final VoidCallback? onTap;
}

/// The "Important" overflow page: the full list of active alerts followed by
/// the full task list, in two clearly separated sections.
///
/// Reached from the home screen's collapsed "N more important items" row. The
/// home screen shows only the single most-urgent item inline; everything
/// (including that top item) is listed here so the page is the complete view.
//
// Implements: DIARY-GUI-main-screen-layout/A+C — the overflow destination for
//   the Main Screen's important-items area: actionable items consolidated in
//   one place, alerts above tasks, in priority order. NOTE: the consolidated /
//   collapse model is not yet reflected in the requirement's assertions (which
//   still describe separate System Notice Area + Task List zones); that
//   divergence is to be reconciled in a later spec pass.
class ImportantScreen extends StatelessWidget {
  const ImportantScreen({
    required this.alerts,
    required this.taskService,
    this.onTaskTap,
    super.key,
  });

  final List<ImportantAlert> alerts;
  final TaskService taskService;
  final ValueChanged<Task>? onTaskTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        // TODO(i18n): localize.
        title: const Text('Important'),
      ),
      // The task list is reactive (ListenableBuilder inside TaskListWidget), so
      // the Tasks section keeps itself current while this page is open.
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          if (alerts.isNotEmpty) ...[
            _SectionHeader(theme: theme, label: 'Alerts'),
            for (final alert in alerts)
              _AlertRow(
                alert: alert,
                // Pop back to home before running the action so it executes in
                // the home navigation context (where the handlers expect to be).
                onTap: alert.onTap == null
                    ? null
                    : () {
                        Navigator.of(context).pop();
                        alert.onTap!.call();
                      },
              ),
          ],
          if (taskService.tasks.isNotEmpty) ...[
            _SectionHeader(theme: theme, label: 'Tasks'),
            TaskListWidget(
              taskService: taskService,
              onTaskTap: (task) {
                Navigator.of(context).pop();
                onTaskTap?.call(task);
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.theme, required this.label});

  final ThemeData theme;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      // TODO(i18n): localize section labels ('Alerts', 'Tasks').
      child: Text(
        label.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _AlertRow extends StatelessWidget {
  const _AlertRow({required this.alert, this.onTap});

  final ImportantAlert alert;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: alert.color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(alert.icon, color: alert.color, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        alert.title,
                        style: TextStyle(
                          color: alert.color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (alert.subtitle != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            alert.subtitle!,
                            style: TextStyle(
                              color: alert.color.withValues(alpha: 0.8),
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (onTap != null)
                  Icon(
                    Icons.chevron_right,
                    color: alert.color.withValues(alpha: 0.7),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
