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
import '../../data/repositories/notification_repository.dart';
import '../../services/sms_service.dart';

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
      _notifications = all;
      _unreadCount = await _repository.getUnreadCount();
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
        await Share.shareXFiles(
          [XFile(savedPath)],
          text: 'Unrecognized SMS report for Shibre developer (@zkaleb)',
          subject: 'Shibre Unrecognized SMS Report',
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

