import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A pull-to-refresh that requires a deliberate **hold**.
///
/// The user drags down past [triggerDistance] and keeps holding while a
/// circular indicator fills over [holdDuration]. If they release (or pull back
/// up) before the circle fills, the refresh is cancelled — so an accidental
/// flick or light drag never triggers [onRefresh]. Only a sustained hold that
/// fills the circle fires the refresh.
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
    this.holdDuration = const Duration(milliseconds: 1000),
  });

  @override
  State<HoldToRefresh> createState() => _HoldToRefreshState();
}

class _HoldToRefreshState extends State<HoldToRefresh>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fill = AnimationController(
    vsync: this,
    duration: widget.holdDuration,
  )
    ..addListener(() => setState(() {}))
    ..addStatusListener(_onFillStatus);

  double _pull = 0; // current overscroll distance at the top
  bool _pointerDown = false;
  bool _armed = false; // hold timer is running
  bool _refreshing = false;

  static const Color _accent = Color(0xFFF0B90B);

  @override
  void dispose() {
    _fill.dispose();
    super.dispose();
  }

  void _onFillStatus(AnimationStatus status) {
    // Circle filled while still held → fire the refresh.
    if (status == AnimationStatus.completed && _armed && !_refreshing) {
      _triggerRefresh();
    }
  }

  Future<void> _triggerRefresh() async {
    setState(() => _refreshing = true);
    try {
      await widget.onRefresh();
    } finally {
      if (mounted) {
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
        // Reached the threshold while holding → start filling.
        _armed = true;
        _fill.forward(from: 0);
      } else if (_armed && _pull < widget.triggerDistance * 0.4) {
        // Pulled back up before it filled → cancel.
        _cancel();
      }
    }
    setState(() {});
    return false;
  }

  void _onRelease() {
    _pointerDown = false;
    // Released before the circle filled → ignore (no refresh).
    if (_armed &&
        !_refreshing &&
        _fill.status != AnimationStatus.completed) {
      setState(_cancel);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool showIndicator = _refreshing || _armed || _pull > 4;
    final double progress = _refreshing
        ? 1.0
        : (_armed
            ? _fill.value
            : (_pull / widget.triggerDistance).clamp(0.0, 1.0));
    final double opacity = (_refreshing || _armed)
        ? 1.0
        : (_pull / widget.triggerDistance).clamp(0.0, 1.0);

    final String label = _refreshing
        ? 'Refreshing…'
        : (_armed ? 'Keep holding…' : 'Hold to refresh');

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
                      padding: const EdgeInsets.only(top: 14),
                      child: Center(
                        child: Opacity(
                          opacity: opacity,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 26,
                                height: 26,
                                child: _refreshing
                                    ? const CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        valueColor:
                                            AlwaysStoppedAnimation(_accent),
                                      )
                                    : CircularProgressIndicator(
                                        value: progress,
                                        strokeWidth: 2.5,
                                        backgroundColor: Colors.white
                                            .withValues(alpha: 0.12),
                                        valueColor:
                                            const AlwaysStoppedAnimation(
                                                _accent),
                                      ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                label,
                                style: const TextStyle(
                                  color: AppColors.textGray,
                                  fontSize: 11,
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
