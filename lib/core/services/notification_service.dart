// NOTIFICATION API SERVICE: load and update consumer notifications
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'session_service.dart';

class AppNotification {
  const AppNotification({
    required this.id,
    required this.accountId,
    required this.notificationType,
    required this.title,
    required this.message,
    required this.priority,
    required this.visibleFrom,
    required this.isRead,
    required this.createdAt,
    this.billId,
    this.paymentId,
    this.expiresAt,
    this.readAt,
    this.actionRoute,
    this.payload = const <String, dynamic>{},
  });

  final int id;
  final int accountId;
  final int? billId;
  final int? paymentId;
  final String notificationType;
  final String title;
  final String message;
  final String priority;
  final DateTime? visibleFrom;
  final DateTime? expiresAt;
  final DateTime? readAt;
  final bool isRead;
  final String? actionRoute;
  final Map<String, dynamic> payload;
  final DateTime? createdAt;

  String get normalizedType =>
      notificationType.trim().toUpperCase();

  bool get isPaymentSuccess =>
      normalizedType == 'PAYMENT_SUCCESS';

  String? get paymentReference =>
      _payloadString('reference_no');

  String? get provider =>
      _payloadString('provider')?.toUpperCase();

  String? get paymentChannel =>
      _payloadString('payment_channel')?.toUpperCase();

  String? get paymentStatus =>
      _payloadString('payment_status')?.toUpperCase();

  String? get billPaymentStatus =>
      _payloadString('bill_payment_status')?.toUpperCase();

  String? get currency =>
      _payloadString('currency')?.toUpperCase();

  double? get paymentAmount =>
      _payloadDouble('amount');

  bool get isBackendConfirmedPayment =>
      isPaymentSuccess &&
          paymentStatus == 'SUCCESS' &&
          billPaymentStatus == 'PAID';

  String? _payloadString(String key) {
    final String value =
        payload[key]?.toString().trim() ?? '';

    return value.isEmpty ? null : value;
  }

  double? _payloadDouble(String key) {
    final dynamic value = payload[key];

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
      value?.toString().trim() ?? '',
    );
  }

  AppNotification copyWith({
    DateTime? readAt,
    bool? isRead,
  }) {
    return AppNotification(
      id: id,
      accountId: accountId,
      billId: billId,
      paymentId: paymentId,
      notificationType: notificationType,
      title: title,
      message: message,
      priority: priority,
      visibleFrom: visibleFrom,
      expiresAt: expiresAt,
      readAt: readAt ?? this.readAt,
      isRead: isRead ?? this.isRead,
      actionRoute: actionRoute,
      payload: payload,
      createdAt: createdAt,
    );
  }

  factory AppNotification.fromJson(
      Map<String, dynamic> json,
      ) {
    return AppNotification(
      id: _asInt(json['id']),
      accountId: _asInt(json['account_id']),
      billId: _asNullableInt(json['bill_id']),
      paymentId: _asNullableInt(json['payment_id']),
      notificationType:
      (json['notification_type'] ?? 'GENERAL')
          .toString()
          .trim()
          .toUpperCase(),
      title: (json['title'] ?? 'ILECO PAY').toString(),
      message: (json['message'] ?? '').toString(),
      priority: (json['priority'] ?? 'NORMAL').toString(),
      visibleFrom: _asDateTime(json['visible_from']),
      expiresAt: _asDateTime(json['expires_at']),
      readAt: _asDateTime(json['read_at']),
      isRead: _asBool(json['is_read']),
      actionRoute: _asNullableString(
        json['action_route'],
      ),
      payload: _asMap(
        json['payload'] ?? json['payload_json'],
      ),
      createdAt: _asDateTime(json['created_at']),
    );
  }

  static int _asInt(dynamic value) {
    if (value is int) {
      return value;
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static int? _asNullableInt(dynamic value) {
    if (value == null || value.toString().trim().isEmpty) {
      return null;
    }

    return int.tryParse(value.toString());
  }

  static DateTime? _asDateTime(dynamic value) {
    if (value == null || value.toString().trim().isEmpty) {
      return null;
    }

    return DateTime.tryParse(value.toString());
  }

  static bool _asBool(dynamic value) {
    if (value is bool) {
      return value;
    }

    final String normalised =
        value?.toString().trim().toLowerCase() ?? '';

    return normalised == '1' ||
        normalised == 'true' ||
        normalised == 'yes';
  }

  static String? _asNullableString(dynamic value) {
    final String text = value?.toString().trim() ?? '';

    return text.isEmpty ? null : text;
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return value.map(
            (dynamic key, dynamic item) =>
            MapEntry(key.toString(), item),
      );
    }

    if (value is String && value.trim().isNotEmpty) {
      try {
        final dynamic decoded = jsonDecode(value);

        if (decoded is Map<String, dynamic>) {
          return decoded;
        }

        if (decoded is Map) {
          return decoded.map(
                (dynamic key, dynamic item) =>
                MapEntry(key.toString(), item),
          );
        }
      } catch (_) {
        return <String, dynamic>{};
      }
    }

    return <String, dynamic>{};
  }
}

