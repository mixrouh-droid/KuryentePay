import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

typedef NotificationTapHandler = void Function(
  Map<String, dynamic>? payload,
);

class LocalNotificationsService {
  LocalNotificationsService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static NotificationTapHandler? _tapHandler;

  static const AndroidNotificationChannel _channel =
      AndroidNotificationChannel(
    'ileco_pay_channel',
    'KuryentePay Notifications',
    description:
        'Electric bill reminders, account alerts, and payment status updates.',
    importance: Importance.high,
  );

  static Future<void> init({
    NotificationTapHandler? onNotificationTap,
  }) async {
    _tapHandler = onNotificationTap;

    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Manila'));

    const AndroidInitializationSettings androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initSettings =
        InitializationSettings(
      android: androidInit,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse:
          _handleNotificationResponse,
    );

    final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.createNotificationChannel(_channel);
    // main.dart asks permission through FirebaseMessaging on the UI isolate.
    // Background FCM initialization must not request Android UI permission.
  }

  static void setTapHandler(
    NotificationTapHandler? handler,
  ) {
    _tapHandler = handler;
  }

  static Future<bool> areNotificationsEnabled() async {
    final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    return await androidPlugin?.areNotificationsEnabled() ?? false;
  }

  static NotificationDetails _details({
    bool silent = false,
  }) {
    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      _channel.id,
      _channel.name,
      channelDescription: _channel.description,
      importance: Importance.high,
      priority: Priority.high,
      playSound: !silent,
      enableVibration: !silent,
      category: AndroidNotificationCategory.status,
      visibility: NotificationVisibility.public,
    );

    return NotificationDetails(
      android: androidDetails,
    );
  }

  static String? _encodePayload(
    Map<String, dynamic>? payload,
  ) {
    if (payload == null || payload.isEmpty) return null;
    return jsonEncode(payload);
  }

  static Map<String, dynamic>? _decodePayload(
    String? payload,
  ) {
    if (payload == null || payload.trim().isEmpty) {
      return null;
    }

    try {
      final dynamic decoded = jsonDecode(payload);

      if (decoded is Map<String, dynamic>) {
        return decoded;
      }

      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {
      return <String, dynamic>{
        'raw_payload': payload,
      };
    }

    return null;
  }

  static void _handleNotificationResponse(
    NotificationResponse response,
  ) {
    final Map<String, dynamic>? payload =
        _decodePayload(response.payload);

    _tapHandler?.call(payload);
  }

  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    Map<String, dynamic>? payload,
    bool silent = false,
  }) async {
    await _plugin.show(
      id,
      title,
      body,
      _details(silent: silent),
      payload: _encodePayload(payload),
    );
  }

  static Future<void> showBillCreated({
    required int notificationId,
    required int billId,
    required String billingMonth,
    required double amount,
  }) {
    return showNotification(
      id: notificationId,
      title: 'New electricity bill',
      body:
          'Your $billingMonth bill worth ₱${amount.toStringAsFixed(2)} is now available.',
      payload: <String, dynamic>{
        'type': 'BILL_CREATED',
        'bill_id': billId,
      },
    );
  }

  static Future<void> showDueSoon({
    required int notificationId,
    required int billId,
    required String dueDateLabel,
  }) {
    return showNotification(
      id: notificationId,
      title: 'Bill due soon',
      body:
          'Your electricity bill is due on $dueDateLabel. Pay on time to keep your account updated.',
      payload: <String, dynamic>{
        'type': 'DUE_SOON',
        'bill_id': billId,
      },
    );
  }

  static Future<void> showOverdue({
    required int notificationId,
    required int billId,
  }) {
    return showNotification(
      id: notificationId,
      title: 'Bill overdue',
      body:
          'Your electricity bill is past its due date. Please review your account balance.',
      payload: <String, dynamic>{
        'type': 'OVERDUE',
        'bill_id': billId,
      },
    );
  }

  static Future<void> showPaymentSuccess({
    required int notificationId,
    required int paymentId,
    required int billId,
    required double amount,
  }) {
    return showNotification(
      id: notificationId,
      title: 'Payment received',
      body:
          'Your payment of ₱${amount.toStringAsFixed(2)} was recorded successfully.',
      payload: <String, dynamic>{
        'type': 'PAYMENT_SUCCESS',
        'payment_id': paymentId,
        'bill_id': billId,
      },
    );
  }

  static Future<void> showPaymentPending({
    required int notificationId,
    required int paymentId,
    required int billId,
  }) {
    return showNotification(
      id: notificationId,
      title: 'Payment under review',
      body:
          'Your payment is still being processed. We will update you once it is confirmed.',
      payload: <String, dynamic>{
        'type': 'PAYMENT_PENDING',
        'payment_id': paymentId,
        'bill_id': billId,
      },
    );
  }

  static Future<void> showPaymentFailed({
    required int notificationId,
    required int paymentId,
    required int billId,
  }) {
    return showNotification(
      id: notificationId,
      title: 'Payment not completed',
      body:
          'Your payment was not completed. Please review the transaction and try again.',
      payload: <String, dynamic>{
        'type': 'PAYMENT_FAILED',
        'payment_id': paymentId,
        'bill_id': billId,
      },
    );
  }

  static Future<void> showSystemNotice({
    required int notificationId,
    required String title,
    required String message,
    int? announcementId,
  }) {
    return showNotification(
      id: notificationId,
      title: title,
      body: message,
      payload: <String, dynamic>{
        'type': 'SYSTEM',
        if (announcementId != null)
          'announcement_id': announcementId,
      },
    );
  }

  static Future<void> scheduleBillReminder({
    required int notificationId,
    required int billId,
    required tz.TZDateTime scheduledTime,
    required String title,
    required String body,
  }) async {
    if (!scheduledTime.isAfter(tz.TZDateTime.now(tz.local))) {
      return;
    }

    await _plugin.zonedSchedule(
      notificationId,
      title,
      body,
      scheduledTime,
      _details(),
      payload: _encodePayload(
        <String, dynamic>{
          'type': 'DUE_SOON',
          'bill_id': billId,
        },
      ),
      androidScheduleMode:
          AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  static Future<void> cancelNotification(
    int notificationId,
  ) async {
    await _plugin.cancel(notificationId);
  }

  static Future<void> cancelAllNotifications() async {
    await _plugin.cancelAll();
  }

  static Future<void> showTestNotification() async {
    await showNotification(
      id: 1,
      title: 'KuryentePay',
      body: 'Local notifications are working.',
      payload: const <String, dynamic>{
        'type': 'TEST',
      },
    );
  }

  static Future<void> scheduleDueSoonIn1Minute() async {
    final tz.TZDateTime scheduledTime =
        tz.TZDateTime.now(tz.local).add(
      const Duration(minutes: 1),
    );

    await scheduleBillReminder(
      notificationId: 2,
      billId: 0,
      scheduledTime: scheduledTime,
      title: 'KuryentePay Reminder',
      body:
          'Your bill is due soon. Please review your account.',
    );
  }
}
