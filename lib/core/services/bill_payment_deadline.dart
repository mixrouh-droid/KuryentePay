import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';

/// Philippine payment-date helper for ILECO PAY.
///
/// Synchronizes with the Hostinger server used by the checkout endpoint.
/// Payment eligibility does not fall back to the phone's calendar clock.
///
/// Online payment is allowed THROUGH the bill's due date.
/// Office payment is required starting on the following Philippine date.
///
/// The PHP checkout endpoint remains the authority for real payments.
class BillPaymentDeadline {
  static const String title = 'ONLINE PAYMENT UNAVAILABLE';

  static const String officeAction =
      'PROCEED TO ILECO OFFICE FOR PAYMENT';

  static const String explanation =
      'The due date for this bill has passed. '
      'Online payment is no longer available. Please visit an ILECO office '
      'to settle your outstanding balance.';

  static DateTime? _serverUtcAtSync;
  static Stopwatch? _elapsedSinceSync;
  static Future<bool>? _syncInProgress;

  static const Duration _syncTimeout = Duration(seconds: 12);
  static const Duration _maxClockAge = Duration(hours: 24);

  /// Technical status for diagnostics only.
  /// Do not display raw server data or network exceptions in payment notices.
  static String? lastSyncDiagnostic;

  /// The app can display an invoice offline, but payment eligibility requires
  /// a previously verified server clock that has not exceeded its maximum age.
  static bool get serverClockVerified => _trustedServerUtcNow() != null;

  /// Returns the Philippine calendar date when the server clock is known.
  static DateTime? get verifiedManilaToday {
    final DateTime? utcNow = _trustedServerUtcNow();

    if (utcNow == null) return null;

    return _manilaDateFromUtc(utcNow);
  }

  /// Synchronize from the server. Only one request is in flight at a time.
  /// Preserves the existing server_time.php endpoint and response format.
  static Future<bool> syncServerTime({bool force = false}) {
    final Future<bool>? running = _syncInProgress;

    if (running != null) return running;

    final Stopwatch? uptime = _elapsedSinceSync;

    if (!force &&
        _trustedServerUtcNow() != null &&
        uptime != null &&
        uptime.elapsed < const Duration(minutes: 5)) {
      return Future<bool>.value(true);
    }

    final Future<bool> request = _fetchServerTime();

    _syncInProgress = request;

    return request.whenComplete(() {
      if (identical(_syncInProgress, request)) {
        _syncInProgress = null;
      }
    });
  }

  static Future<bool> _fetchServerTime() async {
    try {
      final Uri uri = ApiConfig.buildUri('server_time.php');

      final http.Response response = await http.get(
        uri,
        headers: const <String, String>{
          'Cache-Control': 'no-cache',
        },
      ).timeout(_syncTimeout);

      if (response.statusCode != 200) {
        lastSyncDiagnostic =
        'Server time HTTP ${response.statusCode}';
        return false;
      }

      final dynamic payload = jsonDecode(response.body);

      if (payload is! Map) {
        lastSyncDiagnostic =
        'Server time response was not JSON object';
        return false;
      }

      if (payload['success'] != true ||
          payload['timezone'] != 'Asia/Manila') {
        lastSyncDiagnostic =
        'Server time response missing required fields';
        return false;
      }

      final String rawTime =
      (payload['philippine_datetime'] ?? '').toString();

      final String rawDate =
      (payload['philippine_date'] ?? '').toString();

      // Require an explicit UTC+08:00 offset rather than interpreting an
      // ambiguous local timestamp according to the phone's timezone.
      if (!RegExp(r'\+08:00$').hasMatch(rawTime)) {
        lastSyncDiagnostic =
        'Server time lacks explicit +08:00 offset';
        return false;
      }

      final DateTime? parsed = DateTime.tryParse(rawTime);

      if (parsed == null) {
        lastSyncDiagnostic =
        'Server time has an invalid timestamp';
        return false;
      }

      final DateTime parsedServerUtc = parsed.toUtc();

      final DateTime expectedPhilippineDate =
      _manilaDateFromUtc(parsedServerUtc);

      final String expectedDate =
          '${expectedPhilippineDate.year.toString().padLeft(4, '0')}-'
          '${expectedPhilippineDate.month.toString().padLeft(2, '0')}-'
          '${expectedPhilippineDate.day.toString().padLeft(2, '0')}';

      if (rawDate != expectedDate) {
        lastSyncDiagnostic =
        'Server date does not match server timestamp';
        return false;
      }

      if (expectedPhilippineDate.year < 2020 ||
          expectedPhilippineDate.year > 2100) {
        lastSyncDiagnostic =
        'Server date is outside supported range';
        return false;
      }

      // Advance the verified server timestamp using elapsed time instead
      // of trusting later changes to the phone's calendar clock.
      _serverUtcAtSync = parsedServerUtc;
      _elapsedSinceSync = Stopwatch()..start();

      lastSyncDiagnostic = null;

      return true;
    } on TimeoutException {
      lastSyncDiagnostic =
      'Server time connection timed out';
      return false;
    } catch (_) {
      lastSyncDiagnostic =
      'Server time request could not be completed';

      // Preserve the existing cached-clock behavior during a temporary
      // outage. The clock must still pass the maximum-age check below.
      // Without a trusted clock, online payment remains disabled.
      return false;
    }
  }

