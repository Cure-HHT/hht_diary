// Implements: DIARY-PRD-incomplete-entry-preservation/B — list view of all
//   incomplete (checkpointed) records. Reached from the "Needs your attention"
//   tile on the home screen when there is more than one incomplete record; with
//   a single record the home screen jumps straight to the recording-screen edit
//   path. The list is reactive (DiaryViewBuilder), so completing a row from
//   here returns to a list that no longer contains it.
import 'package:clinical_diary/l10n/app_localizations.dart';
import 'package:clinical_diary/read/diary_entry_view.dart';
import 'package:clinical_diary/read/diary_view.dart';
import 'package:clinical_diary/read/diary_view_builder.dart';
import 'package:clinical_diary/screens/recording_screen.dart';
import 'package:clinical_diary/screens/settings_screen.dart';
import 'package:clinical_diary/utils/app_page_route.dart';
import 'package:clinical_diary/widgets/back_to_home_row.dart';
import 'package:clinical_diary/widgets/brand_header.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class IncompleteRecordsScreen extends StatelessWidget {
  const IncompleteRecordsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DiaryViewBuilder(builder: _buildScaffold);
  }

  Widget _buildScaffold(BuildContext context, DiaryView view) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final incomplete =
        view.incompleteEntries.whereType<EpistaxisEntryView>().toList()
          ..sort((a, b) => b.startTime.compareTo(a.startTime));

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BrandHeader(
              leading: Image.asset(
                'assets/images/cure-hht-grey.png',
                width: 107,
                height: 42,
                fit: BoxFit.contain,
              ),
              trailing: PopupMenuButton<String>(
                icon: const Icon(Icons.menu, color: Color(0xFF04161E)),
                tooltip: l10n.userMenu,
                onSelected: (value) => _handleMenuSelection(context, value),
                itemBuilder: _menuItems,
              ),
            ),
            BackToHomeRow(onBack: () => Navigator.of(context).pop()),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.incompleteRecords,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w600,
                        height: 1.1,
                        letterSpacing: -0.22,
                        color: Color(0xFF04161E),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // TODO(i18n): localize "Review and Complete".
                    const Text(
                      'Review and Complete',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        height: 26.4 / 22,
                        letterSpacing: -0.44,
                        color: Color(0xFF04161E),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // TODO(i18n): localize the explanatory copy.
                    const Text(
                      'Some records need more information before they can be '
                      'completed.',
                      style: TextStyle(
                        fontSize: 15,
                        height: 23.25 / 15,
                        letterSpacing: -0.22,
                        color: Color(0xFF54636A),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: incomplete.isEmpty
                          ? Center(
                              child: Text(
                                l10n.noRecords,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            )
                          : ListView.separated(
                              padding: EdgeInsets.zero,
                              itemCount: incomplete.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, i) => _IncompleteRecordRow(
                                entry: incomplete[i],
                                onTap: () => _openEdit(context, incomplete[i]),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openEdit(BuildContext context, EpistaxisEntryView entry) async {
    // The recording screen pops a String? (the aggregate id) on save; declaring
    // the route's result type matches that so a save-pop doesn't throw.
    await Navigator.of(context).push<String?>(
      AppPageRoute(builder: (context) => RecordingScreen(existing: entry)),
    );
  }

  /// Stateless subset of the home-screen user menu. Items that require the
  /// enrollment service (Profile, Enroll) aren't surfaced here — the
  /// participant can reach them from Home.
  List<PopupMenuEntry<String>> _menuItems(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return [
      PopupMenuItem(
        value: 'accessibility',
        child: Row(
          children: [
            const Icon(Icons.settings, size: 20),
            const SizedBox(width: 12),
            Text(l10n.accessibilityAndPreferences),
          ],
        ),
      ),
      PopupMenuItem(
        value: 'privacy',
        child: Row(
          children: [
            const Icon(Icons.privacy_tip, size: 20),
            const SizedBox(width: 12),
            Text(l10n.privacy),
          ],
        ),
      ),
    ];
  }

  Future<void> _handleMenuSelection(BuildContext context, String value) async {
    if (value == 'accessibility') {
      await Navigator.push(
        context,
        AppPageRoute<void>(builder: (_) => const SettingsScreen()),
      );
    } else if (value == 'privacy') {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).privacyComingSoon),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}

class _IncompleteRecordRow extends StatelessWidget {
  const _IncompleteRecordRow({required this.entry, required this.onTap});

  final EpistaxisEntryView entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;
    final timestamp = DateFormat(
      'hh:mm a MM/dd/yyyy',
      locale,
    ).format(entry.startTime);
    const accent = Color(0xFFB9790A);

    final radius = BorderRadius.circular(8);
    return Material(
      color: Colors.white,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          height: 50,
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFECEEF0), width: 1.111),
            borderRadius: radius,
          ),
          padding: const EdgeInsets.fromLTRB(13, 0, 9, 0),
          child: Row(
            children: [
              // TODO(i18n): localize "Incomplete Record".
              const Text(
                'Incomplete Record',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  height: 1.1,
                  letterSpacing: -0.22,
                  color: accent,
                ),
              ),
              const Spacer(),
              Text(
                timestamp,
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.1,
                  letterSpacing: -0.22,
                  color: accent,
                ),
              ),
              const SizedBox(width: 4),
              // Chevron rotated to point right (figma uses -90° rotated
              // arrow-down for the chevron-right affordance).
              const Icon(Icons.chevron_right, size: 28, color: accent),
            ],
          ),
        ),
      ),
    );
  }
}
