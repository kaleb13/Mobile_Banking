import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../../models/app_notification.dart';
import '../../providers/finance_provider.dart';
import '../../theme/app_theme.dart';
import 'manual_transaction_sheet.dart';

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
      backgroundColor: const Color(0xFF1F1F25),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.only(
                          right: 16.0, top: 4.0, bottom: 4.0),
                      child: SvgPicture.asset(
                        'assets/images/BackForNav.svg',
                        colorFilter: const ColorFilter.mode(
                            Colors.white, BlendMode.srcIn),
                        width: 22,
                        height: 22,
                      ),
                    ),
                  ),
                  const Expanded(
                    child: Text(
                      'Notifications',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (provider.notifications.isNotEmpty)
                    GestureDetector(
                      onTap: () => _showClearAll(context, provider),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlue.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'Clear',
                          style: TextStyle(
                            color: AppColors.primaryBlue,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // List / Empty State
            Expanded(
              child: provider.notifications.isEmpty
                  ? _buildEmpty()
                  : ListView.builder(
                      padding: const EdgeInsets.only(top: 8, bottom: 40),
                      physics: const BouncingScrollPhysics(),
                      itemCount: provider.notifications.length,
                      itemBuilder: (context, index) {
                        final notif = provider.notifications[index];
                        final isSystem = notif.sender.startsWith('Loan') ||
                            notif.sender.startsWith('System');

                        return Container(
                          margin: const EdgeInsets.only(
                              bottom: 12, left: 20, right: 20),
                          child: Slidable(
                            key: Key(notif.id),
                            direction: Axis.horizontal,
                            endActionPane: ActionPane(
                              motion: const DrawerMotion(),
                              extentRatio: isSystem ? 0.35 : 0.78,
                              dismissible: DismissiblePane(
                                onDismissed: () =>
                                    provider.deleteNotification(notif.id),
                              ),
                              children: [
                                _buildSlidableAction(
                                  onPressed: (context) =>
                                      provider.deleteNotification(notif.id),
                                  icon: Icons.delete_rounded,
                                  label: 'Delete',
                                  color: AppColors.alertRed,
                                  isFirst: true,
                                  isLast: isSystem,
                                ),
                                if (!isSystem) ...[
                                  _buildSlidableAction(
                                    onPressed: (context) => _showManualInsert(
                                        context, provider, notif),
                                    icon: Icons.add_circle_outline_rounded,
                                    label: 'Insert',
                                    color: AppColors.primaryBlue,
                                  ),
                                  _buildSlidableAction(
                                    onPressed: (context) =>
                                        _informDeveloper(context, notif.body),
                                    icon: Icons.telegram_rounded,
                                    label: 'Inform',
                                    color: AppColors.labelGray
                                        .withValues(alpha: 0.7),
                                    isLast: true,
                                  ),
                                ],
                              ],
                            ),
                            child: GestureDetector(
                              onLongPress: () =>
                                  _showLongPressModal(context, provider, notif),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceLight
                                      .withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                      color:
                                          Colors.white.withValues(alpha: 0.03)),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: AppColors.primaryBlue
                                            .withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: SvgPicture.asset(
                                        'assets/images/Notification.svg',
                                        colorFilter: const ColorFilter.mode(
                                            AppColors.primaryBlue,
                                            BlendMode.srcIn),
                                        width: 20,
                                        height: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Wrap(
                                                  spacing: 8,
                                                  runSpacing: 4,
                                                  children: [
                                                    Text(
                                                      notif.sender,
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 15,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                    if (isSystem)
                                                      Container(
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                horizontal: 6,
                                                                vertical: 2),
                                                        decoration:
                                                            BoxDecoration(
                                                          color: AppColors
                                                              .primaryBlue
                                                              .withValues(
                                                                  alpha: 0.15),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(6),
                                                        ),
                                                        child: const Text(
                                                          'System Message',
                                                          style: TextStyle(
                                                            color: AppColors
                                                                .primaryBlue,
                                                            fontSize: 10,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                          ),
                                                        ),
                                                      )
                                                    else
                                                      Container(
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                horizontal: 6,
                                                                vertical: 2),
                                                        decoration:
                                                            BoxDecoration(
                                                          color: AppColors
                                                              .labelGray
                                                              .withValues(
                                                                  alpha: 0.12),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(6),
                                                        ),
                                                        child: const Text(
                                                          'Unregistered',
                                                          style: TextStyle(
                                                            color: AppColors
                                                                .labelGray,
                                                            fontSize: 10,
                                                            fontWeight:
                                                                FontWeight.w500,
                                                          ),
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                DateFormat('MMM d, HH:mm')
                                                    .format(notif.date),
                                                style: const TextStyle(
                                                  color: AppColors.labelGray,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            notif.body,
                                            style: const TextStyle(
                                              color: AppColors.labelGray,
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
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SvgPicture.asset(
            'assets/images/Notification.svg',
            colorFilter:
                const ColorFilter.mode(AppColors.primaryBlue, BlendMode.srcIn),
            width: 48,
            height: 48,
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
            style: TextStyle(
                color: AppColors.labelGray, fontSize: 14, height: 1.6),
          ),
        ],
      ),
    );
  }

  void _showManualInsert(
      BuildContext context, FinanceProvider provider, AppNotification notif) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ManualTransactionSheet(
        notification: notif,
        provider: provider,
      ),
    );
  }

  Future<void> _informDeveloper(BuildContext context, String rawMessage) async {
    final String template =
        'I found a transaction message that was not automatically categorized. Sharing it here for feedback:\n\n```$rawMessage```';

    // 1. Copy to clipboard because Telegram often ignores pre-filled text for private users
    await Clipboard.setData(ClipboardData(text: template));

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Message copied! Please paste it in the chat.'),
          backgroundColor: Color(0xFF3EB489),
          duration: Duration(seconds: 2),
        ),
      );
    }

    // 2. Attempt to open Telegram
    final String encodedMsg = Uri.encodeComponent(template);
    // tg://msg?text= format is more likely to work with the app if installed
    final Uri tgUrl = Uri.parse('tg://msg?text=$encodedMsg');
    final Uri webUrl = Uri.parse('https://t.me/Shibre_Plus');

    try {
      if (await canLaunchUrl(tgUrl)) {
        await launchUrl(tgUrl);
      } else {
        await launchUrl(webUrl, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      await launchUrl(webUrl, mode: LaunchMode.externalApplication);
    }
  }

  void _showLongPressModal(
      BuildContext context, FinanceProvider provider, AppNotification notif) {
    final isSystem =
        notif.sender.startsWith('Loan') || notif.sender.startsWith('System');

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 16),
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Text(
              'Message Options',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            if (!isSystem) ...[
              _buildModalItem(
                icon: Icons.add_circle_outline_rounded,
                label: 'Insert Transaction Manually',
                color: AppColors.primaryBlue,
                onTap: () {
                  Navigator.pop(ctx);
                  _showManualInsert(context, provider, notif);
                },
              ),
              _buildModalItem(
                icon: Icons.telegram_rounded,
                label: 'Inform Developer',
                color: AppColors.labelGray.withValues(alpha: 0.7),
                onTap: () {
                  Navigator.pop(ctx);
                  _informDeveloper(context, notif.body);
                },
              ),
            ],
            _buildModalItem(
              icon: Icons.delete_rounded,
              label: 'Delete Message',
              color: AppColors.alertRed,
              onTap: () {
                Navigator.pop(ctx);
                provider.deleteNotification(notif.id);
              },
            ),
            _buildModalItem(
              icon: Icons.block_rounded,
              label: 'Ignore Permanently',
              color: AppColors.labelGray,
              onTap: () {
                Navigator.pop(ctx);
                provider.ignoreNotification(notif.id);
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildModalItem({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
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
          style: TextStyle(color: AppColors.labelGray),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.labelGray)),
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

  Widget _buildSlidableAction({
    required Function(BuildContext) onPressed,
    required IconData icon,
    required String label,
    required Color color,
    bool isFirst = false,
    bool isLast = false,
  }) {
    return CustomSlidableAction(
      onPressed: onPressed,
      backgroundColor: Colors.transparent,
      padding: EdgeInsets.zero,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          color: const Color(
              0xFF2A2D36), // Visibly elevated grey-blue that matches premium dark themes
          borderRadius: BorderRadius.horizontal(
            left: Radius.circular(isFirst ? 16 : 0),
            right: Radius.circular(isLast ? 16 : 0),
          ),
          border: isLast
              ? null
              : Border(
                  right: BorderSide(
                    color: Colors.white.withValues(alpha: 0.05),
                    width: 1,
                  ),
                ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8), // More compact padding
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: color.withValues(alpha: 0.9),
                size: 22, // Standard cleaner size
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label, // Standard capitalization
              style: TextStyle(
                color: color.withValues(alpha: 0.85),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
