import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import 'app_badges.dart';
import 'app_button.dart';

enum AppToastType {
  info,
  success,
  warning,
  error,
}

/// Global top-floating frosted-glass Toast component with single source-of-truth card.
///
/// Features:
/// - Floats at the top with comfortable breathing room below the status bar.
/// - Single source-of-truth card: identical background, color, blur, and perimeter stroke in both compact and expanded states.
/// - Concentric countdown progress stroke in primary brand green inset 4px along the perimeter of the card.
/// - Tap to expand: pauses the countdown stroke and smoothly increases the card height downward with clean low-opacity description.
/// - Blurs the screen background when expanded.
/// - Tap outside or on 'X' to collapse/dismiss.
class AppToast {
  static OverlayEntry? _currentEntry;
  static Timer? _dismissTimer;

  /// Display a generic toast notification
  static void show(
    BuildContext context, {
    required String message,
    String? subtitle,
    String? details,
    Map<String, String>? metadata,
    String? actionLabel,
    VoidCallback? onAction,
    AppToastType type = AppToastType.info,
    Duration duration = const Duration(milliseconds: 3600),
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
        details: details,
        metadata: metadata,
        actionLabel: actionLabel,
        onAction: onAction,
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
  }

  /// Convenience helper for info toast
  static void info(
    BuildContext context, {
    required String message,
    String? subtitle,
    String? details,
    Map<String, String>? metadata,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(milliseconds: 3600),
  }) {
    show(
      context,
      message: message,
      subtitle: subtitle,
      details: details,
      metadata: metadata,
      actionLabel: actionLabel,
      onAction: onAction,
      type: AppToastType.info,
      duration: duration,
    );
  }

  /// Convenience helper for success toast
  static void success(
    BuildContext context, {
    required String message,
    String? subtitle,
    String? details,
    Map<String, String>? metadata,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(milliseconds: 3600),
  }) {
    show(
      context,
      message: message,
      subtitle: subtitle,
      details: details,
      metadata: metadata,
      actionLabel: actionLabel,
      onAction: onAction,
      type: AppToastType.success,
      duration: duration,
    );
  }

  /// Convenience helper for warning toast
  static void warning(
    BuildContext context, {
    required String message,
    String? subtitle,
    String? details,
    Map<String, String>? metadata,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(milliseconds: 3600),
  }) {
    show(
      context,
      message: message,
      subtitle: subtitle,
      details: details,
      metadata: metadata,
      actionLabel: actionLabel,
      onAction: onAction,
      type: AppToastType.warning,
      duration: duration,
    );
  }

  /// Convenience helper for error toast
  static void error(
    BuildContext context, {
    required String message,
    String? subtitle,
    String? details,
    Map<String, String>? metadata,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(milliseconds: 4200),
  }) {
    show(
      context,
      message: message,
      subtitle: subtitle,
      details: details,
      metadata: metadata,
      actionLabel: actionLabel,
      onAction: onAction,
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
  final String? details;
  final Map<String, String>? metadata;
  final String? actionLabel;
  final VoidCallback? onAction;
  final AppToastType type;
  final IconData? customIcon;
  final Duration duration;
  final VoidCallback onDismiss;

  const _AppToastWidget({
    required this.message,
    this.subtitle,
    this.details,
    this.metadata,
    this.actionLabel,
    this.onAction,
    required this.type,
    this.customIcon,
    required this.duration,
    required this.onDismiss,
  });

  @override
  State<_AppToastWidget> createState() => _AppToastWidgetState();
}

class _AppToastWidgetState extends State<_AppToastWidget>
    with TickerProviderStateMixin {
  late AnimationController _entryController;
  late Animation<Offset> _slideAnim;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;

  late AnimationController _progressController;
  late AnimationController _expandController;
  late Animation<double> _expandAnim;

  bool _isExpanded = false;
  bool _isDismissing = false;

  @override
  void initState() {
    super.initState();

    // 1. Entry & Exit slide / scale / fade controller
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
      reverseDuration: const Duration(milliseconds: 240),
    );

    _slideAnim = Tween<Offset>(
      begin: const Offset(0, -0.7),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      ),
    );

    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: Curves.easeOut,
        reverseCurve: Curves.easeIn,
      ),
    );

