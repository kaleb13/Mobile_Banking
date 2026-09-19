import 'package:flutter/services.dart';

/// Minimalist Android status bar notification client for cloud synchronization.
///
/// Communicates with native Kotlin NotificationManager via MethodChannel to display
/// an ongoing, non-intrusive progress notification while synchronizing with the cloud.
/// Prevents Android OS from killing background data sync when the screen turns off.
class SyncNotificationService {
  SyncNotificationService._();

  static const MethodChannel _channel =
      MethodChannel('com.shibre/sync_notification');

  /// Displays or updates the persistent status bar notification.
  static Future<void> show({
    required String title,
    required String message,
    int progress = 0,
    int max = 0,
    bool isIndeterminate = true,
  }) async {
    try {
      await _channel.invokeMethod('showSyncNotification', {
        'title': title,
        'message': message,
        'progress': progress,
        'max': max,
        'isIndeterminate': isIndeterminate,
      });
    } catch (_) {}
  }

  /// Dismisses the persistent status bar sync notification.
  static Future<void> dismiss() async {
    try {
      await _channel.invokeMethod('dismissSyncNotification');
    } catch (_) {}
  }
}