class NotificationPageResult {
  const NotificationPageResult({
    required this.notifications,
    required this.unreadCount,
    required this.page,
    required this.limit,
    required this.returned,
    required this.filteredTotal,
    required this.hasMore,
  });

  final List<AppNotification> notifications;
  final int unreadCount;
  final int page;
  final int limit;
  final int returned;
  final int filteredTotal;
  final bool hasMore;

  factory NotificationPageResult.fromJson(
      Map<String, dynamic> json,
      ) {
    final dynamic rawNotifications =
    json['notifications'];

    final List<AppNotification> notifications =
    rawNotifications is List
        ? rawNotifications
        .whereType<Map>()
        .map(
          (Map item) =>
          AppNotification.fromJson(
            item.map(
                  (dynamic key, dynamic value) =>
                  MapEntry(
                    key.toString(),
                    value,
                  ),
            ),
          ),
    )
        .toList()
        : <AppNotification>[];

    final Map<String, dynamic> pagination =
    _asMap(json['pagination']);

    return NotificationPageResult(
      notifications: notifications,
      unreadCount: _asInt(json['unread_count']),
      page: _asInt(pagination['page'], fallback: 1),
      limit: _asInt(pagination['limit'], fallback: 50),
      returned: _asInt(
        pagination['returned'],
        fallback: notifications.length,
      ),
      filteredTotal: _asInt(
        pagination['filtered_total'],
        fallback: notifications.length,
      ),
      hasMore: _asBool(pagination['has_more']),
    );
  }

  static int _asInt(
      dynamic value, {
        int fallback = 0,
      }) {
    if (value is int) {
      return value;
    }

    return int.tryParse(value?.toString() ?? '') ??
        fallback;
  }

  static bool _asBool(dynamic value) {
    if (value is bool) {
      return value;
    }

    final String normalised =
        value?.toString().trim().toLowerCase() ?? '';

    return normalised == '1' ||
        normalised == 'true' ||
        normalised == 'yes';
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return value.map(
            (dynamic key, dynamic item) =>
            MapEntry(key.toString(), item),
      );
    }

    return <String, dynamic>{};
  }
}

class NotificationUpdateResult {
  const NotificationUpdateResult({
    required this.success,
    required this.unreadCount,
    required this.message,
    this.updatedCount = 0,
    this.notificationId,
    this.readAt,
  });

  final bool success;
  final int unreadCount;
  final String message;
  final int updatedCount;
  final int? notificationId;
  final DateTime? readAt;

  factory NotificationUpdateResult.fromJson(
      Map<String, dynamic> json,
      ) {
    return NotificationUpdateResult(
      success: json['success'] == true,
      unreadCount:
      int.tryParse(
        json['unread_count']?.toString() ?? '',
      ) ??
          0,
      message: (json['message'] ?? '').toString(),
      updatedCount:
      int.tryParse(
        json['updated_count']?.toString() ?? '',
      ) ??
          0,
      notificationId:
      int.tryParse(
        json['notification_id']?.toString() ?? '',
      ),
      readAt: DateTime.tryParse(
        json['read_at']?.toString() ?? '',
      ),
    );
  }
}

class NotificationService {
  NotificationService._();

  static const Duration _timeout =
  Duration(seconds: 12);

