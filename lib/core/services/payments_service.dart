import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';

class PaymentsService {
  static const Duration _timeout = Duration(seconds: 10);

  static Future<Map<String, dynamic>> getPayments({
    required String accountNo,
  }) async {
    final url = ApiConfig.buildUri(
      'payments_history.php',
      query: {'account_no': accountNo},
    );

    final res = await http.get(url).timeout(_timeout);

    Map<String, dynamic> json;
    try {
      json = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      throw Exception('Invalid server response: ${res.body}');
    }

    if (res.statusCode == 200 && json['success'] == true) {
      return json;
    }

    throw Exception(
      (json['message'] ?? 'Failed to load payments').toString(),
    );
  }

  static Future<Map<String, dynamic>> getPaymentsHistory({
    required String accountNo,
  }) async {
    return getPayments(accountNo: accountNo);
  }
}