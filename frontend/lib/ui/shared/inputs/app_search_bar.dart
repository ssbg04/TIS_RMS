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

  const AppSearchBar({
    super.key,
    this.hint = 'Search...',
    this.onSubmitted,
    this.onChanged,
    this.controller,
    this.maxWidth = 420,
    this.showClear = true,
  });

  @override
  State<AppSearchBar> createState() => _AppSearchBarState();
}

class _AppSearchBarState extends State<AppSearchBar> {
  late final TextEditingController _controller;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    _controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final hasText = _controller.text.isNotEmpty;
    if (hasText != _hasText) setState(() => _hasText = hasText);
  }

  @override
  void dispose() {
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: widget.maxWidth),
      child: TextField(
        controller: _controller,
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
          prefixIcon: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 10),
            child: Icon(Icons.search_rounded, size: 20, color: AppColors.primaryGreen),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 40),
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
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primaryGreen, width: 1.5),
          ),
        ),
      ),
    );
  }
}
