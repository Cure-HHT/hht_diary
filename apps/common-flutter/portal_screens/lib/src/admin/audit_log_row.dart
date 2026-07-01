import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/audit_entry_view.dart';

/// One expandable row in the [AuditLogsScreen] table.
///
/// **Collapsed:** Timestamp / User (name + role) / Activity / chevron — a
/// single tappable row. **Expanded:** the same row with the chevron rotated
/// to face down, and a tinted panel below containing a headline, a
/// metadata line, and the raw audit JSON pretty-printed. The expansion
/// panel is left-indented past the Timestamp column so the time axis
/// stays as a clean visual anchor down the page.
///
/// Stateful so each row owns its own open/closed flag; collapsing one row
/// never collapses another. The cost is one extra `State` per visible row,
/// which is negligible against the JSON-rendering cost of the expansion.
class AuditLogRow extends StatefulWidget {
  const AuditLogRow({
    super.key,
    required this.entry,
    required this.columnWidths,
  });

  final AuditEntryView entry;

  /// Pixel widths for the four columns: Timestamp, User, Activity,
  /// chevron. Mirrors what the column-header row uses so cell content
  /// and header labels line up vertically. Passed in (rather than
  /// computed here) because the screen owns the layout decision.
  final AuditColumnWidths columnWidths;

  @override
  State<AuditLogRow> createState() => _AuditLogRowState();
}

class _AuditLogRowState extends State<AuditLogRow> {
  bool _expanded = false;

  void _toggle() => setState(() => _expanded = !_expanded);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          // Domain-keyed Playwright handle (the event id) — pages and
          // refreshes reorder rows, so never address them positionally.
          // container + explicitChildNodes keep the identifier on its own
          // node (web flattener gotcha — event_sourcing prd-reaction).
          identifier: 'audit-row-${widget.entry.id}',
          button: true,
          container: true,
          explicitChildNodes: true,
          child: InkWell(
            onTap: _toggle,
            child: _CollapsedRow(
              entry: widget.entry,
              columnWidths: widget.columnWidths,
              expanded: _expanded,
            ),
          ),
        ),
        if (_expanded)
          Semantics(
            identifier: 'audit-row-${widget.entry.id}-details',
            container: true,
            explicitChildNodes: true,
            child: _ExpandedPanel(
              entry: widget.entry,
              timestampColumnWidth: widget.columnWidths.timestamp,
              theme: theme,
            ),
          ),
      ],
    );
  }
}

/// Pixel widths for the four columns, shared between the header row and
/// every body row so the layouts line up. The Activity column is a flex
/// slot — its width is whatever the table has left after the fixed
/// columns claim theirs.
@immutable
class AuditColumnWidths {
  const AuditColumnWidths({
    required this.timestamp,
    required this.user,
    required this.chevron,
  });

  final double timestamp;
  final double user;
  final double chevron;
}

class _CollapsedRow extends StatelessWidget {
  const _CollapsedRow({
    required this.entry,
    required this.columnWidths,
    required this.expanded,
  });

