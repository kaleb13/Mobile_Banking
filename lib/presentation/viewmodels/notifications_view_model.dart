import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
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

  Future<void> loadNotifications() async {
    _isLoading = true;
    notifyListeners();

    try {
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
      if (transactions != null && transactions.isNotEmpty) {
        final reasons = getReasons?.call() ?? [];
        final List<String> idsToDelete = [];

        for (final n in all) {
          final bodyNorm = n.body.replaceAll(RegExp(r'\s+'), ' ').trim();

          // Check if this notification's body matches any existing transaction
          final matchedTx = transactions.cast<AppTransaction?>().firstWhere(
            (t) =>
                t!.rawMessage.replaceAll(RegExp(r'\s+'), ' ').trim() ==
                bodyNorm,
            orElse: () => null,
          );

          if (matchedTx != null) {
            // Transfer pending reason from notification → transaction
            if (n.reason != null &&
                n.reason!.isNotEmpty &&
                (matchedTx.reason == null ||
                    matchedTx.reason!.isEmpty ||
                    matchedTx.reason!.toLowerCase() == 'uncategorized') &&
                updateTransactionReason != null &&
                matchedTx.id != null) {
              final matchedReason = reasons.cast<AppReason?>().firstWhere(
                (r) =>
                    r!.name.toLowerCase().trim() ==
                    n.reason!.toLowerCase().trim(),
                orElse: () => null,
              );
              await updateTransactionReason!(
                matchedTx.id!,
                matchedReason?.name ?? n.reason!,
                matchedReason?.id,
              );
            }
            idsToDelete.add(n.id);
          }
        }

        // Delete reconciled notifications from DB and in-memory list
        for (final id in idsToDelete) {
          _repository.deleteNotification(id);
        }
        all.removeWhere((n) => idsToDelete.contains(n.id));
      }

      _notifications = all;
      _unreadCount = all.where((n) => !n.isRead).length;
    } catch (_) {
    } finally {
      _isLoading = false;
      notifyListeners();
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

    // Direct Telegram link fallback
    final Uri tgUrl = Uri.parse('https://t.me/zkaleb');
    try {
      await launchUrl(tgUrl, mode: LaunchMode.externalApplication);
    } catch (_) {}

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

