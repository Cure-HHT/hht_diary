import 'package:flutter/material.dart';

/// Top app brand bar — sponsor/app logo on the left, a trailing action on the
/// right. Shared by the home screen and any sub-screen that needs the same
/// visual continuity (e.g. the incomplete-records screen).
///
/// The structure (padding, row, leading + spacer + trailing) is fixed; what
/// goes inside is callsite-controlled so screens can plug in their own logo
/// surface (the home screen wires the cache-backed sponsor logo + actions
/// menu; sub-screens typically pass a plain app-logo image and a decorative
/// menu icon).
class BrandHeader extends StatelessWidget {
  const BrandHeader({required this.leading, required this.trailing, super.key});

  /// Left side — the logo surface. On the home screen this is the actionable
  /// `LogoMenu`; on sub-screens it is typically a plain `Image.asset(...)`.
  final Widget leading;

  /// Right side — the trailing action. On the home screen this is the user
  /// menu's `PopupMenuButton`; on sub-screens it is typically a decorative
  /// menu icon.
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [leading, const Spacer(), trailing]),
    );
  }
}
