
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../providers/search_history_provider.dart';

class AppSearchBar extends ConsumerStatefulWidget {
  final String hint;
  final void Function(String value)? onSubmitted;
  final void Function(String value)? onChanged;
  final TextEditingController? controller;
  final double maxWidth;
  final bool showClear;
  final FocusNode? focusNode;
  final bool enableHistory;
  final bool collapsible;
  final bool hideIconWhenExpanded;

  const AppSearchBar({
    super.key,
    this.hint = 'Search...',
    this.onSubmitted,
    this.onChanged,
    this.controller,
    this.focusNode,
    this.maxWidth = 420,
    this.showClear = true,
    this.enableHistory = true,
    this.collapsible = false,
    this.hideIconWhenExpanded = false,
  });

  @override
  ConsumerState<AppSearchBar> createState() => _AppSearchBarState();
}

class _AppSearchBarState extends ConsumerState<AppSearchBar> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  bool _hasText = false;
  bool _isExpanded = false;

  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    _focusNode = widget.focusNode ?? FocusNode();
    _isExpanded = !widget.collapsible;
    _controller.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);
  }

  void _onTextChanged() {
    final hasText = _controller.text.isNotEmpty;
    if (hasText != _hasText) setState(() => _hasText = hasText);
    
    // Update overlay if history is visible
    if (_overlayEntry != null && widget.enableHistory) {
      _overlayEntry?.markNeedsBuild();
    }
  }

  void _onFocusChanged() {
    if (mounted) setState(() {});
    
    if (_focusNode.hasFocus && widget.enableHistory) {
      _showOverlay();
    } else {
      // Delay removal to allow overlay tap events (InkWell) to fire before the widget is destroyed
      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted && !_focusNode.hasFocus) {
          _removeOverlay();
          
          // Auto collapse if empty and collapsible
          if (widget.collapsible && _controller.text.trim().isEmpty) {
            setState(() => _isExpanded = false);
          }
        }
      });
    }
  }

  void _showOverlay() {
    if (_overlayEntry != null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _overlayEntry != null || !_focusNode.hasFocus) return;

      _overlayEntry = OverlayEntry(
        builder: (context) => Positioned(
          width: widget.maxWidth,
          child: CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            offset: const Offset(0, 48),
            child: _buildHistoryOverlay(),
          ),
        ),
      );

      Overlay.of(context).insert(_overlayEntry!);
    });
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  Widget _buildHistoryOverlay() {
    return Consumer(
      builder: (context, ref, child) {
        final history = ref.watch(searchHistoryProvider);
        if (history.isEmpty) return const SizedBox.shrink();

        return TapRegion(
          groupId: _focusNode,
          child: Material(
            elevation: 4,
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              shrinkWrap: true,
              itemCount: history.length,
              itemBuilder: (context, index) {
                final term = history[index];
                return InkWell(
                  onTap: () {
                    _controller.text = term;
                    _focusNode.unfocus();
                    if (widget.onSubmitted != null) {
                      widget.onSubmitted!(term);
                    }
                    ref.read(searchHistoryProvider.notifier).addSearch(term);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(
                      children: [
                        Icon(Icons.history, size: 18, color: Colors.grey.shade400),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            term,
                            style: const TextStyle(fontSize: 14, color: Colors.black87),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close, size: 16, color: Colors.grey.shade400),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () {
                            ref.read(searchHistoryProvider.notifier).removeSearch(term);
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
      },
    );
  }

  @override
  void dispose() {
    _removeOverlay();
    _controller.removeListener(_onTextChanged);
    _focusNode.removeListener(_onFocusChanged);
    if (widget.controller == null) _controller.dispose();
    if (widget.focusNode == null) _focusNode.dispose();
    super.dispose();
  }

  void _handleSubmit(String val) {
    if (val.trim().isNotEmpty) {
      if (widget.enableHistory) {
        ref.read(searchHistoryProvider.notifier).addSearch(val.trim());
      }
      widget.onSubmitted?.call(val.trim());
      _focusNode.unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isExpanded && widget.collapsible) {
      if (_hasText) {
        return IconButton(
          onPressed: () {
            _controller.clear();
            widget.onChanged?.call('');
            if (widget.onSubmitted != null) widget.onSubmitted!('');
          },
          icon: const Icon(Icons.close, size: 28, color: Colors.redAccent),
          tooltip: 'Clear search',
        );
      }
      return IconButton(
        onPressed: () {
          setState(() => _isExpanded = true);
          _focusNode.requestFocus();
        },
        icon: const Icon(Icons.search, size: 28),
        tooltip: 'Search',
      );
    }

    return TapRegion(
      groupId: _focusNode,
      onTapOutside: (event) => _focusNode.unfocus(),
      child: CompositedTransformTarget(
        link: _layerLink,
        child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: widget.maxWidth,
        height: 42.0,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: TextField(
          controller: _controller,
          focusNode: _focusNode,
          textInputAction: TextInputAction.search,
          onSubmitted: _handleSubmit,
          onChanged: widget.onChanged,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade500),
            prefixIcon: widget.hideIconWhenExpanded
                ? null
                : const Icon(Icons.search_rounded, size: 20, color: AppColors.primaryGreen),
            prefixIconConstraints: widget.hideIconWhenExpanded
                ? const BoxConstraints(minWidth: 16, minHeight: 0)
                : const BoxConstraints(minWidth: 42, minHeight: 42),
            suffixIcon: widget.showClear && _hasText
                ? IconButton(
                    icon: Icon(Icons.close_rounded, size: 18, color: Colors.grey.shade500),
                    splashRadius: 16,
                    onPressed: () {
                      _controller.clear();
                      widget.onChanged?.call('');
                      _focusNode.requestFocus();
                    },
                  )
                : null,
            filled: false,
            isDense: true,
            contentPadding: const EdgeInsets.only(top: 11, bottom: 11, right: 12),
            border: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.black26),
            ),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.black26),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.primaryGreen, width: 1.5),
            ),
          ),
        ),
      ),
    ),
    );
  }
}