  static Future<NotificationPageResult>
  fetchNotifications({
    int page = 1,
    int limit = 50,
    bool unreadOnly = false,
    String? accountNoOverride,
  }) async {
    final int safePage = page < 1 ? 1 : page;
    final int safeLimit =
    limit < 1 ? 1 : (limit > 100 ? 100 : limit);

    final String accountNo =
    await _requireAccountNumber(
      accountNoOverride,
    );

    final Uri endpoint =
    ApiConfig.buildUri('notifications.php').replace(
      queryParameters: <String, String>{
        'account_no': accountNo,
        'page': safePage.toString(),
        'limit': safeLimit.toString(),
        if (unreadOnly) 'unread_only': '1',
      },
    );

    final http.Response response = await http
        .get(
      endpoint,
      headers: const <String, String>{
        'Accept': 'application/json',
      },
    )
        .timeout(_timeout);

    final Map<String, dynamic> payload =
    _decodeResponse(response.body);

    _throwWhenFailed(
      response: response,
      payload: payload,
      fallbackMessage:
      'Unable to load notifications.',
    );

    return NotificationPageResult.fromJson(
      payload,
    );
  }

  static Future<int> fetchUnreadCount({
    String? accountNoOverride,
  }) async {
    final NotificationPageResult result =
    await fetchNotifications(
      page: 1,
      limit: 1,
      unreadOnly: false,
      accountNoOverride: accountNoOverride,
    );

    return result.unreadCount;
  }

  static Future<NotificationUpdateResult>
  markAsRead({
    required int notificationId,
    String? accountNoOverride,
  }) async {
    if (notificationId <= 0) {
      throw ArgumentError.value(
        notificationId,
        'notificationId',
        'A valid notification ID is required.',
      );
    }

    final String accountNo =
    await _requireAccountNumber(
      accountNoOverride,
    );

    return _postAction(
      <String, dynamic>{
        'action': 'mark_read',
        'account_no': accountNo,
        'notification_id': notificationId,
      },
    );
  }

  static Future<NotificationUpdateResult>
  markAllAsRead({
    String? accountNoOverride,
  }) async {
    final String accountNo =
    await _requireAccountNumber(
      accountNoOverride,
    );

    return _postAction(
      <String, dynamic>{
        'action': 'mark_all_read',
        'account_no': accountNo,
      },
    );
  }

  static Future<NotificationUpdateResult>
  _postAction(
      Map<String, dynamic> body,
      ) async {
    final Uri endpoint =
    ApiConfig.buildUri('notifications.php');

    final http.Response response = await http
        .post(
      endpoint,
      headers: const <String, String>{
        'Content-Type':
        'application/json; charset=UTF-8',
        'Accept': 'application/json',
      },
      body: jsonEncode(body),
    )
        .timeout(_timeout);

    final Map<String, dynamic> payload =
    _decodeResponse(response.body);

    _throwWhenFailed(
      response: response,
      payload: payload,
      fallbackMessage:
      'Unable to update the notification.',
    );

    return NotificationUpdateResult.fromJson(
      payload,
    );
  }

  static Future<String> _requireAccountNumber(
      String? accountNoOverride,
      ) async {
    final String raw =
        accountNoOverride ??
            await SessionService.loadAccountNumber() ??
            '';

    final String digits = raw.replaceAll(
      RegExp(r'[^0-9]'),
      '',
    );

    if (digits.isEmpty) {
      throw Exception(
        'No active consumer account was found. Please sign in again.',
      );
    }

    return digits;
  }

  static Map<String, dynamic> _decodeResponse(
      String body,
      ) {
    if (body.trim().isEmpty) {
      return <String, dynamic>{};
    }

    try {
      final dynamic decoded = jsonDecode(body);

      if (decoded is Map<String, dynamic>) {
        return decoded;
      }

      if (decoded is Map) {
        return decoded.map(
              (dynamic key, dynamic value) =>
              MapEntry(key.toString(), value),
        );
      }
    } catch (_) {
      throw Exception(
        'The notification server returned an invalid response.',
      );
    }

    return <String, dynamic>{};
  }

  static void _throwWhenFailed({
    required http.Response response,
    required Map<String, dynamic> payload,
    required String fallbackMessage,
  }) {
    final bool requestSuccessful =
        response.statusCode >= 200 &&
            response.statusCode < 300 &&
            payload['success'] == true;

    if (requestSuccessful) {
      return;
    }

    final dynamic rawErrors = payload['errors'];

    String? errorDetails;

    if (rawErrors is List && rawErrors.isNotEmpty) {
      errorDetails = rawErrors
          .map((dynamic item) => item.toString())
          .join(' ');
    }

    final String message =
    errorDetails?.trim().isNotEmpty == true
        ? errorDetails!
        : (payload['message'] ??
        fallbackMessage)
        .toString();

    throw Exception(message);
  }
}
