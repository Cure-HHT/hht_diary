import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// One row in the [ParticipantActionsDialog]: a Figma "Button" card with a
/// tinted glyph, a label, and a trailing chevron. [destructive] flips the
/// glyph chip + label to the Critical palette (Disconnect, Mark Not
/// Participating).
@immutable
class ParticipantActionItem {
  const ParticipantActionItem({
    required this.label,
    required this.iconAsset,
    required this.onSelected,
    this.destructive = false,
  });

  /// Figma label, e.g. "Show Linking Code".
  final String label;

  /// `assets/icons/participant/<name>.svg` (exported from the Figma UI Kit).
  final String iconAsset;

  /// Invoked after the dialog dismisses itself — routes to the existing
  /// lifecycle handler (code dialog / link / confirm).
  final VoidCallback onSelected;

  final bool destructive;
}

/// "Participant Actions" — the per-status action sheet opened by tapping a
/// participant row (Figma: Participant Management / ParticipantActionsDialog).
///
/// Snapshot in, callbacks out: the wiring layer composes the per-status
/// [actions] (reusing the lifecycle handlers that formerly backed the row's
/// overflow menu) and shows this dialog. Each card dismisses the sheet, then
/// invokes its handler.
class ParticipantActionsDialog extends StatelessWidget {
  const ParticipantActionsDialog({
    super.key,
    required this.participantId,
    required this.actions,
  });

  final String participantId;
  final List<ParticipantActionItem> actions;

  // Figma "Sponsor Portal — UI Pack" tokens.
  static const Color _black = Color(0xFF04161E);
  static const Color _darkGrey = Color(0xFF54636A);
  static const Color _primary = Color(0xFF165C7D);
  static const Color _primaryLightSoft = Color(0xFFE8F3F7);
  static const Color _grey = Color(0xFFA4B9C2);
  static const Color _lightGray = Color(0xFFECEEF0);
  static const Color _critical = Color(0xFFCB333B);
  static const Color _criticalBg = Color(0xFFFDEBEC);
  static const Color _primaryBg = Color(0xFFF7FAFB);

  static Future<void> show({
    required BuildContext context,
    required String participantId,
    required List<ParticipantActionItem> actions,
  }) => showDialog<void>(
    context: context,
    builder: (_) =>
        ParticipantActionsDialog(participantId: participantId, actions: actions),
  );

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(8);
    return Semantics(
      identifier: 'participant-actions-dialog-$participantId',
      namesRoute: true,
      container: true,
      explicitChildNodes: true,
      child: Dialog(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shadowColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 512),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: _primaryBg,
              borderRadius: borderRadius,
              border: Border.all(color: _lightGray),
              // Figma drop shadow: x=5, y=10, blur=20, spread=-3, #364153@10%.
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1A364153),
                  offset: Offset(5, 10),
                  blurRadius: 20,
                  spreadRadius: -3,
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _header(context),
                  const SizedBox(height: 32),
                  for (var i = 0; i < actions.length; i++) ...[
                    if (i > 0) const SizedBox(height: 12),
                    _ActionCard(item: actions[i]),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Participant Actions',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 24,
                height: 32 / 24,
                letterSpacing: 0.07,
                color: _black,
              ),
            ),
            const SizedBox(height: 8),
            Text.rich(
              TextSpan(
                text: 'Participant ID: ',
                style: const TextStyle(
                  fontWeight: FontWeight.w400,
                  fontSize: 14,
                  height: 20 / 14,
                  letterSpacing: -0.15,
                  color: _darkGrey,
                ),
                children: [
                  TextSpan(
                    text: participantId,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: _black,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      Semantics(
        identifier: 'participant-actions-close-$participantId',
        button: true,
        child: InkWell(
          onTap: () => Navigator.of(context).pop(),
          customBorder: const CircleBorder(),
          child: const Padding(
            padding: EdgeInsets.all(2),
            child: Icon(Icons.close, size: 20, color: _darkGrey),
          ),
        ),
      ),
    ],
  );
}

/// A single Figma "Button" card: glyph chip + label + chevron, full-width tap.
class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.item});

  final ParticipantActionItem item;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(8);
    final accent = item.destructive
        ? ParticipantActionsDialog._critical
        : ParticipantActionsDialog._primary;
    final chipColor = item.destructive
        ? ParticipantActionsDialog._criticalBg
        : ParticipantActionsDialog._primaryLightSoft;
    final labelColor = item.destructive
        ? ParticipantActionsDialog._critical
        : ParticipantActionsDialog._black;

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: () {
          // Dismiss the sheet first, then hand off to the lifecycle handler
          // (which opens its own confirm/code dialog).
          Navigator.of(context).pop();
          item.onSelected();
        },
        borderRadius: borderRadius,
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: borderRadius,
            border: Border.all(color: ParticipantActionsDialog._lightGray),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.5),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: chipColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: SvgPicture.asset(
                    item.iconAsset,
                    width: 20,
                    height: 20,
                    colorFilter: ColorFilter.mode(accent, BlendMode.srcIn),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.label,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      height: 24 / 16,
                      letterSpacing: -0.31,
                      color: labelColor,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SvgPicture.asset(
                  'assets/icons/participant/chevron_right.svg',
                  width: 20,
                  height: 20,
                  colorFilter: const ColorFilter.mode(
                    ParticipantActionsDialog._grey,
                    BlendMode.srcIn,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
