// PUSH TOKEN SERVICE: register the active phone with the PHP API
import 'dart:async';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'session_service.dart';

class PushTokenService {
  PushTokenService._();

  static StreamSubscription<String>? _tokenRefreshSubscription;
  static bool _started = false;

  /// Starts token synchronisation once for the current app process.
  ///
  /// Safe to call more than once.
  static Future<void> start() async {
    if (_started) {
      return;
    }

    _started = true;

    try {
      await syncCurrentDevice();
    } catch (_) {
      // A temporary server/network problem must not stop the app.
    }

    _tokenRefreshSubscription =
        FirebaseMessaging.instance.onTokenRefresh.listen(
              (String refreshedToken) {
            unawaited(
              syncCurrentDevice(
                tokenOverride: refreshedToken,
              ),
            );
          },
          onError: (_) {
            // Firebase will try again when a future token refresh occurs.
          },
        );
  }

  /// Registers or refreshes this phone under the active consumer.
  ///
  /// [accountNoOverride] is useful immediately after login, before the
  /// saved session is read again.
  static Future<bool> syncCurrentDevice({
    String? accountNoOverride,
    String? tokenOverride,
  }) async {
    final String? accountNo =
    _normaliseAccountNumber(
      accountNoOverride ??
          await SessionService.loadAccountNumber() ??
          '',
    );

    if (accountNo == null) {
      return false;
    }

    final FirebaseMessaging messaging =
        FirebaseMessaging.instance;

    final String? token =
    _cleanToken(
      tokenOverride ??
          await messaging.getToken(),
    );

    if (token == null) {
      return false;
    }

    final NotificationSettings settings =
    await messaging.getNotificationSettings();

    final bool authorised =
        settings.authorizationStatus ==
            AuthorizationStatus.authorized ||
            settings.authorizationStatus ==
                AuthorizationStatus.provisional;

    final Uri endpoint =
    ApiConfig.buildUri('save_push_token.php');

    final http.Response response = await http
        .post(
      endpoint,
      headers: const <String, String>{
        'Content-Type':
        'application/json; charset=UTF-8',
        'Accept': 'application/json',
      },
      body: jsonEncode(
        <String, dynamic>{
          'account_no': accountNo,
          'fcm_token': token,
          'platform': 'android',
          'notifications_authorised': authorised,
        },
      ),
    )
        .timeout(const Duration(seconds: 12));

    final Map<String, dynamic> payload =
    _decodeResponse(response.body);

    final bool success =
        response.statusCode >= 200 &&
            response.statusCode < 300 &&
            payload['success'] == true;

    if (!success) {
      final String message =
      (payload['message'] ??
          'Unable to register this phone for notifications.')
          .toString();

      throw Exception(message);
    }

    return true;
  }

  static Future<void> dispose() async {
    await _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = null;
    _started = false;
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
      return <String, dynamic>{
        'success': false,
        'message':
        'The notification server returned an invalid response.',
      };
    }

    return <String, dynamic>{};
  }

  static String? _normaliseAccountNumber(
      String value,
      ) {
    final String digits = value.replaceAll(
      RegExp(r'[^0-9]'),
      '',
    );

    return digits.isEmpty ? null : digits;
  }

  static String? _cleanToken(
      String? value,
      ) {
    final String token = (value ?? '').trim();

    return token.isEmpty ? null : token;
  }
}
