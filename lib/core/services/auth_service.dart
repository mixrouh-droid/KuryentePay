import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';

class AuthService {
  static const Duration _timeout = Duration(seconds: 10);

  // LOGIN
  static Future<Map<String, dynamic>> login({
    required String accountNo,
    required String password,
  }) async {
    final url = ApiConfig.buildUri('login.php');

    final res = await http
        .post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'account_no': accountNo.trim(),
        'password': password,
      }),
    )
        .timeout(_timeout);

    Map<String, dynamic> json;
    try {
      json = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      throw Exception('Invalid server response.');
    }

    if (res.statusCode == 200 && json['success'] == true) {
      return json;
    }

    final msg = (json['message'] ?? 'Login failed').toString().trim();
    throw Exception(
      msg.isEmpty ? 'Login failed. Please try again.' : msg,
    );
  }

  // REGISTRATION STATUS
  static Future<String> checkRegistrationStatus({
    required String accountNo,
  }) async {
    final url = ApiConfig.buildUri('auth/registration_status.php');

    final res = await http
        .post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'account_no': accountNo.trim(),
      }),
    )
        .timeout(_timeout);

    Map<String, dynamic> json;
    try {
      json = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      throw Exception('Invalid server response.');
    }

    if (res.statusCode == 200 && json['success'] == true) {
      final status = (json['status'] ?? 'UNKNOWN')
          .toString()
          .trim()
          .toUpperCase();

      if (status == 'PENDING' ||
          status == 'ACTIVE' ||
          status == 'REJECTED' ||
          status == 'INACTIVE') {
        return status;
      }

      return 'UNKNOWN';
    }

    final msg = (json['message'] ?? 'Unable to check registration status.')
        .toString()
        .trim();

    throw Exception(
      msg.isEmpty
          ? 'Unable to check registration status.'
          : msg,
    );
  }

  // REGISTER
  static Future<Map<String, dynamic>> register({
    required String accountNo,
    required String name,
    required String address,
    required String phone,
    required String password,
    String? firstName,
    String? middleName,
    String? lastName,
    String? nameExtension,
    String? houseStreet,
    String? barangay,
    String? municipality,
    String? province,
    String? meterSerialNo,
  }) async {
    // Registration is hosted under /api/auth/register.php.
    final url = ApiConfig.buildUri('auth/register.php');

    final Map<String, dynamic> payload = {
      'account_no': accountNo.trim(),
      'name': name.trim(),
      'address': address.trim(),
      'phone': phone.trim(),
      'password': password,
    };

    // Keep the existing combined name/address fields for compatibility.
    // Structured registration fields are added only when explicitly supplied
    // by the registration screen, so older callers remain compatible.
    void addStructuredField(String key, String? value) {
      if (value == null) return;
      payload[key] = value.trim();
    }

    addStructuredField('first_name', firstName);
    addStructuredField('middle_name', middleName);
    addStructuredField('last_name', lastName);
    addStructuredField('name_extension', nameExtension);
    addStructuredField('house_street', houseStreet);
    addStructuredField('barangay', barangay);
    addStructuredField('municipality', municipality);
    addStructuredField('province', province);

    // Optional consumer-supplied Meter S/N. This is NOT an Admin-verified
    // meter assignment; the server stores it unverified for later review.
    // Omit it entirely for older callers that have no meter information.
    addStructuredField('meter_serial_no', meterSerialNo);

    final res = await http
        .post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    )
        .timeout(_timeout);

    Map<String, dynamic> json;
    try {
      json = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      throw Exception('Invalid server response.');
    }

    if ((res.statusCode == 200 || res.statusCode == 201) &&
        json['success'] == true) {
      return json;
    }

    final msg =
    (json['message'] ?? 'Registration failed').toString().trim();

    throw Exception(
      msg.isEmpty
          ? 'Registration failed. Please try again.'
          : msg,
    );
  }
}
