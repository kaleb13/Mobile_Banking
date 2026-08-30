import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

/// Presentation mode of the [AppSearchBar] when unopened.
enum AppSearchBarMode {
  /// Always expanded full-width search input line.
  bar,

  /// Unopened state displays a title/label on the left and a rounded pill
  /// button `[ 🔍 Search ]` on the right. Tapping expands to the full line.
  pill,

  /// Unopened state displays leading widgets (e.g. filter/back), title in the center,
  /// and an icon-only search button `🔍` on the right. Tapping expands to the full line.
  icon,
}

/// Standardized Search Bar & Expandable Search Header component for the Mobile Banking design system.
///
/// Features:
/// - When active/opened, takes 100% of its row/line width.
/// - Left-aligned search icon inside the input.
/// - Right-aligned clear/close 'X' icon positioned **inside** the search input.
/// - 3 versatile unopened presentation modes: [AppSearchBarMode.bar], [AppSearchBarMode.pill], [AppSearchBarMode.icon].
/// - 100% fully rounded pill shape (`borderRadius: 100`) and zero border strokes.
class AppSearchBar extends StatefulWidget {
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String hint;
  final Widget? customHintWidget;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onClose;
  final ValueChanged<bool>? onExpandChanged;
  final bool? isExpanded;
  final bool initiallyExpanded;
  final bool autofocus;
  final AppSearchBarMode mode;

  /// Title or label shown when unopened in `pill` or `icon` mode.
  final String? title;

  /// Custom title widget shown when unopened in `pill` or `icon` mode.
  final Widget? titleWidget;

  /// Leading widget shown when unopened in `icon` mode (e.g. filter button, back button).
  final Widget? leading;

  /// Trailing widget shown alongside the search input or unopened header.
  final Widget? trailing;

  /// Text displayed inside the unopened pill button in `pill` mode (default: 'Search').
  final String pillLabel;

  /// Background color of the search input box.
  final Color? backgroundColor;

  /// Text color of the query input and unopened title.
  final Color? textColor;

  /// Color of the hint text.
  final Color? hintColor;

  /// Color of the leading search icon.
  final Color? iconColor;

  /// Color of the trailing clear / close icon.
  final Color? closeIconColor;

  /// Height of the search bar (default: 42).
  final double height;

  /// Border radius (default: 100 for 100% fully rounded pill shape).
  final double borderRadius;

  /// Outer padding around the search bar component.
  final EdgeInsetsGeometry padding;

  /// Whether to center the title horizontally when unopened.
  final bool centerTitle;

  const AppSearchBar({
    super.key,
    this.controller,
    this.focusNode,
    this.hint = 'Search...',
    this.customHintWidget,
    this.onChanged,
    this.onClear,
    this.onSubmitted,
    this.onClose,
    this.onExpandChanged,
    this.isExpanded,
    this.initiallyExpanded = false,
    this.autofocus = false,
    this.mode = AppSearchBarMode.bar,
    this.title,
    this.titleWidget,
    this.leading,
    this.trailing,
    this.pillLabel = 'Search',
    this.backgroundColor,
    this.textColor,
    this.hintColor,
    this.iconColor,
    this.closeIconColor,
    this.height = 42,
    this.borderRadius = 100,
    this.padding = EdgeInsets.zero,
    this.centerTitle = false,
  });

  @override
  State<AppSearchBar> createState() => _AppSearchBarState();
}

