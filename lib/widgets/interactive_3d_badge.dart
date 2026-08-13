import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/app_theme.dart';

/// An interactive 3D Level Badge widget that reacts to swipe / drag gestures.
///
/// Features:
/// - 3D Perspective Rotation responding smoothly to horizontal/vertical swiping
/// - Holding/dragging turns the badge to view the metallic silver back
/// - Releasing automatically spring-rotates the badge back to the FRONT face (0.0)
/// - Fluid, continuous sine-wave metallic sheen motion with zero jumpiness
/// - Engraved metallic typography & silver star emblem on the silver back
/// - Clean, un-distorted front badge display with no overlays
///
/// Performance note:
/// Drag updates write directly to ValueNotifiers instead of calling setState.
/// An AnimatedBuilder rebuilds only the Transform subtree, not the whole widget.
class Interactive3DBadge extends StatefulWidget {
  final int level;
  final String levelName;
  final String badgePath;
  final Color glowColor;
  final double size;

  const Interactive3DBadge({
    super.key,
    required this.level,
    required this.levelName,
    required this.badgePath,
    required this.glowColor,
    this.size = 130.0,
  });

  @override
  State<Interactive3DBadge> createState() => _Interactive3DBadgeState();
}

class _Interactive3DBadgeState extends State<Interactive3DBadge>
    with SingleTickerProviderStateMixin {
  // Use ValueNotifiers so we can update angles without calling setState.
  // AnimatedBuilder listens to these and only rebuilds the Transform layer.
  final _angleYNotifier = ValueNotifier<double>(0.0);
  final _angleXNotifier = ValueNotifier<double>(0.0);

  double get _angleY => _angleYNotifier.value;
  double get _angleX => _angleXNotifier.value;

  late AnimationController _snapController;
  Animation<double>? _animationY;
  Animation<double>? _animationX;

  @override
  void initState() {
    super.initState();
    _snapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    // Drive angle notifiers from the snap animation — no setState needed.
    _snapController.addListener(() {
      if (_animationY != null) _angleYNotifier.value = _animationY!.value;
      if (_animationX != null) _angleXNotifier.value = _animationX!.value;
    });
  }

  @override
  void dispose() {
    _angleYNotifier.dispose();
    _angleXNotifier.dispose();
    _snapController.dispose();
    super.dispose();
  }

  void _onHorizontalDragStart(DragStartDetails details) {
    if (_snapController.isAnimating) _snapController.stop();
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    // Direct notifier write — no setState, no widget rebuild overhead.
    _angleYNotifier.value += details.delta.dx * 0.022;
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    _animateToFront();
  }

  void _onVerticalDragStart(DragStartDetails details) {
    if (_snapController.isAnimating) _snapController.stop();
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    _angleXNotifier.value =
        (_angleXNotifier.value - details.delta.dy * 0.015).clamp(-0.45, 0.45);
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    _animateToFront();
  }

  void _onTap() async {
    if (_snapController.isAnimating) return;

    _animationY = Tween<double>(
      begin: _angleY,
      end: math.pi,
    ).animate(CurvedAnimation(
      parent: _snapController,
      curve: Curves.easeOutCubic,
    ));
    _animationX = Tween<double>(
      begin: _angleX,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _snapController,
      curve: Curves.easeOutCubic,
    ));

    await _snapController.forward(from: 0.0);
    await Future.delayed(const Duration(milliseconds: 350));
    if (mounted) _animateToFront();
  }

  void _animateToFront() {
    _animationY = Tween<double>(
      begin: _angleY,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _snapController,
      curve: Curves.easeOutBack,
    ));

    _animationX = Tween<double>(
      begin: _angleX,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _snapController,
      curve: Curves.easeOutCubic,
    ));

    _snapController.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Center(
        child: GestureDetector(
          onHorizontalDragStart: _onHorizontalDragStart,
          onHorizontalDragUpdate: _onHorizontalDragUpdate,
          onHorizontalDragEnd: _onHorizontalDragEnd,
          onVerticalDragStart: _onVerticalDragStart,
          onVerticalDragUpdate: _onVerticalDragUpdate,
          onVerticalDragEnd: _onVerticalDragEnd,
          onTap: _onTap,
          behavior: HitTestBehavior.opaque,
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                // 1. Ambient Level Radial Glow — static, lives outside AnimatedBuilder
                //    so it is never rebuilt during drag/animation frames.
                OverflowBox(
                  maxWidth: widget.size * 2.2,
                  maxHeight: widget.size * 2.2,
                  child: Container(
                    width: widget.size * 2.2,
                    height: widget.size * 2.2,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          widget.glowColor.withValues(alpha: 0.40),
                          widget.glowColor.withValues(alpha: 0.18),
                          widget.glowColor.withValues(alpha: 0.04),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.35, 0.70, 1.0],
                      ),
                    ),
                  ),
                ),

                // 2. 3D Perspective Matrix — rebuilt only when angles change.
                AnimatedBuilder(
                  animation:
                      Listenable.merge([_angleYNotifier, _angleXNotifier]),
                  builder: (context, _) {
                    final angleY = _angleYNotifier.value;
                    final angleX = _angleXNotifier.value;

                    // Normalize Y angle to [0, 2*pi)
                    final normalizedY =
                        (angleY % (2 * math.pi) + 2 * math.pi) % (2 * math.pi);
                    final isBackFacing = normalizedY > math.pi / 2 &&
                        normalizedY < 3 * math.pi / 2;

                    return Transform(
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.0015) // Perspective depth
                        ..rotateX(angleX)
                        ..rotateY(angleY),
                      alignment: Alignment.center,
                      child: !isBackFacing
                          ? _buildFrontBadge()
                          : _buildExactSilverBackBadge(angleY, angleX),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Front Side of Badge (Original SVG badge, crisp with no overlays)
  Widget _buildFrontBadge() {
    return SvgPicture.asset(
      widget.badgePath,
      width: widget.size,
      height: widget.size,
      fit: BoxFit.contain,
    );
  }

  /// Back Side of Badge: Solid flat white SVG with ultra-smooth liquid metallic silver sheen
  Widget _buildExactSilverBackBadge(double angleY, double angleX) {
    // Continuous trigonometric sine wave formula for 100% smooth sheen sweeping without jumps
    final sheenOffset = math.sin(angleY * 0.85 + angleX * 0.5);

    // Counter-rotate 180° so back typography reads correctly when flipped
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()..rotateY(math.pi),
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 1. Solid Flat White SVG with Liquid Specular Chrome Gradient
            ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                begin: Alignment(-1.2 + (sheenOffset * 0.65), -1.2 + (sheenOffset * 0.2)),
                end: Alignment(1.2 + (sheenOffset * 0.65), 1.2 + (sheenOffset * 0.2)),
                colors: [
                  AppColors.cardCbeBirrSilver, // Platinum silver base
                  AppColors.slateMuted,        // Steel silver shadow
                  AppColors.whiterGlow,        // Concentrated specular shine streak
                  AppColors.textPrimary,       // Pure liquid chrome glare
                  AppColors.slateLight,        // Mid metallic chrome
                  AppColors.slateMuted,        // Outer dark silver edge
                ],
                stops: const [0.0, 0.25, 0.46, 0.54, 0.75, 1.0],
              ).createShader(bounds),
              blendMode: BlendMode.srcIn,
              child: ColorFiltered(
                colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                child: SvgPicture.asset(
                  widget.badgePath,
                  width: widget.size,
                  height: widget.size,
                  fit: BoxFit.contain,
                ),
              ),
            ),

            // 2. Engraved Metallic Content: Silver Star & Level Typography
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Engraved Silver Star Emblem Pill
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.navyDark.withValues(alpha: 0.88),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withValues(alpha: 0.70),
                          blurRadius: 5,
                          spreadRadius: -1,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.star_rounded,
                      color: AppColors.slateSurface,
                      size: widget.size * 0.20,
                    ),
                  ),

                  const SizedBox(height: 4),

                  // Engraved Level Label (e.g. "LEVEL 1")
                  Text(
                    'LEVEL ${widget.level}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.navyDark,
                      fontSize: widget.size * 0.105,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                      shadows: const [
                        Shadow(
                          color: Colors.white,
                          offset: Offset(0.5, 0.8),
                          blurRadius: 0.8,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 1),

                  // Engraved Level Rank Title (e.g. "SURVIVOR", "BUILDER")
                  Text(
                    widget.levelName.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.slateBorder,
                      fontSize: widget.size * 0.07,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      shadows: const [
                        Shadow(
                          color: Colors.white,
                          offset: Offset(0.3, 0.5),
                          blurRadius: 0.5,
                        ),
                      ],
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
