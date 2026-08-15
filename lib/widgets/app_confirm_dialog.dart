import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'app_button.dart';

/// Standardized Confirmation Dialog adhering strictly to:
/// - Low-opacity soft dark shade backdrop with subtle blur (`sigma = 6.0`).
/// - Compact, balanced card proportions (`maxWidth: 320`).
/// - Dark, translucent, and glass-like surface card (`borderRadius = 24.0`).
/// - Zero borders / stroke lines.
/// - Left-aligned title & description (no distracting icons).
/// - Two side-by-side 100% fully rounded pill buttons at the bottom.
class AppConfirmDialog extends StatelessWidget {
  final String title;
  final String? message;
  final String? details;
  final Widget? customContent;
  final String confirmText;
  final String cancelText;
  final VoidCallback onConfirm;
  final VoidCallback? onCancel;
  final bool isDestructive;

  const AppConfirmDialog({
    super.key,
    required this.title,
    this.message,
    this.details,
    this.customContent,
    this.confirmText = 'Confirm',
    this.cancelText = 'Cancel',
    required this.onConfirm,
    this.onCancel,
    this.isDestructive = false,
  });

  /// Standard static launcher with subtle background blur and soft shade barrier.
  static Future<bool?> show({
    required BuildContext context,
    required String title,
    String? message,
    String? details,
    Widget? customContent,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    required VoidCallback onConfirm,
    VoidCallback? onCancel,
    bool isDestructive = false,
    // Deprecated parameters kept for API compatibility but omitted visually
    IconData? icon,
    Color? iconColor,
  }) {
    return showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.35),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (ctx, anim1, anim2) => const SizedBox.shrink(),
      transitionBuilder: (ctx, anim1, anim2, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Soft subtle blur on the background behind the modal
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
                child: AppConfirmDialog(
                  title: title,
                  message: message,
                  details: details,
                  customContent: customContent,
                  confirmText: confirmText,
                  cancelText: cancelText,
                  onConfirm: onConfirm,
                  onCancel: onCancel,
                  isDestructive: isDestructive,
                ),
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
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: AppColors.glassBlurSigma,
              sigmaY: AppColors.glassBlurSigma,
            ),
            child: Container(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
              decoration: BoxDecoration(
                color: AppColors.glassSurfaceModal,
                borderRadius: BorderRadius.circular(32),
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
                  const SizedBox(height: 8),

                  // Left-aligned Description / Message
                  if (message != null && message!.isNotEmpty)
                    Text(
                      message!,
                      textAlign: TextAlign.left,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        height: 1.45,
                      ),
                    ),

                  // Optional details in translucent glass card
                  if (details != null && details!.isNotEmpty)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(top: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.buttonSecondary,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        details!,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textPrimary,
                          height: 1.35,
                        ),
                      ),
                    ),

                  if (customContent != null) ...[
                    if (message != null) const SizedBox(height: 12),
                    customContent!,
                  ],

                  const SizedBox(height: 20),

                  // Two side-by-side 100% Fully Rounded Pill Buttons
                  Row(
                    children: [
                      Expanded(
                        child: AppButton.secondary(
                          text: cancelText,
                          height: 42,
                          onPressed: () {
                            Navigator.pop(context, false);
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
                                onPressed: () {
                                  Navigator.pop(context, true);
                                  onConfirm();
                                },
                              )
                            : AppButton.primary(
                                text: confirmText,
                                height: 42,
                                onPressed: () {
                                  Navigator.pop(context, true);
                                  onConfirm();
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
    );
  }
}
