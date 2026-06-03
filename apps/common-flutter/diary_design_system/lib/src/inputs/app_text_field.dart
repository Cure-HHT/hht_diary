import 'dart:async';

import 'package:flutter/material.dart';

import '../tokens/radius_tokens.dart';
import '../tokens/spacing_tokens.dart';

/// The design system text input.
///
/// One widget covers both standard forms and search use. The default
/// constructor takes the full prop set; [AppTextField.search] is a factory
/// that pre-configures the magnifier prefix, clear button, and 300 ms
/// debounce.
///
/// **Label / required indicator** render *above* the input (per Figma) rather
/// than using Material's floating label.
///
/// **Debounce**: when [onChangedDebounce] is non-null, [onChanged] is delayed
/// until the user stops typing for that duration. Useful for search-as-you-type
/// without firing a network request on every keystroke.
class AppTextField extends StatefulWidget {
  final String? label;
  final String? hintText;
  final String? helperText;
  final String? errorText;

  /// Controller for external text-state ownership. If null, an internal
  /// controller is created (and disposed) automatically.
  final TextEditingController? controller;
  final String? initialValue;

  final ValueChanged<String>? onChanged;
  final FormFieldValidator<String>? validator;

  final bool required;
  final bool enabled;
  final bool obscureText;
  final bool autofocus;
  final int? maxLines;
  final int? minLines;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;

  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final VoidCallback? onSuffixTap;

  /// When true, a clear (X) suffix button is shown whenever the field has text.
  /// Overrides [suffixIcon] when active.
  final bool showClearButton;

  /// If non-null, [onChanged] is invoked only after the user stops typing for
  /// this duration.
  final Duration? onChangedDebounce;

  final FocusNode? focusNode;

  /// When true, the field renders at the Figma "compact" 36-px height
  /// (tighter vertical padding). Default `false` = standard input height.
  final bool dense;

  const AppTextField({
    super.key,
    this.label,
    this.hintText,
    this.helperText,
    this.errorText,
    this.controller,
    this.initialValue,
    this.onChanged,
    this.validator,
    this.required = false,
    this.enabled = true,
    this.obscureText = false,
    this.autofocus = false,
    this.maxLines = 1,
    this.minLines,
    this.keyboardType,
    this.textInputAction,
    this.prefixIcon,
    this.suffixIcon,
    this.onSuffixTap,
    this.showClearButton = false,
    this.onChangedDebounce,
    this.focusNode,
    this.dense = false,
  });

  /// Pre-configured search input: magnifier prefix, clear button suffix,
  /// 300 ms debounce, compact 36-px height.
  factory AppTextField.search({
    Key? key,
    TextEditingController? controller,
    String hintText = 'Search',
    ValueChanged<String>? onChanged,
    Duration debounce = const Duration(milliseconds: 300),
    bool enabled = true,
    bool autofocus = false,
    FocusNode? focusNode,
  }) {
    return AppTextField(
      key: key,
      controller: controller,
      hintText: hintText,
      onChanged: onChanged,
      onChangedDebounce: debounce,
      prefixIcon: Icons.search,
      showClearButton: true,
      enabled: enabled,
      autofocus: autofocus,
      focusNode: focusNode,
      dense: true,
    );
  }

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late final TextEditingController _controller;
  bool _ownsController = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
    } else {
      _controller = TextEditingController(text: widget.initialValue ?? '');
      _ownsController = true;
    }
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _debounceTimer?.cancel();
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    if (widget.showClearButton) {
      // Force rebuild so the clear-button suffix visibility tracks the text.
      setState(() {});
    }
  }

  void _handleChanged(String value) {
    final cb = widget.onChanged;
    if (cb == null) return;
    final debounce = widget.onChangedDebounce;
    if (debounce == null || debounce == Duration.zero) {
      cb(value);
      return;
    }
    _debounceTimer?.cancel();
    _debounceTimer = Timer(debounce, () => cb(value));
  }

  void _handleClear() {
    _controller.clear();
    _handleChanged('');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget? suffix;
    if (widget.showClearButton && _controller.text.isNotEmpty) {
      suffix = IconButton(
        icon: const Icon(Icons.close, size: 18),
        tooltip: 'Clear',
        onPressed: _handleClear,
      );
    } else if (widget.suffixIcon != null) {
      suffix = widget.onSuffixTap != null
          ? IconButton(
              icon: Icon(widget.suffixIcon, size: 18),
              onPressed: widget.onSuffixTap,
            )
          : Icon(widget.suffixIcon, size: 18);
    }

    final field = TextFormField(
      controller: _controller,
      onChanged: _handleChanged,
      validator: widget.validator,
      enabled: widget.enabled,
      obscureText: widget.obscureText,
      autofocus: widget.autofocus,
      maxLines: widget.maxLines,
      minLines: widget.minLines,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      focusNode: widget.focusNode,
      style: theme.textTheme.bodyMedium,
      decoration: InputDecoration(
        hintText: widget.hintText,
        helperText: widget.helperText,
        errorText: widget.errorText,
        prefixIcon: widget.prefixIcon == null
            ? null
            : Icon(widget.prefixIcon, size: 18),
        prefixIconConstraints: widget.dense
            ? const BoxConstraints(minWidth: 36, minHeight: 36)
            : null,
        suffixIcon: suffix,
        suffixIconConstraints: widget.dense
            ? const BoxConstraints(minWidth: 36, minHeight: 36)
            : null,
        isDense: widget.dense,
        contentPadding: widget.dense
            ? const EdgeInsets.symmetric(horizontal: 12, vertical: 8)
            : EdgeInsets.symmetric(
                horizontal: SpacingTokens.md,
                vertical: SpacingTokens.sm,
              ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(RadiusTokens.md),
        ),
      ),
    );

    if (widget.label == null) return field;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _LabelRow(label: widget.label!, required: widget.required),
        SizedBox(height: SpacingTokens.xs),
        field,
      ],
    );
  }
}

class _LabelRow extends StatelessWidget {
  final String label;
  final bool required;
  const _LabelRow({required this.label, required this.required});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: theme.textTheme.labelMedium),
        if (required) ...[
          const SizedBox(width: 2),
          Text(
            '*',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
      ],
    );
  }
}
