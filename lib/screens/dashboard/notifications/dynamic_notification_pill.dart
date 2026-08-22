import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../presentation/viewmodels/notifications_view_model.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/hold_to_refresh.dart';
import 'notifications_panel_overlay.dart';

class DynamicNotificationPill extends StatefulWidget {
  const DynamicNotificationPill({super.key});

  @override
  State<DynamicNotificationPill> createState() =>
      _DynamicNotificationPillState();
}

class _DynamicNotificationPillState extends State<DynamicNotificationPill>
    with TickerProviderStateMixin {
  final GlobalKey _pillKey = GlobalKey();
  OverlayEntry? _overlayEntry;
  late AnimationController _animController;
  late Animation<double> _expandAnim;
  late Animation<double> _fadeAnim;

  late AnimationController _unfurlCtrl;
  late Animation<double> _unfurlAnim;
  bool _isCircle = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _expandAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.3, 1.0, curve: Curves.easeIn),
    );

    _unfurlCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    );
    _unfurlAnim = CurvedAnimation(
      parent: _unfurlCtrl,
      curve: Curves.easeInOutCubic,
    );

    _triggerUnfurlAnimation();
  }

  void _triggerUnfurlAnimation() async {
    if (!mounted) return;
    setState(() {
      _isCircle = true;
    });
    _unfurlCtrl.reset();
    await Future.delayed(const Duration(milliseconds: 450));
    if (mounted) {
      _unfurlCtrl.forward().then((_) {
        if (mounted) {
          setState(() {
            _isCircle = false;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _removeOverlay();
    _animController.dispose();
    _unfurlCtrl.dispose();
    super.dispose();
  }

  void _openPanel() {
    final notifVM = Provider.of<NotificationsViewModel>(context, listen: false);
    if (!notifVM.hasPermission) {
      notifVM.requestPermission();
      return;
    }
    _unfurlCtrl.stop();
    _isCircle = false;

    final RenderBox? renderBox =
        _pillKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return;

    final Offset pillOffset = renderBox.localToGlobal(Offset.zero);
    final double pillWidth = renderBox.size.width;
    final double pillTop = pillOffset.dy;
    final double screenHeight = MediaQuery.of(context).size.height;
    final double bottomInset =
        MediaQuery.of(context).viewPadding.bottom + 80 + 16;
    final double expandedHeight = screenHeight - pillTop - bottomInset;

    _overlayEntry = OverlayEntry(
      builder: (ctx) => NotificationsPanelOverlay(
        pillTop: pillTop,
        pillLeft: pillOffset.dx,
        pillWidth: pillWidth,
        expandedHeight: expandedHeight,
        expandAnim: _expandAnim,
        fadeAnim: _fadeAnim,
        onClose: _closePanel,
      ),
    );

    Overlay.of(context, rootOverlay: true).insert(_overlayEntry!);
    _animController.forward();
    if (mounted) setState(() {});
  }

  void _closePanel() async {
    await _animController.reverse();
    _removeOverlay();
    _triggerUnfurlAnimation();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    final notifsVM = context.watch<NotificationsViewModel>();
    final unreadCount = notifsVM.unreadCount;

    return AnimatedBuilder(
      animation: Listenable.merge([_expandAnim, _unfurlAnim]),
      builder: (context, child) {
        final double pillOpacity = (1.0 - _expandAnim.value).clamp(0.0, 1.0);
        return Opacity(
          opacity: pillOpacity,
          child: child!,
        );
      },
      child: ValueListenableBuilder<RefreshState>(
        valueListenable: refreshStateNotifier,
        builder: (context, refreshState, _) {
          final isRefreshing = refreshState.phase != RefreshPhase.idle;
          final double maxPillWidth = MediaQuery.of(context).size.width - 32.0;
          final double idlePillWidth = !notifsVM.hasPermission
              ? 210.0
              : unreadCount > 0
                  ? 195.0
                  : 180.0;

          final double baseWidth;
          if (_isCircle || _unfurlCtrl.isAnimating) {
            baseWidth = lerpDouble(38.0, idlePillWidth, _unfurlAnim.value) ??
                idlePillWidth;
          } else {
            baseWidth = idlePillWidth;
          }

          final double targetWidth;
          if (refreshState.phase == RefreshPhase.idle) {
            targetWidth = baseWidth;
          } else if (refreshState.phase == RefreshPhase.dragging) {
            targetWidth = lerpDouble(
                  baseWidth,
                  maxPillWidth,
                  refreshState.dragProgress,
                ) ??
                baseWidth;
          } else {
            targetWidth = maxPillWidth;
          }

          return GestureDetector(
            key: _pillKey,
            onTap: isRefreshing ? null : _openPanel,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              height: 38,
              width: targetWidth,
              padding: (isRefreshing || _isCircle || targetWidth < 60.0)
                  ? EdgeInsets.zero
                  : const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: isRefreshing
                    ? AppColors.positive.withValues(alpha: 0.07)
                    : Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(19),
              ),
              child: SizedBox(
                width: targetWidth,
                height: 38,
                child: RefreshAwarePillContent(
                  idleChild: ClipRRect(
                    borderRadius: BorderRadius.circular(19),
                    child: ClipRect(
                      child: Center(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const NeverScrollableScrollPhysics(),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 22,
                                height: 38,
                                child: Center(
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    alignment: Alignment.center,
                                    children: [
                                      const Icon(
                                        Icons.notifications,
                                        color: AppColors.textSoft,
                                        size: 16,
                                      ),
                                      if (unreadCount > 0)
                                        Positioned(
                                          right: 0,
                                          top: 2,
                                          child: Container(
                                            width: 6,
                                            height: 6,
                                            decoration: const BoxDecoration(
                                              color: AppColors.gold,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              AnimatedBuilder(
                                animation: _unfurlAnim,
                                builder: (context, _) {
                                  if (targetWidth < 60.0) {
                                    return const SizedBox.shrink();
                                  }

                                  final double textOpacity;
                                  if (_isCircle || _unfurlCtrl.isAnimating) {
                                    final double unfurlT = _unfurlAnim.value;
                                    if (unfurlT < 0.25) {
                                      textOpacity = 0.0;
                                    } else {
                                      textOpacity = ((unfurlT - 0.25) / 0.75)
                                          .clamp(0.0, 1.0);
                                    }
                                  } else {
                                    textOpacity = 1.0;
                                  }

                                  return Opacity(
                                    opacity: textOpacity,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const SizedBox(width: 8),
                                        Text(
                                          !notifsVM.hasPermission
                                              ? 'Tap to enable SMS tracking'
                                              : unreadCount > 0
                                                  ? '$unreadCount unread notification${unreadCount > 1 ? 's' : ''}'
                                                  : 'No new notifications',
                                          style: TextStyle(
                                            color: !notifsVM.hasPermission
                                                ? AppColors.positive
                                                : AppColors.textSoft,
                                            fontSize: 12,
                                            fontWeight: !notifsVM.hasPermission
                                                ? FontWeight.w600
                                                : FontWeight.w400,
                                            letterSpacing: -0.1,
                                          ),
                                          maxLines: 1,
                                          softWrap: false,
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
