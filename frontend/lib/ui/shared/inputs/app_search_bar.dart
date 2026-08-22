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
  void didUpdateWidget(AppSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final currentHasText = _controller.text.isNotEmpty;
    if (currentHasText != _hasText) {
      setState(() {
        _hasText = currentHasText;
        if (currentHasText) _isExpanded = true;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    _focusNode = widget.focusNode ?? FocusNode();
    _hasText = _controller.text.isNotEmpty;
    _isExpanded = !widget.collapsible || _controller.text.trim().isNotEmpty;
    _controller.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);
  }

  void _onTextChanged() {
    final hasText = _controller.text.isNotEmpty;
    if (hasText != _hasText) {
      setState(() {
        _hasText = hasText;
        if (hasText) _isExpanded = true;
      });
    }
  }

  void _onFocusChanged() {
    if (mounted) {
      setState(() {
        if (!_focusNode.hasFocus &&
            widget.collapsible &&
            _controller.text.trim().isEmpty) {
          _isExpanded = false;
        }
      });
    }

    if (_focusNode.hasFocus && widget.enableHistory) {
      _showOverlay();
    } else {
      // Delay removal to allow overlay tap events (InkWell) to fire before the widget is destroyed
      Future.delayed(const Duration(milliseconds: 200), () {
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
        builder: (ctx) {
          final renderBox = context.findRenderObject() as RenderBox?;
          final actualWidth = renderBox?.size.width;
          final safeWidth =
              actualWidth ??
              (widget.maxWidth == double.infinity ? 400.0 : widget.maxWidth);

          return Positioned(
            width: safeWidth,
            child: CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              offset: const Offset(0, 48),
              child: _buildHistoryOverlay(),
            ),
          );
        },
      );

      Overlay.of(context).insert(_overlayEntry!);
    });
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  Widget _buildHistoryOverlay() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final halfScreenHeight = MediaQuery.of(context).size.height * 0.5;

    return Consumer(
      builder: (context, ref, child) {
        final history = ref.watch(searchHistoryProvider);
        if (history.isEmpty) return const SizedBox.shrink();

        return Material(
          elevation: 4,
          color: isDark ? AppColors.darkSurfaceCard : Colors.white,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            constraints: BoxConstraints(maxHeight: halfScreenHeight),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : Colors.grey.shade200,
              ),
            ),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              shrinkWrap: true,
              itemCount: history.length,
              itemBuilder: (context, index) {
                final term = history[index];
                return Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () {
                          _controller.text = term;
                          if (widget.onSubmitted != null) {
                            widget.onSubmitted!(term);
                          }
                          ref
                              .read(searchHistoryProvider.notifier)
                              .addSearch(term);
                          Future.delayed(
                            const Duration(milliseconds: 50),
                            () {
                              if (mounted) _focusNode.unfocus();
                            },
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.history,
                                size: 18,
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : Colors.grey.shade400,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  term,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isDark
                                        ? AppColors.darkTextPrimary
                                        : Colors.black87,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    InkResponse(
                      radius: 16,
                      onTap: () {
                        ref
                            .read(searchHistoryProvider.notifier)
                            .removeSearch(term);
                        _focusNode.requestFocus();
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        child: Icon(
                          Icons.close_rounded,
                          size: 16,
                          color: isDark
                              ? AppColors.darkTextMuted
                              : Colors.grey.shade400,
                        ),
                      ),
                    ),
                  ],
                );
              },
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
    if (!_isExpanded && widget.collapsible && !_hasText) {
      return IconButton(
        onPressed: () {
          setState(() => _isExpanded = true);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _focusNode.requestFocus();
            }
          });
        },
        icon: const Icon(Icons.search, size: 32),
        tooltip: 'Search',
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return TapRegion(
      onTapOutside: (event) {
        if (_focusNode.hasFocus) {
          _focusNode.unfocus();
        }
      },
      child: CompositedTransformTarget(
        link: _layerLink,
        child: Container(
          width: widget.maxWidth,
          height: 42.0,
          decoration: BoxDecoration(
            color: _focusNode.hasFocus
                ? AppColors.primaryGreen.withValues(alpha: 0.05)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            textInputAction: TextInputAction.search,
            onSubmitted: _handleSubmit,
            onChanged: widget.onChanged,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? AppColors.darkTextPrimary : Colors.black87,
            ),
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: TextStyle(
                fontSize: 13,
                color: isDark ? AppColors.darkTextMuted : Colors.grey.shade500,
              ),
              prefixIcon: widget.hideIconWhenExpanded
                  ? null
                  : const Icon(
                      Icons.search_rounded,
                      size: 20,
                      color: AppColors.primaryGreen,
                    ),
              prefixIconConstraints: widget.hideIconWhenExpanded
                  ? const BoxConstraints(minWidth: 16, minHeight: 0)
                  : const BoxConstraints(minWidth: 42, minHeight: 42),
              suffixIcon:
                  widget.showClear &&
                      (_hasText ||
                          _controller.text.isNotEmpty ||
                          (widget.collapsible && _isExpanded))
                  ? IconButton(
                      icon: Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: isDark ? AppColors.darkTextMuted : Colors.grey.shade500,
                      ),
                      splashRadius: 16,
                      onPressed: () {
                        _controller.clear();
                        widget.onChanged?.call('');
                        widget.onSubmitted?.call('');
                        setState(() {
                          _hasText = false;
                        });
                        _focusNode.requestFocus();
                      },
                    )
                  : null,
              filled: false,
              isDense: true,
              contentPadding: const EdgeInsets.only(
                top: 11,
                bottom: 11,
                right: 12,
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
            ),
          ),
        ),
      ),
    );
  }
}
