import 'dart:ui';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_back_button.dart';
import 'notifications/dynamic_notification_pill.dart';
import 'notifications/notifications_panel_content.dart';

export 'notifications/dynamic_notification_pill.dart';
export 'notifications/notifications_panel_overlay.dart';
export 'notifications/notifications_panel_content.dart';
export 'notifications/notification_card.dart';
export 'notifications/notification_action_dialogs.dart';

// ── Legacy wrappers kept for backwards compatibility ────────────────────────

/// Legacy — use [DynamicNotificationPill] instead.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12.0, 16.0, 16.0, 16.0),
              child: Row(
                children: [
                  const AppBackButton.dark(),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Unread Notifications',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                      ),
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

/// Legacy — use [DynamicNotificationPill] instead.
class NotificationsModalWidget extends StatelessWidget {
  final VoidCallback? onClose;
  const NotificationsModalWidget({super.key, this.onClose});

  @override
  Widget build(BuildContext context) {
    return NotificationsPanelContent(
      onClose: onClose ?? () => Navigator.pop(context),
    );
  }
}

/// Legacy function kept for any lingering references.
void showNotificationsOverlay(BuildContext context) {
  showModalBottomSheet(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.65),
    builder: (ctx) => BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
      child: Container(
        height: MediaQuery.of(ctx).size.height * 0.92,
        margin: EdgeInsets.only(
          top: MediaQuery.of(ctx).padding.top + 8,
          left: 12,
          right: 12,
          bottom: 12,
        ),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(AppRadius.sheet),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: NotificationsModalWidget(
          onClose: () => Navigator.of(ctx, rootNavigator: true).pop(),
        ),
      ),
    ),
  );
}
