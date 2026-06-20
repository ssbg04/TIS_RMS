import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

/// A reusable, styled search bar module.
///
/// Usage:
/// ```dart
/// AppSearchBar(
///   hint: 'Search students...',
///   onSubmitted: (value) { /* handle search */ },
/// )
/// ```
class AppSearchBar extends StatefulWidget {
  /// Placeholder text inside the field.
  final String hint;

  /// Called when the user submits (presses Enter / search action).
  final void Function(String value)? onSubmitted;

  /// Called on every keystroke.
  final void Function(String value)? onChanged;

  /// External controller – if not provided, one is created internally.
  final TextEditingController? controller;

  /// Max width the field will stretch to. Defaults to 420.
  final double maxWidth;

  /// Whether to show a clear (×) button when the field has text.
  final bool showClear;

  final FocusNode? focusNode;

  const AppSearchBar({
    super.key,
    this.hint = 'Search...',
    this.onSubmitted,
    this.onChanged,
    this.controller,
    this.focusNode,
    this.maxWidth = 420,
    this.showClear = true,
  });

  @override
  State<AppSearchBar> createState() => _AppSearchBarState();
}

class _AppSearchBarState extends State<AppSearchBar> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  bool _hasText = false;


  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    _focusNode = widget.focusNode ?? FocusNode();
    _controller.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);
  }

  void _onTextChanged() {
    final hasText = _controller.text.isNotEmpty;
    if (hasText != _hasText) setState(() => _hasText = hasText);
  }

  void _onFocusChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    if (widget.controller == null) _controller.dispose();
    if (widget.focusNode == null) _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.maxWidth,
      height: 42.0,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _focusNode.hasFocus ? AppColors.primaryGreen : Colors.grey.shade200,
          width: _focusNode.hasFocus ? 1.5 : 1.0,
        ),
      ),
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        textInputAction: TextInputAction.search,
        onSubmitted: (val) {
          if (val.trim().isNotEmpty) {
            widget.onSubmitted?.call(val.trim());
          }
        },
        onChanged: widget.onChanged,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          hintText: widget.hint,
          hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade500),
          prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppColors.primaryGreen),
          prefixIconConstraints: const BoxConstraints(minWidth: 42, minHeight: 42),
          suffixIcon: widget.showClear && _hasText
              ? IconButton(
                  icon: Icon(Icons.close_rounded, size: 18, color: Colors.grey.shade500),
                  splashRadius: 16,
                  onPressed: () {
                    _controller.clear();
                    widget.onChanged?.call('');
                  },
                )
              : null,
          filled: false,
          isDense: true,
          contentPadding: const EdgeInsets.only(top: 11, bottom: 11, right: 12),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
      ),
    );
  }
}
