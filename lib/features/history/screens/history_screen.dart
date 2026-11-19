// HISTORY PROFESSIONAL POLISH: unified bills UI, exact bill navigation, and a non-repetitive transaction summary with clear paid/in-progress/failed states
import 'package:flutter/material.dart';

import '../../../core/services/bill_payment_deadline.dart';
import '../../../core/services/billing_service.dart';
import '../../../core/services/payments_service.dart';
import '../../../core/services/session_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../bills/screens/bill_details_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({
    super.key,
    this.initialTab = 0,
  });

  /// 0 = Bills, 1 = Transactions.
  ///
  /// Normal bottom-navigation use keeps the default Bills tab. Notification
  /// navigation may pass 1 so payment alerts land directly on Transactions.
  final int initialTab;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with WidgetsBindingObserver {
  late Future<Map<String, dynamic>?> _sessionFuture;
  Future<Map<String, dynamic>>? _billingFuture;
  Future<Map<String, dynamic>>? _paymentsFuture;

  final TextEditingController _searchCtrl = TextEditingController();

  late int _selectedTab; // 0 = Bills, 1 = Transactions
  String _query = '';

  String _billFilter = 'ALL';
  String _paymentFilter = 'ALL';
  String _paymentSort = 'Newest';

  String _activeAccountNo = '';
  bool _resumeRefreshInProgress = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _selectedTab = widget.initialTab.clamp(0, 1);
    _sessionFuture = SessionService.loadUser();
    _searchCtrl.addListener(() {
      setState(() => _query = _searchCtrl.text.trim().toLowerCase());
    });
  }

  @override
  void didUpdateWidget(covariant HistoryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    final int nextTab = widget.initialTab.clamp(0, 1);

    if (oldWidget.initialTab != widget.initialTab &&
        _selectedTab != nextTab) {
      setState(() {
        _selectedTab = nextTab;
        _query = '';
        _searchCtrl.clear();
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _activeAccountNo.isNotEmpty &&
        !_resumeRefreshInProgress) {
      _refreshAfterAppResume();
    }
  }

  Future<void> _refreshAfterAppResume() async {
    if (_resumeRefreshInProgress ||
        _activeAccountNo.isEmpty ||
        !mounted) {
      return;
    }

    _resumeRefreshInProgress = true;

    try {
      await _refresh(_activeAccountNo);
    } finally {
      _resumeRefreshInProgress = false;
    }
  }

  void _loadAll(String accountNo) {
    _activeAccountNo = accountNo.trim();
    _billingFuture = BillingService.getBillingHistory(accountNo: accountNo);
    _paymentsFuture = PaymentsService.getPaymentsHistory(accountNo: accountNo);
  }

  Future<void> _refresh(String accountNo) async {
    setState(() => _loadAll(accountNo));
    try {
      await Future.wait([
        _billingFuture!,
        _paymentsFuture!,
      ]);
    } catch (_) {}
  }

  int? _extractBillId(dynamic bill) {
    if (bill is Map) {
      final raw = bill['id'] ?? bill['bill_id'] ?? bill['billId'];
      if (raw == null) return null;
      return int.tryParse(raw.toString());
    }
    return null;
  }

  int? _extractInt(dynamic raw) {
    if (raw == null) return null;
    return int.tryParse(raw.toString());
  }

  String _firstName(String fullName) {
    final cleaned = fullName.trim();
    if (cleaned.isEmpty) return '';
    return cleaned.split(RegExp(r'\s+')).first;
  }

  DateTime? _parseDate(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return null;

    try {
      return DateTime.parse(value);
    } catch (_) {}

    try {
      return DateTime.parse(value.replaceFirst(' ', 'T'));
    } catch (_) {}

    return null;
  }

  double _toDouble(dynamic raw) {
    if (raw is num) return raw.toDouble();
    return double.tryParse(raw.toString()) ?? 0;
  }

  String _monthName(int month) {
    const names = [
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
    return names[(month - 1).clamp(0, 11)];
  }

  bool _isReasonableBillingYear(int year) {
    return year >= 2000 && year <= 2100;
  }

  String _displayMonth(String input) {
    final value = input.trim();
    if (value.isEmpty) return 'Billing record';

    final match = RegExp(r'^(\d{4})-(\d{2})$').firstMatch(value);
    if (match != null) {
      final int? year = int.tryParse(match.group(1) ?? '');
      final int? month = int.tryParse(match.group(2) ?? '');

      if (year != null &&
          month != null &&
          month >= 1 &&
          month <= 12 &&
          _isReasonableBillingYear(year)) {
        return '${_monthName(month)} $year';
      }

      return 'Billing record';
    }

    final dt = _parseDate(value);
    if (dt != null && _isReasonableBillingYear(dt.year)) {
      return '${_monthName(dt.month)} ${dt.year}';
    }

    return 'Billing record';
  }

  String _shortDate(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return '—';

    final parsed = _parseDate(value);
    if (parsed == null) return value;

    final DateTime dt = parsed.isUtc ? parsed.toLocal() : parsed;
    final int hour12 = dt.hour == 0
        ? 12
        : dt.hour > 12
        ? dt.hour - 12
        : dt.hour;
    final String minute = dt.minute.toString().padLeft(2, '0');
    final String period = dt.hour >= 12 ? 'PM' : 'AM';

    return '${_monthName(dt.month)} ${dt.day}, ${dt.year} • '
        '$hour12:$minute $period';
  }

  String _displayDate(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return '—';

    final parsed = _parseDate(value);
    if (parsed == null) return value;

    final DateTime dt = parsed.isUtc ? parsed.toLocal() : parsed;
    return '${_monthName(dt.month)} ${dt.day}, ${dt.year}';
  }

  String _paymentMethodLabel(Map payment) {
    final String provider =
    (payment['provider'] ?? '').toString().trim().toUpperCase();
    final String channel =
    (payment['payment_channel'] ?? '')
        .toString()
        .trim()
        .toUpperCase();
    final String method =
    (payment['method'] ?? 'Payment').toString().trim();

    if (provider == 'ILECO' && (channel.isEmpty || channel == 'OFFICE')) {
      return 'Office Payment';
    }

    final String providerLabel =
    provider == 'PAYMONGO'
        ? 'PayMongo'
        : (provider == 'ILECO' ? 'Cooperative Payment' : provider);
    final String channelLabel =
    channel == 'QRPH' ? 'QR Ph' : channel;

    if (providerLabel.isNotEmpty && channelLabel.isNotEmpty) {
      return '$providerLabel • $channelLabel';
    }

    if (providerLabel.isNotEmpty) {
      return providerLabel;
    }

    if (channelLabel.isNotEmpty) {
      return channelLabel;
    }

    return method.isEmpty ? 'Payment' : method;
  }

  bool _isSuccessfulPaymentStatus(String status) {
    final String normalized = status.trim().toUpperCase();
    return normalized == 'SUCCESS' ||
        normalized == 'PAID' ||
        normalized == 'COMPLETED';
  }

  bool _isInProgressPaymentStatus(String status) {
    final String normalized = status.trim().toUpperCase();
    return normalized == 'PENDING' || normalized == 'PROCESSING';
  }

  bool _isFailedPaymentStatus(String status) {
    final String normalized = status.trim().toUpperCase();
    return normalized == 'FAILED' ||
        normalized == 'CANCELLED' ||
        normalized == 'CANCELED' ||
        normalized == 'DECLINED' ||
        normalized == 'EXPIRED';
  }

  String _paymentStatusLabel(String status) {
    final String normalized = status.trim().toUpperCase();

    if (_isSuccessfulPaymentStatus(normalized)) {
      return 'PAID';
    }

    if (_isInProgressPaymentStatus(normalized)) {
      return 'IN PROGRESS';
    }

    if (normalized == 'CANCELLED' || normalized == 'CANCELED') {
      return 'CANCELLED';
    }

    return normalized.isEmpty ? 'RECORDED' : normalized;
  }

  String _paymentDateLabel(String status) {
    final String normalized = status.trim().toUpperCase();

    if (_isSuccessfulPaymentStatus(normalized)) {
      return 'Paid';
    }

    if (normalized == 'PENDING' || normalized == 'PROCESSING') {
      return 'Started';
    }

    return 'Recorded';
  }

  String _billReference(Map bill) {
    final String billNo = (bill['bill_no'] ?? '').toString().trim();

    if (billNo.isNotEmpty) {
      if (RegExp(r'^\d+$').hasMatch(billNo)) {
        return 'Bill #$billNo';
      }
      return billNo;
    }

    final int? billId = _extractBillId(bill);
    return billId == null ? 'Billing statement' : 'Bill #$billId';
  }

  String _paymentTimestampRaw(Map payment) {
    final String paidAt =
    (payment['paid_at'] ?? '').toString().trim();
    if (paidAt.isNotEmpty) return paidAt;

    return (payment['created_at'] ?? '').toString().trim();
  }

  String _paymentGroupLabel(String key) {
    if (key == 'Recent') return 'Recent activity';

    final String label = _displayMonth(key);
    return label == 'Billing record' ? 'Recent activity' : label;
  }

  String _groupKeyForPayment(Map payment) {
    final String paidAt = _paymentTimestampRaw(payment);
    final dt = _parseDate(paidAt);
    if (dt != null) {
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
    }
    return 'Recent';
  }

  String _normaliseBillStatus(dynamic value) {
    final String status = value?.toString().trim().toUpperCase() ?? '';

    return status == 'PAID' ? 'PAID' : 'UNPAID';
  }

  String _billDisplayStatus(Map bill) {
    final String stored = _normaliseBillStatus(
      bill['payment_status'],
    );

    if (stored == 'PAID') {
      return 'PAID';
    }

    final String dueDate =
    (bill['due_date'] ?? '').toString().trim();
    final int? days = BillPaymentDeadline.daysUntilDue(dueDate);

    if (days == null) {
      return 'UNPAID';
    }

    if (days < 0) {
      return 'OVERDUE';
    }

    if (days == 0) {
      return 'DUE TODAY';
    }

    return 'UNPAID';
  }

  bool _matchesBillQuery(Map bill) {
    if (_query.isEmpty) return true;

    final month = (bill['billing_month'] ?? '').toString().toLowerCase();
    final status = _billDisplayStatus(bill).toLowerCase();
    final due = (bill['due_date'] ?? '').toString().toLowerCase();
    final amount = (bill['total_amount_due'] ?? '').toString().toLowerCase();
    final kwh = (bill['kwh_used'] ?? '').toString().toLowerCase();

    return month.contains(_query) ||
        status.contains(_query) ||
        due.contains(_query) ||
        amount.contains(_query) ||
        kwh.contains(_query);
  }

  bool _matchesPaymentQuery(Map payment) {
    if (_query.isEmpty) return true;

    final method = (payment['method'] ?? '').toString().toLowerCase();
    final status = (payment['status'] ?? '').toString().toLowerCase();
    final ref = (payment['reference_no'] ?? '').toString().toLowerCase();
    final amount = (payment['amount'] ?? '').toString().toLowerCase();
    final paidAt = _paymentTimestampRaw(payment).toLowerCase();
    final billId = (payment['bill_id'] ?? '').toString().toLowerCase();

    return method.contains(_query) ||
        status.contains(_query) ||
        ref.contains(_query) ||
        amount.contains(_query) ||
        paidAt.contains(_query) ||
        billId.contains(_query);
  }

  bool _matchesBillFilter(Map bill) {
    if (_billFilter == 'ALL') return true;

    final String status = _normaliseBillStatus(
      bill['payment_status'],
    );

    return status == _billFilter;
  }

  bool _matchesPaymentFilter(Map payment) {
    if (_paymentFilter == 'ALL') return true;

    final String status =
    (payment['status'] ?? '').toString().trim().toUpperCase();

    if (_paymentFilter == 'PAID' || _paymentFilter == 'SUCCESSFUL') {
      return _isSuccessfulPaymentStatus(status);
    }

    if (_paymentFilter == 'IN PROGRESS') {
      return _isInProgressPaymentStatus(status);
    }

    if (_paymentFilter == 'FAILED / CANCELLED' ||
        _paymentFilter == 'FAILED') {
      return _isFailedPaymentStatus(status);
    }

    return true;
  }

  void _sortBills(List<Map> bills) {
// Billing History always opens with every bill visible, newest first.
// Paid / Unpaid only narrow the list; they do not change its order.
    bills.sort((a, b) {
      final DateTime da =
          _parseDate((a['due_date'] ?? '').toString()) ?? DateTime(1900);
      final DateTime db =
          _parseDate((b['due_date'] ?? '').toString()) ?? DateTime(1900);

      final int byDate = db.millisecondsSinceEpoch.compareTo(
        da.millisecondsSinceEpoch,
      );
      if (byDate != 0) return byDate;

      final int aId = _extractBillId(a) ?? 0;
      final int bId = _extractBillId(b) ?? 0;
      return bId.compareTo(aId);
    });
  }

  void _sortPayments(List<Map> payments) {
    switch (_paymentSort) {
      case 'Oldest':
        payments.sort((a, b) {
          final da =
              (_parseDate(_paymentTimestampRaw(a)) ?? DateTime(1900))
                  .millisecondsSinceEpoch;
          final db =
              (_parseDate(_paymentTimestampRaw(b)) ?? DateTime(1900))
                  .millisecondsSinceEpoch;
          return da.compareTo(db);
        });
        break;
      case 'Highest amount':
        payments.sort(
              (a, b) => _toDouble(b['amount']).compareTo(_toDouble(a['amount'])),
        );
        break;
      case 'Lowest amount':
        payments.sort(
              (a, b) => _toDouble(a['amount']).compareTo(_toDouble(b['amount'])),
        );
        break;
      default:
        payments.sort((a, b) {
          final da =
              (_parseDate(_paymentTimestampRaw(a)) ?? DateTime(1900))
                  .millisecondsSinceEpoch;
          final db =
              (_parseDate(_paymentTimestampRaw(b)) ?? DateTime(1900))
                  .millisecondsSinceEpoch;
          return db.compareTo(da);
        });
    }
  }

  _StatusStyle _billStatusStyle(String status) {
    final String normalized = status.trim().toUpperCase();

    if (normalized == 'PAID') {
      return _StatusStyle(
        icon: Icons.verified_rounded,
        accent: _HistoryPalette.success(context),
        solid: true,
      );
    }

    if (normalized == 'OVERDUE') {
      return _StatusStyle(
        icon: Icons.warning_amber_rounded,
        accent: _HistoryPalette.danger(context),
        solid: true,
      );
    }

    return _StatusStyle(
      icon: Icons.schedule_rounded,
      accent: _HistoryPalette.warning(context),
      solid: true,
    );
  }

  _StatusStyle _paymentStatusStyle(String status) {
    final String normalized = status.toUpperCase().trim();

    if (normalized == 'SUCCESS' ||
        normalized == 'PAID' ||
        normalized == 'COMPLETED') {
      return _StatusStyle(
        icon: Icons.verified_rounded,
        accent: _HistoryPalette.success(context),
        solid: true,
      );
    }

    if (normalized == 'PENDING' || normalized == 'PROCESSING') {
      return _StatusStyle(
        icon: Icons.hourglass_top_rounded,
        accent: _HistoryPalette.warning(context),
        solid: true,
      );
    }

    if (normalized == 'FAILED' ||
        normalized == 'CANCELLED' ||
        normalized == 'CANCELED' ||
        normalized == 'DECLINED' ||
        normalized == 'EXPIRED') {
      return _StatusStyle(
        icon: Icons.error_rounded,
        accent: _HistoryPalette.danger(context),
        solid: true,
      );
    }

    return _StatusStyle(
      icon: Icons.account_balance_wallet_rounded,
      accent: _HistoryPalette.info(context),
      solid: false,
    );
  }

  void _showTransactionDetails(Map payment) {
    final method = _paymentMethodLabel(payment);
    final ref = (payment['reference_no'] ?? 'N/A').toString();
    final status = (payment['status'] ?? 'Unknown').toString().toUpperCase();
    final amount = double.tryParse((payment['amount'] ?? 0).toString()) ?? 0;
    final paidAt = _shortDate(_paymentTimestampRaw(payment));
    final dateLabel = '${_paymentDateLabel(status)} at';
    final billId = _extractInt(payment['bill_id']);

    final style = _paymentStatusStyle(status);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final double maxHeight =
            MediaQuery.of(context).size.height * 0.78;

        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxHeight),
              child: SingleChildScrollView(
                child: _GlassShell(
                  padding: const EdgeInsets.all(16),
                  borderRadius: 28,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          _IconBubble(
                            icon: style.icon,
                            accent: style.accent,
                            size: 40,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Transaction Details',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          _StatusChip(
                            text: _paymentStatusLabel(status),
                            accent: style.accent,
                            solid: style.solid,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _InfoStrip(
                        icon: Icons.account_balance_wallet_rounded,
                        title: 'Amount',
                        value: '₱ ${amount.toStringAsFixed(2)}',
                        accent: _HistoryPalette.gold(context),
                      ),
                      const SizedBox(height: 12),
                      _DetailRow(label: 'Method', value: method),
                      _DetailRow(label: 'Reference', value: ref),
                      _DetailRow(label: dateLabel, value: paidAt),
                      _DetailRow(
                        label: 'Bill ID',
                        value: billId?.toString() ?? 'Not linked',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _searchHint() {
    return _selectedTab == 0
        ? 'Search bills, status, amount'
        : 'Search reference, method, amount';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _HistoryPalette.background(context),
      body: Stack(
        children: [
          const _HistoryBackdrop(),
          SafeArea(
            bottom: false,
            child: FutureBuilder<Map<String, dynamic>?>(
              future: _sessionFuture,
              builder: (context, snapUser) {
                if (snapUser.connectionState == ConnectionState.waiting) {
                  return const _SkeletonList();
                }

                if (snapUser.hasError) {
                  return _CenteredMessageCard(
                    title: 'Failed to load session',
                    subtitle: snapUser.error
                        .toString()
                        .replaceFirst('Exception: ', ''),
                    icon: Icons.person_off_rounded,
                  );
                }

                final user = snapUser.data;
                if (user == null) {
                  return const _CenteredMessageCard(
                    title: 'No session found',
                    subtitle: 'Please login again to load your history.',
                    icon: Icons.login_rounded,
                  );
                }

                final accountNo = (user['account_no'] ?? '').toString();
                final fullName = (user['name'] ?? 'My Account').toString();
                final displayName = _firstName(fullName);
                final address = (user['address'] ?? '').toString();

                if (_billingFuture == null || _paymentsFuture == null) {
                  _loadAll(accountNo);
                }

                return RefreshIndicator(
                  color: _HistoryPalette.primary(context),
                  backgroundColor: _HistoryPalette.surface(context),
                  onRefresh: () => _refresh(accountNo),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: [
                      _TopHeader(
                        title: _selectedTab == 0 ? 'Billing History' : 'Transaction History',
                        subtitle: address.trim().isEmpty
                            ? 'Your electric bills and payment records'
                            : address,
                        accountNo: accountNo,
                      ),
                      const SizedBox(height: 12),
                      _HistoryTabSwitch(
                        selectedIndex: _selectedTab,
                        onChanged: (index) {
                          if (_selectedTab == index) return;

                          _searchCtrl.clear();
                          setState(() {
                            _selectedTab = index;
                            if (index == 0) {
                              _billFilter = 'ALL';
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      _PremiumSearchBar(
                        controller: _searchCtrl,
                        hint: _searchHint(),
                        helper: _selectedTab == 0
                            ? 'Find a bill quickly.'
                            : 'Find a payment quickly.',
                        onClear: () => _searchCtrl.clear(),
                      ),
                      const SizedBox(height: 12),
                      if (_selectedTab == 1)
                        _DropdownFilterDeck(
                          title: 'Transaction Controls',
                          filterLabel: 'Transaction Status',
                          filterValue: _paymentFilter,
                          filterItems: const [
                            'ALL',
                            'PAID',
                            'IN PROGRESS',
                            'FAILED / CANCELLED',
                          ],
                          onFilterChanged: (value) {
                            if (value == null) return;
                            setState(() => _paymentFilter = value);
                          },
                          sortLabel: 'Sort Transactions',
                          sortValue: _paymentSort,
                          sortItems: const [
                            'Newest',
                            'Oldest',
                            'Highest amount',
                            'Lowest amount',
                          ],
                          onSortChanged: (value) {
                            if (value == null) return;
                            setState(() => _paymentSort = value);
                          },
                        ),
                      const SizedBox(height: 12),
                      if (_selectedTab == 0)
                        FutureBuilder<Map<String, dynamic>>(

                          future: _billingFuture,
                          builder: (context, snap) {
                            if (snap.connectionState ==
                                ConnectionState.waiting) {
                              return const _SkeletonContent();
                            }

                            if (snap.hasError) {
                              return _ErrorState(
                                message: snap.error
                                    .toString()
                                    .replaceFirst('Exception: ', ''),
                                onRetry: () => setState(
                                      () => _billingFuture =
                                      BillingService.getBillingHistory(
                                        accountNo: accountNo,
                                      ),
                                ),
                              );
                            }

                            final data = snap.data ?? {};
                            final rawBills = (data['bills'] as List?) ??
                                (data['items'] as List?) ??
                                [];
                            final bills = rawBills.whereType<Map>().toList();

                            final filtered = bills.where((bill) {
                              return _matchesBillQuery(bill) &&
                                  _matchesBillFilter(bill);
                            }).toList();

                            _sortBills(filtered);

                            final paidCount = bills.where((b) {
                              final String status = _normaliseBillStatus(
                                b['payment_status'],
                              );

                              return status == 'PAID';
                            }).length;

                            final unpaidCount = bills.length - paidCount;

                            final totalOutstanding = bills.where((b) {
                              final String status = _normaliseBillStatus(
                                b['payment_status'],
                              );

                              return status == 'UNPAID';
                            }).fold<double>(
                              0,
                                  (sum, item) =>
                              sum + _toDouble(item['total_amount_due']),
                            );

                            if (bills.isEmpty) {
                              return const _EmptyState(
                                icon: Icons.receipt_long_rounded,
                                title: 'No billing history yet',
                                subtitle:
                                'Your electric bills will appear here when they are available. Pull down to refresh.',
                              );
                            }

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _BillOverviewCard(
                                  totalBills: bills.length,
                                  paidBills: paidCount,
                                  openBills: unpaidCount,
                                  outstanding: totalOutstanding,
                                ),
                                const SizedBox(height: 20),
                                _SectionTitle(
                                  title: 'Billing Statements',
                                  subtitle: filtered.length == bills.length
                                      ? '${bills.length} Bills'
                                      : 'Showing ${filtered.length} of ${bills.length}',
                                ),
                                const SizedBox(height: 10),
                                _BillFilterTabs(
                                  value: _billFilter,
                                  onChanged: (value) {
                                    if (_billFilter == value) return;
                                    setState(() => _billFilter = value);
                                  },
                                ),
                                const SizedBox(height: 12),
                                if (filtered.isEmpty)
                                  const _EmptyState(
                                    icon: Icons.search_off_rounded,
                                    title: 'No matching bills',
                                    subtitle:
                                    'Try another search or choose All, PAID, or UNPAID above.',
                                  )
                                else
                                  _BillListSurface(
                                    children: filtered.map((bill) {
                                      final String month =
                                      (bill['billing_month'] ?? '').toString();
                                      final String due =
                                      (bill['due_date'] ?? '').toString();
                                      final String status =
                                      _billDisplayStatus(bill);
                                      final double amount =
                                      _toDouble(bill['total_amount_due']);
                                      final String kwh =
                                      (bill['kwh_used'] ?? '')
                                          .toString()
                                          .trim();
                                      final int? billId = _extractBillId(bill);
                                      final style = _billStatusStyle(status);
                                      final bool canOpenBill =
                                          billId != null && billId > 0;

                                      return _BillStatementTile(
                                        monthLabel: _displayMonth(month),
                                        reference: _billReference(bill),
                                        dueDate: due.isEmpty
                                            ? 'Not available'
                                            : _displayDate(due),
                                        usage: kwh.isEmpty
                                            ? null
                                            : '$kwh kWh',
                                        amount: amount,
                                        status: status,
                                        accent: style.accent,
                                        canOpen: canOpenBill,
                                        onTap: canOpenBill
                                            ? () {
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  BillDetailsScreen(
                                                    nickname:
                                                    displayName.isEmpty
                                                        ? 'My Account'
                                                        : displayName,
                                                    accountNo: accountNo,
                                                    address: address,
                                                    month: month,
                                                    amount: amount,
                                                    dueDate: due,
                                                    status: status,
                                                    billId: billId,
                                                  ),
                                            ),
                                          );
                                        }
                                            : null,
                                      );
                                    }).toList(growable: false),
                                  ),
                              ],
                            );
                          },
                        )
                      else
                        FutureBuilder<Map<String, dynamic>>(
                          future: _paymentsFuture,
                          builder: (context, snap) {
                            if (snap.connectionState ==
                                ConnectionState.waiting) {
                              return const _SkeletonContent();
                            }

                            if (snap.hasError) {
                              return _ErrorState(
                                message: snap.error
                                    .toString()
                                    .replaceFirst('Exception: ', ''),
                                onRetry: () => setState(
                                      () => _paymentsFuture =
                                      PaymentsService.getPaymentsHistory(
                                        accountNo: accountNo,
                                      ),
                                ),
                              );
                            }

                            final data = snap.data ?? {};
                            final rawPayments = (data['payments'] as List?) ??
                                (data['transactions'] as List?) ??
                                (data['items'] as List?) ??
                                (data['history'] as List?) ??
                                [];
                            final payments =
                            rawPayments.whereType<Map>().toList();

                            final filtered = payments.where((payment) {
                              return _matchesPaymentQuery(payment) &&
                                  _matchesPaymentFilter(payment);
                            }).toList();

                            _sortPayments(filtered);

                            final int paidCount = payments.where((payment) {
                              final String status =
                              (payment['status'] ?? '')
                                  .toString()
                                  .trim()
                                  .toUpperCase();
                              return _isSuccessfulPaymentStatus(status);
                            }).length;

                            final int inProgressCount =
                                payments.where((payment) {
                                  final String status =
                                  (payment['status'] ?? '')
                                      .toString()
                                      .trim()
                                      .toUpperCase();
                                  return _isInProgressPaymentStatus(status);
                                }).length;

                            final int failedCount = payments.where((payment) {
                              final String status =
                              (payment['status'] ?? '')
                                  .toString()
                                  .trim()
                                  .toUpperCase();
                              return _isFailedPaymentStatus(status);
                            }).length;

                            final double totalAmountPaid = payments
                                .where((payment) {
                              final String status =
                              (payment['status'] ?? '')
                                  .toString()
                                  .trim()
                                  .toUpperCase();
                              return _isSuccessfulPaymentStatus(status);
                            })
                                .fold<double>(
                              0,
                                  (sum, item) =>
                              sum + _toDouble(item['amount']),
                            );

                            final Map<String, List<Map>> groups = {};
                            for (final payment in filtered) {
                              final key = _groupKeyForPayment(payment);
                              groups.putIfAbsent(key, () => []);
                              groups[key]!.add(payment);
                            }

                            final groupKeys = groups.keys.toList()
                              ..sort((a, b) => b.compareTo(a));

                            if (payments.isEmpty) {
                              return const _EmptyState(
                                icon: Icons.payments_rounded,
                                title: 'No transactions yet',
                                subtitle:
                                'Payment records will appear here once available.',
                              );
                            }

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _TransactionOverviewCard(
                                  totalAmountPaid: totalAmountPaid,
                                  paidCount: paidCount,
                                  inProgressCount: inProgressCount,
                                  failedCount: failedCount,
                                ),
                                const SizedBox(height: 20),
                                _SectionTitle(
                                  title: 'Payment Activity',
                                  subtitle: filtered.length == payments.length
                                      ? '${payments.length} Records'
                                      : 'Showing ${filtered.length} of ${payments.length}',
                                ),
                                const SizedBox(height: 10),
                                if (filtered.isEmpty)
                                  const _EmptyState(
                                    icon: Icons.search_off_rounded,
                                    title: 'No matching transactions',
                                    subtitle:
                                    'Try a different search or change the transaction filter above.',
                                  )
                                else
                                  ...groupKeys.expand((key) {
                                    final items = groups[key]!;

                                    return [
                                      const SizedBox(height: 6),
                                      _SectionTitle(
                                        title: _paymentGroupLabel(key),
                                        subtitle: items.length == 1
                                            ? '1 record'
                                            : '${items.length} records',
                                      ),
                                      const SizedBox(height: 8),
                                      ...items.map((payment) {
                                        final method =
                                        _paymentMethodLabel(payment);
                                        final ref = (payment['reference_no'] ??
                                            'No reference')
                                            .toString();
                                        final status =
                                        (payment['status'] ?? 'UNKNOWN')
                                            .toString()
                                            .toUpperCase();
                                        final amount = double.tryParse(
                                          (payment['amount'] ?? 0)
                                              .toString(),
                                        ) ??
                                            0;
                                        final paidAt = _shortDate(
                                          _paymentTimestampRaw(payment),
                                        );
                                        final paymentDateLabel =
                                        _paymentDateLabel(status);
                                        final style =
                                        _paymentStatusStyle(status);

                                        return Padding(
                                          padding:
                                          const EdgeInsets.only(bottom: 10),
                                          child: _HistoryItemCard(
                                            leading: _IconBubble(
                                              icon: style.icon,
                                              accent: style.accent,
                                              size: 40,
                                            ),
                                            title: method,
                                            subtitleTop: ref,
                                            subtitleBottom:
                                            '$paymentDateLabel: $paidAt',
                                            amount: amount,
                                            statusChip: _StatusChip(
                                              text:
                                              _paymentStatusLabel(status),
                                              accent: style.accent,
                                              solid: style.solid,
                                            ),
                                            extraTags: const [],
                                            actionText: 'Details',
                                            onTap: () =>
                                                _showTransactionDetails(
                                                    payment),
                                          ),
                                        );
                                      }),
                                    ];
                                  }),
                              ],
                            );
                          },
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryPalette {
  static bool _isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  // KuryentePay design tokens. These are presentation colors only.
  static const Color navy = Color(0xFF102F3E);
  static const Color teal = Color(0xFF087F79);
  static const Color softGold = Color(0xFFF6D483);

  static Color background(BuildContext context) =>
      _isDark(context) ? const Color(0xFF071D26) : const Color(0xFFF4F7FA);

  static Color surface(BuildContext context) =>
      _isDark(context) ? const Color(0xFF112D38) : Colors.white;

  static Color border(BuildContext context) =>
      _isDark(context) ? const Color(0xFF2A4D57) : const Color(0xFFDCE6EA);

  static Color primary(BuildContext context) =>
      _isDark(context) ? const Color(0xFF74D7C8) : teal;

  static Color info(BuildContext context) =>
      _isDark(context) ? const Color(0xFF74D7C8) : teal;

  static Color gold(BuildContext context) =>
      _isDark(context) ? softGold : const Color(0xFFA47524);

  static Color success(BuildContext context) =>
      _isDark(context) ? const Color(0xFF86E2B6) : const Color(0xFF168356);

  static Color warning(BuildContext context) =>
      _isDark(context) ? softGold : const Color(0xFFAA7425);

  static Color danger(BuildContext context) =>
      _isDark(context) ? const Color(0xFFFF9C9E) : const Color(0xFFC7424A);

  static Color secondaryText(BuildContext context) =>
      _isDark(context) ? const Color(0xFFBAD0D6) : const Color(0xFF5A707C);
}

class _HistoryType {
  static TextStyle pageTitle(BuildContext context) =>
      (Theme.of(context).textTheme.headlineSmall ?? const TextStyle()).copyWith(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.55,
        height: 1.10,
      );

  static TextStyle subtitle(BuildContext context) =>
      (Theme.of(context).textTheme.bodyMedium ?? const TextStyle()).copyWith(
        color: _HistoryPalette.secondaryText(context),
        fontSize: 13,
        fontWeight: FontWeight.w400,
        height: 1.35,
      );

  static TextStyle body(BuildContext context) =>
      (Theme.of(context).textTheme.bodyMedium ?? const TextStyle()).copyWith(
        fontSize: 13.5,
        fontWeight: FontWeight.w400,
        height: 1.30,
      );

  static TextStyle control(BuildContext context) =>
      (Theme.of(context).textTheme.labelLarge ?? const TextStyle()).copyWith(
        fontSize: 12.5,
        fontWeight: FontWeight.w500,
      );

  static TextStyle sectionTitle(BuildContext context) =>
      (Theme.of(context).textTheme.titleMedium ?? const TextStyle()).copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.20,
      );

  static TextStyle cardTitle(BuildContext context) =>
      (Theme.of(context).textTheme.titleMedium ?? const TextStyle()).copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w700,
      );

  static TextStyle money(BuildContext context) =>
      (Theme.of(context).textTheme.headlineMedium ?? const TextStyle()).copyWith(
        fontSize: 30,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.65,
      );

  static TextStyle billMonth(BuildContext context) =>
      (Theme.of(context).textTheme.titleMedium ?? const TextStyle()).copyWith(
        fontSize: 16.5,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.15,
      );

  static TextStyle billAmount(BuildContext context) =>
      (Theme.of(context).textTheme.headlineSmall ?? const TextStyle()).copyWith(
        fontSize: 25,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.45,
      );

  static TextStyle meta(BuildContext context) =>
      (Theme.of(context).textTheme.bodySmall ?? const TextStyle()).copyWith(
        color: _HistoryPalette.secondaryText(context),
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.30,
      );

  static TextStyle status(BuildContext context) =>
      (Theme.of(context).textTheme.labelMedium ?? const TextStyle()).copyWith(
        fontSize: 11.5,
        fontWeight: FontWeight.w600,
      );

  static TextStyle action(BuildContext context) =>
      (Theme.of(context).textTheme.bodyMedium ?? const TextStyle()).copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w600,
      );
}

class _StatusStyle {
  const _StatusStyle({
    required this.icon,
    required this.accent,
    required this.solid,
  });

  final IconData icon;
  final Color accent;
  final bool solid;
}

class _HistoryBackdrop extends StatelessWidget {
  const _HistoryBackdrop();

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? const [Color(0xFF071D26), Color(0xFF0B2731)]
                : const [Color(0xFFF4F8F8), Color(0xFFF4F7FA)],
          ),
        ),
      ),
    );
  }
}

class _GlassShell extends StatelessWidget {
  const _GlassShell({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 22,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: _HistoryPalette.surface(context),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: _HistoryPalette.border(context),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.20)
                : AppTheme.brandNavy.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _CenteredMessageCard extends StatelessWidget {
  const _CenteredMessageCard({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: _GlassShell(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _IconBubble(
                icon: icon,
                accent: _HistoryPalette.primary(context),
                size: 52,
              ),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: _HistoryPalette.secondaryText(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopHeader extends StatelessWidget {
  const _TopHeader({
    required this.title,
    required this.subtitle,
    required this.accountNo,
  });

  final String title;
  final String subtitle;
  final String accountNo;

  @override
  Widget build(BuildContext context) {
    final String value =
    accountNo.trim().isEmpty ? 'Not available' : accountNo.trim();
    final Color primary = _HistoryPalette.primary(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 8, 2, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(Icons.bolt_rounded, size: 18, color: primary),
              ),
              const SizedBox(width: 8),
              Text(
                'KuryentePay',
                style: _HistoryType.control(context).copyWith(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(title, style: _HistoryType.pageTitle(context)),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                subtitle == 'Your electric bills and payment records'
                    ? Icons.info_outline_rounded
                    : Icons.location_on_outlined,
                size: 16,
                color: _HistoryPalette.secondaryText(context),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  subtitle.trim(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: _HistoryType.subtitle(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            decoration: BoxDecoration(
              color: _HistoryPalette.surface(context),
              border: Border.all(color: _HistoryPalette.border(context)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.badge_outlined, size: 16, color: primary),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    'Account $value',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _HistoryType.meta(context).copyWith(
                      color: primary,
                      fontWeight: FontWeight.w700,
                    ),
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

class _HistoryTabSwitch extends StatelessWidget {
  const _HistoryTabSwitch({
    required this.selectedIndex,
    required this.onChanged,
  });

  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 53,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _HistoryPalette.surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _HistoryPalette.border(context)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SegmentButton(
              icon: Icons.receipt_long_outlined,
              text: 'Bills',
              selected: selectedIndex == 0,
              onTap: () => onChanged(0),
            ),
          ),
          Expanded(
            child: _SegmentButton(
              icon: Icons.account_balance_wallet_outlined,
              text: 'Transactions',
              selected: selectedIndex == 1,
              onTap: () => onChanged(1),
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  const _SegmentButton({
    required this.icon,
    required this.text,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String text;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color foreground = selected
        ? Colors.white
        : _HistoryPalette.secondaryText(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? _HistoryPalette.teal : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: foreground),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _HistoryType.control(context).copyWith(
                    color: foreground,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BillFilterTabs extends StatelessWidget {
  const _BillFilterTabs({
    required this.value,
    required this.onChanged,
  });

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    const options = <String>['ALL', 'PAID', 'UNPAID'];
    const labels = <String>['All', 'PAID', 'UNPAID'];
    const icons = <IconData>[
      Icons.grid_view_rounded,
      Icons.check_circle_outline_rounded,
      Icons.schedule_outlined,
    ];

    return Semantics(
      container: true,
      label: 'Bill status filter',
      child: Row(
        children: List.generate(options.length, (index) {
          final String option = options[index];
          final bool selected = value == option;
          final Color foreground = selected
              ? Colors.white
              : _HistoryPalette.secondaryText(context);
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: index == 2 ? 0 : 8),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => onChanged(option),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected
                          ? _HistoryPalette.teal
                          : _HistoryPalette.surface(context),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected
                            ? _HistoryPalette.teal
                            : _HistoryPalette.border(context),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(icons[index], color: foreground, size: 16),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            labels[index],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _HistoryType.control(context).copyWith(
                              color: foreground,
                              fontWeight: selected
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _DropdownFilterDeck extends StatelessWidget {
  const _DropdownFilterDeck({
    required this.title,
    required this.filterLabel,
    required this.filterValue,
    required this.filterItems,
    required this.onFilterChanged,
    required this.sortLabel,
    required this.sortValue,
    required this.sortItems,
    required this.onSortChanged,
  });

  final String title;
  final String filterLabel;
  final String filterValue;
  final List<String> filterItems;
  final ValueChanged<String?> onFilterChanged;
  final String sortLabel;
  final String sortValue;
  final List<String> sortItems;
  final ValueChanged<String?> onSortChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: title,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final Widget filter = _PremiumDropdownField(
            label: filterLabel,
            icon: Icons.filter_alt_rounded,
            value: filterValue,
            items: filterItems,
            onChanged: onFilterChanged,
          );

          final Widget sort = _PremiumDropdownField(
            label: sortLabel,
            icon: Icons.swap_vert_rounded,
            value: sortValue,
            items: sortItems,
            onChanged: onSortChanged,
          );

          if (constraints.maxWidth < 340) {
            return Column(
              children: [
                filter,
                const SizedBox(height: 8),
                sort,
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: filter),
              const SizedBox(width: 8),
              Expanded(child: sort),
            ],
          );
        },
      ),
    );
  }
}

String _controlLabel(String item) {
  switch (item) {
    case 'ALL': return 'All';
    case 'PAID': return 'PAID';
    case 'IN PROGRESS': return 'In Progress';
    case 'FAILED / CANCELLED': return 'Unsuccessful';
    case 'Highest amount': return 'Highest Amount';
    case 'Lowest amount': return 'Lowest Amount';
    default: return item;
  }
}

class _PremiumDropdownField extends StatelessWidget {
  const _PremiumDropdownField({
    required this.label,
    required this.icon,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final IconData icon;
  final String value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: _HistoryPalette.surface(context),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: _HistoryPalette.border(context),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: _HistoryPalette.primary(context),
            size: 17,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                isExpanded: true,
                borderRadius: BorderRadius.circular(16),
                dropdownColor: _HistoryPalette.surface(context),
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 19,
                ),
                selectedItemBuilder: (context) {
                  return items.map((String item) {
                    return Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _controlLabel(item),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    );
                  }).toList();
                },
                items: items
                    .map(
                      (String item) => DropdownMenuItem<String>(
                    value: item,
                    child: Text(
                      _controlLabel(item),
                      style:
                      Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                )
                    .toList(),
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionOverviewCard extends StatelessWidget {
  const _TransactionOverviewCard({
    required this.totalAmountPaid,
    required this.paidCount,
    required this.inProgressCount,
    required this.failedCount,
  });

  final double totalAmountPaid;
  final int paidCount;
  final int inProgressCount;
  final int failedCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(19, 19, 19, 19),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF102F3E), Color(0xFF164956)],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.account_balance_wallet_outlined,
                  color: Color(0xFFF6D483), size: 19),
              SizedBox(width: 9),
              Text('Payment Overview',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  )),
            ],
          ),
          const SizedBox(height: 18),
          const Text('Total Paid',
              style: TextStyle(color: Color(0xFFBCD6D9), fontSize: 12)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '₱ ${totalAmountPaid.toStringAsFixed(2)}',
              maxLines: 1,
              style: _HistoryType.money(context).copyWith(color: Colors.white),
            ),
          ),
          const SizedBox(height: 18),
          Divider(height: 1, color: Colors.white.withValues(alpha: 0.18)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _TransactionOverviewMetric(
                  value: paidCount.toString(),
                  label: 'PAID',
                  icon: Icons.check_circle_outline_rounded,
                  valueColor: const Color(0xFF92E2C2),
                ),
              ),
              Expanded(
                child: _TransactionOverviewMetric(
                  value: inProgressCount.toString(),
                  label: 'In Progress',
                  icon: Icons.schedule_outlined,
                  valueColor: const Color(0xFFF6D483),
                ),
              ),
              Expanded(
                child: _TransactionOverviewMetric(
                  value: failedCount.toString(),
                  label: 'Unsuccessful',
                  icon: Icons.error_outline_rounded,
                  valueColor: const Color(0xFFFFA5A5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TransactionOverviewMetric extends StatelessWidget {
  const _TransactionOverviewMetric({
    required this.value,
    required this.label,
    required this.icon,
    required this.valueColor,
  });

  final String value;
  final String label;
  final IconData icon;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Column(
        children: [
          Icon(icon, size: 17, color: valueColor),
          const SizedBox(height: 6),
          Text(value,
              style: _HistoryType.cardTitle(context).copyWith(
                  color: Colors.white, fontSize: 18)),
          const SizedBox(height: 3),
          Text(label,
              maxLines: 2,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Color(0xFFBCD6D9), fontSize: 10, height: 1.2)),
        ],
      ),
    );
  }
}

class _TransactionOverviewDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 42,
      color: _HistoryPalette.border(context).withValues(alpha: 0.72),
    );
  }
}

class _PremiumSearchBar extends StatelessWidget {
  const _PremiumSearchBar({
    required this.controller,
    required this.hint,
    required this.helper,
    required this.onClear,
  });

  final TextEditingController controller;
  final String hint;
  final String helper;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: _HistoryPalette.surface(context),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: _HistoryPalette.border(context)),
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded,
              color: _HistoryPalette.primary(context), size: 21),
          const SizedBox(width: 11),
          Expanded(
            child: Semantics(
              textField: true,
              hint: helper,
              child: TextField(
                controller: controller,
                style: _HistoryType.body(context),
                decoration: InputDecoration(
                  hintText: hint,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  hintStyle: _HistoryType.body(context).copyWith(
                    color: _HistoryPalette.secondaryText(context),
                  ),
                ),
              ),
            ),
          ),
          if (controller.text.isNotEmpty)
            IconButton(
              tooltip: 'Clear search',
              onPressed: onClear,
              icon: Icon(Icons.close_rounded,
                  size: 19, color: _HistoryPalette.secondaryText(context)),
            ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: _HistoryType.sectionTitle(context),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            subtitle,
            style: _HistoryType.meta(context),
          ),
        ],
      ),
    );
  }
}

class _BillOverviewCard extends StatelessWidget {
  const _BillOverviewCard({
    required this.totalBills,
    required this.paidBills,
    required this.openBills,
    required this.outstanding,
  });

  final int totalBills;
  final int paidBills;
  final int openBills;
  final double outstanding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(19, 19, 19, 19),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF102F3E), Color(0xFF164956)],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: _HistoryPalette.navy.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.receipt_long_outlined,
                  color: Color(0xFFF6D483), size: 19),
              SizedBox(width: 9),
              Text('Billing Overview',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  )),
            ],
          ),
          const SizedBox(height: 18),
          const Text('Outstanding Balance',
              style: TextStyle(color: Color(0xFFBCD6D9), fontSize: 12)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '₱ ${outstanding.toStringAsFixed(2)}',
              maxLines: 1,
              style: _HistoryType.money(context).copyWith(
                color: Colors.white,
                fontSize: 31,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Divider(height: 1, color: Colors.white.withValues(alpha: 0.18)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _BillOverviewMetric(
                  label: 'Total Bills',
                  value: totalBills.toString(),
                  icon: Icons.receipt_outlined,
                  valueColor: Colors.white,
                ),
              ),
              Expanded(
                child: _BillOverviewMetric(
                  label: 'PAID',
                  value: paidBills.toString(),
                  icon: Icons.check_circle_outline_rounded,
                  valueColor: const Color(0xFF92E2C2),
                ),
              ),
              Expanded(
                child: _BillOverviewMetric(
                  label: 'UNPAID',
                  value: openBills.toString(),
                  icon: Icons.schedule_outlined,
                  valueColor: const Color(0xFFF6D483),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BillOverviewMetric extends StatelessWidget {
  const _BillOverviewMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.valueColor,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 17, color: valueColor),
        const SizedBox(height: 6),
        Text(value,
            style: _HistoryType.cardTitle(context).copyWith(
              color: Colors.white,
              fontSize: 18,
            )),
        const SizedBox(height: 3),
        Text(label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFFBCD6D9), fontSize: 10.5)),
      ],
    );
  }
}

class _BillOverviewDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 34,
      color: _HistoryPalette.border(context).withValues(alpha: 0.75),
    );
  }
}

class _BillListSurface extends StatelessWidget {
  const _BillListSurface({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (int index = 0; index < children.length; index++) ...[
          children[index],
          if (index != children.length - 1) const SizedBox(height: 11),
        ],
      ],
    );
  }
}

class _BillStatementTile extends StatelessWidget {
  const _BillStatementTile({
    required this.monthLabel,
    required this.reference,
    required this.dueDate,
    required this.usage,
    required this.amount,
    required this.status,
    required this.accent,
    required this.canOpen,
    required this.onTap,
  });

  final String monthLabel;
  final String reference;
  final String dueDate;
  final String? usage;
  final double amount;
  final String status;
  final Color accent;
  final bool canOpen;
  final VoidCallback? onTap;

  String get _statusLabel {
    switch (status.trim().toUpperCase()) {
      case 'PAID':
        return 'PAID';
      case 'OVERDUE':
        return 'Overdue';
      case 'DUE TODAY':
        return 'Due Today';
      default:
        return 'UNPAID';
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryText = Theme.of(context).colorScheme.onSurface;
    final Color secondaryText = _HistoryPalette.secondaryText(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(19),
        onTap: canOpen ? onTap : null,
        child: Ink(
          padding: const EdgeInsets.fromLTRB(15, 15, 15, 13),
          decoration: BoxDecoration(
            color: _HistoryPalette.surface(context),
            borderRadius: BorderRadius.circular(19),
            border: Border.all(color: _HistoryPalette.border(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _IconBubble(
                    icon: Icons.receipt_long_rounded,
                    accent: _HistoryPalette.primary(context),
                    size: 44,
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          monthLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _HistoryType.billMonth(context),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          reference,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _HistoryType.meta(context),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  _StatusChip(text: _statusLabel, accent: accent, solid: true),
                ],
              ),
              const SizedBox(height: 16),
              Text('Bill Amount',
                  style: _HistoryType.meta(context).copyWith(fontSize: 11)),
              const SizedBox(height: 3),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  '₱ ${amount.toStringAsFixed(2)}',
                  maxLines: 1,
                  style: _HistoryType.billAmount(context).copyWith(
                    color: primaryText,
                  ),
                ),
              ),
              const SizedBox(height: 13),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _BillMetaChip(icon: Icons.event_outlined,
                      text: dueDate == 'Not available'
                          ? 'Due Date Unavailable'
                          : 'Due $dueDate'),
                  if (usage != null && usage!.trim().isNotEmpty)
                    _BillMetaChip(icon: Icons.bolt_outlined,
                        text: usage!),
                ],
              ),
              const SizedBox(height: 13),
              Container(
                height: 1,
                color: _HistoryPalette.border(context).withValues(alpha: 0.75),
              ),
              const SizedBox(height: 11),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      canOpen ? 'View Bill' : 'Bill Unavailable',
                      style: _HistoryType.action(context).copyWith(
                        color: canOpen
                            ? _HistoryPalette.primary(context)
                            : secondaryText,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Icon(
                    canOpen
                        ? Icons.arrow_forward_rounded
                        : Icons.lock_outline_rounded,
                    size: 18,
                    color: canOpen
                        ? _HistoryPalette.primary(context)
                        : secondaryText,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BillMetaChip extends StatelessWidget {
  const _BillMetaChip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: _HistoryPalette.primary(context).withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: _HistoryPalette.primary(context)),
          const SizedBox(width: 5),
          Text(text,
              style: _HistoryType.meta(context).copyWith(fontSize: 11)),
        ],
      ),
    );
  }
}

class _HistoryItemCard extends StatelessWidget {
  const _HistoryItemCard({
    required this.leading,
    required this.title,
    required this.subtitleTop,
    required this.subtitleBottom,
    required this.amount,
    required this.statusChip,
    required this.extraTags,
    required this.actionText,
    required this.onTap,
  });

  final Widget leading;
  final String title;
  final String subtitleTop;
  final String? subtitleBottom;
  final double amount;
  final Widget statusChip;
  final List<Widget> extraTags;
  final String actionText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(19),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: _HistoryPalette.surface(context),
            borderRadius: BorderRadius.circular(19),
            border: Border.all(color: _HistoryPalette.border(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  leading,
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _HistoryType.cardTitle(context)),
                        const SizedBox(height: 3),
                        Text(subtitleTop,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _HistoryType.meta(context)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 5),
                  statusChip,
                ],
              ),
              const SizedBox(height: 14),
              Text('Amount', style: _HistoryType.meta(context)),
              const SizedBox(height: 2),
              Text('₱ ${amount.toStringAsFixed(2)}',
                  maxLines: 1,
                  style: _HistoryType.billAmount(context).copyWith(fontSize: 23)),
              if (subtitleBottom != null) ...[
                const SizedBox(height: 9),
                Row(
                  children: [
                    Icon(Icons.event_outlined, size: 15,
                        color: _HistoryPalette.primary(context)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(subtitleBottom!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _HistoryType.meta(context)),
                    ),
                  ],
                ),
              ],
              if (extraTags.isNotEmpty) ...[
                const SizedBox(height: 6),
                Wrap(spacing: 6, runSpacing: 4, children: extraTags),
              ],
              const SizedBox(height: 12),
              Divider(height: 1, color: _HistoryPalette.border(context)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(actionText,
                      style: _HistoryType.action(context).copyWith(
                        color: _HistoryPalette.primary(context),
                        fontWeight: FontWeight.w800,
                      )),
                  const Spacer(),
                  Icon(Icons.arrow_forward_rounded,
                      color: _HistoryPalette.primary(context), size: 18),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return _GlassShell(
      padding: const EdgeInsets.all(16),
      borderRadius: 24,
      child: Row(
        children: [
          _IconBubble(
            icon: icon,
            accent: _HistoryPalette.primary(context),
            size: 40,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: _HistoryPalette.secondaryText(context),
                    fontWeight: FontWeight.w600,
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

class _SkeletonList extends StatelessWidget {
  const _SkeletonList();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: const [
        _SkeletonCard(height: 72),
        SizedBox(height: 16),
        _SkeletonCard(height: 116),
        SizedBox(height: 12),
        _SkeletonCard(height: 56),
        SizedBox(height: 12),
        _SkeletonCard(height: 104),
        SizedBox(height: 12),
        _SkeletonCard(height: 126),
        SizedBox(height: 12),
        _SkeletonCard(height: 74),
        SizedBox(height: 10),
        _SkeletonCard(height: 110),
        SizedBox(height: 10),
        _SkeletonCard(height: 110),
      ],
    );
  }
}

class _SkeletonContent extends StatelessWidget {
  const _SkeletonContent();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        _SkeletonCard(height: 74),
        SizedBox(height: 10),
        _SkeletonCard(height: 74),
        SizedBox(height: 12),
        _SkeletonCard(height: 40),
        SizedBox(height: 10),
        _SkeletonCard(height: 110),
        SizedBox(height: 10),
        _SkeletonCard(height: 110),
        SizedBox(height: 10),
        _SkeletonCard(height: 110),
      ],
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return _GlassShell(
      padding: EdgeInsets.zero,
      borderRadius: 24,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: isDark
              ? Colors.white.withValues(alpha: 0.035)
              : Colors.white.withValues(alpha: 0.40),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _GlassShell(
      padding: const EdgeInsets.all(16),
      borderRadius: 24,
      child: Column(
        children: [
          _IconBubble(
            icon: Icons.cloud_off_rounded,
            accent: Theme.of(context).colorScheme.error,
            size: 40,
          ),
          const SizedBox(height: 10),
          Text(
            'Failed to load',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: onRetry,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _InfoStrip extends StatelessWidget {
  const _InfoStrip({
    required this.icon,
    required this.title,
    required this.value,
    required this.accent,
  });

  final IconData icon;
  final String title;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.black.withValues(alpha:
        Theme.of(context).brightness == Brightness.dark ? 0.12 : 0.03,
        ),
        border: Border.all(
          color: _HistoryPalette.border(context).withValues(alpha: 0.80),
        ),
      ),
      child: Row(
        children: [
          _IconBubble(
            icon: icon,
            accent: accent,
            size: 40,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: _HistoryPalette.secondaryText(context),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: accent,
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

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: _HistoryPalette.secondaryText(context),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: cs.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IconBubble extends StatelessWidget {
  const _IconBubble({
    required this.icon,
    required this.accent,
    this.size = 40,
  });

  final IconData icon;
  final Color accent;
  final double size;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.30),
        color: accent.withValues(alpha: isDark ? 0.14 : 0.09),
      ),
      child: Icon(
        icon,
        color: accent,
        size: size * 0.46,
      ),
    );
  }
}

String _readableStatus(String value) {
  switch (value.trim().toUpperCase()) {
    case 'PAID': return 'PAID';
    case 'UNPAID': return 'UNPAID';
    case 'OVERDUE': return 'Overdue';
    case 'DUE TODAY': return 'Due Today';
    case 'IN PROGRESS': return 'In Progress';
    case 'SUCCESS': return 'PAID';
    case 'FAILED': return 'Failed';
    case 'CANCELLED': return 'Cancelled';
    case 'CANCELED': return 'Cancelled';
    default: return value;
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.text,
    required this.accent,
    this.solid = false,
  });

  final String text;
  final Color accent;
  final bool solid;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: solid ? 0.16 : 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: accent.withValues(alpha: solid ? 0.24 : 0.14),
        ),
      ),
      child: Text(
        _readableStatus(text),
        style: TextStyle(
          color: accent,
          fontWeight: FontWeight.w800,
          fontSize: 10.5,
          letterSpacing: 0.1,
        ),
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({
    required this.size,
    required this.color,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color,
              blurRadius: size * 0.50,
              spreadRadius: size * 0.04,
            ),
          ],
        ),
      ),
    );
  }
}