class _AppSearchBarState extends State<AppSearchBar> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  bool _internalController = false;
  bool _internalFocusNode = false;
  bool _hasText = false;
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    if (widget.controller == null) {
      _controller = TextEditingController();
      _internalController = true;
    } else {
      _controller = widget.controller!;
    }

    if (widget.focusNode == null) {
      _focusNode = FocusNode();
      _internalFocusNode = true;
    } else {
      _focusNode = widget.focusNode!;
    }

    _expanded = widget.isExpanded ??
        (widget.mode == AppSearchBarMode.bar || widget.initiallyExpanded);

    _hasText = _controller.text.isNotEmpty;
    _controller.addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(covariant AppSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isExpanded != null && widget.isExpanded != _expanded) {
      setState(() {
        _expanded = widget.isExpanded!;
      });
      if (_expanded && widget.autofocus) {
        _focusNode.requestFocus();
      }
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    if (_internalController) {
      _controller.dispose();
    }
    if (_internalFocusNode) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  void _onTextChanged() {
    final has = _controller.text.isNotEmpty;
    if (has != _hasText) {
      setState(() {
        _hasText = has;
      });
    }
  }

  void _expand() {
    setState(() {
      _expanded = true;
    });
    widget.onExpandChanged?.call(true);
    _focusNode.requestFocus();
  }

  void _collapse() {
    _controller.clear();
    _focusNode.unfocus();
    setState(() {
      _expanded = false;
      _hasText = false;
    });
    widget.onChanged?.call('');
    widget.onClear?.call();
    widget.onClose?.call();
    widget.onExpandChanged?.call(false);
  }

  void _handleClear() {
    _controller.clear();
    widget.onChanged?.call('');
    widget.onClear?.call();
  }

  @override
  Widget build(BuildContext context) {
    final isEffectiveExpanded = widget.mode == AppSearchBarMode.bar ||
        (widget.isExpanded ?? _expanded);

    return Padding(
      padding: widget.padding,
      child: AnimatedCrossFade(
        duration: const Duration(milliseconds: 220),
        firstCurve: Curves.easeOutCubic,
        secondCurve: Curves.easeInCubic,
        crossFadeState: isEffectiveExpanded
            ? CrossFadeState.showFirst
            : CrossFadeState.showSecond,
        firstChild: _buildFullWidthSearchInput(context),
        secondChild: _buildUnopenedHeader(context),
      ),
    );
  }

  /// Full-width search bar input covering the entirety of the row.
  Widget _buildFullWidthSearchInput(BuildContext context) {
    final bool isLight = Theme.of(context).brightness == Brightness.light ||
        widget.backgroundColor == AppColors.lightGreyBackground ||
        widget.textColor == AppColors.darkCharcoal;

    final bgColor = widget.backgroundColor ??
        (isLight ? AppColors.lightGreyBackground : AppColors.surface);

    final txtColor = widget.textColor ??
        (isLight ? AppColors.darkCharcoal : Colors.white);

    final hColor = widget.hintColor ??
        (isLight ? AppColors.greyText : AppColors.textSoft);

    final icColor = widget.iconColor ??
        (isLight ? AppColors.darkGreyText : AppColors.textSecondary);

    final clColor = widget.closeIconColor ??
        (isLight ? AppColors.darkCharcoal : Colors.white70);

    final isCollapsible = widget.mode != AppSearchBarMode.bar;

    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(widget.borderRadius),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          // Search icon inside on the left
          Icon(
            Icons.search_rounded,
            color: icColor,
            size: 18,
          ),
          const SizedBox(width: 8),

          // Search input field
          Expanded(
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                if (widget.customHintWidget != null && !_hasText)
                  IgnorePointer(child: widget.customHintWidget!),
                TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  autofocus: widget.autofocus,
                  cursorColor: isLight ? AppColors.darkCharcoal : AppColors.positive,
                  onChanged: widget.onChanged,
                  onSubmitted: widget.onSubmitted,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(80),
                  ],
                  style: TextStyle(
                    color: txtColor,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    hintText: widget.customHintWidget != null ? '' : widget.hint,
                    hintStyle: TextStyle(
                      color: hColor,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w400,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ],
            ),
          ),

          // Clear button ('X') when text is typed
          if (_hasText)
            GestureDetector(
              onTap: _handleClear,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.all(4.0),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: clColor.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.close_rounded,
                    color: clColor,
                    size: 14,
                  ),
                ),
              ),
            ),

          // Collapse button ('X') inside on the right when collapsible
          if (isCollapsible)
            GestureDetector(
              onTap: _collapse,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: Icon(
                  Icons.close_rounded,
                  color: clColor,
                  size: 18,
                ),
              ),
            ),

          if (widget.trailing != null) ...[
            const SizedBox(width: 4),
            widget.trailing!,
          ],
        ],
      ),
    );
  }

  /// Unopened header row representation according to [AppSearchBarMode].
  Widget _buildUnopenedHeader(BuildContext context) {
    final bool isLight = Theme.of(context).brightness == Brightness.light ||
        widget.backgroundColor == AppColors.lightGreyBackground ||
        widget.textColor == AppColors.darkCharcoal;

    final titleColor = widget.textColor ??
        (isLight ? AppColors.darkCharcoal : Colors.white);

    final iconColor = widget.iconColor ??
        (isLight ? AppColors.overlayDark50 : AppColors.textSecondary);

    final effectiveButtonBg = isLight
        ? AppColors.lightGreyBackground
        : (widget.backgroundColor ?? AppColors.buttonSecondary);

    if (widget.mode == AppSearchBarMode.pill) {
      if (widget.centerTitle) {
        return SizedBox(
          height: widget.height,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 80),
                  child: widget.titleWidget ??
                      Text(
                        widget.title ?? '',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: titleColor,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                ),
              ),
              Positioned(
                right: 0,
                child: GestureDetector(
                  onTap: _expand,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: effectiveButtonBg,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.search_rounded,
                          color: widget.iconColor ??
                              (isLight
                                  ? AppColors.darkCharcoal
                                  : AppColors.positive),
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          widget.pillLabel,
                          style: TextStyle(
                            color: widget.textColor ??
                                (isLight ? AppColors.darkCharcoal : Colors.white),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }

      return SizedBox(
        height: widget.height,
        child: Row(
          children: [
            if (widget.titleWidget != null)
              Expanded(child: widget.titleWidget!)
            else
              Expanded(
                child: Text(
                  widget.title ?? '',
                  style: TextStyle(
                    color: titleColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            GestureDetector(
              onTap: _expand,
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: effectiveButtonBg,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.search_rounded,
                      color: widget.iconColor ??
                          (isLight
                              ? AppColors.darkCharcoal
                              : AppColors.positive),
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      widget.pillLabel,
                      style: TextStyle(
                        color: widget.textColor ??
                            (isLight ? AppColors.darkCharcoal : Colors.white),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (widget.mode == AppSearchBarMode.icon) {
      if (widget.centerTitle) {
        return SizedBox(
          height: widget.height,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 48),
                  child: widget.titleWidget ??
                      Text(
                        widget.title ?? '',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: titleColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                ),
              ),
              if (widget.leading != null)
                Positioned(
                  left: 0,
                  child: widget.leading!,
                ),
              Positioned(
                right: 0,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        _expand();
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: effectiveButtonBg,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.search_rounded,
                          color: iconColor,
                          size: 18,
                        ),
                      ),
                    ),
                    if (widget.trailing != null) ...[
                      const SizedBox(width: 4),
                      widget.trailing!,
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      }

      return SizedBox(
        height: widget.height,
        child: Row(
          children: [
            if (widget.leading != null) ...[
              widget.leading!,
              const SizedBox(width: 10),
            ],
            Expanded(
              child: widget.titleWidget ??
                  Text(
                    widget.title ?? '',
                    textAlign: TextAlign.start,
                    style: TextStyle(
                      color: titleColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.3,
                    ),
                  ),
            ),
            GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                _expand();
              },
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: effectiveButtonBg,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.search_rounded,
                  color: iconColor,
                  size: 18,
                ),
              ),
            ),
            if (widget.trailing != null) ...[
              const SizedBox(width: 4),
              widget.trailing!,
            ],
          ],
        ),
      );
    }

    // Default bar mode fallback
    return _buildFullWidthSearchInput(context);
  }
}
