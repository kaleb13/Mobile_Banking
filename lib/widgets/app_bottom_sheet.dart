import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'interactive_drag_handle.dart';

/// Standardized Modal Bottom Sheet Layout & Scaffold with Frosted Dark Blur.
class AppBottomSheet extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final Widget? trailingHeader;
  final Widget child;
  final Widget? footer;
  final EdgeInsetsGeometry padding;
  final bool showDragHandle;
  final double maxHeightFactor;

  const AppBottomSheet({
    super.key,
    this.title,
    this.subtitle,
    this.trailingHeader,
    required this.child,
    this.footer,
    this.padding = const EdgeInsets.fromLTRB(20, 16, 20, 24),
    this.showDragHandle = true,
    this.maxHeightFactor = 0.9,
  });

  /// Standard static launcher for Bottom Sheets throughout the app.
  /// Automatically renders a frosted, dark blurred background barrier.
  static Future<T?> show<T>({
    required BuildContext context,
    required Widget Function(BuildContext) builder,
    bool isScrollControlled = true,
    bool isDismissible = true,
    bool enableDrag = true,
    Color? barrierColor,
    double blurSigma = 8.0,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      barrierColor: Colors.transparent,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: isDismissible ? () => Navigator.pop(ctx) : null,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
                child: Container(
                  color: barrierColor ?? Colors.black.withValues(alpha: 0.52),
                ),
              ),
            ),
          ),
          builder(ctx),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final systemNavBottom = MediaQuery.paddingOf(context).bottom;
    final double extraBottom = bottomInset > 0 ? bottomInset : systemNavBottom;
    final insets = padding.resolve(Directionality.of(context));
    final maxHeight = MediaQuery.of(context).size.height * maxHeightFactor;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: AppRadius.sheetRadius,
      ),
      padding: EdgeInsets.fromLTRB(
        insets.left,
        insets.top,
        insets.right,
        insets.bottom + extraBottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showDragHandle)
            const Center(
              child: Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: InteractiveDragHandle(),
              ),
            ),

          if (title != null && title!.isNotEmpty) ...[
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title!,
                        style: AppTypography.heading1.copyWith(
                          color: context.themeTextPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (subtitle != null && subtitle!.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          subtitle!,
                          style: AppTypography.bodySmall.copyWith(
                            color: context.themeTextSecondary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailingHeader != null) trailingHeader!,
              ],
            ),
            const SizedBox(height: 18),
          ],

          Flexible(
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              child: child,
            ),
          ),

          if (footer != null) ...[
            const SizedBox(height: 16),
            footer!,
          ],
        ],
      ),
    );
  }
}
