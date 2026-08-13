import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Shared refresh state passed from [HoldToRefresh] down to [DynamicNotificationPill]
/// so the pill morphs in-place instead of spawning a floating overlay.
class RefreshState {
  /// 0.0–1.0 pull progress (dragging phase)
  final double dragProgress;
  /// 0–100 refresh completion percentage
  final int refreshPercent;
  final RefreshPhase phase;

  const RefreshState({
    this.dragProgress = 0.0,
    this.refreshPercent = 0,
    this.phase = RefreshPhase.idle,
  });
}

enum RefreshPhase { idle, dragging, refreshing, done }

/// Global notifier — HoldToRefresh writes, DynamicNotificationPill reads.
final refreshStateNotifier = ValueNotifier<RefreshState>(const RefreshState());

/// A custom curve for the progress bar: fast sprint 0→50%, slow crawl 50→95%
class _EasedRefreshCurve extends Curve {
  const _EasedRefreshCurve();

  @override
  double transformInternal(double t) {
    if (t < 0.30) {
      return (t / 0.30) * 0.50;
    } else {
      final slow = (t - 0.30) / 0.70;
      return 0.50 + slow * 0.50 * (1 - (1 - slow) * (1 - slow));
    }
  }
}

/// A premium pull-to-refresh widget that morphs the [DynamicNotificationPill]
/// in-place instead of spawning a floating pill overlay.
class HoldToRefresh extends StatefulWidget {
  final Widget child;
  final Future<void> Function() onRefresh;

  /// Pull distance (px) before refresh is triggered.
  final double triggerDistance;

  const HoldToRefresh({
    super.key,
    required this.child,
    required this.onRefresh,
    this.triggerDistance = 72,
  });

  @override
  State<HoldToRefresh> createState() => _HoldToRefreshState();
}

