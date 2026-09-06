import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_banking_app/data/repositories/notification_repository.dart';
import 'package:mobile_banking_app/models/app_notification.dart';
import 'package:mobile_banking_app/presentation/viewmodels/notifications_view_model.dart';

class MockNotificationRepo implements NotificationRepository {
  List<AppNotification> notifications = [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<List<AppNotification>> getNotifications() async => notifications;
  @override
  Future<void> insertNotification(AppNotification notification) async =>
      notifications.add(notification);
  @override
  Future<void> deleteNotification(String id) async =>
      notifications.removeWhere((n) => n.id == id);
  @override
  Future<void> deleteAllNotifications() async => notifications.clear();
  @override
  Future<void> markAllAsRead() async {}
}

void main() {
  group('Notifications Panel Back Navigation Tests', () {
    late NotificationsViewModel notifsVM;
    late MockNotificationRepo repo;

    setUp(() {
      repo = MockNotificationRepo();
      notifsVM = NotificationsViewModel(repository: repo);
    });

    test('panel open and close callbacks work correctly', () {
      bool closeCallbackCalled = false;

      expect(notifsVM.isPanelOpen, isFalse);

      notifsVM.setPanelOpen(true, onClose: () {
        closeCallbackCalled = true;
      });

      expect(notifsVM.isPanelOpen, isTrue);

      final closed = notifsVM.closePanel();
      expect(closed, isTrue);
      expect(closeCallbackCalled, isTrue);
      expect(notifsVM.isPanelOpen, isFalse);
    });

    test('handleBackPress handles sub-view dismissal before closing panel', () {
      bool closeCalled = false;
      bool subViewOpen = true;

      notifsVM.setPanelOpen(true, onClose: () {
        closeCalled = true;
      });

      notifsVM.handleBackPress = () {
        if (subViewOpen) {
          subViewOpen = false;
          return true; // handled sub-view
        }
        notifsVM.closePanel();
        return true;
      };

      // First back press: dismisses sub-view
      final firstBackHandled = notifsVM.handleBackPress?.call();
      expect(firstBackHandled, isTrue);
      expect(subViewOpen, isFalse);
      expect(closeCalled, isFalse);
      expect(notifsVM.isPanelOpen, isTrue);

      // Second back press: closes notification panel
      final secondBackHandled = notifsVM.handleBackPress?.call();
      expect(secondBackHandled, isTrue);
      expect(closeCalled, isTrue);
      expect(notifsVM.isPanelOpen, isFalse);
    });
  });
}
