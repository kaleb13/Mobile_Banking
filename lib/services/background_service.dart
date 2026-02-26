import 'dart:async';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:telephony/telephony.dart';
import '../models/transaction.dart';
import '../models/sender.dart';
import '../models/app_notification.dart';
import 'database_service.dart';
import 'telebirr_parser.dart';
import 'cbe_parser.dart';
import 'cbe_birr_parser.dart';

Future<void> initializeBackgroundService() async {
  final service = FlutterBackgroundService();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'my_foreground',
    'Mobile Banking Service',
    description: 'Running in background to monitor SMS.',
    importance: Importance.low,
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: true,
      isForegroundMode: true,
      notificationChannelId: 'my_foreground',
      initialNotificationTitle: 'Shibre is Active',
      initialNotificationContent: 'Looking for transaction SMS',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(),
  );

  service.startService();
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });
    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
    service.on('stopService').listen((event) {
      service.stopSelf();
    });

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    // Periodically update the notification to keep it permanently pinned and "active"
    Timer.periodic(const Duration(seconds: 15), (timer) async {
      if (await service.isForegroundService()) {
        flutterLocalNotificationsPlugin.show(
          id: 888,
          title: 'Shibre is Active',
          body: 'Looking for transaction SMS',
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'my_foreground',
              'Mobile Banking Service',
              icon: 'launch_background',
              ongoing: true, // This is explicitly sticky (cannot be swiped)
              autoCancel: false,
              priority: Priority
                  .min, // Low/min priority usually puts it strictly in status bar without heads-up
              importance: Importance.low, // doesn't make sound
              playSound: false,
              enableVibration: false,
              showWhen: false, // Don't keep updating the timestamp constantly
            ),
          ),
        );
      }
    });
  }

  // Set up telephony SMS listening
  final Telephony telephony = Telephony.instance;
  telephony.listenIncomingSms(
    onNewMessage: (SmsMessage message) async {
      await processBackgroundSms(message);
    },
    onBackgroundMessage: backgroundMessageHandler,
    listenInBackground: true,
  );
}

@pragma('vm:entry-point')
Future<void> backgroundMessageHandler(SmsMessage message) async {
  DartPluginRegistrant.ensureInitialized();
  await processBackgroundSms(message);
}

Future<void> processBackgroundSms(SmsMessage message) async {
  if (message.address == null || message.body == null) return;
  final senderAddress = message.address!;
  final body = message.body!;
  final date = DateTime.fromMillisecondsSinceEpoch(
      message.date ?? DateTime.now().millisecondsSinceEpoch);

  AppTransaction? tx;

  if (senderAddress == TelebirrParser.senderNumber ||
      senderAddress.toLowerCase() == TelebirrParser.senderName.toLowerCase()) {
    tx = TelebirrParser.parse(body, date);
  } else if (senderAddress.toUpperCase() == CbeParser.senderName) {
    tx = CbeParser.parse(body, date);
  } else if (senderAddress.toUpperCase() ==
      CbeBirrParser.senderName.toUpperCase()) {
    tx = CbeBirrParser.parse(body, date);
  } else {
    // Custom Senders matching
    final senders = await DatabaseService.instance.getSenders();
    AppSender? matchedSender;
    try {
      matchedSender = senders.firstWhere(
          (s) => s.senderName.toLowerCase() == senderAddress.toLowerCase());
    } catch (e) {
      return;
    }

    final lowerMsg = body.toLowerCase();
    bool hasDeposit = matchedSender.depositKeywords
        .any((kw) => lowerMsg.contains(kw.toLowerCase()));
    bool hasExpense = matchedSender.expenseKeywords
        .any((kw) => lowerMsg.contains(kw.toLowerCase()));

    // Basic amount extract
    final amountMatch = RegExp(r'[0-9.,]+').firstMatch(body);
    double amount = 0;
    if (amountMatch != null) {
      amount = double.tryParse(amountMatch.group(0)!.replaceAll(',', '')) ?? 0;
    }

    if (hasDeposit && !hasExpense) {
      tx = AppTransaction(
        id: '${senderAddress}_${date.millisecondsSinceEpoch}',
        name: matchedSender.senderName,
        amount: amount,
        type: 'income',
        date: date,
        sender: senderAddress,
        category: 'Auto',
        rawMessage: body,
        isAutoDetected: true,
      );
    } else if (hasExpense && !hasDeposit) {
      tx = AppTransaction(
        id: '${senderAddress}_${date.millisecondsSinceEpoch}',
        name: matchedSender.senderName,
        amount: amount,
        type: 'expense',
        date: date,
        sender: senderAddress,
        category: 'Auto',
        rawMessage: body,
        isAutoDetected: true,
      );
    } else {
      // Unrecognized: save to in-app notifications instead of pending
      final notificationId = '${senderAddress}_${date.millisecondsSinceEpoch}';

      // We do not have easy access to SharedPreferences ignored_notification_ids
      // here to filter out ignored ones, but usually background unknown messages
      // are fine to log. For complete parity, we could check prefs, but inserting
      // directly is safer for background to ensure no missed data.
      final notification = AppNotification(
        id: notificationId,
        sender: senderAddress,
        body: body,
        date: date,
      );
      await DatabaseService.instance.insertNotification(notification);

      // Return early so we don't insert a null tx
      return;
    }
  }

  if (tx != null) {
    await DatabaseService.instance.insertTransaction(tx);

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();
    await flutterLocalNotificationsPlugin.show(
      id: DateTime.now().millisecond,
      title: 'New Transaction Detected',
      body: 'Saved a new ${tx.type} from ${tx.name} for ${tx.amount} Br.',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'my_foreground',
          'Mobile Banking Service',
          icon: 'launch_background',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }
}
