import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Displays a participant linking code in a bordered, monospace box with a
/// copy-to-clipboard button, an optional label, and an optional expiry
/// subtitle. Self-contained: no legacy portal-ui imports.
///
/// Mirrors the legacy `ActivationCodeDisplay` UX (monospace code box + copy
/// icon) used by the original portal participant linking flow.
///
/// Implements: DIARY-GUI-show-linking-code/A
class ActivationCodeDisplay extends StatelessWidget {
  const ActivationCodeDisplay({
    super.key,
    required this.code,
    this.label,
    this.expiresAt,
    this.fontSize,
  });

  /// The linking code to display (server-generated).
  final String code;

  /// Optional label rendered above the code box.
  final String? label;

  /// Optional ISO-8601 expiry timestamp rendered as a subtitle below the box.
  final String? expiresAt;

  /// Optional code font size override.
  final double? fontSize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (label != null) ...<Widget>[
          Text(
            label!,
            style: theme.textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
        ],
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            // Figma: pale slate code field (#F7FAFB) with a hairline border —
            // NOT surfaceContainerHighest, which resolves to a medium grey.
            color: colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SelectableText(
                _formatCode(code),
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: fontSize ?? 16,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.copy_outlined),
                iconSize: 18,
                tooltip: 'Copy code',
                onPressed: () => _copy(context),
              ),
            ],
          ),
        ),
        if (expiresAt != null) ...<Widget>[
          const SizedBox(height: 4),
          Text(
            'Expires ${_formatExpiry(expiresAt!)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }

  void _copy(BuildContext context) {
    Clipboard.setData(ClipboardData(text: code));
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(
      SnackBar(
        content: Text('Code copied: $code'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Groups a linking code into two dash-separated halves for display
  /// (Figma: "KJWF8-ALS57"). Codes are a fixed 10 chars (2 prefix + 6 random +
  /// 2 check), so the dash lands at the midpoint. Codes that already contain a
  /// separator, or non-code placeholders like "(none)", are returned as-is.
  /// The clipboard copy always uses the raw, un-dashed [code].
  static String _formatCode(String code) {
    if (code.contains('-') || code.contains(' ')) return code;
    if (code.length < 6 || !RegExp(r'^[A-Za-z0-9]+$').hasMatch(code)) {
      return code;
    }
    final mid = code.length ~/ 2;
    return '${code.substring(0, mid)}-${code.substring(mid)}';
  }

  /// Formats an ISO-8601 [expiresAt] as a short local date-time, falling back
  /// to the raw string if it cannot be parsed.
  static String _formatExpiry(String expiresAt) {
    try {
      final dt = DateTime.parse(expiresAt).toLocal();
      String two(int n) => n.toString().padLeft(2, '0');
      return '${dt.year}-${two(dt.month)}-${two(dt.day)} '
          '${two(dt.hour)}:${two(dt.minute)}';
    } catch (_) {
      return expiresAt;
    }
  }
}
