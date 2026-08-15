import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

enum AppToastType {
  info,
  success,
  warning,
  error,
}

/// Global top-floating frosted-glass Toast Notification component.
///
/// Features:
/// - Floats at the top of the screen (underneath the SafeArea).
/// - Translucent dark frosted glass with Gaussian backdrop blur.
/// - 100% borderless rounded rectangle (`borderRadius: 20`).
/// - Pure white text, semantic leading icon, and top-right close 'x' button.
/// - Auto-dismisses, swipe-up to dismiss, or tap 'x' to dismiss.
class AppToast {
  static OverlayEntry? _currentEntry;
  static Timer? _dismissTimer;

  /// Display a generic toast notification
  static void show(
    BuildContext context, {
    required String message,
    String? subtitle,
    AppToastType type = AppToastType.info,
    Duration duration = const Duration(milliseconds: 3200),
    IconData? customIcon,
  }) {
    // Dismiss any active toast immediately
    hide();

    final overlayState = Overlay.of(context, rootOverlay: true);

    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) => _AppToastWidget(
        message: message,
        subtitle: subtitle,
        type: type,
        customIcon: customIcon,
        duration: duration,
        onDismiss: () {
          if (_currentEntry == entry) {
            hide();
          }
        },
      ),
    );

    _currentEntry = entry;
    overlayState.insert(entry);

    _dismissTimer = Timer(duration, () {
      if (_currentEntry == entry) {
        hide();
      }
    });
  }

  /// Convenience helper for info toast
  static void info(
    BuildContext context, {
    required String message,
    String? subtitle,
    Duration duration = const Duration(milliseconds: 3200),
  }) {
    show(
      context,
      message: message,
      subtitle: subtitle,
      type: AppToastType.info,
      duration: duration,
    );
  }

  /// Convenience helper for success toast
  static void success(
    BuildContext context, {
    required String message,
    String? subtitle,
    Duration duration = const Duration(milliseconds: 3200),
  }) {
    show(
      context,
      message: message,
      subtitle: subtitle,
      type: AppToastType.success,
      duration: duration,
    );
  }

  /// Convenience helper for warning toast
  static void warning(
    BuildContext context, {
    required String message,
    String? subtitle,
    Duration duration = const Duration(milliseconds: 3200),
  }) {
    show(
      context,
      message: message,
      subtitle: subtitle,
      type: AppToastType.warning,
      duration: duration,
    );
  }

  /// Convenience helper for error toast
  static void error(
    BuildContext context, {
    required String message,
    String? subtitle,
    Duration duration = const Duration(milliseconds: 3800),
  }) {
    show(
      context,
      message: message,
      subtitle: subtitle,
      type: AppToastType.error,
      duration: duration,
    );
  }

  /// Dismiss the active toast immediately
  static void hide() {
    _dismissTimer?.cancel();
    _dismissTimer = null;
    _currentEntry?.remove();
    _currentEntry = null;
  }
}

class _AppToastWidget extends StatefulWidget {
  final String message;
  final String? subtitle;
  final AppToastType type;
  final IconData? customIcon;
  final Duration duration;
  final VoidCallback onDismiss;

  const _AppToastWidget({
    required this.message,
    this.subtitle,
    required this.type,
    this.customIcon,
    required this.duration,
    required this.onDismiss,
  });

  @override
  State<_AppToastWidget> createState() => _AppToastWidgetState();
}

class _AppToastWidgetState extends State<_AppToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnim;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 340),
      reverseDuration: const Duration(milliseconds: 240),
    );

    _slideAnim = Tween<Offset>(
      begin: const Offset(0, -0.6),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      ),
    );

    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
        reverseCurve: Curves.easeIn,
      ),
    );

    _scaleAnim = Tween<double>(begin: 0.94, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutBack,
        reverseCurve: Curves.easeIn,
      ),
    );

    _controller.forward();
  }

  Future<void> _handleDismiss() async {
    if (_controller.isAnimating || !_controller.isCompleted) return;
    await _controller.reverse();
    widget.onDismiss();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  IconData get _icon {
    if (widget.customIcon != null) return widget.customIcon!;
    switch (widget.type) {
      case AppToastType.success:
        return Icons.check_circle_rounded;
      case AppToastType.warning:
        return Icons.warning_amber_rounded;
      case AppToastType.error:
        return Icons.error_outline_rounded;
      case AppToastType.info:
        return Icons.info_outline_rounded;
    }
  }

  Color get _iconBgColor {
    return Colors.white.withValues(alpha: 0.14);
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Positioned(
      top: topPadding + 10,
      left: 16,
      right: 16,
      child: Material(
        type: MaterialType.transparency,
        child: GestureDetector(
          onVerticalDragUpdate: (details) {
            if (details.primaryDelta! < -4) {
              _handleDismiss();
            }
          },
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return SlideTransition(
                position: _slideAnim,
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: Transform.scale(
                    scale: _scaleAnim.value,
                    child: child,
                  ),
                ),
              );
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated.withValues(alpha: 0.88),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      // Content Row (with right padding for the top-right X button)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 38, 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Leading Semantic Icon (Pure White with Soft Tinted Circle)
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: _iconBgColor,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _icon,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),

                            const SizedBox(width: 12),

                            // Text Content (Message & Subtitle)
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    widget.message,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: -0.2,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (widget.subtitle != null &&
                                      widget.subtitle!.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      widget.subtitle!,
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.70),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w400,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Top-Right Close Button 'X' (Positioned strictly in top-right corner)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            _handleDismiss();
                          },
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.14),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              color: Colors.white,
                              size: 13,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