  final AuditEntryView entry;
  final AuditColumnWidths columnWidths;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // 24h matches AppDataTable's row padding so audit rows sit on the
    // same content edge as user rows; 16v matches the top row's vertical
    // padding (the band that contains the search field), so rows + top
    // row read as a single rhythm down the card.
    final cellPad = EdgeInsets.symmetric(horizontal: 24, vertical: 16);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: columnWidths.timestamp,
          child: Padding(
            padding: cellPad,
            child: Text(
              _formatTimestamp(entry.timestamp),
              // Inter Regular 14 / 20 / -0.15 / Dark Grey
              // (onSurfaceVariant). The Figma timestamp is #4A5565; the
              // theme's onSurfaceVariant (#54636A) is the closest tone.
              style: TextStyle(
                fontWeight: FontWeight.w400,
                fontSize: 14,
                height: 20 / 14,
                letterSpacing: -0.15,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
        SizedBox(
          width: columnWidths.user,
          child: Padding(
            padding: cellPad,
            child: _UserCell(entry: entry, theme: theme),
          ),
        ),
        Expanded(
          child: Padding(
            padding: cellPad,
            child: Text(
              entry.activityLabel.isEmpty ? '—' : entry.activityLabel,
              style: TextStyle(
                fontWeight: FontWeight.w400,
                fontSize: 14,
                height: 20 / 14,
                letterSpacing: -0.15,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ),
        SizedBox(
          width: columnWidths.chevron,
          // No Align wrapper: with the column wide enough (128) the
          // default top-left placement of the cell-padded child seats
          // the chevron at column_left + 24, which is the same offset
          // UsersScreen's kebab glyph uses (see users_screen.dart). That
          // way the right-edge column reads as a single vertical line
          // when you switch tabs.
          child: Padding(
            padding: cellPad,
            child: Icon(
              expanded ? Icons.keyboard_arrow_down : Icons.chevron_right,
              size: 20,
              // Primary tone so the expander reads as the row's
              // affordance, not as muted chrome — matches Figma.
              color: theme.colorScheme.primary,
            ),
          ),
        ),
      ],
    );
  }
}

/// User column content: bold name (Inter Medium 14) on top, role label
/// (Inter Regular 12, muted) underneath. Empty actor name (automation
/// initiators) collapses the role line and shows the system actor as
/// "Automation" so the column isn't blank.
class _UserCell extends StatelessWidget {
  const _UserCell({required this.entry, required this.theme});

  final AuditEntryView entry;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final isAutomation = entry.actorName.isEmpty;
    final displayName = isAutomation ? 'Automation' : entry.actorName;
    // Email subtitle under the name. Hidden for automation, and when it would
    // merely duplicate the name (no display name resolved, so the name line is
    // already the email).
    final displayEmail = (isAutomation || entry.actorEmail == entry.actorName)
        ? ''
        : entry.actorEmail;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          displayName,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 14,
            height: 20 / 14,
            letterSpacing: -0.15,
            color: theme.colorScheme.onSurface,
          ),
        ),
        if (displayEmail.isNotEmpty)
          Text(
            displayEmail,
            style: TextStyle(
              fontWeight: FontWeight.w400,
              fontSize: 12,
              height: 16 / 12,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}

/// Expanded panel rendered under the row when the user taps the chevron.
///
/// Layout (matches Figma image 2): a soft-tinted band that spans the full
/// row width, with the content area indented past the Timestamp column
/// (the timestamp area stays empty). Inside the indented area we render:
///   1. Headline — `humanizeEntryType(raw['entry_type'])`
///   2. Metadata line — timestamp · initiator label · aggregate ref · change reason
///   3. Pretty-printed JSON of the raw map.
class _ExpandedPanel extends StatelessWidget {
  const _ExpandedPanel({
    required this.entry,
    required this.timestampColumnWidth,
    required this.theme,
  });

  final AuditEntryView entry;
  final double timestampColumnWidth;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final bg = theme.colorScheme.surfaceContainerLow;
    final headline = _humanizeEntryType(
      (entry.raw['entry_type'] as String?) ?? '',
    );
    final metadata = _buildMetadataLine(entry);
    final jsonText = const JsonEncoder.withIndent('  ').convert(entry.raw);

    return ColoredBox(
      color: bg,
      child: Padding(
        // Match the cell's vertical rhythm and indent the inner content
        // past the Timestamp column on the left so the time axis above
        // visually leads into a blank gutter rather than into prose.
        padding: EdgeInsets.fromLTRB(timestampColumnWidth, 16, 24.0, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.only(left: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    headline,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                      height: 20 / 14,
                      letterSpacing: -0.15,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    metadata,
                    style: TextStyle(
                      fontWeight: FontWeight.w400,
                      fontSize: 12,
                      height: 16 / 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  SizedBox(height: 16),
                  SelectableText(
                    jsonText,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      height: 16 / 12,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Formatting helpers — kept private to this file because they're tightly
// coupled to the expanded-panel layout. If/when more screens need them
// they'll move to a shared `audit_format.dart`, mirroring portal_ui_evs's
// existing helper.
// -----------------------------------------------------------------------------

const Map<String, String> _entryTypeLabelOverrides = <String, String>{
  'site_synced_from_edc': 'Site Synced From EDC',
  'participant_synced_from_edc': 'Participant Synced From EDC',
};

String _humanizeEntryType(String entryType) {
  if (entryType.isEmpty) return '(unknown)';
  final override = _entryTypeLabelOverrides[entryType];
  if (override != null) return override;
  return entryType
      .split('_')
      .where((w) => w.isNotEmpty)
      .map((w) => w[0].toUpperCase() + w.substring(1))
      .join(' ');
}

String _initiatorLabel(Map<String, Object?>? initiator) {
  if (initiator == null) return '(unknown)';
  final label = (initiator['label'] as String?) ?? '';
  return switch (initiator['kind']) {
    'user' => 'user:$label',
    'automation' => 'auto:$label',
    'anonymous' => 'anon',
    _ => '(unknown)',
  };
}

String _buildMetadataLine(AuditEntryView entry) {
  final raw = entry.raw;
  final ts = (raw['timestamp'] as String?) ?? entry.timestamp.toIso8601String();
  final initiator = _initiatorLabel(raw['initiator'] as Map<String, Object?>?);
  final aggType = (raw['aggregate_type'] as String?) ?? '?';
  final aggId = (raw['aggregate_id'] as String?) ?? '?';
  final reason = (raw['change_reason'] as String?) ?? '';
  final tail = reason.isEmpty ? '' : ' — $reason';
  return '$ts · $initiator · $aggType $aggId$tail';
}

// "Oct 16, 2024, 07:30 AM" — matches the Figma's timestamp formatting.
// Kept inline (no `intl` dep) because the audit log is the only screen
// that needs this format today.
String _formatTimestamp(DateTime t) {
  const months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final local = t.toLocal();
  final month = months[local.month - 1];
  final hour12 = local.hour == 0
      ? 12
      : (local.hour > 12 ? local.hour - 12 : local.hour);
  final ampm = local.hour < 12 ? 'AM' : 'PM';
  final mm = local.minute.toString().padLeft(2, '0');
  return '$month ${local.day}, ${local.year}, '
      '${hour12.toString().padLeft(2, '0')}:$mm $ampm';
}
