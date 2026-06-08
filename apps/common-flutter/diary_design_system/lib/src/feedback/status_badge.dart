import 'package:flutter/material.dart';

import '../theme/app_theme_extension.dart';

/// Status category for [StatusBadge].
///
/// Maps to the semantic status colors from [AppSemanticColors]:
/// - [active] → `statusActive` (Approved / green)
/// - [pending] → `statusAttention` (Pending / amber)
/// - [atRisk] → `statusAtRisk` (Critical / red)
/// - [inactive] → grey, rendered as a hollow (outline-only) dot
enum StatusBadgeKind { active, pending, atRisk, inactive }

/// A small dot + label combo for showing a status — used in tables, user
/// detail panels, and anywhere a single-glance state indicator is needed.
// Implements: DIARY-DEV-test-instrumentation/B
class StatusBadge extends StatelessWidget {
  final StatusBadgeKind kind;

  /// Optional label override. When null, a sensible default is used per
  /// kind ("Active" / "Pending" / "At risk" / "Inactive").
  final String? label;

  /// Test-harness locator. When set, wraps the badge in a
  /// `Semantics(identifier: ..., value: <label-or-default>, container: true, explicitChildNodes: true)`
  /// node so Playwright can `readSemanticValue` the current status.
  final String? semanticId;

  const StatusBadge({
    super.key,
    required this.kind,
    this.label,
    this.semanticId,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = theme.extension<AppSemanticColors>()!;

    final (color, defaultLabel, hollow) = switch (kind) {
      StatusBadgeKind.active => (semantic.statusActive, 'Active', false),
      StatusBadgeKind.pending => (semantic.statusAttention, 'Pending', false),
      StatusBadgeKind.atRisk => (semantic.statusAtRisk, 'At risk', false),
      StatusBadgeKind.inactive => (theme.colorScheme.outline, 'Inactive', true),
    };

    final effectiveLabel = label ?? defaultLabel;

    // Announce as "<label> status" so the semantic role survives even
    // when the colored dot can't be perceived. The dot is decorative;
    // ExcludeSemantics keeps it out of the traversal order.
    final Widget bare = Semantics(
      label: '$effectiveLabel status',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: hollow ? null : color,
              border: hollow ? Border.all(color: color, width: 1.5) : null,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            effectiveLabel,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 14,
              height: 20 / 14,
              letterSpacing: -0.15,
              color: color,
            ),
          ),
        ],
      ),
    );

    if (semanticId == null) return bare;

    return Semantics(
      identifier: semanticId,
      value: effectiveLabel,
      container: true,
      explicitChildNodes: true,
      child: bare,
    );
  }
}
