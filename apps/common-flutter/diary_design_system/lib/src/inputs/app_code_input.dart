import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme_extension.dart';
import '../tokens/radius_tokens.dart';
import '../tokens/spacing_tokens.dart';

/// Validation state for [AppCodeInput]. Drives the segment border
/// colour + width and the typed-text colour together so all three cues
/// stay in agreement.
enum AppCodeInputState {
  /// Resting / focused. Default outlineVariant border (1px). The
  /// focused segment picks up `primaryLight` at 2px via the standard
  /// `focusedBorder` of [InputDecoration].
  idle,

  /// Successfully validated (e.g. linking code verified). Both
  /// segments get a 2px success border and the typed text renders in
  /// `semantic.success`.
  valid,

  /// Invalid input. Both segments get a 2px error border and the
  /// typed text renders in `colorScheme.error`. Pair with [errorText]
  /// to surface a message below the row.
  invalid,
}

/// A segmented code input — N text segments of fixed length joined by a
/// visible [separator]. Models the linking-code field from the Figma
/// `XXXXX – XXXXX` notifications screen and any future N-part code
/// (OTP, voucher, etc.).
///
/// The widget owns its segment controllers; the parent observes the
/// joined (un-separated) value via [onChanged], or queries the final
/// value via the optional [controller]. Auto-advance moves focus
/// forward when a segment fills; backspace on an empty segment jumps
/// focus to the previous one and deletes its last character.
///
/// Each segment is rendered by a private widget tuned to the Figma
/// spec (60px tall, 6px radius, centered 20px letter-spaced glyphs).
/// We don't reuse [AppTextField] here because its decoration is geared
/// for form labels + ~36px height — too different to coerce cleanly.
class AppCodeInput extends StatefulWidget {
  /// Number of segments. Defaults to 2 (the linking-code shape).
  final int segments;

  /// Number of characters per segment. Defaults to 5.
  final int segmentLength;

  /// The visible separator drawn between segments. Defaults to an en-dash.
  final String separator;

  /// Initial joined value (without separators). Caller-supplied; the
  /// widget splits it into segments. Ignored when [controller] is non-null.
  final String? initialValue;

  /// External controller for the joined value. When provided, the widget
  /// stays in sync with `controller.text`; the caller owns disposal.
  final TextEditingController? controller;

  /// Fired with the joined value (no separators) after every keystroke.
  final ValueChanged<String>? onChanged;

  /// Fired with the joined value when the last segment is submitted.
  final ValueChanged<String>? onCompleted;

  /// Validation state. When set to [AppCodeInputState.invalid] alongside
  /// a non-null [errorText], the error message replaces [helperText] and
  /// renders in the critical colour.
  final AppCodeInputState state;

  final String? helperText;
  final String? errorText;
  final bool enabled;

  /// Input filter applied to every segment. Defaults to upper-case letters
  /// + digits (the linking-code alphabet). Pass an empty list to disable.
  final List<TextInputFormatter>? inputFormatters;

  /// Test-harness locator prefix. When set, each segment gets the
  /// identifier `<semanticId>-<index>` so harnesses can target them
  /// individually.
  final String? semanticId;

  const AppCodeInput({
    super.key,
    this.segments = 2,
    this.segmentLength = 5,
    this.separator = '–',
    this.initialValue,
    this.controller,
    this.onChanged,
    this.onCompleted,
    this.state = AppCodeInputState.idle,
    this.helperText,
    this.errorText,
    this.enabled = true,
    this.inputFormatters,
    this.semanticId,
  }) : assert(segments >= 1, 'segments must be ≥ 1'),
       assert(segmentLength >= 1, 'segmentLength must be ≥ 1');

  @override
  State<AppCodeInput> createState() => _AppCodeInputState();
}

class _AppCodeInputState extends State<AppCodeInput> {
  late final List<TextEditingController> _segmentControllers;
  late final List<FocusNode> _focusNodes;
  late final List<TextInputFormatter> _formatters;

  @override
  void initState() {
    super.initState();
    _formatters =
        widget.inputFormatters ??
        [
          FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
          _UpperCaseFormatter(),
        ];
    _segmentControllers = List.generate(
      widget.segments,
      (_) => TextEditingController(),
    );
    _focusNodes = List.generate(widget.segments, (_) => FocusNode());
    _hydrateFromJoined(widget.controller?.text ?? widget.initialValue ?? '');
    widget.controller?.addListener(_onExternalControllerChanged);
  }

