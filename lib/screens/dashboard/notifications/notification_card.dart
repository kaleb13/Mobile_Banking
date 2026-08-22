import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import '../../../models/app_notification.dart';
import '../../../theme/app_theme.dart';

class NotificationCard extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onIgnore;
  final VoidCallback onLongPress;

  const NotificationCard({
    super.key,
    required this.notification,
    required this.onIgnore,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final isSystem = notification.sender.startsWith('Loan') ||
        notification.sender.startsWith('System');
    final String formattedDate =
        DateFormat('MMM d, HH:mm').format(notification.date);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Slidable(
        key: Key(notification.id),
        direction: Axis.horizontal,
        endActionPane: ActionPane(
          motion: const BehindMotion(),
          extentRatio: 0.24,
          dismissible: DismissiblePane(
            onDismissed: onIgnore,
          ),
          children: [
            CustomSlidableAction(
              onPressed: (_) => onIgnore(),
              backgroundColor: Colors.transparent,
              padding: const EdgeInsets.only(left: 8),
              child: Container(
                width: double.infinity,
                height: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: AppRadius.cardRadius,
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.textSecondary.withValues(alpha: 0.14),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.block_rounded,
                          color: AppColors.textSecondary,
                          size: 18,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Ignore',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        child: GestureDetector(
          onLongPress: onLongPress,
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.cardRadius,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Row: Sender + Date
                Row(
                  children: [
                    Icon(
                      isSystem
                          ? Icons.notifications_active_rounded
                          : Icons.sms_outlined,
                      color: isSystem ? AppColors.amber : Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        notification.displaySender,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      formattedDate,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontSize: 11,
                      ),
                      maxLines: 1,
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Badge for Unparsed Financial SMS
                if (!isSystem) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          color: AppColors.amber,
                          size: 15,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Unrecognized financial format. You can export and send this report to the developer.',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11.5,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Raw SMS Message Body
                Text(
                  notification.body,
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
