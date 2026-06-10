import 'package:diary_design_system/diary_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// One parameter row in a [StudySettingsSectionView].
@immutable
class StudySettingRowView {
  const StudySettingRowView({
    required this.label,
    required this.value,
    this.implemented = true,
    this.variableName,
  });

  /// Parameter display name (left column).
  final String label;

  /// Pre-formatted current value (right column). For rows the platform
  /// does not implement yet, the wiring layer passes the standard
  /// "Not yet implemented" copy with [implemented] false.
  final String value;

  /// False renders the value in the dimmer not-yet-implemented style so
  /// real values and placeholders are visually distinct at a glance.
  final bool implemented;

  /// The parameter's true source identifier (settings key, env var, or
  /// code symbol — e.g. `clinical.lockThresholdHours`). When the screen
  /// runs with [StudySettingsScreen.showVariableNames], hovering the row
  /// reveals it and clicking copies it, so a developer can grep for it.
  /// Null for rows with no backing implementation.
  final String? variableName;
}

/// One titled group of parameters on the Study Settings page.
@immutable
class StudySettingsSectionView {
  const StudySettingsSectionView({
    required this.title,
    required this.description,
    required this.rows,
  });

  final String title;
  final String description;
  final List<StudySettingRowView> rows;
}

/// Study Settings page — read-only table of the study's configuration
/// parameters, grouped into titled sections (Figma: Study Settings).
///
/// **Snapshot in, callbacks out.** The wiring layer (`portal_ui_evs`)
/// fetches `GET /config/study`, formats every value (including the
/// "Not yet implemented" placeholders), and hands the sections here;
/// the screen renders them and emits [onRetry] from the error state.
class StudySettingsScreen extends StatelessWidget {
  const StudySettingsScreen({
    super.key,
    required this.sections,
    required this.isLoading,
    required this.onRetry,
    this.errorMessage,
    this.showVariableNames = false,
  });

  final List<StudySettingsSectionView> sections;
  final bool isLoading;
  final VoidCallback onRetry;
  final String? errorMessage;

  /// Developer affordance for SystemOperator viewers: rows with a
  /// [StudySettingRowView.variableName] show it on hover and copy it to
  /// the clipboard on click. Off for regular roles.
  final bool showVariableNames;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      identifier: 'settings-screen',
      container: true,
      explicitChildNodes: true,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(48, 24, 48, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _Header(),
            const SizedBox(height: 16),
            const AppBanner(
              severity: AppBannerSeverity.info,
              message: 'These settings are view only.',
              semanticId: 'settings-banner',
            ),
            const SizedBox(height: 24),
            _Body(
              sections: sections,
              isLoading: isLoading,
              errorMessage: errorMessage,
              onRetry: onRetry,
              showVariableNames: showVariableNames,
              theme: theme,
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Study Settings',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 32,
            height: 40 / 32,
            letterSpacing: -0.5,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'View current configuration settings for this study.',
          style: TextStyle(
            fontWeight: FontWeight.w400,
            fontSize: 14,
            height: 20 / 14,
            letterSpacing: -0.15,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.sections,
    required this.isLoading,
    required this.errorMessage,
    required this.onRetry,
    required this.showVariableNames,
    required this.theme,
  });

  final List<StudySettingsSectionView> sections;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onRetry;
  final bool showVariableNames;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.fromLTRB(32, 32, 32, 32),
      child: _cardContent(context),
    );

    if (!isLoading || errorMessage != null) return card;
    return Stack(
      fit: StackFit.passthrough,
      children: [
        card,
        const Positioned.fill(
          child: ColoredBox(
            color: Colors.black12,
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
      ],
    );
  }

  Widget _cardContent(BuildContext context) {
    if (errorMessage != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Couldn't load study settings.",
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              errorMessage!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            AppButton(
              label: 'Retry',
              variant: AppButtonVariant.secondary,
              onPressed: onRetry,
            ),
          ],
        ),
      );
    }
    if (sections.isEmpty) {
      // First load: the spinner overlay covers this; keep the card from
      // collapsing to zero height underneath it.
      return const SizedBox(height: 160);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < sections.length; i++) ...[
          if (i > 0) const SizedBox(height: 48),
          _Section(
            section: sections[i],
            showVariableNames: showVariableNames,
            theme: theme,
          ),
        ],
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.section,
    required this.showVariableNames,
    required this.theme,
  });

  final StudySettingsSectionView section;
  final bool showVariableNames;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final mutedSmall = TextStyle(
      fontWeight: FontWeight.w400,
      fontSize: 13,
      height: 20 / 13,
      letterSpacing: -0.1,
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          section.title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            height: 24 / 16,
            letterSpacing: -0.2,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 2),
        Text(section.description, style: mutedSmall),
        const SizedBox(height: 16),
        _columnsRow(
          left: Text('Parameter', style: mutedSmall),
          right: Text('Current Value', style: mutedSmall),
        ),
        const SizedBox(height: 8),
        _divider(),
        for (final row in section.rows) ...[
          _rowWidget(context, row),
          if (row != section.rows.last) _divider(),
        ],
      ],
    );
  }

  Widget _rowWidget(BuildContext context, StudySettingRowView row) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: _columnsRow(
        left: Text(
          row.label,
          style: TextStyle(
            fontWeight: FontWeight.w400,
            fontSize: 14,
            height: 20 / 14,
            letterSpacing: -0.15,
            color: theme.colorScheme.onSurface,
          ),
        ),
        right: Text(
          row.value,
          style: TextStyle(
            fontWeight: FontWeight.w400,
            fontSize: 14,
            height: 20 / 14,
            letterSpacing: -0.15,
            fontStyle: row.implemented ? null : FontStyle.italic,
            color: theme.colorScheme.onSurfaceVariant.withValues(
              alpha: row.implemented ? 1.0 : 0.7,
            ),
          ),
        ),
      ),
    );
    final name = row.variableName;
    if (!showVariableNames || name == null) return content;
    // SystemOperator developer affordance: hover reveals the parameter's
    // true source identifier; click copies it so it can be grepped.
    return Tooltip(
      message: name,
      child: InkWell(
        onTap: () {
          Clipboard.setData(ClipboardData(text: name));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Copied $name'),
              duration: const Duration(seconds: 2),
            ),
          );
        },
        child: content,
      ),
    );
  }

  /// Two-column rhythm shared by the header row and every parameter row:
  /// parameter takes ~3/5 of the card, the value column the rest.
  Widget _columnsRow({required Widget left, required Widget right}) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(flex: 3, child: left),
      Expanded(flex: 2, child: right),
    ],
  );

  Widget _divider() => ColoredBox(
    color: theme.colorScheme.outlineVariant,
    child: const SizedBox(height: 1, width: double.infinity),
  );
}
