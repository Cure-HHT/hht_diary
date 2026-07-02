import 'package:clinical_diary/scope/sponsor_ui_config_scope.dart';
import 'package:flutter/material.dart';

/// A widget that animates a flash highlight and passes the color to a builder.
/// Used to draw attention to newly added records in a list.
///
/// Animation is controlled by:
/// - `enabled` parameter (user preference, defaults to true)
/// - the sponsor `ui.useAnimations` capability gate (disables when false)
///
/// If animations are disabled, the widget still calls onFlashComplete
/// immediately so the caller knows the "flash" is done.
// Implements: DIARY-PRD-mobile-offline-first/A+B+C
class FlashHighlight extends StatefulWidget {
  const FlashHighlight({
    required this.builder,
    required this.flash,
    super.key,
    this.highlightColor,
    this.onFlashComplete,
    this.enabled = true,
  });

  /// Builder that receives the current highlight color (or null when not flashing).
  final Widget Function(BuildContext context, Color? color) builder;

  /// Whether to trigger the flash animation.
  final bool flash;

  /// The color to flash. Defaults to a red for visibility.
  final Color? highlightColor;

  /// Called when the flash animation completes.
  final VoidCallback? onFlashComplete;

  /// Whether animations are enabled (user preference).
  /// This is overridden by FeatureFlags.useAnimations if that is false.
  final bool enabled;

  @override
  State<FlashHighlight> createState() => _FlashHighlightState();
}

class _FlashHighlightState extends State<FlashHighlight>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );

    // Create a curve that goes 0 -> 1 -> 0 (one pulse)
    _animation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _controller.addStatusListener(_onAnimationStatus);

    if (widget.flash) {
      _startFlash();
    }
  }

  @override
  void didUpdateWidget(FlashHighlight oldWidget) {
    super.didUpdateWidget(oldWidget);
    // CUR-554: re-fire on every false->true transition. The transition check
    // already prevents re-firing on rebuilds where flash stays true, so no
    // latch is needed beyond that.
    if (widget.flash && !oldWidget.flash) {
      _startFlash();
    }
  }

  /// Check if animations are enabled (both feature flag and user preference)
  bool get _animationsEnabled =>
      SponsorUiConfigScope.read(context).useAnimations && widget.enabled;

  void _startFlash() {
    // CUR-554: reset cycle counter so each new flash plays the full two
    // pulses. _onAnimationStatus increments _flashCount up to 2 and never
    // resets it; without this the second flash would forward once, never
    // reverse (count > 2), and freeze.
    _flashCount = 0;
    if (_animationsEnabled) {
      _controller.forward();
    } else {
      // Animations disabled - immediately call completion callback
      widget.onFlashComplete?.call();
    }
  }

  int _flashCount = 0;

  void _onAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _flashCount++;
      if (_flashCount <= 2) {
        _controller.reverse();
      }
    } else if (status == AnimationStatus.dismissed && _flashCount > 0) {
      if (_flashCount < 2) {
        _controller.forward();
      } else {
        widget.onFlashComplete?.call();
      }
    }
  }

  @override
  void dispose() {
    _controller
      ..removeStatusListener(_onAnimationStatus)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Use a bright teal color for the flash
    final baseColor = widget.highlightColor ?? Colors.teal.shade300;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        final color = _animation.value > 0
            ? Color.lerp(
                null,
                baseColor.withValues(alpha: 0.3),
                _animation.value,
              )
            : null;
        return widget.builder(context, color);
      },
    );
  }
}
