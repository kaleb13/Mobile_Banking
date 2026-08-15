import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:intl/intl.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../../models/app_notification.dart';
import '../../providers/finance_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/interactive_drag_handle.dart';
import '../../widgets/hold_to_refresh.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_badges.dart';
import 'manual_transaction_sheet.dart';

/// A pill widget that morphs in-place into a full notifications panel.
/// Place this in the dashboard layout using [DynamicNotificationPill].
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
    final provider = Provider.of<FinanceProvider>(context, listen: false);
    if (!provider.hasPermission) {
      provider.requestPermission();
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
      builder: (ctx) => _MorphingPanelOverlay(
        pillTop: pillTop,
        pillLeft: pillOffset.dx,
        pillWidth: pillWidth,
        expandedHeight: expandedHeight,
        expandAnim: _expandAnim,
        fadeAnim: _fadeAnim,
        onClose: _closePanel,
        onDragUpdate: (deltaY) {
          final double deltaRange = expandedHeight - 38.0;
          final double currentVal = _animController.value;
          final double newVal =
              (currentVal + deltaY / deltaRange).clamp(0.0, 1.0);
          _animController.value = newVal;
        },
        onDragEnd: (velocityY) {
          if (_animController.value <= 0.60 || velocityY < -150) {
            _closePanel();
          } else {
            _animController.forward();
          }
        },
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
    final provider = Provider.of<FinanceProvider>(context);

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
          final double idlePillWidth = !provider.hasPermission
              ? 210.0
              : provider.unreadNotificationCount > 0
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
                                      if (provider.unreadNotificationCount > 0)
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
                                          !provider.hasPermission
                                              ? 'Tap to enable SMS tracking'
                                              : provider.unreadNotificationCount > 0
                                                  ? '${provider.unreadNotificationCount} unread notification${provider.unreadNotificationCount > 1 ? 's' : ''}'
                                                  : 'No new notifications',
                                          style: TextStyle(
                                            color: !provider.hasPermission
                                                ? AppColors.positive
                                                : AppColors.textSoft,
                                            fontSize: 12,
                                            fontWeight: !provider.hasPermission
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

/// The morphing overlay that renders on top of everything.
class _MorphingPanelOverlay extends StatelessWidget {
  final double pillTop;
  final double pillLeft;
  final double pillWidth;
  final double expandedHeight;
  final Animation<double> expandAnim;
  final Animation<double> fadeAnim;
  final VoidCallback onClose;
  final ValueChanged<double>? onDragUpdate;
  final ValueChanged<double>? onDragEnd;

  const _MorphingPanelOverlay({
    required this.pillTop,
    required this.pillLeft,
    required this.pillWidth,
    required this.expandedHeight,
    required this.expandAnim,
    required this.fadeAnim,
    required this.onClose,
    this.onDragUpdate,
    this.onDragEnd,
  });

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FinanceProvider>(context);
    final double screenWidth = MediaQuery.of(context).size.width;
    const double targetLeft = 16.0;
    final double targetWidth = screenWidth - 32.0;

    return AnimatedBuilder(
      animation: expandAnim,
      builder: (context, child) {
        final double currentHeight =
            38.0 + (expandedHeight - 38.0) * expandAnim.value;
        final double currentWidth =
            pillWidth + (targetWidth - pillWidth) * expandAnim.value;
        final double currentLeft =
            pillLeft + (targetLeft - pillLeft) * expandAnim.value;
        const double currentRadius = 24.0;

        // Morph fraction between 0.0 (top 0%) and 0.30 (top 30%)
        final double morphT = (expandAnim.value / 0.30).clamp(0.0, 1.0);

        final Color currentBg = Color.lerp(
          Colors.white.withValues(alpha: 0.08),
          AppColors.background,
          morphT,
        )!;

        return Stack(
          children: [
            // Dark Backdrop blur
            if (expandAnim.value > 0.01)
              Positioned.fill(
                child: GestureDetector(
                  onTap: onClose,
                  child: BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: 18 * expandAnim.value,
                      sigmaY: 18 * expandAnim.value,
                    ),
                    child: Container(
                      color: Colors.black
                          .withValues(alpha: 0.60 * expandAnim.value),
                    ),
                  ),
                ),
              ),

            // Morphing Dynamic Island panel expanding sideways & downwards
            Positioned(
              top: pillTop,
              left: currentLeft,
              width: currentWidth,
              child: Material(
                type: MaterialType.transparency,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {}, // prevent backdrop tap
                  onVerticalDragUpdate: (details) {
                    onDragUpdate?.call(details.primaryDelta ?? 0);
                  },
                  onVerticalDragEnd: (details) {
                    onDragEnd?.call(details.velocity.pixelsPerSecond.dy);
                  },
                  onVerticalDragCancel: () {
                    onDragEnd?.call(0);
                  },
                  child: Container(
                    height: currentHeight,
                    decoration: BoxDecoration(
                      color: currentBg,
                      borderRadius:
                          BorderRadius.circular(currentRadius),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.35 * expandAnim.value),
                          blurRadius: 20 * expandAnim.value,
                          offset: Offset(0, 8 * expandAnim.value),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.hardEdge,
                    child: OverflowBox(
                      minWidth: currentWidth,
                      maxWidth: currentWidth,
                      minHeight: 0,
                      maxHeight: expandedHeight,
                      alignment: Alignment.topCenter,
                      child: SizedBox(
                        height: expandedHeight,
                        child: Stack(
                          children: [
                            // Full Expanded Panel Content (visible when morphT > 0)
                            if (morphT > 0.0)
                              Opacity(
                                opacity: morphT,
                                child: _NotificationPanelContent(
                                  onClose: onClose,
                                  onDragUpdate: onDragUpdate,
                                  onDragEnd: onDragEnd,
                                ),
                              ),

                            // Island Pill Content (morphs in as expandAnim <= 0.30)
                            if (morphT < 1.0)
                              Opacity(
                                opacity: 1.0 - morphT,
                                child: Container(
                                  height: 38,
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          const Icon(
                                            Icons.notifications_rounded,
                                            color: AppColors.textSoft,
                                            size: 16,
                                          ),
                                          if (provider.unreadNotificationCount >
                                              0)
                                            Positioned(
                                              right: -2,
                                              top: -2,
                                              child: Container(
                                                width: 7,
                                                height: 7,
                                                decoration: const BoxDecoration(
                                                  color: AppColors.gold,
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          provider.unreadNotificationCount > 0
                                              ? '${provider.unreadNotificationCount} unread notification${provider.unreadNotificationCount > 1 ? 's' : ''}'
                                              : 'No new notifications',
                                          style: const TextStyle(
                                            color: AppColors.textSoft,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            letterSpacing: -0.1,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
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
          ],
        );
      },
    );
  }
}

/// The full notification panel content rendered inside the morphed pill.
class _NotificationPanelContent extends StatefulWidget {
  final VoidCallback onClose;
  final ValueChanged<double>? onDragUpdate;
  final ValueChanged<double>? onDragEnd;

  const _NotificationPanelContent({
    required this.onClose,
    this.onDragUpdate,
    this.onDragEnd,
  });

  @override
  State<_NotificationPanelContent> createState() =>
      _NotificationPanelContentState();
}

class _NotificationPanelContentState extends State<_NotificationPanelContent> {
  AppNotification? _selectedNotificationForMenu;
  AppNotification? _selectedNotificationForManualInsert;
  bool _isConfirmingClearAll = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FinanceProvider>(context);

    return Stack(
      children: [
        Column(
          children: [
            // ── Header ──
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onVerticalDragUpdate: (details) {
                widget.onDragUpdate?.call(details.primaryDelta ?? 0);
              },
              onVerticalDragEnd: (details) {
                widget.onDragEnd?.call(details.velocity.pixelsPerSecond.dy);
              },
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: widget.onClose,
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: SvgPicture.asset(
                          'assets/images/BackForNav.svg',
                          colorFilter: const ColorFilter.mode(
                              Colors.white, BlendMode.srcIn),
                          width: 18,
                          height: 18,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Unread Notifications',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (provider.notifications.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _isConfirmingClearAll = true;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.buttonPrimary,
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: const Text(
                            'Clear',
                            style: TextStyle(
                              color: AppColors.buttonPrimaryText,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // ── List ──
            Expanded(
              child: provider.notifications.isEmpty
                  ? _buildEmpty()
                  : ListView.builder(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      physics: const BouncingScrollPhysics(),
                      itemCount: provider.notifications.length,
                      itemBuilder: (context, index) {
                        return _buildCard(
                            context, provider, provider.notifications[index]);
                      },
                    ),
            ),

            // ── Drag Handle ──
            InteractiveDragHandle(
              onTap: widget.onClose,
              onVerticalDragUpdate: (details) {
                widget.onDragUpdate?.call(details.primaryDelta ?? 0);
              },
              onVerticalDragEnd: (details) {
                widget.onDragEnd?.call(details.velocity.pixelsPerSecond.dy);
              },
              padding: const EdgeInsets.only(top: 6, bottom: 10),
            ),
          ],
        ),

        // ── Internal Glass Options Menu Sheet ──
        if (_selectedNotificationForMenu != null)
          Positioned.fill(
            child: Stack(
              children: [
                GestureDetector(
                  onTap: () =>
                      setState(() => _selectedNotificationForMenu = null),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 6.0, sigmaY: 6.0),
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.35),
                    ),
                  ),
                ),
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: _buildInternalGlassMenu(
                      provider, _selectedNotificationForMenu!),
                ),
              ],
            ),
          ),

        // ── Internal Clear All Confirmation Modal ──
        if (_isConfirmingClearAll)
          Positioned.fill(
            child: Stack(
              alignment: Alignment.center,
              children: [
                GestureDetector(
                  onTap: () => setState(() => _isConfirmingClearAll = false),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 6.0, sigmaY: 6.0),
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.35),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 320),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
                          decoration: BoxDecoration(
                            color: AppColors.surface.withValues(alpha: 0.88),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Clear All Notifications?',
                                textAlign: TextAlign.left,
                                style: AppTypography.heading2.copyWith(
                                  color: AppColors.textPrimary,
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Are you sure you want to permanently clear all unread notification messages?',
                                textAlign: TextAlign.left,
                                style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.textSecondary,
                                  fontSize: 13,
                                  height: 1.45,
                                ),
                              ),
                              const SizedBox(height: 20),
                              Row(
                                children: [
                                  Expanded(
                                    child: AppButton.secondary(
                                      text: 'Cancel',
                                      height: 42,
                                      onPressed: () => setState(
                                          () => _isConfirmingClearAll = false),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: AppButton.destructive(
                                      text: 'Clear All',
                                      height: 42,
                                      onPressed: () async {
                                        setState(
                                            () => _isConfirmingClearAll = false);
                                        final ids = provider.notifications
                                            .map((n) => n.id)
                                            .toList();
                                        for (final id in ids) {
                                          await provider.deleteNotification(id);
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

        // ── Internal Manual Transaction Sheet Overlay ──
        if (_selectedNotificationForManualInsert != null)
          Positioned.fill(
            child: Stack(
              children: [
                GestureDetector(
                  onTap: () => setState(
                      () => _selectedNotificationForManualInsert = null),
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.55),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  top: 0,
                  child: Material(
                    type: MaterialType.transparency,
                    child: ManualTransactionSheet(
                      notification: _selectedNotificationForManualInsert!,
                      provider: provider,
                      onClose: () {
                        setState(() =>
                            _selectedNotificationForManualInsert = null);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildCard(
      BuildContext context, FinanceProvider provider, AppNotification notif) {
    final isSystem =
        notif.sender.startsWith('Loan') || notif.sender.startsWith('System');
    final String formattedDate = DateFormat('MMM d, HH:mm').format(notif.date);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Slidable(
        key: Key(notif.id),
        direction: Axis.horizontal,
        endActionPane: ActionPane(
          motion: const BehindMotion(),
          extentRatio: isSystem ? 0.28 : 0.48,
          dismissible: DismissiblePane(
            onDismissed: () => provider.deleteNotification(notif.id),
          ),
          children: [
            CustomSlidableAction(
              onPressed: (_) {},
              backgroundColor: Colors.transparent,
              padding: const EdgeInsets.only(left: 8),
              child: Container(
                width: double.infinity,
                height: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: isSystem
                    ? Column(
                        children: [
                          Expanded(
                            child: _buildGridActionButton(
                              onTap: () => provider.deleteNotification(notif.id),
                              icon: Icons.delete_rounded,
                              label: 'Delete',
                              color: AppColors.negative,
                            ),
                          ),
                          Divider(
                            height: 1,
                            thickness: 0.5,
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                          Expanded(
                            child: _buildGridActionButton(
                              onTap: () => provider.ignoreNotification(notif.id),
                              icon: Icons.block_rounded,
                              label: 'Ignore',
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          // Top Row (Delete & Insert)
                          Expanded(
                            child: Row(
                              children: [
                                Expanded(
                                  child: _buildGridActionButton(
                                    onTap: () =>
                                        provider.deleteNotification(notif.id),
                                    icon: Icons.delete_rounded,
                                    label: 'Delete',
                                    color: AppColors.negative,
                                  ),
                                ),
                                VerticalDivider(
                                  width: 1,
                                  thickness: 0.5,
                                  color: Colors.white.withValues(alpha: 0.08),
                                ),
                                Expanded(
                                  child: _buildGridActionButton(
                                    onTap: () => _showManualInsert(
                                        context, provider, notif),
                                    icon: Icons.add_circle_outline_rounded,
                                    label: 'Insert',
                                    color: AppColors.positive,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Divider(
                            height: 1,
                            thickness: 0.5,
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                          // Bottom Row (Inform & Ignore)
                          Expanded(
                            child: Row(
                              children: [
                                Expanded(
                                  child: _buildGridActionButton(
                                    onTap: () => _informDeveloper(
                                        context, notif.body),
                                    icon: Icons.telegram_rounded,
                                    label: 'Inform',
                                    color: const Color(0xFF0284C7),
                                  ),
                                ),
                                VerticalDivider(
                                  width: 1,
                                  thickness: 0.5,
                                  color: Colors.white.withValues(alpha: 0.08),
                                ),
                                Expanded(
                                  child: _buildGridActionButton(
                                    onTap: () => provider
                                        .ignoreNotification(notif.id),
                                    icon: Icons.block_rounded,
                                    label: 'Ignore',
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
        child: GestureDetector(
          onLongPress: () {
            setState(() {
              _selectedNotificationForMenu = notif;
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Icon(Icons.notifications_sharp,
                        color: Colors.white, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        notif.sender,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  notif.body,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    AppBadge.neutral(
                      text: isSystem ? 'System Message' : 'Unregistered',
                      size: AppBadgeSize.small,
                    ),
                    Flexible(
                      child: Text(
                        formattedDate,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.45),
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.notifications_none_rounded,
              color: Colors.white30, size: 40),
          const SizedBox(height: 12),
          const Text(
            'No Unread Notifications',
            style: TextStyle(
                color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            'Unrecognized messages will appear here',
            style:
                TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 13),
          ),
        ],
      ),
    );
  }

  void _showManualInsert(
      BuildContext context, FinanceProvider provider, AppNotification notif) {
    setState(() {
      _selectedNotificationForMenu = null;
      _selectedNotificationForManualInsert = notif;
    });
  }

  Future<void> _informDeveloper(
      BuildContext context, String rawMessage) async {
    final String template =
        'I found a transaction message that was not automatically categorized. Sharing it here for feedback:\n\n```$rawMessage```';
    await Clipboard.setData(ClipboardData(text: template));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Message copied! Please paste it in the chat.'),
          backgroundColor: AppColors.positive,
          duration: Duration(seconds: 2),
        ),
      );
    }
    final String encodedMsg = Uri.encodeComponent(template);
    final Uri tgUrl = Uri.parse('tg://msg?text=$encodedMsg');
    final Uri webUrl = Uri.parse('https://t.me/Shibre_Plus');
    try {
      if (await canLaunchUrl(tgUrl)) {
        await launchUrl(tgUrl);
      } else {
        await launchUrl(webUrl, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      await launchUrl(webUrl, mode: LaunchMode.externalApplication);
    }
  }

  Widget _buildInternalGlassMenu(
      FinanceProvider provider, AppNotification notif) {
    final isSystem =
        notif.sender.startsWith('Loan') || notif.sender.startsWith('System');

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              InteractiveDragHandle(
                color: AppColors.textDisabled,
                onTap: () => setState(() => _selectedNotificationForMenu = null),
                onVerticalDragUpdate: (details) {
                  if ((details.primaryDelta ?? 0) > 2) {
                    setState(() => _selectedNotificationForMenu = null);
                  }
                },
                padding: const EdgeInsets.only(top: 10, bottom: 8),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Message Options',
                    style: AppTypography.heading2.copyWith(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (!isSystem) ...[
                _buildModalItem(
                  icon: Icons.add_circle_outline_rounded,
                  label: 'Insert Transaction Manually',
                  iconColor: AppColors.positive,
                  onTap: () {
                    setState(() => _selectedNotificationForMenu = null);
                    _showManualInsert(context, provider, notif);
                  },
                ),
                _buildModalItem(
                  icon: Icons.telegram_rounded,
                  label: 'Inform Developer',
                  iconColor: AppColors.skyBlue,
                  onTap: () {
                    setState(() => _selectedNotificationForMenu = null);
                    _informDeveloper(context, notif.body);
                  },
                ),
              ],
              _buildModalItem(
                icon: Icons.delete_rounded,
                label: 'Delete Message',
                iconColor: AppColors.negative,
                onTap: () {
                  setState(() => _selectedNotificationForMenu = null);
                  provider.deleteNotification(notif.id);
                },
              ),
              _buildModalItem(
                icon: Icons.block_rounded,
                label: 'Ignore Permanently',
                iconColor: AppColors.textSecondary,
                onTap: () {
                  setState(() => _selectedNotificationForMenu = null);
                  provider.ignoreNotification(notif.id);
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModalItem({
    required IconData icon,
    required String label,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      splashColor: AppColors.buttonSecondary,
      highlightColor: AppColors.buttonSecondary,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Text(
              label,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridActionButton({
    required VoidCallback onTap,
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        splashColor: color.withValues(alpha: 0.15),
        highlightColor: color.withValues(alpha: 0.08),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                                  ),
                child: Icon(icon, color: color, size: 16),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Legacy wrappers kept for any references ──────────────────────────────────

/// Legacy — use [DynamicNotificationPill] instead.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: SvgPicture.asset(
                      'assets/images/BackForNav.svg',
                      colorFilter: const ColorFilter.mode(
                          Colors.white, BlendMode.srcIn),
                      width: 18,
                      height: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Unread Notifications',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Legacy — use [DynamicNotificationPill] instead.
class NotificationsModalWidget extends StatelessWidget {
  final VoidCallback? onClose;
  const NotificationsModalWidget({super.key, this.onClose});

  @override
  Widget build(BuildContext context) {
    return _NotificationPanelContent(
      onClose: onClose ?? () => Navigator.pop(context),
    );
  }
}

/// Legacy function kept for any lingering references.
void showNotificationsOverlay(BuildContext context) {
  showModalBottomSheet(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.65),
    builder: (ctx) => BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
      child: Container(
        height: MediaQuery.of(ctx).size.height * 0.92,
        margin: EdgeInsets.only(
          top: MediaQuery.of(ctx).padding.top + 8,
          left: 12,
          right: 12,
          bottom: 12,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFF141419),
          borderRadius: BorderRadius.circular(32),
                    boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: NotificationsModalWidget(
          onClose: () => Navigator.of(ctx, rootNavigator: true).pop(),
        ),
      ),
    ),
  );
}