  static DateTime? _trustedServerUtcNow() {
    final DateTime? sync = _serverUtcAtSync;
    final Stopwatch? elapsed = _elapsedSinceSync;

    if (sync == null || elapsed == null) return null;

    if (elapsed.elapsed > _maxClockAge) return null;

    return sync.add(elapsed.elapsed);
  }

  static DateTime _manilaDateFromUtc(DateTime utcTime) {
    final DateTime manila =
    utcTime.toUtc().add(const Duration(hours: 8));

    // A UTC date-only value represents the Philippine calendar date.
    // Calendar comparisons therefore do not use the device's timezone.
    return DateTime.utc(
      manila.year,
      manila.month,
      manila.day,
    );
  }

  /// A due_date column is a calendar date, not a timezone-aware timestamp.
  /// Preserves support for an ISO date with an optional time suffix.
  static DateTime? parseDueDate(String raw) {
    final String value = raw.trim();

    final RegExpMatch? match =
    RegExp(r'^(\d{4})-(\d{2})-(\d{2})(?:[ T].*)?$')
        .firstMatch(value);

    if (match == null) return null;

    final int? year = int.tryParse(match.group(1)!);
    final int? month = int.tryParse(match.group(2)!);
    final int? day = int.tryParse(match.group(3)!);

    if (year == null ||
        month == null ||
        day == null ||
        year < 2000 ||
        year > 2100) {
      return null;
    }

    final DateTime date = DateTime.utc(year, month, day);

    // Reject invalid dates instead of accepting normalized overflow.
    if (date.year != year ||
        date.month != month ||
        date.day != day) {
      return null;
    }

    return date;
  }

  /// Used by the existing UI date-change tickers.
  ///
  /// The phone-clock fallback is for calendar display only.
  /// Payment eligibility does not use that fallback.
  static DateTime manilaToday({DateTime? now}) {
    if (now != null) {
      return _manilaDateFromUtc(now.toUtc());
    }

    return verifiedManilaToday ??
        _manilaDateFromUtc(DateTime.now().toUtc());
  }

  /// Returns:
  /// - A positive number when the due date is in the future.
  /// - Zero when the bill is due today.
  /// - A negative number when the due date has passed.
  /// - Null when the due date or trusted server date is unavailable.
  ///
  /// The existing optional [now] parameter is retained for controlled tests.
  /// Normal payment screens should use the verified server date.
  static int? daysUntilDue(String dueDate, {DateTime? now}) {
    final DateTime? due = parseDueDate(dueDate);

    if (due == null) return null;

    final DateTime? today = now == null
        ? verifiedManilaToday
        : manilaToday(now: now);

    if (today == null) return null;

    return due.difference(today).inDays;
  }

  /// Office payment is required only AFTER the due date.
  ///
  /// Due today means zero days remaining and is still eligible online.
  /// An unknown date does not establish that a bill is overdue.
  static bool isOfficePaymentRequired(
      String dueDate, {
        DateTime? now,
      }) {
    final int? days = daysUntilDue(dueDate, now: now);

    return days != null && days < 0;
  }

  /// Online payment is allowed before AND on the due date.
  ///
  /// This is only the date-eligibility check. The backend must still
  /// validate the account, bill, amount, and existing payment status.
  ///
  /// Fail closed when the server date is unavailable or the due date
  /// is invalid. The configured grace period does not extend this cutoff.
  static bool canStartOnlinePayment(
      String dueDate, {
        DateTime? now,
      }) {
    final int? days = daysUntilDue(dueDate, now: now);

    return days != null && days >= 0;
  }

  static String friendlyDueDate(String raw) {
    final DateTime? date = parseDueDate(raw);

    if (date == null) {
      return raw.trim().isEmpty ? 'Not available' : raw;
    }

    const List<String> months = <String>[
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}