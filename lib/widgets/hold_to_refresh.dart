import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A premium pull-to-refresh widget featuring the **Shibre Logo** with smooth scale,
/// pulsing animations, and primary green theme highlights.
class HoldToRefresh extends StatefulWidget {
  final Widget child;
  final Future<void> Function() onRefresh;

  /// How far the user must pull (in pixels) before the hold timer starts.
  final double triggerDistance;

  /// How long the user must keep holding for the circle to fill and fire.
  final Duration holdDuration;

  const HoldToRefresh({
    super.key,
    required this.child,
    required this.onRefresh,
    this.triggerDistance = 75,
    this.holdDuration = const Duration(milliseconds: 900),
  });

  @override
  State<HoldToRefresh> createState() => _HoldToRefreshState();
}

class _HoldToRefreshState extends State<HoldToRefresh>
    with TickerProviderStateMixin {
  late final AnimationController _fill = AnimationController(
    vsync: this,
    duration: widget.holdDuration,
  )
    ..addListener(() => setState(() {}))
    ..addStatusListener(_onFillStatus);

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  )..addListener(() => setState(() {}));

  late final Animation<double> _pulseScale =
      Tween<double>(begin: 0.92, end: 1.08).animate(
    CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
  );

  double _pull = 0; // current overscroll distance at the top
  bool _pointerDown = false;
  bool _armed = false; // hold timer is running
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _pulse.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _pulse.reverse();
      } else if (status == AnimationStatus.dismissed && _refreshing) {
        _pulse.forward();
      }
    });
  }

  @override
  void dispose() {
    _fill.dispose();
    _pulse.dispose();
    super.dispose();
  }

  void _onFillStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && _armed && !_refreshing) {
      _triggerRefresh();
    }
  }

  Future<void> _triggerRefresh() async {
    setState(() => _refreshing = true);
    _pulse.forward(from: 0);
    try {
      await widget.onRefresh();
    } finally {
      if (mounted) {
        _pulse.stop();
        _pulse.value = 0;
        setState(() {
          _refreshing = false;
          _armed = false;
        });
        _fill.value = 0;
      }
    }
  }

  void _cancel() {
    _armed = false;
    _fill.stop();
    _fill.value = 0;
  }

  bool _onScroll(ScrollNotification n) {
    if (n.metrics.axis != Axis.vertical) return false;
    final over = n.metrics.minScrollExtent - n.metrics.pixels;
    _pull = over > 0 ? over : 0;

    if (!_refreshing) {
      if (!_armed && _pointerDown && _pull >= widget.triggerDistance) {
        _armed = true;
        _fill.forward(from: 0);
      } else if (_armed && _pull < widget.triggerDistance * 0.4) {
        _cancel();
      }
    }
    setState(() {});
    return false;
  }

  void _onRelease() {
    _pointerDown = false;
    if (_armed &&
        !_refreshing &&
        _fill.status != AnimationStatus.completed) {
      setState(_cancel);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool showIndicator = _refreshing || _armed || _pull > 4;
    final double rawProgress = _refreshing
        ? 1.0
        : (_armed
            ? _fill.value
            : (_pull / widget.triggerDistance).clamp(0.0, 1.0));
    final double opacity = (_refreshing || _armed)
        ? 1.0
        : (_pull / widget.triggerDistance).clamp(0.0, 1.0);

    final String label = _refreshing
        ? 'Updating transactions…'
        : (_armed ? 'Keep holding…' : 'Pull to refresh');

    final double logoScale = _refreshing
        ? _pulseScale.value
        : (0.6 + (rawProgress * 0.4));

    return Listener(
      onPointerDown: (_) => _pointerDown = true,
      onPointerUp: (_) => _onRelease(),
      onPointerCancel: (_) => _onRelease(),
      child: NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: Stack(
          children: [
            if (showIndicator)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Center(
                        child: Opacity(
                          opacity: opacity,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Transform.scale(
                                scale: logoScale,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    // Outer Progress Ring / Spinner
                                    SizedBox(
                                      width: 48,
                                      height: 48,
                                      child: _refreshing
                                          ? const CircularProgressIndicator(
                                              strokeWidth: 2.5,
                                              valueColor:
                                                  AlwaysStoppedAnimation(
                                                      AppColors.positive),
                                            )
                                          : CircularProgressIndicator(
                                              value: rawProgress,
                                              strokeWidth: 2.5,
                                              backgroundColor: AppColors
                                                  .positive
                                                  .withValues(alpha: 0.15),
                                              valueColor:
                                                  const AlwaysStoppedAnimation(
                                                      AppColors.positive),
                                            ),
                                    ),
                                    // Center Shibre Logo Container
                                    Container(
                                      width: 38,
                                      height: 38,
                                      decoration: BoxDecoration(
                                        color: AppColors.surfaceCard,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: AppColors.positive
                                              .withValues(alpha: 0.25),
                                          width: 1,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppColors.positive
                                                .withValues(alpha: 0.15),
                                            blurRadius: 10,
                                            spreadRadius: 1,
                                          ),
                                        ],
                                      ),
                                      padding: const EdgeInsets.all(7),
                                      child: Image.asset(
                                        'assets/images/Shibre Icon.png',
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                label,
                                style: const TextStyle(
                                  color: AppColors.positive,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.3,
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
            widget.child,
          ],
        ),
      ),
    );
  }
}
