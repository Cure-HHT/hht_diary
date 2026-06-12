import 'package:flutter/material.dart';

/// "< Home" breadcrumb-style back row used directly under the brand header
/// on sub-screens (Figma node 446:8232 et al.). Reused by the enrollment,
/// incomplete-records, and profile screens so the chevron, label, font and
/// padding stay identical across the app.
class BackToHomeRow extends StatelessWidget {
  const BackToHomeRow({
    this.onBack,
    this.semanticId,
    this.semanticLabel = 'Back to home',
    // TODO(i18n): localize "Home".
    this.label = 'Home',
    super.key,
  });

  /// Tap callback. When null the row renders disabled (no ink response).
  final VoidCallback? onBack;

  /// Visible row label. Defaults to "Home"; sub-flows that return to a parent
  /// screen rather than home pass "Back" (Figma 675:486).
  final String label;

  /// Optional Playwright/test locator. When null the row renders without a
  /// surrounding [Semantics] node.
  final String? semanticId;

  /// Screen-reader label paired with [semanticId].
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final row = InkWell(
      onTap: onBack,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(13, 8, 16, 8),
        child: Row(
          children: [
            const Icon(Icons.chevron_left, size: 32, color: Color(0xFF54636A)),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w500,
                height: 1.1,
                letterSpacing: -0.22,
                color: Color(0xFF54636A),
              ),
            ),
          ],
        ),
      ),
    );

    if (semanticId == null) return row;
    return Semantics(
      identifier: semanticId,
      button: true,
      label: semanticLabel,
      child: row,
    );
  }
}
