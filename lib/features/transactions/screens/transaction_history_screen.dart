// KuryentePay Transaction History: presentation-only redesign; payments and state logic preserved.
import 'package:flutter/material.dart';

import '../../../core/services/payments_service.dart';
import '../../../core/services/session_service.dart';

class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({
    super.key,
    this.initialPaymentId,
  });

  final int? initialPaymentId;

  @override
  State<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen>
    with WidgetsBindingObserver {
  late Future<Map<String, dynamic>?> _sessionFuture;
  Future<Map<String, dynamic>>? _paymentsFuture;

  String? _activeAccountNo;
  _TxnFilter _activeFilter = _TxnFilter.all;
  bool _initialPaymentHandled = false;

  static const List<String> _monthNames = <String>[
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sessionFuture = SessionService.loadUser();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final String accountNo = _activeAccountNo?.trim() ?? '';
      if (accountNo.isNotEmpty && mounted) {
        setState(() => _load(accountNo));
      }
    }
  }

  void _load(String accountNo) {
    _paymentsFuture = PaymentsService.getPayments(accountNo: accountNo);
  }

  Future<void> _refresh(String accountNo) async {
    setState(() => _load(accountNo));
    await _paymentsFuture;
  }

  DateTime? _parseDate(String raw) {
    final String value = raw.trim();
    if (value.isEmpty) return null;

    try {
      return DateTime.parse(value);
    } catch (_) {
      return null;
    }
  }

  String _formatDateTime(String raw) {
    final DateTime? parsed = _parseDate(raw);
    if (parsed == null) return 'Date unavailable';

    final DateTime local = parsed.isUtc ? parsed.toLocal() : parsed;
    final int hour12 = local.hour == 0
        ? 12
        : local.hour > 12
        ? local.hour - 12
        : local.hour;
    final String minute = local.minute.toString().padLeft(2, '0');
    final String period = local.hour >= 12 ? 'PM' : 'AM';

    return '${_monthNames[local.month - 1]} ${local.day}, ${local.year} \u2022 '
        '$hour12:$minute $period';
  }

  bool _isPaidStatus(String status) {
    return <String>{
      'SUCCESS',
      'PAID',
      'COMPLETED',
    }.contains(status.toUpperCase());
  }

  bool _isPendingStatus(String status) {
    return <String>{
      'PENDING',
      'PROCESSING',
      'VERIFYING',
    }.contains(status.toUpperCase());
  }

  bool _isFailedStatus(String status) {
    return <String>{
      'FAILED',
      'CANCELLED',
      'CANCELED',
      'EXPIRED',
      'VOIDED',
    }.contains(status.toUpperCase());
  }

  bool _matchesFilter(Map payment) {
    final String status =
    (payment['status'] ?? '').toString().trim().toUpperCase();

    switch (_activeFilter) {
      case _TxnFilter.paid:
        return _isPaidStatus(status);
      case _TxnFilter.pending:
        return _isPendingStatus(status);
      case _TxnFilter.failed:
        return _isFailedStatus(status);
      case _TxnFilter.all:
        return true;
    }
  }

  String _statusLabel(String status) {
    final String normalized = status.trim().toUpperCase();

    if (_isPaidStatus(normalized)) return 'Paid';
    if (_isPendingStatus(normalized)) return 'In Progress';

    switch (normalized) {
      case 'FAILED':
        return 'Failed';
      case 'CANCELLED':
      case 'CANCELED':
        return 'Cancelled';
      case 'EXPIRED':
        return 'Expired';
      case 'VOIDED':
        return 'Voided';
      default:
        final String clean = normalized.replaceAll('_', ' ').trim();
        if (clean.isEmpty) return 'Recorded';
        return clean.split(' ').where((part) => part.isNotEmpty).map(
              (part) => part[0] + part.substring(1).toLowerCase(),
        ).join(' ');
    }
  }

  bool _isOfficePayment(Map payment) {
    final String provider =
    (payment['provider'] ?? '').toString().trim().toUpperCase();
    final String channel = (payment['payment_channel'] ?? '')
        .toString()
        .trim()
        .toUpperCase();
    final String method =
    (payment['method'] ?? '').toString().trim().toUpperCase();

    return provider == 'ILECO' ||
        provider == 'ILECO OFFICE' ||
        channel == 'OFFICE' ||
        method == 'OFFICE';
  }

  bool _isPayMongoPayment(Map payment) {
    return (payment['provider'] ?? '').toString().trim().toUpperCase() ==
        'PAYMONGO';
  }

  String _paymentMethodLabel(Map payment) {
    final String provider =
    (payment['provider'] ?? '').toString().trim().toUpperCase();
    final String channel = (payment['payment_channel'] ?? '')
        .toString()
        .trim()
        .toUpperCase();
    final String method = (payment['method'] ?? '').toString().trim();

    if (_isOfficePayment(payment)) return 'Office Payment';

    if (_isPayMongoPayment(payment)) {
      return channel == 'QRPH' ? 'PayMongo \u2022 QR Ph' : 'PayMongo';
    }

    final String channelLabel = channel == 'QRPH' ? 'QR Ph' : channel;

    if (provider.isNotEmpty && channelLabel.isNotEmpty) {
      return '$provider \u2022 $channelLabel';
    }

    if (provider.isNotEmpty) return provider;
    if (channelLabel.isNotEmpty) return channelLabel;
    if (method.toUpperCase() == 'ONLINE') return 'Online Payment';

    return method.isEmpty ? 'Payment' : method;
  }

  String _paymentSourceLabel(Map payment) {
    if (_isOfficePayment(payment)) return 'Office Payment';

    if (_isPayMongoPayment(payment) ||
        (payment['method'] ?? '').toString().trim().toUpperCase() == 'ONLINE') {
      return 'Online Payment';
    }

    return 'Payment Record';
  }

  Color _paymentSourceAccent(BuildContext context, Map payment) {
    // All payment-method icons share the KuryentePay teal accent.
    // Status colors remain separate to avoid suggesting a failed payment is paid.
    return _TxnPalette.brand(context);
  }

  IconData _paymentIcon(Map payment) {
    if (_isOfficePayment(payment)) return Icons.account_balance_rounded;
    if (_isPayMongoPayment(payment)) return Icons.qr_code_2_rounded;
    return Icons.payments_outlined;
  }

  Color _statusAccent(BuildContext context, String status) {
    if (_isPaidStatus(status)) return _TxnPalette.success(context);
    if (_isPendingStatus(status)) return _TxnPalette.warning(context);
    return _TxnPalette.danger(context);
  }

  String _paymentReference(Map payment) {
    final String reference =
    (payment['reference_no'] ?? '').toString().trim();
    return reference.isEmpty ? '\u2014' : reference;
  }

  String _transactionDate(Map payment, String status) {
    final bool paid = _isPaidStatus(status);
    final String paidAt = (payment['paid_at'] ?? '').toString().trim();
    final String createdAt =
    (payment['created_at'] ?? payment['updated_at'] ?? '')
        .toString()
        .trim();

    if (paid && paidAt.isNotEmpty) return _formatDateTime(paidAt);
    if (createdAt.isNotEmpty) return _formatDateTime(createdAt);
    if (paidAt.isNotEmpty) return _formatDateTime(paidAt);

    return 'Date unavailable';
  }

  String _transactionDatePrefix(String status) {
    if (_isPaidStatus(status)) return 'Paid On';
    if (_isPendingStatus(status)) return 'Started On';
    return 'Recorded On';
  }

  DateTime _sortDate(Map payment) {
    final String raw =
    (payment['paid_at'] ?? payment['updated_at'] ?? payment['created_at'] ?? '')
        .toString();
    return _parseDate(raw) ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  int _sortId(Map payment) {
    final dynamic raw = payment['id'];
    if (raw is int) return raw;
    return int.tryParse(raw?.toString() ?? '') ?? 0;
  }

  double _amount(Map payment) {
    final dynamic raw = payment['amount'] ?? 0;
    if (raw is num) return raw.toDouble();
    return double.tryParse(raw.toString()) ?? 0;
  }

  int? _billId(Map payment) {
    final dynamic raw = payment['bill_id'];
    if (raw == null) return null;
    return int.tryParse(raw.toString());
  }

  void _queueInitialPaymentDetails(List<dynamic> allPayments) {
    final int? targetId = widget.initialPaymentId;

    if (_initialPaymentHandled || targetId == null || targetId <= 0) {
      return;
    }

    Map? targetPayment;

    for (final dynamic raw in allPayments) {
      if (raw is! Map) continue;

      final dynamic rawId = raw['id'];
      final int? paymentId = rawId is int
          ? rawId
          : int.tryParse(rawId?.toString() ?? '');

      if (paymentId == targetId) {
        targetPayment = raw;
        break;
      }
    }

    _initialPaymentHandled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      if (targetPayment != null) {
        _showTransactionDetails(targetPayment);
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'The selected transaction is no longer available.',
            ),
          ),
        );
    });
  }

  String _monthKey(Map payment) {
    final DateTime date = _sortDate(payment);
    if (date.millisecondsSinceEpoch == 0) return 'UNKNOWN';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}';
  }

  String _monthLabel(String key) {
    final RegExpMatch? match = RegExp(r'^(\d{4})-(\d{2})$').firstMatch(key);
    if (match == null) return 'Other Transactions';

    final int? year = int.tryParse(match.group(1) ?? '');
    final int? month = int.tryParse(match.group(2) ?? '');

    if (year == null || month == null || month < 1 || month > 12) {
      return 'Other Transactions';
    }

    return '${_monthNames[month - 1]} $year';
  }

  void _showTransactionDetails(Map payment) {
    final String status =
    (payment['status'] ?? '').toString().trim().toUpperCase();
    final double amount = _amount(payment);
    final Color accent = _statusAccent(context, status);
    final int? billId = _billId(payment);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: _TxnPalette.surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 26),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Transaction Details',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: _TxnPalette.text(context),
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close',
                        icon: const Icon(Icons.close_rounded),
                        color: _TxnPalette.secondaryText(context),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
                    decoration: BoxDecoration(
                      color: _TxnPalette.background(context),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _TxnPalette.border(context)),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.11),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _isPaidStatus(status)
                                ? Icons.check_circle_rounded
                                : _isPendingStatus(status)
                                ? Icons.schedule_rounded
                                : Icons.info_outline_rounded,
                            color: accent,
                            size: 28,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Payment Amount',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: _TxnPalette.secondaryText(context),
                          ),
                        ),
                        const SizedBox(height: 5),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '\u20B1 ${amount.toStringAsFixed(2)}',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              color: _TxnPalette.text(context),
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.7,
                            ),
                          ),
                        ),
                        const SizedBox(height: 9),
                        _StatusMark(text: _statusLabel(status), accent: accent),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Payment Information',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: _TxnPalette.text(context),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _DetailRow(
                    icon: _paymentIcon(payment),
                    label: 'Payment Method',
                    value: _paymentMethodLabel(payment),
                  ),
                  _DetailRow(
                    icon: Icons.tag_rounded,
                    label: 'Reference Number',
                    value: _paymentReference(payment),
                  ),
                  _DetailRow(
                    icon: Icons.calendar_month_outlined,
                    label: 'Transaction Date',
                    value: _transactionDate(payment, status),
                  ),
                  _DetailRow(
                    icon: Icons.receipt_long_rounded,
                    label: 'Bill ID',
                    value: billId?.toString() ?? 'Not linked',
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: _TxnPalette.brand(context),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text(
                        'Done',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _TxnPalette.background(context),
      appBar: AppBar(
        toolbarHeight: 68,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: _TxnPalette.background(context),
        surfaceTintColor: Colors.transparent,
        foregroundColor: _TxnPalette.brand(context),
        iconTheme: IconThemeData(color: _TxnPalette.brand(context)),
        titleSpacing: 4,
        title: Text(
          'Transaction History',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: _TxnPalette.text(context),
            fontSize: 21,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.35,
          ),
        ),
      ),
      body: Stack(
        children: [
          const _SoftBackground(),
          FutureBuilder<Map<String, dynamic>?>(
            future: _sessionFuture,
            builder: (context, snapUser) {
              if (snapUser.connectionState == ConnectionState.waiting) {
                return const _LoadingState();
              }

              if (snapUser.hasError) {
                return _ErrorState(
                  message: snapUser.error
                      .toString()
                      .replaceFirst('Exception: ', ''),
                  onRetry: () {
                    setState(() {
                      _sessionFuture = SessionService.loadUser();
                      _paymentsFuture = null;
                    });
                  },
                );
              }

              final Map<String, dynamic>? user = snapUser.data;
              if (user == null) {
                return const _EmptyState(
                  title: 'Session Unavailable',
                  subtitle: 'Please sign in again to view your transactions.',
                );
              }

              final String accountNo =
              (user['account_no'] ?? '').toString().trim();
              _activeAccountNo = accountNo;

              _paymentsFuture ??= (() {
                _load(accountNo);
                return _paymentsFuture!;
              })();

              return FutureBuilder<Map<String, dynamic>>(
                future: _paymentsFuture,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const _LoadingState();
                  }

                  if (snap.hasError) {
                    return _ErrorState(
                      message: snap.error
                          .toString()
                          .replaceFirst('Exception: ', ''),
                      onRetry: () => setState(() => _load(accountNo)),
                    );
                  }

                  final Map<String, dynamic> data =
                      snap.data ?? const <String, dynamic>{};
                  final List<dynamic> allPayments = List<dynamic>.from(
                    (data['payments'] as List?) ?? const <dynamic>[],
                  );

                  allPayments.sort((dynamic a, dynamic b) {
                    final Map aMap =
                    a is Map ? a : const <String, dynamic>{};
                    final Map bMap =
                    b is Map ? b : const <String, dynamic>{};

                    final int byDate =
                    _sortDate(bMap).compareTo(_sortDate(aMap));
                    if (byDate != 0) return byDate;

                    return _sortId(bMap).compareTo(_sortId(aMap));
                  });

                  _queueInitialPaymentDetails(allPayments);

                  int paidCount = 0;
                  int pendingCount = 0;
                  int failedCount = 0;
                  double totalPaid = 0;

                  for (final dynamic raw in allPayments) {
                    final Map payment =
                    raw is Map ? raw : const <String, dynamic>{};
                    final String status =
                    (payment['status'] ?? '').toString().trim();

                    if (_isPaidStatus(status)) {
                      paidCount++;
                      totalPaid += _amount(payment);
                    } else if (_isPendingStatus(status)) {
                      pendingCount++;
                    } else if (_isFailedStatus(status)) {
                      failedCount++;
                    }
                  }

                  final List<dynamic> visiblePayments = allPayments
                      .where(
                        (dynamic raw) => _matchesFilter(
                      raw is Map
                          ? raw
                          : const <String, dynamic>{},
                    ),
                  )
                      .toList();

                  final Map<String, List<Map>> grouped = <String, List<Map>>{};
                  for (final dynamic raw in visiblePayments) {
                    final Map payment =
                    raw is Map ? raw : const <String, dynamic>{};
                    final String key = _monthKey(payment);
                    grouped.putIfAbsent(key, () => <Map>[]).add(payment);
                  }

                  final List<String> groupKeys = grouped.keys.toList()
                    ..sort((String a, String b) => b.compareTo(a));

                  return RefreshIndicator(
                    color: _TxnPalette.brand(context),
                    backgroundColor: _TxnPalette.surface(context),
                    onRefresh: () => _refresh(accountNo),
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
                      children: [
                        _PaymentSummary(
                          accountNo: accountNo,
                          totalPaid: totalPaid,
                          totalCount: allPayments.length,
                          paidCount: paidCount,
                          pendingCount: pendingCount,
                          failedCount: failedCount,
                        ),
                        const SizedBox(height: 26),
                        _SectionHeading(
                          title: 'Recent Transactions',
                          subtitle: visiblePayments.length == allPayments.length
                              ? '${allPayments.length} transactions'
                              : '${visiblePayments.length} of ${allPayments.length}',
                        ),
                        const SizedBox(height: 13),
                        _FilterTabs(
                          active: _activeFilter,
                          allCount: allPayments.length,
                          paidCount: paidCount,
                          pendingCount: pendingCount,
                          failedCount: failedCount,
                          onChanged: (_TxnFilter filter) {
                            if (_activeFilter == filter) return;
                            setState(() => _activeFilter = filter);
                          },
                        ),
                        const SizedBox(height: 22),
                        if (allPayments.isEmpty)
                          const _EmptyState(
                            title: 'No Transactions Yet',
                            subtitle:
                            'Your online and office payment records will appear here once available.',
                          )
                        else if (visiblePayments.isEmpty)
                          const _EmptyState(
                            title: 'No Matching Transactions',
                            subtitle:
                            'Choose another filter to view your payment history.',
                          )
                        else
                          ...groupKeys.map((String key) {
                            final List<Map> items = grouped[key]!;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(2, 0, 2, 12),
                                    child: Row(
                                      children: [
                                        Container(
                                          height: 17,
                                          width: 4,
                                          decoration: BoxDecoration(
                                            color: _TxnPalette.brand(context),
                                            borderRadius: BorderRadius.circular(5),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            _monthLabel(key),
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleSmall
                                                ?.copyWith(
                                              color: _TxnPalette.text(context),
                                              fontWeight: FontWeight.w800,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          '${items.length} ${items.length == 1 ? 'record' : 'records'}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelSmall
                                              ?.copyWith(
                                            color: _TxnPalette.secondaryText(context),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  ...items.map((Map payment) {
                                    final String status =
                                    (payment['status'] ?? '')
                                        .toString()
                                        .trim()
                                        .toUpperCase();
                                    final bool isLatest = allPayments.isNotEmpty &&
                                        identical(payment, allPayments.first);

                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 11),
                                      child: _TransactionCard(
                                        icon: _paymentIcon(payment),
                                        iconAccent: isLatest
                                            ? _TxnPalette.success(context)
                                            : _paymentSourceAccent(context, payment),
                                        statusAccent: _statusAccent(context, status),
                                        method: _paymentMethodLabel(payment),
                                        sourceLabel: _paymentSourceLabel(payment),
                                        reference: _paymentReference(payment),
                                        dateText: _transactionDate(payment, status),
                                        status: _statusLabel(status),
                                        amount: _amount(payment),
                                        isLatest: isLatest,
                                        onTap: () => _showTransactionDetails(payment),
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            );
                          }),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

enum _TxnFilter { all, paid, pending, failed }

class _TxnPalette {
  static bool _isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color background(BuildContext context) =>
      _isDark(context) ? const Color(0xFF091B25) : const Color(0xFFF4F7FA);

  static Color surface(BuildContext context) =>
      _isDark(context) ? const Color(0xFF142D39) : Colors.white;

  static Color text(BuildContext context) =>
      _isDark(context) ? const Color(0xFFF4F8FA) : const Color(0xFF173347);

  static Color secondaryText(BuildContext context) =>
      _isDark(context) ? const Color(0xFFBDD0D9) : const Color(0xFF617786);

  static Color border(BuildContext context) =>
      _isDark(context) ? const Color(0xFF2C4954) : const Color(0xFFDCE6EA);

  static Color brand(BuildContext context) =>
      _isDark(context) ? const Color(0xFF71D5CA) : const Color(0xFF087F79);

  static Color info(BuildContext context) =>
      _isDark(context) ? const Color(0xFF83D9D0) : const Color(0xFF087F79);

  static Color gold(BuildContext context) =>
      _isDark(context) ? const Color(0xFFF6D483) : const Color(0xFFB28A28);

  static Color success(BuildContext context) =>
      _isDark(context) ? const Color(0xFF75DCB2) : const Color(0xFF177F5B);

  static Color warning(BuildContext context) =>
      _isDark(context) ? const Color(0xFFF6D483) : const Color(0xFFAC781C);

  static Color danger(BuildContext context) =>
      _isDark(context) ? const Color(0xFFFF9FA0) : const Color(0xFFC84954);
}

class _SoftBackground extends StatelessWidget {
  const _SoftBackground();

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return IgnorePointer(
      child: SizedBox.expand(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isDark
                  ? const [Color(0xFF091B25), Color(0xFF0F2430)]
                  : const [Color(0xFFF8FAFB), Color(0xFFF0F5F7)],
            ),
          ),
        ),
      ),
    );
  }
}

class _PaymentSummary extends StatelessWidget {
  const _PaymentSummary({
    required this.accountNo,
    required this.totalPaid,
    required this.totalCount,
    required this.paidCount,
    required this.pendingCount,
    required this.failedCount,
  });

  final String accountNo;
  final double totalPaid;
  final int totalCount;
  final int paidCount;
  final int pendingCount;
  final int failedCount;

  @override
  Widget build(BuildContext context) {
    final double completedPortion = totalCount == 0 ? 0 : paidCount / totalCount;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 19),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFF102F3E), Color(0xFF174B4A)],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFF102F3E).withValues(alpha: 0.14),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_outlined,
                  color: Color(0xFF9DE9CD),
                  size: 21,
                ),
              ),
              const SizedBox(width: 11),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'KuryentePay',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Payment Overview',
                      style: TextStyle(
                        color: Color(0xFFC5DDE0),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$totalCount Records',
                  style: const TextStyle(
                    color: Color(0xFFE2F3F0),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 26),
          const Text(
            'Total Paid',
            style: TextStyle(
              color: Color(0xFFBBD5D8),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '\u20B1 ${totalPaid.toStringAsFixed(2)}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 34,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.8,
              ),
            ),
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              const Icon(
                Icons.person_outline_rounded,
                size: 15,
                color: Color(0xFFBBD5D8),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Account $accountNo',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFBBD5D8),
                    fontSize: 11.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: completedPortion,
              minHeight: 5,
              backgroundColor: Colors.white.withValues(alpha: 0.14),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF7DE0BD)),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _SummaryStat(
                  icon: Icons.check_circle_rounded,
                  value: paidCount.toString(),
                  label: 'Paid',
                  accent: const Color(0xFF9DE9CD),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SummaryStat(
                  icon: Icons.schedule_rounded,
                  value: pendingCount.toString(),
                  label: 'In Progress',
                  accent: const Color(0xFFF6D483),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SummaryStat(
                  icon: Icons.info_outline_rounded,
                  value: failedCount.toString(),
                  label: 'Unsuccessful',
                  accent: const Color(0xFFFFB4BA),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({
    required this.icon,
    required this.value,
    required this.label,
    required this.accent,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(icon, color: accent, size: 17),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFFD0E2E4),
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          height: 34,
          width: 34,
          decoration: BoxDecoration(
            color: _TxnPalette.brand(context).withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(
            Icons.receipt_long_rounded,
            size: 19,
            color: _TxnPalette.brand(context),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: _TxnPalette.text(context),
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: _TxnPalette.secondaryText(context),
            fontWeight: FontWeight.w600,
            fontSize: 10.5,
          ),
        ),
      ],
    );
  }
}

class _FilterTabs extends StatelessWidget {
  const _FilterTabs({
    required this.active,
    required this.allCount,
    required this.paidCount,
    required this.pendingCount,
    required this.failedCount,
    required this.onChanged,
  });

  final _TxnFilter active;
  final int allCount;
  final int paidCount;
  final int pendingCount;
  final int failedCount;
  final ValueChanged<_TxnFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _FilterTab(
            icon: Icons.grid_view_rounded,
            label: 'All',
            count: allCount,
            selected: active == _TxnFilter.all,
            onTap: () => onChanged(_TxnFilter.all),
          ),
          const SizedBox(width: 8),
          _FilterTab(
            icon: Icons.check_circle_outline_rounded,
            label: 'Paid',
            count: paidCount,
            selected: active == _TxnFilter.paid,
            onTap: () => onChanged(_TxnFilter.paid),
          ),
          const SizedBox(width: 8),
          _FilterTab(
            icon: Icons.schedule_rounded,
            label: 'In Progress',
            count: pendingCount,
            selected: active == _TxnFilter.pending,
            onTap: () => onChanged(_TxnFilter.pending),
          ),
          const SizedBox(width: 8),
          _FilterTab(
            icon: Icons.info_outline_rounded,
            label: 'Unsuccessful',
            count: failedCount,
            selected: active == _TxnFilter.failed,
            onTap: () => onChanged(_TxnFilter.failed),
          ),
        ],
      ),
    );
  }
}

class _FilterTab extends StatelessWidget {
  const _FilterTab({
    required this.icon,
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color teal = _TxnPalette.brand(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 170),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: selected ? teal : _TxnPalette.surface(context),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: selected ? teal : _TxnPalette.border(context),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected ? Colors.white : teal,
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : _TxnPalette.text(context),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                count.toString(),
                style: TextStyle(
                  color: selected
                      ? Colors.white.withValues(alpha: 0.85)
                      : _TxnPalette.secondaryText(context),
                  fontWeight: FontWeight.w700,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Every transaction is a distinct, tappable card with its own payment icon.
// The newest record receives a green accent independent of its payment status.
class _TransactionCard extends StatelessWidget {
  const _TransactionCard({
    required this.icon,
    required this.iconAccent,
    required this.statusAccent,
    required this.method,
    required this.sourceLabel,
    required this.reference,
    required this.dateText,
    required this.status,
    required this.amount,
    required this.isLatest,
    required this.onTap,
  });

  final IconData icon;
  final Color iconAccent;
  final Color statusAccent;
  final String method;
  final String sourceLabel;
  final String reference;
  final String dateText;
  final String status;
  final double amount;
  final bool isLatest;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color teal = _TxnPalette.brand(context);
    final Color green = _TxnPalette.success(context);

    return Material(
      color: _TxnPalette.surface(context),
      elevation: isLatest ? 3 : 0,
      shadowColor: green.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isLatest
                  ? green.withValues(alpha: 0.45)
                  : _TxnPalette.border(context),
              width: isLatest ? 1.4 : 1,
            ),
          ),
          padding: const EdgeInsets.fromLTRB(15, 15, 15, 13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PaymentIcon(icon: icon, accent: iconAccent, highlighted: isLatest),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                method,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  color: _TxnPalette.text(context),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            if (isLatest) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: green.withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(7),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.bolt_rounded, size: 12, color: green),
                                    const SizedBox(width: 2),
                                    Text(
                                      'Latest',
                                      style: TextStyle(
                                        color: green,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          sourceLabel,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: _TxnPalette.secondaryText(context),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '\u20B1 ${amount.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: _TxnPalette.text(context),
                          fontSize: 23,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.6,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _StatusMark(text: status, accent: statusAccent),
                ],
              ),
              const SizedBox(height: 14),
              Divider(
                height: 1,
                color: _TxnPalette.border(context),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    color: teal,
                    size: 14,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      dateText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: _TxnPalette.secondaryText(context),
                        fontSize: 11.3,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.tag_rounded, color: teal, size: 15),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      'Ref: $reference',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: _TxnPalette.secondaryText(context),
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Details',
                    style: TextStyle(
                      color: teal,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: teal, size: 19),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaymentIcon extends StatelessWidget {
  const _PaymentIcon({
    required this.icon,
    required this.accent,
    this.highlighted = false,
  });

  final IconData icon;
  final Color accent;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 47,
      height: 47,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: highlighted ? 0.18 : 0.10),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: accent.withValues(alpha: highlighted ? 0.38 : 0.12),
        ),
      ),
      child: Icon(icon, color: accent, size: 23),
    );
  }
}

class _StatusMark extends StatelessWidget {
  const _StatusMark({required this.text, required this.accent});

  final String text;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final IconData statusIcon = text == 'Paid'
        ? Icons.check_circle_rounded
        : text == 'In Progress'
        ? Icons.schedule_rounded
        : Icons.info_outline_rounded;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statusIcon, color: accent, size: 12.5),
          const SizedBox(width: 5),
          Text(
            text,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: accent,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 32,
            width: 32,
            decoration: BoxDecoration(
              color: _TxnPalette.brand(context).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: _TxnPalette.brand(context), size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: _TxnPalette.secondaryText(context),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: _TxnPalette.text(context),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _TxnPalette.surface(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _TxnPalette.border(context)),
      ),
      child: child,
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: CircularProgressIndicator(color: _TxnPalette.brand(context)),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: _Panel(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.wifi_off_rounded,
                size: 42,
                color: _TxnPalette.brand(context),
              ),
              const SizedBox(height: 12),
              Text(
                'Transaction History Unavailable',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: _TxnPalette.text(context),
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: _TxnPalette.secondaryText(context),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: _TxnPalette.brand(context),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Try Again'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Row(
        children: [
          Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              color: _TxnPalette.brand(context).withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              Icons.receipt_long_outlined,
              color: _TxnPalette.brand(context),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: _TxnPalette.text(context),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: _TxnPalette.secondaryText(context),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