  @override
  void didUpdateWidget(covariant AppCodeInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_onExternalControllerChanged);
      widget.controller?.addListener(_onExternalControllerChanged);
    }
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_onExternalControllerChanged);
    for (final c in _segmentControllers) {
      c.dispose();
    }
    for (final n in _focusNodes) {
      n.dispose();
    }
    super.dispose();
  }

  void _onExternalControllerChanged() {
    final external = widget.controller!.text;
    if (_joinedValue() == external) return;
    _hydrateFromJoined(external);
    setState(() {});
  }

  void _hydrateFromJoined(String joined) {
    for (var i = 0; i < widget.segments; i++) {
      final start = i * widget.segmentLength;
      final end = start + widget.segmentLength;
      final chunk = start >= joined.length
          ? ''
          : joined.substring(start, end > joined.length ? joined.length : end);
      _segmentControllers[i].text = chunk;
    }
  }

  String _joinedValue() => _segmentControllers.map((c) => c.text).join();

  /// Handle a segment's text changing. Two behaviours need to coexist:
  ///
  ///   1. **Normal type** — keep the typed value in this segment and
  ///      auto-advance focus when the segment fills.
  ///   2. **Paste overflow** — when the new value exceeds
  ///      [AppCodeInput.segmentLength] (typically a paste of the joined
  ///      code), keep the first N chars here and spill the rest into
  ///      subsequent segments, capped at the field's total capacity.
  ///
  /// `LengthLimitingTextInputFormatter` is intentionally NOT attached to
  /// the segment so the overflow is visible here.
  void _handleSegmentChanged(int index, String value) {
    final segLen = widget.segmentLength;
    final overflowed = value.length > segLen;

    if (overflowed) {
      // Re-apply the segment cap on the source segment, then push the
      // remainder downstream. The text mutation triggers another
      // onChanged for the segment we set, so we set the controller value
      // (cursor + text) directly instead of via .text= to avoid a
      // selection jump.
      final mine = value.substring(0, segLen);
      var leftover = value.substring(segLen);
      _segmentControllers[index].value = TextEditingValue(
        text: mine,
        selection: TextSelection.collapsed(offset: mine.length),
      );

      // Spill across each downstream segment, taking up to segLen each.
      var cursor = index + 1;
      while (cursor < widget.segments && leftover.isNotEmpty) {
        final take = leftover.length > segLen ? segLen : leftover.length;
        final chunk = leftover.substring(0, take);
        leftover = leftover.substring(take);
        _segmentControllers[cursor].value = TextEditingValue(
          text: chunk,
          selection: TextSelection.collapsed(offset: chunk.length),
        );
        cursor++;
      }

      // Focus on the last segment that received text (or the last
      // segment if everything filled up).
      final lastFilled = (cursor - 1).clamp(0, widget.segments - 1);
      _focusNodes[lastFilled].requestFocus();
    } else if (value.length >= segLen && index < widget.segments - 1) {
      _focusNodes[index + 1].requestFocus();
    }

    _broadcastChange();
  }

  /// Backspace handler invoked by the [_BackspaceIntent] action. Called
  /// BEFORE the TextField's internal handler so the empty-segment case
  /// (jump-to-previous + delete) can actually run.
  void _handleBackspace(int index) {
    final ctrl = _segmentControllers[index];
    if (ctrl.text.isNotEmpty) {
      // Standard delete-last-char. Re-implemented here because
      // intercepting backspace via Shortcuts replaces the TextField's
      // native handler entirely.
      final newText = ctrl.text.substring(0, ctrl.text.length - 1);
      ctrl.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newText.length),
      );
      _broadcastChange();
      return;
    }
    if (index == 0) return;
    // Empty segment + backspace → behave as one field: jump to the
    // previous segment and delete its last char.
    _focusNodes[index - 1].requestFocus();
    final prev = _segmentControllers[index - 1];
    if (prev.text.isEmpty) {
      _broadcastChange();
      return;
    }
    final newPrev = prev.text.substring(0, prev.text.length - 1);
    prev.value = TextEditingValue(
      text: newPrev,
      selection: TextSelection.collapsed(offset: newPrev.length),
    );
    _broadcastChange();
  }

  void _broadcastChange() {
    final joined = _joinedValue();
    widget.controller?.value = TextEditingValue(
      text: joined,
      selection: TextSelection.collapsed(offset: joined.length),
    );
    widget.onChanged?.call(joined);
    final filled = joined.length >= widget.segments * widget.segmentLength;
    if (filled) widget.onCompleted?.call(joined);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final semantic = theme.extension<AppSemanticColors>()!;

    // Effective state: an errorText forces invalid even if state was
    // left at idle. Lets callers wire errorText alone for the common
    // case and still get the red border + red text together.
    final effectiveState = widget.errorText != null
        ? AppCodeInputState.invalid
        : widget.state;

    final segmentRow = Row(
      children: [
        for (var i = 0; i < widget.segments; i++) ...[
          if (i > 0) ...[
            SizedBox(width: SpacingTokens.md),
            Text(
              widget.separator,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w500,
                height: 33 / 22,
                color: cs.outline,
              ),
            ),
            SizedBox(width: SpacingTokens.md),
          ],
          Expanded(
            // Shortcuts intercepts backspace BEFORE the TextField's
            // internal handler can swallow it — necessary because the
            // empty-segment case (jump back + delete from previous)
            // can't be detected once TextField consumes the key.
            child: Shortcuts(
              shortcuts: const <ShortcutActivator, Intent>{
                SingleActivator(LogicalKeyboardKey.backspace):
                    _BackspaceIntent(),
              },
              child: Actions(
                actions: <Type, Action<Intent>>{
                  _BackspaceIntent: CallbackAction<_BackspaceIntent>(
                    onInvoke: (_) {
                      _handleBackspace(i);
                      return null;
                    },
                  ),
                },
                child: _CodeSegment(
                  controller: _segmentControllers[i],
                  focusNode: _focusNodes[i],
                  onChanged: (value) => _handleSegmentChanged(i, value),
                  enabled: widget.enabled,
                  maxLength: widget.segmentLength,
                  formatters: _formatters,
                  state: effectiveState,
                  textInputAction: i == widget.segments - 1
                      ? TextInputAction.done
                      : TextInputAction.next,
                  semanticId: widget.semanticId == null
                      ? null
                      : '${widget.semanticId}-$i',
                ),
              ),
            ),
          ),
        ],
      ],
    );

    // Helper / error rendered once under the row — single sentence about
    // the field; screen readers don't announce it N times. Colour follows
    // the validation state.
    final caption = widget.errorText ?? widget.helperText;
    final captionColor = effectiveState == AppCodeInputState.invalid
        ? cs.error
        : effectiveState == AppCodeInputState.valid
        ? semantic.success
        : cs.outline;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        segmentRow,
        if (caption != null) ...[
          SizedBox(height: SpacingTokens.sm),
          Text(
            caption,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 19.5 / 13,
              letterSpacing: -0.1,
              color: captionColor,
            ),
          ),
        ],
      ],
    );
  }
}

