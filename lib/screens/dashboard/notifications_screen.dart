import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/finance_provider.dart';
import '../../theme/app_theme.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FinanceProvider>(context);

    // Mark all as read when screen is opened
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (provider.unreadNotificationCount > 0) {
        provider.markNotificationsRead();
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFF0A0B0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0B0D),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: AppColors.textWhite, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Notifications',
          style: TextStyle(
            color: AppColors.textWhite,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          if (provider.notifications.isNotEmpty)
            TextButton(
              onPressed: () => _showClearAll(context, provider),
              child: const Text(
                'Clear all',
                style:
                    TextStyle(color: AppColors.primaryBlue, fontSize: 13),
              ),
            ),
        ],
      ),
      body: provider.notifications.isEmpty
          ? _buildEmpty()
          : ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: provider.notifications.length,
              separatorBuilder: (_, __) => const Divider(
                color: AppColors.surfaceDark,
                height: 1,
              ),
              itemBuilder: (context, index) {
                final notif = provider.notifications[index];
                return GestureDetector(
                  onLongPress: () =>
                      _showLongPressModal(context, provider, notif.id),
                  child: Dismissible(
                    key: Key(notif.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      color: AppColors.alertRed.withValues(alpha: 0.8),
                      child:
                          const Icon(Icons.delete_outline, color: Colors.white),
                    ),
                    onDismissed: (_) => provider.deleteNotification(notif.id),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppColors.alertRed.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.sms_failed_outlined,
                              color: AppColors.alertRed,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.alertRed
                                            .withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        notif.sender,
                                        style: const TextStyle(
                                          color: AppColors.alertRed,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.textGray
                                            .withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        'Unregistered Message',
                                        style: TextStyle(
                                          color: AppColors.textGray,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      DateFormat('MMM d, HH:mm')
                                          .format(notif.date),
                                      style: const TextStyle(
                                        color: AppColors.textGray,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  notif.body,
                                  style: const TextStyle(
                                    color: AppColors.textWhite,
                                    fontSize: 13,
                                    height: 1.5,
                                  ),
                                  maxLines: 4,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.surfaceDark,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(
              Icons.notifications_none_rounded,
              color: AppColors.primaryBlue,
              size: 40,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'No Notifications',
            style: TextStyle(
              color: AppColors.textWhite,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Unrecognized messages from\nregistered senders will appear here',
            textAlign: TextAlign.center,
            style:
                TextStyle(color: AppColors.textGray, fontSize: 14, height: 1.6),
          ),
        ],
      ),
    );
  }

  void _showLongPressModal(
      BuildContext context, FinanceProvider provider, String id) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 16),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textGray.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Text(
              'Message Options',
              style: TextStyle(
                color: AppColors.textWhite,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'What would you like to do with this message?',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textGray, fontSize: 13),
              ),
            ),
            const SizedBox(height: 20),
            // Ignore permanently
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () async {
                Navigator.pop(ctx);
                await provider.ignoreNotification(id);
              },
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.alertRed.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.alertRed.withValues(alpha: 0.3),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.block_rounded,
                        color: AppColors.alertRed, size: 20),
                    SizedBox(width: 10),
                    Text(
                      'Ignore this message',
                      style: TextStyle(
                        color: AppColors.alertRed,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Just delete (not ignored — can come back on refresh)
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () async {
                Navigator.pop(ctx);
                await provider.deleteNotification(id);
              },
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.textGray.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.delete_outline,
                        color: AppColors.textGray, size: 20),
                    SizedBox(width: 10),
                    Text(
                      'Just delete',
                      style: TextStyle(
                        color: AppColors.textGray,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Cancel
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => Navigator.pop(ctx),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    color: AppColors.primaryBlue,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showClearAll(BuildContext context, FinanceProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        title: const Text('Clear All',
            style: TextStyle(color: AppColors.textWhite)),
        content: const Text(
          'Remove all notifications?',
          style: TextStyle(color: AppColors.textGray),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textGray)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final notifsCopy = List.of(provider.notifications);
              for (final n in notifsCopy) {
                await provider.deleteNotification(n.id);
              }
            },
            child: const Text('Clear',
                style: TextStyle(color: AppColors.alertRed)),
          ),
        ],
      ),
    );
  }
}
