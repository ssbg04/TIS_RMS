import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  late TextEditingController _controller;
  late FocusNode _focusNode;
  bool _hasText = false;
  bool _isExpanded = false;

  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();
  final Object _tapRegionGroupId = Object();
  bool _isOverlayOpen = false;
  bool _isPointerOverOverlay = false;

  @override
  void didUpdateWidget(AppSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      if (oldWidget.controller == null) {
        _controller.removeListener(_onTextChanged);
        _controller.dispose();
      } else {
        oldWidget.controller!.removeListener(_onTextChanged);
      }
      _controller = widget.controller ?? TextEditingController();
      _controller.addListener(_onTextChanged);
    }
    if (oldWidget.focusNode != widget.focusNode) {
      if (oldWidget.focusNode == null) {
        _focusNode.removeListener(_onFocusChanged);
        _focusNode.dispose();
      } else {
        oldWidget.focusNode!.removeListener(_onFocusChanged);
      }
      _focusNode = widget.focusNode ?? FocusNode();
      _focusNode.addListener(_onFocusChanged);
    }
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
    if (_isOverlayOpen) {
      _overlayEntry?.markNeedsBuild();
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
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted && !_focusNode.hasFocus && !_isPointerOverOverlay) {
          _removeOverlay();

          if (widget.collapsible && _controller.text.trim().isEmpty) {
            setState(() => _isExpanded = false);
          }
        }
      });
    }
  }

  void _showOverlay() {
    if (!widget.enableHistory || !mounted) return;

    final history = ref.read(searchHistoryProvider);
    if (history.isEmpty) return;

    if (_overlayEntry != null) {
      _isOverlayOpen = true;
      _overlayEntry?.markNeedsBuild();
      return;
    }

    _isOverlayOpen = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          !_isOverlayOpen ||
          (!_focusNode.hasFocus && !_isPointerOverOverlay) ||
          _overlayEntry != null) {
        return;
      }

      final overlay = Overlay.maybeOf(context);
      if (overlay == null) return;

      _overlayEntry = OverlayEntry(
        builder: (ctx) {
          final renderBox = context.findRenderObject() as RenderBox?;
          final actualWidth = (renderBox != null && renderBox.hasSize)
              ? renderBox.size.width
              : (widget.maxWidth == double.infinity
                  ? 400.0
                  : widget.maxWidth);

          return Positioned(
            width: actualWidth,
            child: CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              offset: const Offset(0, 48),
              child: TapRegion(
                groupId: _tapRegionGroupId,
                behavior: HitTestBehavior.opaque,
                child: MouseRegion(
                  onEnter: (_) => _isPointerOverOverlay = true,
                  onExit: (_) => _isPointerOverOverlay = false,
                  child: _buildHistoryOverlay(),
                ),
              ),
            ),
          );
        },
      );

      overlay.insert(_overlayEntry!);
    });
  }

  void _removeOverlay() {
    _isOverlayOpen = false;
    _isPointerOverOverlay = false;
    if (_overlayEntry != null) {
      if (_overlayEntry!.mounted) {
        _overlayEntry!.remove();
      }
      _overlayEntry = null;
    }
  }

  Widget _buildHistoryOverlay() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final halfScreenHeight = MediaQuery.of(context).size.height * 0.5;

    return Consumer(
      builder: (context, ref, child) {
        final history = ref.watch(searchHistoryProvider);
        if (history.isEmpty) return const SizedBox.shrink();

        final query = _controller.text.trim().toLowerCase();
        final displayList = query.isEmpty
            ? history
            : history
                .where((item) => item.toLowerCase().contains(query))
                .toList();

        if (displayList.isEmpty) return const SizedBox.shrink();

        return Focus(
          canRequestFocus: false,
          skipTraversal: true,
          descendantsAreFocusable: false,
          child: Material(
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 12, 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Recent Searches',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppColors.darkTextMuted
                                : Colors.grey.shade500,
                            letterSpacing: 0.3,
                          ),
                        ),
                        InkWell(
                          borderRadius: BorderRadius.circular(4),
                          canRequestFocus: false,
                          onTap: () {
                            ref
                                .read(searchHistoryProvider.notifier)
                                .clearHistory();
                            _removeOverlay();
                            if (!_focusNode.hasFocus) {
                              _focusNode.requestFocus();
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            child: Text(
                              'Clear all',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : Colors.grey.shade600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: isDark ? AppColors.darkBorder : Colors.grey.shade200,
                  ),
                  Flexible(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      shrinkWrap: true,
                      itemCount: displayList.length,
                      itemBuilder: (context, index) {
                        final term = displayList[index];
                        return Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                borderRadius: BorderRadius.circular(8),
                                canRequestFocus: false,
                                onTap: () {
                                  final selected = term;
                                  _controller.text = selected;
                                  _controller.selection = TextSelection.collapsed(
                                    offset: selected.length,
                                  );
                                  setState(() {
                                    _hasText = selected.isNotEmpty;
                                  });
                                  ref
                                      .read(searchHistoryProvider.notifier)
                                      .addSearch(selected);
                                  widget.onChanged?.call(selected);
                                  widget.onSubmitted?.call(selected);
                                  _removeOverlay();
                                  _focusNode.unfocus();
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 9,
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
                            IconButton(
                              icon: Icon(
                                Icons.close_rounded,
                                size: 16,
                                color: isDark
                                    ? AppColors.darkTextMuted
                                    : Colors.grey.shade400,
                              ),
                              splashRadius: 16,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              constraints: const BoxConstraints(),
                              tooltip: 'Remove',
                              onPressed: () {
                                ref
                                    .read(searchHistoryProvider.notifier)
                                    .removeSearch(term);
                                if (!_focusNode.hasFocus) {
                                  _focusNode.requestFocus();
                                }
                                if (_overlayEntry != null) {
                                  _overlayEntry!.markNeedsBuild();
                                }
                              },
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
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
    final query = val.trim();
    if (query.isNotEmpty) {
      if (widget.enableHistory) {
        ref.read(searchHistoryProvider.notifier).addSearch(query);
      }
      widget.onSubmitted?.call(query);
    }
    _removeOverlay();
    _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<List<String>>(searchHistoryProvider, (previous, next) {
      if (!mounted) return;
      if (next.isEmpty && _isOverlayOpen) {
        _removeOverlay();
      } else if (next.isNotEmpty &&
          _focusNode.hasFocus &&
          !_isOverlayOpen &&
          widget.enableHistory) {
        _showOverlay();
      } else if (_isOverlayOpen) {
        _overlayEntry?.markNeedsBuild();
      }
    });

    if (!_isExpanded && widget.collapsible && !_hasText) {
      return IconButton(
        onPressed: () {
          setState(() => _isExpanded = true);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _focusNode.requestFocus();
              if (widget.enableHistory) {
                _showOverlay();
              }
            }
          });
        },
        icon: const Icon(Icons.search, size: 32),
        tooltip: 'Search',
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (_isOverlayOpen) {
            _removeOverlay();
          } else if (_focusNode.hasFocus) {
            _focusNode.unfocus();
          }
        },
      },
      child: TapRegion(
        groupId: _tapRegionGroupId,
        behavior: HitTestBehavior.opaque,
        onTapOutside: (event) {
          if (!_isPointerOverOverlay) {
            if (_focusNode.hasFocus) {
              _focusNode.unfocus();
            }
            _removeOverlay();
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
              onTap: () {
                if (widget.enableHistory) {
                  _showOverlay();
                }
              },
              style: TextStyle(
                fontSize: 14,
                color: isDark ? AppColors.darkTextPrimary : Colors.black87,
              ),
              decoration: InputDecoration(
                hintText: widget.hint,
                hintStyle: TextStyle(
                  fontSize: 13,
                  color:
                      isDark ? AppColors.darkTextMuted : Colors.grey.shade500,
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
                suffixIcon: widget.showClear &&
                        (_hasText ||
                            _controller.text.isNotEmpty ||
                            (widget.collapsible && _isExpanded))
                    ? IconButton(
                        focusNode: FocusNode(
                          skipTraversal: true,
                          canRequestFocus: false,
                        ),
                        icon: Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: isDark
                              ? AppColors.darkTextMuted
                              : Colors.grey.shade500,
                        ),
                        splashRadius: 16,
                        onPressed: () {
                          _controller.clear();
                          widget.onChanged?.call('');
                          widget.onSubmitted?.call('');
                          setState(() {
                            _hasText = false;
                          });
                          if (!_focusNode.hasFocus) {
                            _focusNode.requestFocus();
                          }
                          if (widget.enableHistory) {
                            _showOverlay();
                            _overlayEntry?.markNeedsBuild();
                          }
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
      ),
    );
  }
}
