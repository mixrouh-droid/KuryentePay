import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';

class PaymentService {
  static const Duration _timeout = Duration(seconds: 45);


  static Future<Map<String, dynamic>> createPayMongoPayment({
    required String accountNo,
    required int billId,
  }) async {
    final String cleanAccountNo = accountNo.trim();

    if (cleanAccountNo.isEmpty) {
      throw Exception('Account number is required.');
    }

    if (billId <= 0) {
      throw Exception('A valid bill ID is required.');
    }

    final Uri url = ApiConfig.buildUri(
      'payments/createpayment.php',
    );

    late http.Response response;

    try {
      response = await http
          .post(
        url,
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'account_no': cleanAccountNo,
          'bill_id': billId,
        }),
      )
          .timeout(_timeout);
    } on TimeoutException {
      throw Exception(
        'Connection timeout. Please check your internet connection and try again.',
      );
    } on http.ClientException catch (error) {
      throw Exception(
        'ILECO PAY could not reach the payment service.\n$error',
      );
    } catch (error) {
      throw Exception(
        'Unable to create the payment session.\n$error',
      );
    }

    final Map<String, dynamic> json;

    try {
      final dynamic decoded = jsonDecode(response.body);

      if (decoded is! Map) {
        throw const FormatException();
      }

      json = Map<String, dynamic>.from(decoded);
    } catch (_) {
      throw Exception(
        'Invalid server response:\n${response.body}',
      );
    }

    final bool requestSuccessful =
        response.statusCode == 200 || response.statusCode == 201;

    if (!requestSuccessful || json['success'] != true) {
      final String message =
      (json['message'] ??
          'Unable to create the PayMongo checkout session.')
          .toString();

      throw Exception(message);
    }

    final dynamic paymentData = json['payment'];

    if (paymentData is! Map) {
      throw Exception(
        'The server did not return payment information.',
      );
    }

    final Map<String, dynamic> payment =
    Map<String, dynamic>.from(paymentData);

    final String checkoutUrl =
    (payment['checkout_url'] ??
        payment['payment_link_url'] ??
        '')
        .toString()
        .trim();

    if (checkoutUrl.isEmpty) {
      throw Exception(
        'The server did not return a PayMongo checkout link.',
      );
    }

    return {
      ...json,
      'payment': payment,
    };
  }

  /// Returns the hosted checkout URL from a successful payment-session response.
  ///
  /// checkout_url is preferred.
  /// payment_link_url remains as a backend compatibility fallback only.
  static String getPaymentLink(
      Map<String, dynamic> response,
      ) {
    final dynamic paymentData = response['payment'];

    if (paymentData is! Map) {
      throw Exception(
        'Payment information was not found.',
      );
    }

    final String checkoutUrl =
    (paymentData['checkout_url'] ??
        paymentData['payment_link_url'] ??
        '')
        .toString()
        .trim();

    if (checkoutUrl.isEmpty) {
      throw Exception(
        'PayMongo checkout link was not found.',
      );
    }

    return checkoutUrl;
  }

  /// Preferred provider-neutral name for new payment screens.
  static String getCheckoutUrl(
      Map<String, dynamic> response,
      ) {
    return getPaymentLink(response);
  }

  /// Fetches the latest bill status from the hosted backend.
  ///
  /// Returns only PAID or UNPAID.
  /// This is the source the Flutter app should use after checkout returns.
  /// The app must not assume that closing/returning from PayMongo means PAID.
  static Future<String?> getBillStatus({
    required String accountNo,
  }) async {
    final String cleanAccountNo = accountNo.trim();

    if (cleanAccountNo.isEmpty) {
      throw Exception('Account number is required.');
    }

    final Uri url = ApiConfig.buildUri(
      'current_bill.php',
      query: {
        'account_no': cleanAccountNo,
      },
    );

    late http.Response response;

    try {
      response = await http
          .get(
        url,
        headers: const {
          'Accept': 'application/json',
        },
      )
          .timeout(_timeout);
    } on TimeoutException {
      throw Exception(
        'Connection timeout. Please check your internet connection and try again.',
      );
    } on http.ClientException catch (error) {
      throw Exception(
        'ILECO PAY could not reach the billing service.\n$error',
      );
    } catch (error) {
      throw Exception(
        'Unable to load the bill status.\n$error',
      );
    }

    final Map<String, dynamic> json;

    try {
      final dynamic decoded = jsonDecode(response.body);

      if (decoded is! Map) {
        throw const FormatException();
      }

      json = Map<String, dynamic>.from(decoded);
    } catch (_) {
      throw Exception(
        'Invalid server response:\n${response.body}',
      );
    }

    if (response.statusCode != 200 || json['success'] != true) {
      throw Exception(
        (json['message'] ?? 'Failed to load bill status.').toString(),
      );
    }

    final dynamic billData = json['bill'];

    if (billData == null) {
      return null;
    }

    final Map<String, dynamic> bill =
    billData is Map
        ? Map<String, dynamic>.from(billData)
        : json;

    final String rawStatus =
    (bill['payment_status'] ?? bill['status'] ?? '')
        .toString()
        .trim()
        .toUpperCase();

    if (rawStatus.isEmpty) {
      return null;
    }

    return rawStatus == 'PAID' ? 'PAID' : 'UNPAID';
  }
}