    _scaleAnim = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: Curves.easeOutBack,
        reverseCurve: Curves.easeIn,
      ),
    );

    // 2. Countdown progress controller (1.0 down to 0.0)
    _progressController = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _progressController.addStatusListener((status) {
      if (status == AnimationStatus.dismissed && !_isExpanded) {
        _handleDismiss();
      }
    });

    // 3. Dynamic Expand / Collapse Morph Controller
    _expandController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
      reverseDuration: const Duration(milliseconds: 240),
    );

    _expandAnim = CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    // Start entry animation and countdown progress
    _entryController.forward();
    _progressController.reverse(from: 1.0);
  }

  void _expandToast() {
    if (_isDismissing || _isExpanded) return;
    HapticFeedback.lightImpact();
    setState(() {
      _isExpanded = true;
    });
    _progressController.stop(); // Pause countdown timer on expand
    _expandController.forward();
  }

  void _shrinkToast() {
    if (_isDismissing || !_isExpanded) return;
    HapticFeedback.selectionClick();
    setState(() {
      _isExpanded = false;
    });
    _expandController.reverse().then((_) {
      if (mounted && !_isExpanded && !_isDismissing) {
        _progressController.reverse(from: _progressController.value); // Resume countdown
      }
    });
  }

  Future<void> _handleDismiss() async {
    if (_isDismissing) return;
    _isDismissing = true;
    _progressController.stop();

    if (_isExpanded) {
      _expandController.reverse();
    }

    if (_entryController.status != AnimationStatus.dismissed) {
      await _entryController.reverse();
    }
    if (mounted) {
      widget.onDismiss();
    }
  }

  @override
  void dispose() {
    _entryController.dispose();
    _progressController.dispose();
    _expandController.dispose();
    super.dispose();
  }

  IconData get _icon {
    if (widget.customIcon != null) return widget.customIcon!;
    switch (widget.type) {
      case AppToastType.success:
        return Icons.check_rounded;
      case AppToastType.warning:
        return Icons.warning_amber_rounded;
      case AppToastType.error:
        return Icons.error_outline_rounded;
      case AppToastType.info:
        return Icons.info_outline_rounded;
    }
  }

  String _resolvedDetailText() {
    if (widget.details != null && widget.details!.isNotEmpty) {
      return widget.details!;
    }
    if (widget.subtitle != null && widget.subtitle!.isNotEmpty) {
      return widget.subtitle!;
    }
    switch (widget.type) {
      case AppToastType.success:
        return 'Your changes have been safely updated and synchronized across all dashboards in real time.';
      case AppToastType.warning:
        return 'Please review the requested action to ensure your balances and transactions stay accurate.';
      case AppToastType.error:
        return 'An error occurred while performing this action. Please check your connectivity and try again.';
      case AppToastType.info:
        return 'This update has taken effect. You can manage or review this record anytime.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Stack(
      children: [
        // ── 1. Full Screen Backdrop Blur & Dark Barrier (Active on Expand) ─────
        AnimatedBuilder(
          animation: _expandAnim,
          builder: (context, child) {
            final expandVal = _expandAnim.value;
            if (expandVal <= 0.001) return const SizedBox.shrink();

            return Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _shrinkToast,
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: 8.0 * expandVal,
                    sigmaY: 8.0 * expandVal,
                  ),
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.40 * expandVal),
                  ),
                ),
              ),
            );
          },
        ),

        // ── 2. Top Floating Single Source-of-Truth Card ───────────────────────
        Positioned(
          top: topPadding + 20, // Comfortable breathing room below status bar
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
                animation: _entryController,
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
                child: AnimatedBuilder(
                  animation: Listenable.merge([_progressController, _expandAnim]),
                  builder: (context, _) {
                    return GestureDetector(
                      onTap: () {
                        if (!_isExpanded) {
                          _expandToast();
                        }
                      },
                      behavior: HitTestBehavior.opaque,
                      child: CustomPaint(
                        foregroundPainter: _CapsuleBorderCountdownPainter(
                          progress: _progressController.value,
                          progressColor: AppColors.brandGreen,
                          trackColor: Colors.white.withValues(alpha: 0.10),
                          strokeWidth: 2.2,
                          inset: 4.0,
                          cornerRadius: AppRadius.card,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.card),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
                            child: Container(
                              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceElevated.withValues(alpha: 0.82),
                                borderRadius: BorderRadius.circular(AppRadius.card),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.35),
                                    blurRadius: 30,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: AnimatedSize(
                                duration: const Duration(milliseconds: 260),
                                curve: Curves.easeOutCubic,
                                alignment: Alignment.topCenter,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // ── Main Row (Always Identical) ──────────
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        // Leading: Semantic Icon Badge
                                        Container(
                                          width: 32,
                                          height: 32,
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(alpha: 0.14),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Center(
                                            child: Icon(
                                              _icon,
                                              color: Colors.white,
                                              size: 17,
                                            ),
                                          ),
                                        ),

                                        const SizedBox(width: 12),

                                        // Middle: Title & Description
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                widget.message,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12.5,
                                                  fontWeight: FontWeight.w600,
                                                  letterSpacing: -0.2,
                                                ),
                                                maxLines: _isExpanded ? null : 1,
                                                overflow: _isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                                              ),
                                              if (widget.subtitle != null &&
                                                  widget.subtitle!.isNotEmpty &&
                                                  !_isExpanded) ...[
                                                const SizedBox(height: 1.5),
                                                Text(
                                                  widget.subtitle!,
                                                  style: TextStyle(
                                                    color: Colors.white.withValues(alpha: 0.70),
                                                    fontSize: 10.5,
                                                    fontWeight: FontWeight.w400,
                                                    letterSpacing: -0.1,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),

                                        const SizedBox(width: 8),

                                        // Trailing: Vertically Centered Close Button 'X'
                                        GestureDetector(
                                          behavior: HitTestBehavior.opaque,
                                          onTap: () {
                                            HapticFeedback.selectionClick();
                                            _handleDismiss();
                                          },
                                          child: Container(
                                            width: 26,
                                            height: 26,
                                            decoration: BoxDecoration(
                                              color: Colors.white.withValues(alpha: 0.12),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Center(
                                              child: Icon(
                                                Icons.close_rounded,
                                                color: Colors.white,
                                                size: 13,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),

                                    // ── Expanded Section (Clean & Simple) ────
                                    ClipRect(
                                      child: AnimatedCrossFade(
                                        firstChild: const SizedBox(width: double.infinity, height: 0),
                                        secondChild: Padding(
                                          padding: const EdgeInsets.only(top: 14),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              // Low-opacity clean description text
                                              Text(
                                                _resolvedDetailText(),
                                                style: TextStyle(
                                                  color: Colors.white.withValues(alpha: 0.70),
                                                  fontSize: 12.0,
                                                  fontWeight: FontWeight.w400,
                                                  height: 1.45,
                                                  letterSpacing: -0.1,
                                                ),
                                              ),

                                              // Optional Standard Badge Key-Values
                                              if (widget.metadata != null && widget.metadata!.isNotEmpty) ...[
                                                const SizedBox(height: 12),
                                                Wrap(
                                                  spacing: 6,
                                                  runSpacing: 6,
                                                  children: widget.metadata!.entries.map((entry) {
                                                    return AppBadge.neutral(
                                                      text: '${entry.key}: ${entry.value}',
                                                      size: AppBadgeSize.small,
                                                    );
                                                  }).toList(),
                                                ),
                                              ],

                                              // Optional Action Button
                                              if (widget.actionLabel != null && widget.actionLabel!.isNotEmpty) ...[
                                                const SizedBox(height: 14),
                                                AppButton.primary(
                                                  text: widget.actionLabel!,
                                                  height: 36,
                                                  onPressed: () {
                                                    widget.onAction?.call();
                                                    _handleDismiss();
                                                  },
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        crossFadeState: _isExpanded
                                            ? CrossFadeState.showSecond
                                            : CrossFadeState.showFirst,
                                        duration: const Duration(milliseconds: 240),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Custom painter that renders a smooth concentric decreasing countdown stroke inset inside the perimeter of the card
class _CapsuleBorderCountdownPainter extends CustomPainter {
  final double progress;
  final Color progressColor;
  final Color trackColor;
  final double strokeWidth;
  final double inset;
  final double cornerRadius;

  const _CapsuleBorderCountdownPainter({
    required this.progress,
    required this.progressColor,
    required this.trackColor,
    this.strokeWidth = 2.2,
    this.inset = 4.0,
    this.cornerRadius = 32.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final rect = Rect.fromLTWH(
      inset,
      inset,
      size.width - (inset * 2),
      size.height - (inset * 2),
    );
    // Concentric inner corner radius: R_inner = R_outer - inset
    final concentricRadius = math.max(0.0, cornerRadius - inset);
    final effectiveRadius = math.min(concentricRadius, (size.height - (inset * 2)) / 2);
    final rrect = RRect.fromRectAndRadius(
      rect,
      Radius.circular(effectiveRadius),
    );

    // 1. Draw subtle background perimeter track
    if (trackColor.opacity > 0) {
      final trackPaint = Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth;
      canvas.drawRRect(rrect, trackPaint);
    }

    // 2. Draw decreasing primary green progress stroke along the perimeter of the card
    if (progress > 0) {
      final basePath = Path()..addRRect(rrect);
      final pathMetrics = basePath.computeMetrics().toList();
      if (pathMetrics.isNotEmpty) {
        final metric = pathMetrics.first;
        final totalLength = metric.length;
        final currentLength = totalLength * progress.clamp(0.0, 1.0);

        final extractedPath = metric.extractPath(0.0, currentLength);

        final progressPaint = Paint()
          ..color = progressColor
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = strokeWidth;

        canvas.drawPath(extractedPath, progressPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CapsuleBorderCountdownPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.progressColor != progressColor ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.inset != inset ||
        oldDelegate.cornerRadius != cornerRadius;
  }
}
