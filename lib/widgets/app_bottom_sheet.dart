import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'interactive_drag_handle.dart';

/// Standardized Modal Bottom Sheet Layout & Scaffold.
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
  static Future<T?> show<T>({
    required BuildContext context,
    required Widget Function(BuildContext) builder,
    bool isScrollControlled = true,
    bool isDismissible = true,
    bool enableDrag = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      backgroundColor: Colors.transparent,
      builder: (ctx) => Stack(
        children: [
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
              child: const SizedBox.expand(),
            ),
          ),
          builder(ctx),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final maxHeight = MediaQuery.of(context).size.height * maxHeightFactor;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          constraints: BoxConstraints(maxHeight: maxHeight),
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.94),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
      padding: EdgeInsets.fromLTRB(
        (padding as EdgeInsets).left,
        (padding as EdgeInsets).top,
        (padding as EdgeInsets).right,
        (padding as EdgeInsets).bottom + bottomInset,
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
              physics: const BouncingScrollPhysics(),
              child: child,
            ),
          ),

          if (footer != null) ...[
            const SizedBox(height: 16),
            footer!,
          ],
        ],
      ),
    ),
  ),
);
  }
}
