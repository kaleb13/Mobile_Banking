import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../presentation/viewmodels/notifications_view_model.dart';
import '../../../services/auth_service.dart';
import '../../../services/cloud_sync_service.dart';
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

  // ── Dynamic Feed Cycling (Notifications ⟷ Cloud Sync & Offline) ───────────
  Timer? _feedTimer;
  int _feedIndex = 0; // 0: Phone SMS Notifications, 1: Cloud Sync & Offline

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
    _startFeedTimer();
    CloudSyncService.instance.statusNotifier.addListener(_onSyncStatusChanged);
  }

  void _onSyncStatusChanged() {
    if (!mounted) return;
    final status = CloudSyncService.instance.statusNotifier.value;
    if (status == CloudSyncStatus.syncing || status == CloudSyncStatus.offline) {
      setState(() => _feedIndex = 1);
      _restartFeedTimer();
    } else {
      setState(() {});
    }
  }

  void _startFeedTimer() {
    _feedTimer?.cancel();
    _feedTimer = Timer.periodic(const Duration(milliseconds: 4800), (_) {
      if (!mounted) return;
      if (refreshStateNotifier.value.phase != RefreshPhase.idle) return;
      if (_overlayEntry != null || _isCircle || _unfurlCtrl.isAnimating) return;
      setState(() {
        _feedIndex = (_feedIndex == 0) ? 1 : 0;
      });
    });
  }

  void _restartFeedTimer() {
    _feedTimer?.cancel();
    _startFeedTimer();
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

  bool _isClosing = false;

  @override
  void dispose() {
    CloudSyncService.instance.statusNotifier.removeListener(_onSyncStatusChanged);
    _feedTimer?.cancel();
    if (_overlayEntry != null) {
      try {
        Provider.of<NotificationsViewModel>(context, listen: false)
            .setPanelOpen(false);
      } catch (_) {}
    }
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
    _feedTimer?.cancel();
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
    notifVM.setPanelOpen(true, onClose: _closePanel);
    _animController.forward();
    if (mounted) setState(() {});
  }

  void _closePanel() async {
    if (_isClosing) return;
    _isClosing = true;
    if (mounted) {
      try {
        Provider.of<NotificationsViewModel>(context, listen: false)
            .setPanelOpen(false);
      } catch (_) {}
    }
    try {
      await _animController.reverse();
      _removeOverlay();
      _triggerUnfurlAnimation();
      _startFeedTimer();
    } finally {
      _isClosing = false;
    }
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  Widget _buildAnimatedText({
    required double targetWidth,
    required String text,
    required Color textColor,
    required FontWeight fontWeight,
  }) {
    return AnimatedBuilder(
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
            textOpacity = ((unfurlT - 0.25) / 0.75).clamp(0.0, 1.0);
          }
        } else {
          textOpacity = 1.0;
        }

        return Opacity(
          opacity: textOpacity,
          child: Text(
            text,
            style: TextStyle(
              color: textColor,
              fontSize: 12,
              fontWeight: fontWeight,
              letterSpacing: -0.1,
            ),
            maxLines: 1,
            softWrap: false,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final notifsVM = context.watch<NotificationsViewModel>();
    final unreadCount = notifsVM.unreadCount;
    final syncStatus = CloudSyncService.instance.statusNotifier.value;
    final isAuthenticated = AuthService.instance.isAuthenticated;

    // ── Feed Item 0: Phone SMS Notifications ──
    final String notifText = !notifsVM.hasPermission
        ? 'Tap to enable SMS tracking'
        : unreadCount > 0
            ? '$unreadCount unread notification${unreadCount > 1 ? 's' : ''}'
            : 'No unread notifications';
    final Color notifColor = !notifsVM.hasPermission
        ? AppColors.positive
        : AppColors.textSoft;
    final double notifWidth = !notifsVM.hasPermission
        ? 198.0
        : (unreadCount > 0 ? 186.0 : 178.0);

    // ── Feed Item 1: Cloud Sync & Offline Status ──
    String syncText;
    IconData syncIcon;
    Color syncIconColor = AppColors.textSoft;
    Color syncTextColor = AppColors.textSoft;
    double syncWidth = 178.0;

    switch (syncStatus) {
      case CloudSyncStatus.syncing:
        syncText = 'Syncing is active';
        syncIcon = Icons.cloud_done;
        syncIconColor = AppColors.textSoft;
        syncTextColor = AppColors.textSoft;
        syncWidth = 172.0;
        break;
      case CloudSyncStatus.offline:
        syncText = 'Offline • Local storage';
        syncIcon = Icons.cloud_off_rounded;
        syncIconColor = AppColors.textSoft;
        syncTextColor = AppColors.textSoft;
        syncWidth = 182.0;
        break;
      case CloudSyncStatus.success:
        syncText = 'Cloud backup up to date';
        syncIcon = Icons.cloud_done_rounded;
        syncIconColor = AppColors.textSoft;
        syncTextColor = AppColors.textSoft;
        syncWidth = 184.0;
        break;
      case CloudSyncStatus.error:
        syncText = 'Sync error • Local storage';
        syncIcon = Icons.cloud_off_rounded;
        syncIconColor = AppColors.textSoft;
        syncTextColor = AppColors.textSoft;
        syncWidth = 182.0;
        break;
      case CloudSyncStatus.disabled:
      case CloudSyncStatus.idle:
        if (isAuthenticated) {
          syncText = 'Cloud backup is active';
          syncIcon = Icons.cloud_done_rounded;
          syncIconColor = AppColors.textSoft;
          syncWidth = 180.0;
        } else {
          syncText = 'Local device storage';
          syncIcon = Icons.cloud_queue_rounded;
          syncIconColor = AppColors.textSoft;
          syncWidth = 180.0;
        }
        break;
    }

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
          final double idlePillWidth =
              _feedIndex == 0 ? notifWidth : syncWidth;

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
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 320),
                            transitionBuilder: (child, anim) {
                              return FadeTransition(
                                opacity: anim,
                                child: SlideTransition(
                                  position: Tween<Offset>(
                                    begin: const Offset(0, 0.35),
                                    end: Offset.zero,
                                  ).animate(CurvedAnimation(
                                    parent: anim,
                                    curve: Curves.easeOutCubic,
                                  )),
                                  child: child,
                                ),
                              );
                            },
                            child: _feedIndex == 0
                                ? Row(
                                    key: const ValueKey<int>(0),
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      SizedBox(
                                        width: 20,
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
                                                    decoration:
                                                        const BoxDecoration(
                                                      color: AppColors.gold,
                                                      shape: BoxShape.circle,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      if (targetWidth >= 60.0 && !_isCircle) ...[
                                        const SizedBox(width: 8),
                                        _buildAnimatedText(
                                          targetWidth: targetWidth,
                                          text: notifText,
                                          textColor: notifColor,
                                          fontWeight: !notifsVM.hasPermission
                                              ? FontWeight.w600
                                              : FontWeight.w400,
                                        ),
                                      ],
                                    ],
                                  )
                                : Row(
                                    key: const ValueKey<int>(1),
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      SizedBox(
                                        width: 20,
                                        height: 38,
                                        child: Center(
                                          child: Icon(
                                            syncIcon,
                                            color: syncIconColor,
                                            size: 16,
                                          ),
                                        ),
                                      ),
                                      if (targetWidth >= 60.0 && !_isCircle) ...[
                                        const SizedBox(width: 8),
                                        _buildAnimatedText(
                                          targetWidth: targetWidth,
                                          text: syncText,
                                          textColor: syncTextColor,
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ],
                                    ],
                                  ),
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
