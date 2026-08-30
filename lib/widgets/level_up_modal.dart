import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/interactive_3d_badge.dart';
import '../widgets/custom_progress_bar.dart';
import '../widgets/app_button.dart';
import '../widgets/app_badges.dart';

// ── Glow colors per level (mirrors profile_hub_screen.dart) ──────────────────
Color _levelGlowColor(int level) {
  switch (level) {
    case 1: return AppColors.levelGlow1;
    case 2: return AppColors.levelGlow2;
    case 3: return AppColors.levelGlow3;
    case 4: return AppColors.levelGlow4;
    case 5: return AppColors.levelGlow5;
    default: return AppColors.levelGlow1;
  }
}

/// Shows the level-up celebration bottom-sheet.
///
/// Call this whenever the user's level advances or when they tap "Claim Badge".
///
/// Parameters:
/// - [newLevel]             — the level just reached (1–5)
/// - [newLevelName]         — display name for [newLevel]
/// - [newLevelDescription]  — motivational description for [newLevel]
/// - [nextLevelName]        — name of the next level, or null if at max
/// - [nextLevelProgress]    — 0.0–1.0 progress towards the next level
/// - [isBalanceVisible]     — whether monetary progress / percent should be displayed or masked
/// - [onContinue]           — callback fired when the user dismisses / taps CTA
Future<void> showLevelUpModal(
  BuildContext context, {
  required int newLevel,
  required String newLevelName,
  required String newLevelDescription,
  String? nextLevelName,
  double nextLevelProgress = 0.0,
  bool isBalanceVisible = true,
  VoidCallback? onContinue,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.65),
    useSafeArea: false,
    builder: (ctx) => Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: () => Navigator.pop(ctx),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                color: Colors.black.withValues(alpha: 0.25),
              ),
            ),
          ),
        ),
        _LevelUpSheet(
          newLevel: newLevel,
          newLevelName: newLevelName,
          newLevelDescription: newLevelDescription,
          nextLevelName: nextLevelName,
          nextLevelProgress: nextLevelProgress,
          isBalanceVisible: isBalanceVisible,
          onContinue: onContinue,
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────

class _LevelUpSheet extends StatefulWidget {
  final int newLevel;
  final String newLevelName;
  final String newLevelDescription;
  final String? nextLevelName;
  final double nextLevelProgress;
  final bool isBalanceVisible;
  final VoidCallback? onContinue;

  const _LevelUpSheet({
    required this.newLevel,
    required this.newLevelName,
    required this.newLevelDescription,
    required this.nextLevelName,
    required this.nextLevelProgress,
    this.isBalanceVisible = true,
    this.onContinue,
  });

  @override
  State<_LevelUpSheet> createState() => _LevelUpSheetState();
}

class _LevelUpSheetState extends State<_LevelUpSheet>
    with TickerProviderStateMixin {

  // Badge elastic pop-in
  late final AnimationController _entryCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 750),
  );
  late final Animation<double> _scaleAnim = CurvedAnimation(
    parent: _entryCtrl,
    curve: Curves.elasticOut,
  );
  late final Animation<double> _fadeAnim = CurvedAnimation(
    parent: _entryCtrl,
    curve: const Interval(0.0, 0.45, curve: Curves.easeIn),
  );

  // Next-level progress bar fill
  late final AnimationController _barCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );
  late final Animation<double> _barAnim = CurvedAnimation(
    parent: _barCtrl,
    curve: Curves.easeOutCubic,
  );

  // Confetti burst
  late final AnimationController _confettiCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );

  @override
  void initState() {
    super.initState();
    _entryCtrl.forward();
    Future.delayed(const Duration(milliseconds: 350), () {
      if (mounted) {
        _barCtrl.forward();
        _confettiCtrl.forward();
      }
    });
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _barCtrl.dispose();
    _confettiCtrl.dispose();
    super.dispose();
  }

  void _dismiss() {
    Navigator.of(context).pop();
    widget.onContinue?.call();
  }

  @override
  Widget build(BuildContext context) {
    final glowColor = _levelGlowColor(widget.newLevel);
    final badgePath = 'assets/images/LV${widget.newLevel}.svg';
    final screenH = MediaQuery.of(context).size.height;

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: screenH * 0.82),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: AppRadius.sheetRadius,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // ── Radial glow background ─────────────────────────────────
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: AppRadius.sheetRadius,
                  child: AnimatedBuilder(
                    animation: _fadeAnim,
                    builder: (_, __) => Opacity(
                      opacity: _fadeAnim.value * 0.20,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            center: const Alignment(0, -0.55),
                            radius: 0.80,
                            colors: [glowColor, Colors.transparent],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // ── Confetti particles ─────────────────────────────────────
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _confettiCtrl,
                    builder: (_, __) => CustomPaint(
                      painter: _ConfettiPainter(
                        progress: _confettiCtrl.value,
                        glowColor: glowColor,
                      ),
                    ),
                  ),
                ),
              ),

              // ── Content ────────────────────────────────────────────────
              SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    24,
                    18,
                    24,
                    24 + (MediaQuery.viewInsetsOf(context).bottom > 0
                        ? MediaQuery.viewInsetsOf(context).bottom
                        : MediaQuery.paddingOf(context).bottom),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Drag handle
                      Center(
                        child: Container(
                          width: 42,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),

                      // ── "LEVEL X UNLOCKED" pill ────────────────────────
                      AnimatedBuilder(
                        animation: _fadeAnim,
                        builder: (_, __) => Opacity(
                          opacity: _fadeAnim.value,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 5),
                            decoration: BoxDecoration(
                              color:
                                  AppColors.positive.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                                                          ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.bolt_rounded,
                                    color: AppColors.positive, size: 14),
                                const SizedBox(width: 5),
                                Text(
                                  'LEVEL ${widget.newLevel} UNLOCKED',
                                  style: const TextStyle(
                                    color: AppColors.positive,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 26),

                      // ── Badge (elastic pop-in) ─────────────────────────
                      AnimatedBuilder(
                        animation: _scaleAnim,
                        builder: (_, child) => Transform.scale(
                          scale: _scaleAnim.value,
                          child: child,
                        ),
                        child: Interactive3DBadge(
                          level: widget.newLevel,
                          levelName: widget.newLevelName,
                          badgePath: badgePath,
                          glowColor: glowColor,
                          size: 140,
                        ),
                      ),
                      const SizedBox(height: 22),

                      // ── Level name & description ───────────────────────
                      AnimatedBuilder(
                        animation: _fadeAnim,
                        builder: (_, __) => Opacity(
                          opacity: _fadeAnim.value,
                          child: Column(
                            children: [
                              Text(
                                widget.newLevelName,
                                style: TextStyle(
                                  color: glowColor,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 7),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                                child: Text(
                                  widget.newLevelDescription,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.56),
                                    fontSize: 13,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ── Next-level progress card ───────────────────────
                      AnimatedBuilder(
                        animation: _fadeAnim,
                        builder: (_, __) => Opacity(
                          opacity: _fadeAnim.value,
                          child: _buildProgressCard(glowColor),
                        ),
                      ),
                      const SizedBox(height: 26),

                      // ── CTA Button ─────────────────────────────────────
                      AnimatedBuilder(
                        animation: _fadeAnim,
                        builder: (_, __) => Opacity(
                          opacity: _fadeAnim.value,
                          child: _buildCTAButton(),
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
    );
  }

  // ── Progress card ───────────────────────────────────────────────────────────

  Widget _buildProgressCard(Color glowColor) {
    if (widget.nextLevelName == null) {
      // Max level — celebratory card
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.cardRadius,
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: glowColor.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.emoji_events_rounded,
                  color: glowColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Maximum Level Achieved!',
                    style: TextStyle(
                      color: glowColor,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'You are among the elite — a rare class of financial excellence.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.48),
                      fontSize: 11.5,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.bolt_rounded,
                      color: AppColors.positive, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'Path to ${widget.nextLevelName}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              AnimatedBuilder(
                animation: _barAnim,
                builder: (_, __) {
                  final pct = (_barAnim.value * widget.nextLevelProgress * 100)
                      .toStringAsFixed(1);
                  return AppBadge.success(
                    text: widget.isBalanceVisible ? '$pct%' : '•••%',
                    size: AppBadgeSize.small,
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 14),
          AnimatedBuilder(
            animation: _barAnim,
            builder: (_, __) => CustomProgressBar(
              progress: widget.isBalanceVisible
                  ? _barAnim.value * widget.nextLevelProgress
                  : 0.0,
              height: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              progressColor: AppColors.positive,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Keep growing your balance to unlock ${widget.nextLevelName}.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.44),
              fontSize: 11.5,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  // ── CTA button ──────────────────────────────────────────────────────────────

  Widget _buildCTAButton() {
    return AppButton.primary(
      text: 'Claim Badge & Continue',
      trailingIcon: Icons.arrow_forward_rounded,
      height: 52,
      onPressed: _dismiss,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Confetti particles
// ─────────────────────────────────────────────────────────────────────────────

class _ConfettiPainter extends CustomPainter {
  final double progress;
  final Color glowColor;

  _ConfettiPainter({required this.progress, required this.glowColor});

  static final _particles = _buildParticles();

  static List<_Particle> _buildParticles() {
    final rng = math.Random(42);
    return List.generate(52, (i) => _Particle(
      startX: rng.nextDouble(),
      startY: 0.20 + rng.nextDouble() * 0.30,
      vx: (rng.nextDouble() - 0.5) * 0.42,
      vy: 0.28 + rng.nextDouble() * 0.48,
      size: 3.5 + rng.nextDouble() * 5.5,
      colorIdx: i % 4,
      rotSpeed: (rng.nextDouble() - 0.5) * math.pi * 3.5,
      isRect: rng.nextBool(),
    ));
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1.0) return;
    final fade = progress < 0.72 ? 1.0 : (1.0 - (progress - 0.72) / 0.28);

    for (final p in _particles) {
      final x = (p.startX + p.vx * progress) * size.width;
      final y = (p.startY + p.vy * progress) * size.height;
      final opacity = (fade * 0.88).clamp(0.0, 1.0);
      final color = _color(p.colorIdx).withValues(alpha: opacity);
      final paint = Paint()..color = color;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.rotSpeed * progress * math.pi * 2);

      if (p.isRect) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: Offset.zero,
                width: p.size,
                height: p.size * 0.42),
            const Radius.circular(1.5),
          ),
          paint,
        );
      } else {
        canvas.drawCircle(Offset.zero, p.size * 0.44, paint);
      }
      canvas.restore();
    }
  }

  Color _color(int idx) {
    switch (idx) {
      case 0: return glowColor;
      case 1: return AppColors.positive;
      case 2: return AppColors.gold;
      default: return Colors.white.withValues(alpha: 0.75);
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) =>
      old.progress != progress || old.glowColor != glowColor;
}

class _Particle {
  final double startX, startY, vx, vy, size, rotSpeed;
  final int colorIdx;
  final bool isRect;
  const _Particle({
    required this.startX, required this.startY,
    required this.vx, required this.vy,
    required this.size, required this.colorIdx,
    required this.rotSpeed, required this.isRect,
  });
}