class _HoldToRefreshState extends State<HoldToRefresh>
    with SingleTickerProviderStateMixin {
  late final AnimationController _progressCtrl = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..addListener(_onProgressTick);

  late final Animation<double> _progressAnim = CurvedAnimation(
    parent: _progressCtrl,
    curve: const _EasedRefreshCurve(),
  );

  double _pull = 0;
  double _startY = 0;
  bool _trackingTouch = false;
  bool _isAtTop = true;
  RefreshPhase _phase = RefreshPhase.idle;
  bool _refreshTriggered = false;

  void _onProgressTick() {
    if (_phase == RefreshPhase.refreshing) {
      final pct = (_progressAnim.value * 95).round().clamp(0, 95);
      refreshStateNotifier.value = RefreshState(
        phase: RefreshPhase.refreshing,
        refreshPercent: pct,
      );
    }
  }

  @override
  void dispose() {
    _progressCtrl.removeListener(_onProgressTick);
    _progressCtrl.dispose();
    super.dispose();
  }

  Future<void> _triggerRefresh() async {
    if (_refreshTriggered) return;
    _refreshTriggered = true;
    _phase = RefreshPhase.refreshing;
    _progressCtrl.value = 0;
    _progressCtrl.forward();
    refreshStateNotifier.value = const RefreshState(
      phase: RefreshPhase.refreshing,
      refreshPercent: 0,
    );

    try {
      await widget.onRefresh();
    } finally {
      _progressCtrl.stop();
      if (mounted) {
        refreshStateNotifier.value = const RefreshState(
          phase: RefreshPhase.done,
          refreshPercent: 100,
        );
        await Future.delayed(const Duration(milliseconds: 300));
        if (mounted) {
          refreshStateNotifier.value = const RefreshState();
          _phase = RefreshPhase.idle;
          _refreshTriggered = false;
          _pull = 0;
          _trackingTouch = false;
        }
      }
    }
  }

  bool _onScroll(ScrollNotification n) {
    if (n.metrics.axis != Axis.vertical) return false;
    _isAtTop = n.metrics.pixels <= 1.0;

    // While dragging or when pull progress is active, lock scroll view at 0,0
    if (_phase == RefreshPhase.dragging || _pull > 0) {
      return true;
    }

    if (_phase == RefreshPhase.refreshing || _phase == RefreshPhase.done) {
      return false;
    }

    if (!_trackingTouch) {
      final over = n.metrics.minScrollExtent - n.metrics.pixels;
      _pull = over > 0 ? over : 0;
      _updateProgress();
    }

    return false;
  }

  void _onPointerDown(PointerDownEvent e) {
    if (_phase == RefreshPhase.refreshing || _phase == RefreshPhase.done) return;
    if (_isAtTop) {
      _startY = e.position.dy;
      _trackingTouch = true;
    }
  }

  void _onPointerMove(PointerMoveEvent e) {
    if (!_trackingTouch ||
        _phase == RefreshPhase.refreshing ||
        _phase == RefreshPhase.done) {
      return;
    }
    final dy = e.position.dy - _startY;
    if (dy > 0) {
      _pull = dy;
      _updateProgress();
    } else {
      if (_pull > 0) {
        _pull = 0;
        _updateProgress();
      }
    }
  }

  void _updateProgress() {
    final dragProgress = (_pull / widget.triggerDistance).clamp(0.0, 1.0);
    if (_pull > 0.5) {
      _phase = RefreshPhase.dragging;
      refreshStateNotifier.value = RefreshState(
        phase: RefreshPhase.dragging,
        dragProgress: dragProgress,
      );
    } else {
      if (_phase == RefreshPhase.dragging) {
        _phase = RefreshPhase.idle;
        refreshStateNotifier.value = const RefreshState();
      }
    }
  }

  void _onRelease() {
    _trackingTouch = false;
    if (_phase == RefreshPhase.dragging) {
      if (_pull >= widget.triggerDistance) {
        _triggerRefresh();
      } else {
        _phase = RefreshPhase.idle;
        _pull = 0;
        refreshStateNotifier.value = const RefreshState();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: (_) => _onRelease(),
      onPointerCancel: (_) => _onRelease(),
      child: NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: widget.child,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Refresh pill content for the notification pill (used inside DynamicNotificationPill)
// ─────────────────────────────────────────────────────────────────────────────

/// Drop-in widget that morphs between idle notification display and refresh states.
/// Wrap the content of DynamicNotificationPill's idle state with this.
class RefreshAwarePillContent extends StatefulWidget {
  final Widget idleChild;

  const RefreshAwarePillContent({super.key, required this.idleChild});

  @override
  State<RefreshAwarePillContent> createState() => _RefreshAwarePillContentState();
}

class _RefreshAwarePillContentState extends State<RefreshAwarePillContent>
    with SingleTickerProviderStateMixin {
  late RefreshState _state;
  late AnimationController _morphCtrl;
  late Animation<double> _morphAnim;

  @override
  void initState() {
    super.initState();
    _state = refreshStateNotifier.value;
    refreshStateNotifier.addListener(_onStateChange);

    _morphCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _morphAnim = CurvedAnimation(
      parent: _morphCtrl,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
  }

  @override
  void dispose() {
    refreshStateNotifier.removeListener(_onStateChange);
    _morphCtrl.dispose();
    super.dispose();
  }

  void _onStateChange() {
    final newState = refreshStateNotifier.value;
    final phaseChanged = _state.phase != newState.phase;
    final percentChanged = _state.refreshPercent != newState.refreshPercent;
    final progressChanged =
        (_state.dragProgress - newState.dragProgress).abs() >= 0.005;
    final wasIdle = _state.phase == RefreshPhase.idle;
    final isIdle = newState.phase == RefreshPhase.idle;

    if (phaseChanged || percentChanged || progressChanged) {
      setState(() => _state = newState);
    } else {
      _state = newState;
    }

    if (wasIdle && !isIdle) {
      _morphCtrl.forward();
    } else if (!wasIdle && isIdle) {
      _morphCtrl.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _morphAnim,
      builder: (context, _) {
        final t = _morphAnim.value;

        if (_state.phase == RefreshPhase.idle && t < 0.01) {
          return Center(child: widget.idleChild);
        }

        return Stack(
          alignment: Alignment.center,
          children: [
            // Idle content fades out
            if (t < 0.99)
              Center(
                child: Opacity(
                  opacity: (1.0 - t).clamp(0.0, 1.0),
                  child: widget.idleChild,
                ),
              ),

            // Refresh content fades in
            if (t > 0.01)
              Opacity(
                opacity: t.clamp(0.0, 1.0),
                child: _buildRefreshContent(),
              ),
          ],
        );
      },
    );
  }

  Widget _buildRefreshContent() {
    final double fillRatio;
    switch (_state.phase) {
      case RefreshPhase.dragging:
        fillRatio = _state.dragProgress.clamp(0.0, 1.0);
        break;
      case RefreshPhase.refreshing:
        fillRatio = (_state.refreshPercent / 100.0).clamp(0.0, 1.0);
        break;
      case RefreshPhase.done:
        fillRatio = 1.0;
        break;
      default:
        fillRatio = 0.0;
    }

    final Widget innerContent;
    switch (_state.phase) {
      case RefreshPhase.dragging:
        innerContent = _buildDraggingContent();
        break;
      case RefreshPhase.refreshing:
        innerContent = _buildRefreshingContent();
        break;
      case RefreshPhase.done:
        innerContent = _buildDoneContent();
        break;
      default:
        innerContent = widget.idleChild;
    }

    return SizedBox(
      width: double.infinity,
      height: double.infinity,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // The whole section fills as a progress bar
            if (fillRatio > 0)
              Positioned.fill(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: fillRatio,
                    heightFactor: 1.0,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.positive.withValues(alpha: 0.30),
                            AppColors.positive.withValues(alpha: 0.55),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // Centered content (Logo, text, percentage in the center of section)
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Center(
                  child: innerContent,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Dragging phase ──────────────────────────────────────────────────────────
  Widget _buildDraggingContent() {
    final progress = _state.dragProgress;
    final pct = (progress * 100).round();
    final isArmed = progress >= 0.85;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.surfaceCard,
            border: Border.all(
              color: AppColors.positive.withValues(alpha: isArmed ? 0.75 : 0.35),
              width: 1.2,
            ),
          ),
          padding: const EdgeInsets.all(4),
          child: Image.asset('assets/images/Shibre Icon.png', fit: BoxFit.contain),
        ),
        const SizedBox(width: 8),
        Text(
          isArmed ? 'Release to refresh' : 'Pull to refresh',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.92),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '$pct%',
          style: const TextStyle(
            color: AppColors.positive,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  // ── Refreshing phase ────────────────────────────────────────────────────────
  Widget _buildRefreshingContent() {
    final pct = _state.refreshPercent;

    final String label;
    if (pct < 30) {
      label = 'Preparing…';
    } else if (pct < 65) {
      label = 'Syncing…';
    } else {
      label = 'Updating transactions…';
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 22,
          height: 22,
          child: Stack(
            alignment: Alignment.center,
            children: [
              const CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(AppColors.positive),
              ),
              Container(
                width: 16,
                height: 16,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surfaceCard,
                ),
                padding: const EdgeInsets.all(3),
                child: Image.asset('assets/images/Shibre Icon.png', fit: BoxFit.contain),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Text(
            label,
            key: ValueKey(label),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.92),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 6),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 100),
          child: Text(
            '$pct%',
            key: ValueKey(pct),
            style: const TextStyle(
              color: AppColors.positive,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  // ── Done phase ──────────────────────────────────────────────────────────────
  Widget _buildDoneContent() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.positive.withValues(alpha: 0.25),
            border: Border.all(
              color: AppColors.positive,
              width: 1.2,
            ),
          ),
          child: const Icon(Icons.check_rounded, color: AppColors.positive, size: 13),
        ),
        const SizedBox(width: 8),
        const Text(
          'Up to date',
          style: TextStyle(
            color: AppColors.positive,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 6),
        const Text(
          '100%',
          style: TextStyle(
            color: AppColors.positive,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
