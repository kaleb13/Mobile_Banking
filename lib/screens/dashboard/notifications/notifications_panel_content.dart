import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/app_notification.dart';
import '../../../presentation/viewmodels/notifications_view_model.dart';
import '../../../widgets/app_back_button.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_toast.dart';
import '../manual_transaction_sheet.dart';
import 'notification_card.dart';
import 'notification_action_dialogs.dart';

class NotificationsPanelContent extends StatefulWidget {
  final VoidCallback onClose;

  const NotificationsPanelContent({
    super.key,
    required this.onClose,
  });

  @override
  State<NotificationsPanelContent> createState() =>
      _NotificationsPanelContentState();
}

class _NotificationsPanelContentState extends State<NotificationsPanelContent> {
  String _selectedBankFilter = 'All';
  bool _showBankFilters = false;
  bool _isShowingSendModal = false;
  AppNotification? _selectedNotificationForMenu;
  AppNotification? _selectedNotificationForManualInsert;
  bool _isConfirmingIgnoreAll = false;
  bool _isExporting = false;

  @override
  Widget build(BuildContext context) {
    final notifsVM = context.watch<NotificationsViewModel>();
    final allNotifications = notifsVM.notifications;

    // Extract unique unified bank senders present in current unread messages (127 -> Telebirr)
    final Set<String> banks = {'All'};
    for (final n in allNotifications) {
      if (n.displaySender.trim().isNotEmpty) {
        banks.add(n.displaySender.trim());
      }
    }
    final bankList = banks.toList();

    // Filter notifications by selected bank (Telebirr matches both 127 and Telebirr)
    final filteredNotifications = _selectedBankFilter == 'All'
        ? allNotifications
        : allNotifications
            .where((n) =>
                n.displaySender.toLowerCase() ==
                _selectedBankFilter.toLowerCase())
            .toList();

    return Stack(
      children: [
        Positioned.fill(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top Header Row (Title & Ignore All) ──
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                child: Row(
                  children: [
                    AppBackButton.dark(onPressed: widget.onClose),
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (allNotifications.isNotEmpty) ...[
                      AppButton.secondary(
                        text: 'Ignore All',
                        height: 32,
                        fullWidth: false,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        fontSize: 12,
                        onPressed: () {
                          setState(() => _isConfirmingIgnoreAll = true);
                        },
                      ),
                    ],
                  ],
                ),
              ),

              // ── Sub-Bar: Filter Icon Trigger & "Send to Developer" Action ──
              if (allNotifications.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Row(
                    children: [
                      // Filter icon button (3-line icon) toggles bank pills
                      AppButton.pill(
                        text: _selectedBankFilter == 'All'
                            ? 'Filter'
                            : _selectedBankFilter,
                        icon: Icons.filter_list_rounded,
                        isSelected:
                            _showBankFilters || _selectedBankFilter != 'All',
                        height: 32,
                        onPressed: () {
                          setState(() {
                            _showBankFilters = !_showBankFilters;
                          });
                        },
                      ),
                      const Spacer(),
                      // Clear descriptive Send to Developer Button
                      AppButton.secondary(
                        icon: Icons.telegram_rounded,
                        text: 'Send to Developer',
                        height: 32,
                        fullWidth: false,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        fontSize: 12,
                        iconSize: 16,
                        onPressed: () {
                          setState(() {
                            _isShowingSendModal = true;
                          });
                        },
                      ),
                    ],
                  ),
                ),

              // ── Expandable Bank Filter Chips (shown when 3-line filter is tapped) ──
              if (_showBankFilters &&
                  bankList.length > 1 &&
                  allNotifications.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SizedBox(
                    height: 34,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      scrollDirection: Axis.horizontal,
                      itemCount: bankList.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final bank = bankList[index];
                        final isSelected = _selectedBankFilter == bank;
                        return AppButton.pill(
                          text: bank,
                          isSelected: isSelected,
                          height: 32,
                          onPressed: () {
                            setState(() => _selectedBankFilter = bank);
                          },
                        );
                      },
                    ),
                  ),
                ),

              // ── Notification List ──
              Expanded(
                child: filteredNotifications.isEmpty
                    ? _buildEmpty()
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 6),
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        itemCount: filteredNotifications.length,
                        itemBuilder: (context, index) {
                          final notif = filteredNotifications[index];
                          return NotificationCard(
                            key: ValueKey(notif.id),
                            notification: notif,
                            onIgnore: () {
                              notifsVM.ignoreNotification(notif.id);
                            },
                            onLongPress: () {
                              setState(() {
                                _selectedNotificationForMenu = notif;
                              });
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),

        // ── "Send to Developer" Explanation Bottom Sheet Modal ──
        if (_isShowingSendModal)
          Positioned.fill(
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                GestureDetector(
                  onTap: () => setState(() => _isShowingSendModal = false),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 6.0, sigmaY: 6.0),
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.45),
                    ),
                  ),
                ),
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 16,
                  child: SendToDeveloperSheet(
                    count: filteredNotifications.length,
                    bankFilter: _selectedBankFilter,
                    isExporting: _isExporting,
                    onClose: () => setState(() => _isShowingSendModal = false),
                    onOpenDirectChat: () async {
                      await notifsVM.openTelegramDeveloper(username: 'zkaleb');
                      if (context.mounted) {
                        AppToast.info(
                          context,
                          message: 'Opening Telegram',
                          subtitle: 'Copied @zkaleb to clipboard',
                        );
                      }
                    },
                    onConfirmSend: () async {
                      setState(() => _isExporting = true);
                      final savedPath =
                          await notifsVM.exportUnreadSmsAndOpenTelegram(
                        bankFilter: _selectedBankFilter == 'All'
                            ? null
                            : _selectedBankFilter,
                      );
                      if (!context.mounted) return;
                      setState(() {
                        _isExporting = false;
                        _isShowingSendModal = false;
                      });
                      if (savedPath != null) {
                        AppToast.success(
                          context,
                          message: 'Report Ready',
                          subtitle: 'Copied @zkaleb • Select Telegram to send',
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ),

        // ── Contextual Glass Options Menu Sheet ──
        if (_selectedNotificationForMenu != null)
          Positioned.fill(
            child: Stack(
              children: [
                GestureDetector(
                  onTap: () =>
                      setState(() => _selectedNotificationForMenu = null),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 6.0, sigmaY: 6.0),
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.35),
                    ),
                  ),
                ),
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: NotificationOptionsSheet(
                    notification: _selectedNotificationForMenu!,
                    onClose: () =>
                        setState(() => _selectedNotificationForMenu = null),
                    onManualInsert: () {
                      final n = _selectedNotificationForMenu!;
                      setState(() {
                        _selectedNotificationForMenu = null;
                        _selectedNotificationForManualInsert = n;
                      });
                    },
                    onIgnore: () {
                      final id = _selectedNotificationForMenu!.id;
                      setState(() => _selectedNotificationForMenu = null);
                      notifsVM.ignoreNotification(id);
                    },
                  ),
                ),
              ],
            ),
          ),

        // ── Ignore All Confirmation Modal ──
        if (_isConfirmingIgnoreAll)
          NotificationConfirmationDialog(
            title: 'Ignore All Notifications?',
            description:
                'Are you sure you want to permanently ignore all unread messages? They will never reappear even if you refresh or rescan.',
            confirmLabel: 'Ignore All',
            isDestructive: false,
            onCancel: () => setState(() => _isConfirmingIgnoreAll = false),
            onConfirm: () async {
              setState(() => _isConfirmingIgnoreAll = false);
              await notifsVM.ignoreAllNotifications();
            },
          ),

        // ── Manual Transaction Sheet Overlay ──
        if (_selectedNotificationForManualInsert != null)
          Positioned.fill(
            child: Stack(
              children: [
                GestureDetector(
                  onTap: () => setState(
                      () => _selectedNotificationForManualInsert = null),
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.55),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  top: 0,
                  child: Material(
                    type: MaterialType.transparency,
                    child: ManualTransactionSheet(
                      notification: _selectedNotificationForManualInsert!,
                      onClose: () {
                        setState(() =>
                            _selectedNotificationForManualInsert = null);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildEmpty() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.only(top: 80, bottom: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.notifications_none_rounded,
                color: Colors.white30, size: 40),
            const SizedBox(height: 12),
            Text(
              _selectedBankFilter == 'All'
                  ? 'No Unread Notifications'
                  : 'No Notifications for $_selectedBankFilter',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _selectedBankFilter == 'All'
                  ? 'Unrecognized messages will appear here'
                  : 'Try selecting "All" to view all messages',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
