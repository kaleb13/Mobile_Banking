import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/app_notification.dart';
import '../../models/transaction.dart';
import '../../models/reason.dart';
import '../../data/repositories/notification_repository.dart';
import '../../services/sms_service.dart';
import '../../services/bank_senders.dart';

class NotificationsViewModel extends ChangeNotifier {
  static final RegExp _whitespaceRegex = RegExp(r'\s+');

  final NotificationRepository _repository;

  NotificationsViewModel({required NotificationRepository repository})
      : _repository = repository;

  List<AppNotification> _notifications = [];
  UnmodifiableListView<AppNotification> get notifications =>
      UnmodifiableListView(_notifications);

  int _unreadCount = 0;
  int get unreadCount => _unreadCount;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _hasPermission = false;
  bool get hasPermission => _hasPermission;

  // ── Notification Panel Open State & Back Navigation ───────────────────────
  bool _isPanelOpen = false;
  bool get isPanelOpen => _isPanelOpen;
  VoidCallback? _closePanelCallback;
  bool Function()? handleBackPress;

  void setPanelOpen(bool open, {VoidCallback? onClose}) {
    if (_isPanelOpen == open && onClose == _closePanelCallback) return;
    _isPanelOpen = open;
    if (open && onClose != null) {
      _closePanelCallback = onClose;
    } else if (!open) {
      _closePanelCallback = null;
    }
    notifyListeners();
  }

  bool closePanel() {
    if (_isPanelOpen && _closePanelCallback != null) {
      final callback = _closePanelCallback;
      _closePanelCallback = null;
      _isPanelOpen = false;
      notifyListeners();
      callback!();
      return true;
    }
    return false;
  }

  // ── Cross-VM callbacks (wired by main.dart ProxyProvider) ────────────────
  List<AppTransaction> Function()? getTransactions;
  List<AppReason> Function()? getReasons;
  Future<void> Function(String txId, String reason, int? reasonId)?
      updateTransactionReason;

  Future<bool> requestPermission() async {
    _hasPermission = await SmsService().requestPermission();
    notifyListeners();
    return _hasPermission;
  }

