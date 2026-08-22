import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/app_notification.dart';
import '../../services/database_service.dart';

abstract class NotificationRepository {
  Future<List<AppNotification>> getNotifications();
  Future<void> insertNotification(AppNotification notification);
  Future<void> insertNotificationsBatch(List<AppNotification> notifications);
  Future<void> deleteNotification(String id);
  Future<void> deleteAllNotifications();
  Future<void> markAllAsRead();
  Future<int> getUnreadCount();
  Future<void> ignoreNotification(String id, {String? body});
  Future<void> ignoreAllNotifications(List<AppNotification> notifications);
  Future<List<String>> getIgnoredHashes();
}

class NotificationRepositoryImpl implements NotificationRepository {
  final DatabaseService _dbService;

  NotificationRepositoryImpl({DatabaseService? dbService})
      : _dbService = dbService ?? DatabaseService.instance;

  @override
  Future<List<AppNotification>> getNotifications() => _dbService.getNotifications();

  @override
  Future<void> insertNotification(AppNotification notification) =>
      _dbService.insertNotification(notification);

  @override
  Future<void> insertNotificationsBatch(List<AppNotification> notifications) =>
      _dbService.insertNotificationsBatch(notifications);

  @override
  Future<void> deleteNotification(String id) async {
    await _dbService.deleteNotification(id);
    try {
      const MethodChannel('com.shibre/quick_edit')
          .invokeMethod('cancelPhoneNotification', {'id': id});
    } catch (_) {}
  }

  @override
  Future<void> deleteAllNotifications() => _dbService.deleteAllNotifications();

  @override
  Future<void> markAllAsRead() => _dbService.markAllNotificationsRead();

  @override
  Future<int> getUnreadCount() => _dbService.getUnreadNotificationCount();

  @override
  Future<void> ignoreNotification(String id, {String? body}) async {
    await deleteNotification(id);
    final prefs = await SharedPreferences.getInstance();
    final ignored = prefs.getStringList('ignored_notification_ids') ?? [];
    if (!ignored.contains(id)) {
      ignored.add(id);
    }
    if (body != null && body.trim().isNotEmpty) {
      final bodyNormalised = body.replaceAll(RegExp(r'\s+'), ' ').trim();
      final bodyHash = sha256.convert(utf8.encode(bodyNormalised)).toString();
      if (!ignored.contains(bodyHash)) {
        ignored.add(bodyHash);
      }
    }
    await prefs.setStringList('ignored_notification_ids', ignored);
  }

  @override
  Future<void> ignoreAllNotifications(List<AppNotification> notifications) async {
    if (notifications.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final ignored = prefs.getStringList('ignored_notification_ids') ?? [];

    for (final n in notifications) {
      if (!ignored.contains(n.id)) {
        ignored.add(n.id);
      }
      if (n.body.trim().isNotEmpty) {
        final bodyNormalised = n.body.replaceAll(RegExp(r'\s+'), ' ').trim();
        final bodyHash = sha256.convert(utf8.encode(bodyNormalised)).toString();
        if (!ignored.contains(bodyHash)) {
          ignored.add(bodyHash);
        }
      }
      await _dbService.deleteNotification(n.id);
      try {
        const MethodChannel('com.shibre/quick_edit')
            .invokeMethod('cancelPhoneNotification', {'id': n.id});
      } catch (_) {}
    }

    await prefs.setStringList('ignored_notification_ids', ignored);
  }

  @override
  Future<List<String>> getIgnoredHashes() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('ignored_notification_ids') ?? [];
  }
}
