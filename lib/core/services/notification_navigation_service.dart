// NOTIFICATION NAVIGATION BRIDGE:
// keeps a pending push-notification destination until MainShell is ready
import 'package:flutter/foundation.dart';

class NotificationNavigationRequest {
  const NotificationNavigationRequest({
    required this.tabIndex,
    required this.payload,
    this.notificationId,
    this.billId,
    this.paymentId,
    this.notificationType,
    this.actionRoute,
  });

  final int tabIndex;
  final int? notificationId;
  final int? billId;
  final int? paymentId;
  final String? notificationType;
  final String? actionRoute;
  final Map<String, dynamic> payload;

  bool get hasBill => billId != null && billId! > 0;

  bool get hasPayment =>
      paymentId != null && paymentId! > 0;

  @override
  String toString() {
    return 'NotificationNavigationRequest('
        'tabIndex: $tabIndex, '
        'notificationId: $notificationId, '
        'billId: $billId, '
        'paymentId: $paymentId, '
        'notificationType: $notificationType, '
        'actionRoute: $actionRoute'
        ')';
  }
}

class NotificationNavigationService {
  NotificationNavigationService._();

  static const int alertsTabIndex = 2;

  static final ValueNotifier<
      NotificationNavigationRequest?>
  pendingRequest =
  ValueNotifier<NotificationNavigationRequest?>(null);

  static void openFromPayload(
      Map<String, dynamic>? payload,
      ) {
    final Map<String, dynamic> safePayload =
    payload == null
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(payload);

    final NotificationNavigationRequest request =
    NotificationNavigationRequest(
      tabIndex: alertsTabIndex,
      notificationId: _readPositiveInt(
        safePayload['notification_id'],
      ),
      billId: _readPositiveInt(
        safePayload['bill_id'],
      ),
      paymentId: _readPositiveInt(
        safePayload['payment_id'],
      ),
      notificationType: _readText(
        safePayload['notification_type'],
      ),
      actionRoute: _readText(
        safePayload['action_route'],
      ),
      payload: safePayload,
    );

    // Clear first so repeated taps on the same notification
    // still create a new ValueNotifier event.
    pendingRequest.value = null;
    pendingRequest.value = request;

    debugPrint(
      'Queued notification navigation: $request',
    );
  }

  static NotificationNavigationRequest?
  takePendingRequest() {
    final NotificationNavigationRequest? request =
        pendingRequest.value;

    pendingRequest.value = null;

    return request;
  }

  static void clear() {
    pendingRequest.value = null;
  }

  static int? _readPositiveInt(dynamic value) {
    if (value == null) {
      return null;
    }

    final int? parsed = value is int
        ? value
        : int.tryParse(value.toString().trim());

    if (parsed == null || parsed <= 0) {
      return null;
    }

    return parsed;
  }

  static String? _readText(dynamic value) {
    final String text = value?.toString().trim() ?? '';

    return text.isEmpty ? null : text;
  }
}