  Future<void> loadNotifications({bool silent = false}) async {
    if (!silent) {
      _isLoading = true;
      notifyListeners();
    }

    try {
      final prevPermission = _hasPermission;
      final prevUnread = _unreadCount;
      final prevCount = _notifications.length;

      // Check current SMS permission status so the pill shows correctly
      _hasPermission = await Permission.sms.status.isGranted;
      final all = await _repository.getNotifications();

      // Automatically purge any stale legacy notifications matching updated ignore rules
      final stale =
          all.where((n) => BankSenders.isIgnoredMessage(n.body)).toList();
      if (stale.isNotEmpty) {
        for (final s in stale) {
          await _repository.deleteNotification(s.id);
        }
        all.removeWhere((n) => BankSenders.isIgnoredMessage(n.body));
      }

      // ── Reconciliation: prune notifications already parsed as transactions ──
      final transactions = getTransactions?.call();
      if (transactions != null && transactions.isNotEmpty && all.isNotEmpty) {
        final reasons = getReasons?.call() ?? [];
        final reasonMap = <String, AppReason>{};
        for (final r in reasons) {
          reasonMap[r.name.toLowerCase().trim()] = r;
        }

        // Index the small set of notifications (typically 0-10 items) in O(K)
        final notifByNormBody = <String, AppNotification>{};
        for (final n in all) {
          final norm = n.body.replaceAll(_whitespaceRegex, ' ').trim();
          if (norm.isNotEmpty) {
            notifByNormBody[norm] = n;
          }
        }

        final List<String> idsToDelete = [];

        // Pruning checks only need to inspect recent transactions (latest 100)
        final candidateTxs = transactions.length > 100
            ? transactions.sublist(0, 100)
            : transactions;

        for (final t in candidateTxs) {
          final norm = t.rawMessage.replaceAll(_whitespaceRegex, ' ').trim();
          final matchedNotif = notifByNormBody[norm];
          if (matchedNotif != null) {
            // Transfer pending reason from notification → transaction
            if (matchedNotif.reason != null &&
                matchedNotif.reason!.isNotEmpty &&
                (t.reason == null ||
                    t.reason!.isEmpty ||
                    t.reason!.toLowerCase() == 'uncategorized') &&
                updateTransactionReason != null &&
                t.id != null) {
              final matchedReason =
                  reasonMap[matchedNotif.reason!.toLowerCase().trim()];
              await updateTransactionReason!(
                t.id!,
                matchedReason?.name ?? matchedNotif.reason!,
                matchedReason?.id,
              );
            }
            idsToDelete.add(matchedNotif.id);
          }
        }

        // Delete reconciled notifications from DB and in-memory list
        if (idsToDelete.isNotEmpty) {
          final deleteSet = idsToDelete.toSet();
          for (final id in idsToDelete) {
            _repository.deleteNotification(id);
          }
          all.removeWhere((n) => deleteSet.contains(n.id));
        }
      }

      _notifications = all;
      _unreadCount = all.where((n) => !n.isRead).length;

      final bool hasChanged = !silent ||
          _hasPermission != prevPermission ||
          _unreadCount != prevUnread ||
          _notifications.length != prevCount;

      if (!silent) {
        _isLoading = false;
      }
      if (hasChanged) {
        notifyListeners();
      }
    } catch (_) {
      if (!silent) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> markAllAsRead() async {
    await _repository.markAllAsRead();
    _unreadCount = 0;
    _notifications = _notifications.map((n) => n.copyWith(isRead: true)).toList();
    notifyListeners();
  }

  Future<void> deleteNotification(String id) async {
    _notifications.removeWhere((n) => n.id == id);
    _unreadCount = _notifications.where((n) => !n.isRead).length;
    notifyListeners();
    await _repository.deleteNotification(id);
  }

  Future<void> clearAllNotifications() async {
    _notifications.clear();
    _unreadCount = 0;
    notifyListeners();
    await _repository.deleteAllNotifications();
  }

  Future<void> ignoreNotification(String id) async {
    final notif = _notifications.where((n) => n.id == id).firstOrNull;
    _notifications.removeWhere((n) => n.id == id);
    _unreadCount = _notifications.where((n) => !n.isRead).length;
    notifyListeners();
    await _repository.ignoreNotification(id, body: notif?.body);
  }

  Future<void> ignoreAllNotifications() async {
    if (_notifications.isEmpty) return;
    final toIgnore = List<AppNotification>.from(_notifications);
    _notifications.clear();
    _unreadCount = 0;
    notifyListeners();
    await _repository.ignoreAllNotifications(toIgnore);
  }

  /// Remove notifications matching a predicate from memory and DB
  Future<void> removeNotificationsWhere(bool Function(AppNotification) test) async {
    final toRemove = _notifications.where(test).toList();
    if (toRemove.isEmpty) return;
    for (final n in toRemove) {
      _notifications.removeWhere((item) => item.id == n.id);
      await _repository.deleteNotification(n.id);
    }
    _unreadCount = _notifications.where((n) => !n.isRead).length;
    notifyListeners();
  }

  /// Opens Telegram chat directly with developer @zkaleb.
  Future<bool> openTelegramDeveloper({String username = 'zkaleb'}) async {
    try {
      await Clipboard.setData(ClipboardData(text: '@$username'));
    } catch (_) {}

    final tgAppUri = Uri.parse('tg://resolve?domain=$username');
    try {
      if (await canLaunchUrl(tgAppUri)) {
        return await launchUrl(
          tgAppUri,
          mode: LaunchMode.externalNonBrowserApplication,
        );
      }
    } catch (_) {}

    final tgWebUri = Uri.parse('https://t.me/$username');
    try {
      return await launchUrl(
        tgWebUri,
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {}

    return false;
  }

  /// Exports unread notification messages to a JSON file and presents the native
  /// share sheet (attaching the file) and opens Telegram for @zkaleb.
  Future<String?> exportUnreadSmsAndOpenTelegram({String? bankFilter}) async {
    final listToExport = (bankFilter == null || bankFilter == 'All')
        ? _notifications
        : _notifications.where((n) {
            final filterLower = bankFilter.toLowerCase();
            return n.displaySender.toLowerCase() == filterLower ||
                n.sender.toLowerCase().contains(filterLower);
          }).toList();

    if (listToExport.isEmpty) return null;

    final dateStr = DateFormat('yyyy-MM-dd_HH-mm').format(DateTime.now());
    final exportData = {
      'app': 'Shibre',
      'exportType': 'unrecognized_sms',
      'developerContact': '@zkaleb',
      'exportedAt': DateTime.now().toIso8601String(),
      'bankFilter': bankFilter ?? 'All',
      'count': listToExport.length,
      'messages': listToExport
          .map((n) => {
                'id': n.id,
                'sender': n.sender,
                'displaySender': n.displaySender,
                'body': n.body,
                'date': n.date.toIso8601String(),
              })
          .toList(),
    };

    final jsonStr = const JsonEncoder.withIndent('  ').convert(exportData);
    final fileName = 'shibre_unrecognized_sms_$dateStr.json';

    String? savedPath;
    try {
      final cacheDir = await getTemporaryDirectory();
      final file = File('${cacheDir.path}/$fileName');
      await file.writeAsString(jsonStr, encoding: utf8);
      savedPath = file.path;
    } catch (_) {
      try {
        final docDir = await getApplicationDocumentsDirectory();
        final file = File('${docDir.path}/$fileName');
        await file.writeAsString(jsonStr, encoding: utf8);
        savedPath = file.path;
      } catch (_) {}
    }

    if (savedPath != null) {
      try {
        // Automatically copy developer username so user can easily paste it in Telegram search
        await Clipboard.setData(const ClipboardData(text: '@zkaleb'));
      } catch (_) {}

      try {
        // Trigger native share sheet with file attached so user can choose Telegram / @zkaleb
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(savedPath)],
            text: 'Unrecognized SMS report for Shibre developer (@zkaleb)',
            subject: 'Shibre Unrecognized SMS Report',
          ),
        );
      } catch (_) {}
    }

    // Direct Telegram link
    await openTelegramDeveloper(username: 'zkaleb');

    return savedPath;
  }

  Future<void> addUnrecognizedNotification({
    required String sender,
    required String body,
    required DateTime date,
  }) async {
    final notification = AppNotification(
      id: '${sender}_${date.millisecondsSinceEpoch}',
      sender: sender,
      body: body,
      date: date,
    );
    await _repository.insertNotification(notification);
    _notifications.insert(0, notification);
    _unreadCount++;
    notifyListeners();
  }
}