/// A single 60×N segment rendered to the Figma linking-code spec:
/// white fill, 6px radius, centered 20px text with 2.4 letter-spacing,
/// 1px outline-variant border at rest and a 2px coloured border per
/// [AppCodeInputState] (or while focused, when state is idle).
///
/// We wrap a borderless [TextField] inside an explicit-height
/// [Container] so the bordered chrome and the editor are decoupled:
/// the container owns the exact 60px box and the border-width swap
/// (1→2px on focus); the TextField just edits. Letting Material's
/// [InputDecorator] own the border was clipping the box short of 60px.
class _CodeSegment extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final bool enabled;
  final int maxLength;
  final List<TextInputFormatter> formatters;
  final AppCodeInputState state;
  final TextInputAction textInputAction;
  final String? semanticId;

  const _CodeSegment({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.enabled,
    required this.maxLength,
    required this.formatters,
    required this.state,
    required this.textInputAction,
    this.semanticId,
  });

  @override
  State<_CodeSegment> createState() => _CodeSegmentState();
}

class _CodeSegmentState extends State<_CodeSegment> {
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocusChange);
    _isFocused = widget.focusNode.hasFocus;
  }

  @override
  void didUpdateWidget(covariant _CodeSegment oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_onFocusChange);
      widget.focusNode.addListener(_onFocusChange);
      _isFocused = widget.focusNode.hasFocus;
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChange);
    super.dispose();
  }

  void _onFocusChange() {
    if (!mounted) return;
    final next = widget.focusNode.hasFocus;
    if (next == _isFocused) return;
    setState(() => _isFocused = next);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final semantic = theme.extension<AppSemanticColors>()!;

    final (resting, focused, accent) = _resolveColors(cs, semantic);
    final radius = BorderRadius.circular(RadiusTokens.md);

    final borderColor = !widget.enabled
        ? cs.outlineVariant
        : _shouldShowFocusRing
        ? focused
        : resting;
    final borderWidth = !widget.enabled
        ? 1.0
        : (_shouldShowFocusRing || widget.state != AppCodeInputState.idle)
        ? 2.0
        : 1.0;

    // Line-box locked to font-size (height: 1.0) so the glyphs sit
    // dead-centre instead of riding the baseline. Without this Flutter
    // adds asymmetric padding above the cap line vs. below the
    // baseline, producing the "extra whitespace on top" the Figma
    // doesn't have.
    const textStyle = TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w500,
      letterSpacing: 2.4,
      height: 1.0,
    );

    const strutStyle = StrutStyle(
      fontSize: 20,
      height: 1.0,
      leading: 0,
      forceStrutHeight: true,
    );

    final hintStyle = textStyle.copyWith(color: cs.outline);
    final filledStyle = textStyle.copyWith(color: accent);

    // Outer 60-px box = line-height (20) + 2×20 contentPadding.
    // Drawing the chrome on a DecoratedBox sized by SizedBox keeps the
    // border-width swap (1↔2 px) from affecting outer dimensions, and
    // the strut-locked TextField inside fills the inner area symmetrically.
    final segment = SizedBox(
      height: 60,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: widget.enabled ? cs.surface : cs.surfaceContainerLow,
          borderRadius: radius,
          border: Border.all(color: borderColor, width: borderWidth),
        ),
        child: TextField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          onChanged: widget.onChanged,
          enabled: widget.enabled,
          textAlign: TextAlign.center,
          textAlignVertical: TextAlignVertical.center,
          style: filledStyle,
          strutStyle: strutStyle,
          cursorColor: accent,
          cursorHeight: 22,
          // No LengthLimitingTextInputFormatter here — paste overflow
          // must reach the parent's `onChanged` so it can spill into the
          // next segment. Single-keystroke typing past the limit is
          // re-capped in `_AppCodeInputState._handleSegmentChanged`.
          inputFormatters: widget.formatters,
          textInputAction: widget.textInputAction,
          decoration: InputDecoration(
            hintText: 'X' * widget.maxLength,
            hintStyle: hintStyle,
            isCollapsed: true,
            // Asymmetric vertical padding (top 23, bottom 17) compensates
            // for the uppercase-only alphabet: with a strut-locked 20-px
            // line box, the visible cap-to-baseline glyph sits in the top
            // ~14 px, leaving 6 px of empty descender at the bottom.
            // Shifting the line box down by 3 px centres the visible
            // glyph in the 60-px outer box. Total = 23 + 20 + 17 = 60.
            contentPadding: const EdgeInsets.only(
              top: 23,
              bottom: 17,
              left: 12,
              right: 12,
            ),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
            filled: false,
          ),
        ),
      ),
    );

    if (widget.semanticId == null) return segment;
    return Semantics(
      identifier: widget.semanticId,
      textField: true,
      container: true,
      explicitChildNodes: true,
      child: segment,
    );
  }

  /// Show the primary-light focus ring only while the state is idle —
  /// once validation has marked the field valid/invalid, that tone
  /// owns the border regardless of focus (matches Figma).
  bool get _shouldShowFocusRing =>
      _isFocused && widget.state == AppCodeInputState.idle;

  /// Returns `(restingBorder, focusedBorder, textAndCursorAccent)` for
  /// the current [_CodeSegment.state]. The text/cursor accent doubles
  /// as the typed-glyph colour in the valid/invalid states (Figma).
  (Color resting, Color focused, Color accent) _resolveColors(
    ColorScheme cs,
    AppSemanticColors semantic,
  ) {
    switch (widget.state) {
      case AppCodeInputState.idle:
        return (cs.outlineVariant, semantic.primaryLight, cs.onSurface);
      case AppCodeInputState.valid:
        return (semantic.success, semantic.success, semantic.success);
      case AppCodeInputState.invalid:
        return (cs.error, cs.error, cs.error);
    }
  }
}

/// Intent dispatched by the [Shortcuts] wrapper around each segment so
/// the parent state can intercept backspace before the TextField's
/// internal handler runs. See [_AppCodeInputState._handleBackspace] for
/// the cross-segment delete behaviour.
class _BackspaceIntent extends Intent {
  const _BackspaceIntent();
}

class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final upper = newValue.text.toUpperCase();
    if (upper == newValue.text) return newValue;
    return newValue.copyWith(text: upper, selection: newValue.selection);
  }
}
