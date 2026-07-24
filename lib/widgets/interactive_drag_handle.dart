import 'package:flutter/material.dart';

/// An interactive drag handle pill indicator.
/// Responds to touch/drag by increasing width slightly and switching to a strong active color.
class InteractiveDragHandle extends StatefulWidget {
  final VoidCallback? onTap;
  final GestureDragUpdateCallback? onVerticalDragUpdate;
  final GestureDragEndCallback? onVerticalDragEnd;
  final Color? color;
  final double width;
  final double height;
  final EdgeInsetsGeometry padding;

  const InteractiveDragHandle({
    super.key,
    this.onTap,
    this.onVerticalDragUpdate,
    this.onVerticalDragEnd,
    this.color,
    this.width = 44,
    this.height = 4,
    this.padding = const EdgeInsets.symmetric(vertical: 8),
  });

  @override
  State<InteractiveDragHandle> createState() => _InteractiveDragHandleState();
}

class _InteractiveDragHandleState extends State<InteractiveDragHandle> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final inactiveColor = widget.color ?? Colors.white.withValues(alpha: 0.25);
    final bool isDarkHandle = (widget.color?.computeLuminance() ?? 0.5) < 0.3;
    final Color activeColor = isDarkHandle ? const Color(0xFF0F172A) : Colors.white;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      onVerticalDragStart: (_) => setState(() => _isPressed = true),
      onVerticalDragUpdate: widget.onVerticalDragUpdate,
      onVerticalDragEnd: (details) {
        setState(() => _isPressed = false);
        widget.onVerticalDragEnd?.call(details);
      },
      child: Padding(
        padding: widget.padding,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          width: _isPressed ? widget.width + 8 : widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: _isPressed ? activeColor : inactiveColor,
            borderRadius: BorderRadius.circular(widget.height / 2),
          ),
        ),
      ),
    );
  }
}
