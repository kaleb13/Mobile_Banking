import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'app_button.dart';

/// Standardized Modal Dialog container following the exact same visual design,
/// glass surface styling, left-aligned typography, and button pill layout
/// as [AppConfirmDialog].
class AppModalDialog extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  final String confirmText;
  final String cancelText;
  final VoidCallback onConfirm;
  final VoidCallback? onCancel;
  final bool isDestructive;
  final bool isLoading;

  const AppModalDialog({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
    this.confirmText = 'Save',
    this.cancelText = 'Cancel',
    required this.onConfirm,
    this.onCancel,
    this.isDestructive = false,
    this.isLoading = false,
  });

  /// Standard static launcher with subtle background blur and soft shade barrier.
  static Future<T?> show<T>({
    required BuildContext context,
    required Widget Function(BuildContext ctx) builder,
    bool barrierDismissible = true,
  }) {
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.35),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (ctx, anim1, anim2) => const SizedBox.shrink(),
      transitionBuilder: (ctx, anim1, anim2, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: 6.0 * anim1.value,
                sigmaY: 6.0 * anim1.value,
              ),
              child: const SizedBox.expand(),
            ),
            FadeTransition(
              opacity: anim1,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.95, end: 1.0).animate(
                  CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic),
                ),
                child: builder(ctx),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: ClipRRect(
          borderRadius: AppRadius.dialogRadius,
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: AppColors.glassBlurSigma,
              sigmaY: AppColors.glassBlurSigma,
            ),
            child: Container(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
              decoration: BoxDecoration(
                color: AppColors.glassSurfaceModal,
                borderRadius: AppRadius.dialogRadius,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left-aligned Title
                  Text(
                    title,
                    textAlign: TextAlign.left,
                    style: AppTypography.heading2.copyWith(
                      color: AppColors.textPrimary,
                      fontSize: 16.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      subtitle!,
                      textAlign: TextAlign.left,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        height: 1.45,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  child,
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: AppButton.secondary(
                          text: cancelText,
                          height: 42,
                          onPressed: () {
                            Navigator.pop(context);
                            onCancel?.call();
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: isDestructive
                            ? AppButton.destructive(
                                text: confirmText,
                                height: 42,
                                isLoading: isLoading,
                                onPressed: onConfirm,
                              )
                            : AppButton.primary(
                                text: confirmText,
                                height: 42,
                                isLoading: isLoading,
                                onPressed: onConfirm,
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
    );
  }
}
