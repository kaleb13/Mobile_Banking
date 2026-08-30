import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Service for managing background scheduled financial summary reports
/// (Daily Spending Summary, Weekly Financial Report, Monthly Spending Analysis)
/// through native Android AlarmManager.
class ReportNotificationService {
  static const MethodChannel _channel = MethodChannel('com.shibre/reports');

  static final ReportNotificationService instance = ReportNotificationService._();
  ReportNotificationService._();

  /// Synchronizes scheduled background alarms according to current settings.
  Future<bool> syncSchedules() async {
    try {
      final result = await _channel.invokeMethod<bool>('scheduleReports');
      debugPrint('[ReportNotificationService] syncSchedules success: $result');
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('[ReportNotificationService] syncSchedules error: ${e.message}');
      return false;
    } catch (e) {
      debugPrint('[ReportNotificationService] syncSchedules unexpected error: $e');
      return false;
    }
  }

  /// Cancels all scheduled background report alarms.
  Future<bool> cancelSchedules() async {
    try {
      final result = await _channel.invokeMethod<bool>('cancelReports');
      debugPrint('[ReportNotificationService] cancelSchedules success: $result');
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('[ReportNotificationService] cancelSchedules error: ${e.message}');
      return false;
    } catch (e) {
      debugPrint('[ReportNotificationService] cancelSchedules unexpected error: $e');
      return false;
    }
  }

  /// Dispatches an immediate test push notification for a specific report type
  /// ('daily', 'weekly', or 'monthly') with the exact live total balance.
  Future<bool> sendTestReport(
    String reportType, {
    double? totalBalance,
    String? currency,
  }) async {
    try {
      final result = await _channel.invokeMethod<bool>('sendTestReport', {
        'type': reportType,
        if (totalBalance != null) 'totalBalance': totalBalance,
        if (currency != null) 'currency': currency,
      });
      debugPrint('[ReportNotificationService] sendTestReport ($reportType) result: $result');
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('[ReportNotificationService] sendTestReport error: ${e.message}');
      return false;
    } catch (e) {
      debugPrint('[ReportNotificationService] sendTestReport unexpected error: $e');
      return false;
    }
  }
}
