import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Standardized Search Bar component for the Mobile Banking design system.
///
/// Provides consistent theme styling, search icon, clear button, and focus behavior.
class AppSearchBar extends StatefulWidget {
  final TextEditingController? controller;
  final String hint;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  const AppSearchBar({
    super.key,
    this.controller,
    this.hint = 'Search...',
    this.onChanged,
    this.onClear,
    this.onSubmitted,
    this.autofocus = false,
    this.trailing,
    this.padding = EdgeInsets.zero,
  });

  @override
  State<AppSearchBar> createState() => _AppSearchBarState();
}

class _AppSearchBarState extends State<AppSearchBar> {
  late final TextEditingController _controller;
  bool _internalController = false;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    if (widget.controller == null) {
      _controller = TextEditingController();
      _internalController = true;
    } else {
      _controller = widget.controller!;
    }
    _hasText = _controller.text.isNotEmpty;
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    if (_internalController) {
      _controller.dispose();
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

  void _handleClear() {
    _controller.clear();
    widget.onChanged?.call('');
    widget.onClear?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: widget.padding,
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: context.themeTileBg,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            const Icon(
              Icons.search_rounded,
              color: AppColors.brandGreen,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _controller,
                autofocus: widget.autofocus,
                onChanged: widget.onChanged,
                onSubmitted: widget.onSubmitted,
                style: AppTypography.bodyMedium.copyWith(
                  color: context.themeTextPrimary,
                ),
                decoration: InputDecoration(
                  hintText: widget.hint,
                  hintStyle: AppTypography.bodyMedium.copyWith(
                    color: context.themeTextSecondary,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
            if (_hasText)
              GestureDetector(
                onTap: _handleClear,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: context.themeTextSecondary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.close_rounded,
                      color: context.themeTextSecondary,
                      size: 14,
                    ),
                  ),
                ),
              ),
            if (widget.trailing != null) ...[
              const SizedBox(width: 6),
              widget.trailing!,
            ],
          ],
        ),
      ),
    );
  }
}
