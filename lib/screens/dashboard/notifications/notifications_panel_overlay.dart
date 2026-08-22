import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../presentation/viewmodels/notifications_view_model.dart';
import '../../../theme/app_theme.dart';
import 'notifications_panel_content.dart';

class NotificationsPanelOverlay extends StatelessWidget {
  final double pillTop;
  final double pillLeft;
  final double pillWidth;
  final double expandedHeight;
  final Animation<double> expandAnim;
  final Animation<double> fadeAnim;
  final VoidCallback onClose;

  const NotificationsPanelOverlay({
    super.key,
    required this.pillTop,
    required this.pillLeft,
    required this.pillWidth,
    required this.expandedHeight,
    required this.expandAnim,
    required this.fadeAnim,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final notifsVM = context.watch<NotificationsViewModel>();
    final unreadCount = notifsVM.unreadCount;

    final double screenWidth = MediaQuery.of(context).size.width;
    const double targetLeft = 0.0;
    final double targetWidth = screenWidth;

    return AnimatedBuilder(
      animation: expandAnim,
      builder: (context, child) {
        final double currentHeight =
            38.0 + (expandedHeight - 38.0) * expandAnim.value;
        final double currentWidth =
            pillWidth + (targetWidth - pillWidth) * expandAnim.value;
        final double currentLeft =
            pillLeft + (targetLeft - pillLeft) * expandAnim.value;
        final double currentRadius =
            lerpDouble(19.0, AppRadius.card, expandAnim.value) ??
                AppRadius.card;

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
                child: Container(
                  height: currentHeight,
                  decoration: BoxDecoration(
                    color: currentBg,
                    borderRadius: BorderRadius.circular(currentRadius),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black
                            .withValues(alpha: 0.35 * expandAnim.value),
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
                      width: currentWidth,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Full Expanded Panel Content
                          if (morphT > 0.0)
                            Positioned.fill(
                              child: Opacity(
                                opacity: morphT,
                                child: NotificationsPanelContent(
                                  onClose: onClose,
                                ),
                              ),
                            ),

                          // Island Pill Content (morphs in as expandAnim <= 0.30)
                          if (morphT < 1.0)
                            Positioned(
                              top: 0,
                              left: 0,
                              right: 0,
                              height: 38,
                              child: Opacity(
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
                                          if (unreadCount > 0)
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
                                          unreadCount > 0
                                              ? '$unreadCount unread notification${unreadCount > 1 ? 's' : ''}'
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
                            ),
                        ],
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
