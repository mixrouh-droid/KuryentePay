// SESSION REVISION: expose the active account number for push-token sync
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class SessionService {
  static const String _keyUser = 'ileco_user_json';
  static const String _keyActiveAccountNo =
      'ileco_active_account_no';

  static Future<void> saveUser(
      Map<String, dynamic> user,
      ) async {
    final SharedPreferences prefs =
    await SharedPreferences.getInstance();

    await prefs.setString(
      _keyUser,
      jsonEncode(user),
    );

    final String? accountNo =
    accountNumberFromUser(user);

    if (accountNo != null) {
      await prefs.setString(
        _keyActiveAccountNo,
        accountNo,
      );
    }
  }

  static Future<void> saveActiveAccountNumber(
      String accountNo,
      ) async {
    final String normalised =
    _normaliseAccountNumber(accountNo);

    if (normalised.isEmpty) {
      return;
    }

    final SharedPreferences prefs =
    await SharedPreferences.getInstance();

    await prefs.setString(
      _keyActiveAccountNo,
      normalised,
    );
  }

  static Future<Map<String, dynamic>?> loadUser() async {
    final SharedPreferences prefs =
    await SharedPreferences.getInstance();

    final String? stored =
    prefs.getString(_keyUser);

    if (stored == null || stored.trim().isEmpty) {
      return null;
    }

    try {
      final dynamic decoded = jsonDecode(stored);

      if (decoded is Map<String, dynamic>) {
        return decoded;
      }

      if (decoded is Map) {
        return decoded.map(
              (dynamic key, dynamic value) =>
              MapEntry(key.toString(), value),
        );
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  static Future<String?> loadAccountNumber() async {
    final Map<String, dynamic>? user =
    await loadUser();

    final String? accountFromUser =
    user == null
        ? null
        : accountNumberFromUser(user);

    if (accountFromUser != null) {
      return accountFromUser;
    }

    final SharedPreferences prefs =
    await SharedPreferences.getInstance();

    final String normalised =
    _normaliseAccountNumber(
      prefs.getString(_keyActiveAccountNo) ?? '',
    );

    return normalised.isEmpty ? null : normalised;
  }

  static String? accountNumberFromUser(
      Map<String, dynamic> user,
      ) {
    const List<String> possibleKeys = <String>[
      'account_no',
      'accountNo',
      'account_number',
      'accountNumber',
      'consumer_account_no',
      'consumerAccountNo',
    ];

    for (final String key in possibleKeys) {
      final String normalised =
      _normaliseAccountNumber(
        user[key]?.toString() ?? '',
      );

      if (normalised.isNotEmpty) {
        return normalised;
      }
    }

    final dynamic nestedAccount =
    user['account'];

    if (nestedAccount is Map) {
      for (final String key in possibleKeys) {
        final String normalised =
        _normaliseAccountNumber(
          nestedAccount[key]?.toString() ?? '',
        );

        if (normalised.isNotEmpty) {
          return normalised;
        }
      }
    }

    return null;
  }

  static Future<void> clear() async {
    final SharedPreferences prefs =
    await SharedPreferences.getInstance();

    await prefs.remove(_keyUser);
    await prefs.remove(_keyActiveAccountNo);
  }

  static String _normaliseAccountNumber(
      String value,
      ) {
    return value.replaceAll(
      RegExp(r'[^0-9]'),
      '',
    );
  }
}
