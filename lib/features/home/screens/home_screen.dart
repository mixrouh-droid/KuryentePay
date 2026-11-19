// V29 THROUGH-DUE-DATE PAYMENT - existing Home layout and services preserved; no manual dashboard refresh button
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:fl_chart/fl_chart.dart';

import '../../../core/services/billing_service.dart';
import '../../../core/services/bill_payment_deadline.dart';
import '../../../core/services/session_service.dart';
import '../../../core/services/usage_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../bills/screens/bill_details_screen.dart';
import '../../payment/screens/payment_method_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with WidgetsBindingObserver {
  late Future<Map<String, dynamic>?> _sessionFuture;

  Future<Map<String, dynamic>>? _billFuture;
  Future<Map<String, dynamic>>? _usageFuture;
  Future<Map<String, dynamic>>? _historyFuture;

  String _activeAccountNo = '';
  bool _resumeRefreshInProgress = false;
  Timer? _manilaDayTimer;
  DateTime? _lastManilaDay = BillPaymentDeadline.verifiedManilaToday;
  bool _lastClockVerified = BillPaymentDeadline.serverClockVerified;
  bool _clockRequestRunning = false;
  int _clockRetryTicks = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sessionFuture = SessionService.loadUser();
    // Do not rely on main.dart having run a previous server-time sync.
    unawaited(_syncClockAndRebuild());
    _manilaDayTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      final DateTime? date = BillPaymentDeadline.verifiedManilaToday;
      final bool verified = BillPaymentDeadline.serverClockVerified;
      if (mounted &&
          (date != _lastManilaDay || verified != _lastClockVerified)) {
        setState(() {
          _lastManilaDay = date;
          _lastClockVerified = verified;
        });
      }
      if (!verified) {
        _clockRetryTicks++;
        // Quietly retry once a minute while a connection is missing.
        if (_clockRetryTicks >= 2) {
          _clockRetryTicks = 0;
          unawaited(_syncClockAndRebuild(force: true));
        }
      } else {
        _clockRetryTicks = 0;
      }
    });
  }

  Future<void> _syncClockAndRebuild({bool force = false}) async {
    if (_clockRequestRunning) {
      // Another screen or lifecycle callback may already be syncing.
      await BillPaymentDeadline.syncServerTime(force: force);
      return;
    }
    _clockRequestRunning = true;
    try {
      await BillPaymentDeadline.syncServerTime(force: force);
    } finally {
      _clockRequestRunning = false;
      if (mounted) {
        setState(() {
          _lastClockVerified = BillPaymentDeadline.serverClockVerified;
          _lastManilaDay = BillPaymentDeadline.verifiedManilaToday;
        });
      }
    }
  }

  @override
  void dispose() {
    _manilaDayTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_syncClockAndRebuild(force: true));
    }
    if (state == AppLifecycleState.resumed &&
        _activeAccountNo.isNotEmpty &&
        !_resumeRefreshInProgress) {
      unawaited(_refreshAfterAppResume());
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
      // PayMongo checkout opens outside the app. When the user returns,
      // reload the authoritative Hostinger data so a webhook-confirmed
      // UNPAID -> PAID change can appear without requiring a manual pull.
      await _refresh(_activeAccountNo);
    } finally {
      _resumeRefreshInProgress = false;
    }
  }

  void _loadAll(String accountNo) {
    _billFuture = BillingService.getCurrentBill(accountNo: accountNo);
    _usageFuture = UsageService.getUsageSummary(accountNo: accountNo);
    // Read-only history lets Home flag older overdue bills even when
    // the newest bill is already paid or not yet due.
    _historyFuture = BillingService.getBillingHistory(accountNo: accountNo);
  }

  Future<void> _refresh(String accountNo) async {
    setState(() => _loadAll(accountNo));
    try {
      // History refreshes independently in its FutureBuilder, so a slow
      // history request cannot delay the PAID status after PayMongo returns.
      await Future.wait([
        _billFuture!,
        _usageFuture!,
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

  String _firstName(String fullName) {
    final cleaned = fullName.trim();
    if (cleaned.isEmpty) return '';
    final parts = cleaned.split(RegExp(r'\s+'));
    return parts.first;
  }

  void _showSoon(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _copyToClipboard(String value, String successMessage) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    _showSoon(context, successMessage);
  }

  void _openQuickHelp() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _QuickHelpSheet(),
    );
  }

  static int? _daysUntilDue(String dueDateStr) {
    return _HomeDateTools.daysUntil(dueDateStr);
  }

  // A separate reminder appears only when a payment is approaching its due date.
  // Payment eligibility is checked independently by BillPaymentDeadline.
  static bool _isDueSoon(String dueDateStr, {int days = 3}) {
    final diff = _daysUntilDue(dueDateStr);
    return diff != null && diff >= 0 && diff <= days;
  }

  static String _dueBadgeText(String dueDateStr) {
    if (BillPaymentDeadline.parseDueDate(dueDateStr) == null) {
      return 'Due date unavailable';
    }
    final diff = _daysUntilDue(dueDateStr);
    if (diff == null) return 'Checking due date';
    if (diff < 0) {
      final days = diff.abs();
      return '$days day${days == 1 ? '' : 's'} overdue';
    }
    if (diff == 0) return 'Due today';
    if (diff == 1) return 'Due tomorrow';
    return '$diff days left';
  }

  static String _normaliseBillStatus(dynamic value) {
    final String status = value?.toString().trim().toUpperCase() ?? '';

    return status == 'PAID' ? 'PAID' : 'UNPAID';
  }

  static String _statusSummary(String status, String dueDateStr) {
    final normalized = status.toUpperCase();
    final diff = _daysUntilDue(dueDateStr);

    if (normalized == 'PAID') {
      return 'Payment recorded. You can review the bill details anytime.';
    }

    if (diff == null) {
      if (BillPaymentDeadline.parseDueDate(dueDateStr) == null) {
        return 'The saved bill due date is unavailable. Please contact your billing administrator.';
      }
      return 'Verifying the due date. Online payment will be available once verification completes.';
    }
    if (diff < 0) {
      final int days = diff.abs();
      return 'This bill is $days day${days == 1 ? '' : 's'} overdue. '
          'Online payment is closed. Please contact your billing office for settlement options. '
          'If you already started a payment, check its status before paying again.';
    }
    if (diff == 0) {
      return 'Online payment remains available today.';
    }
    if (diff == 1) {
      return 'Online payment is available through the due date shown below.';
    }
    return 'Online payment is available through the due date shown below.';
  }

  static String _formatPeso(String amountStr) {
    final double value = double.tryParse(amountStr) ?? 0;
    final String fixed = value.toStringAsFixed(2);
    final List<String> parts = fixed.split('.');
    final String whole = parts.first;
    final bool negative = whole.startsWith('-');
    final String digits = negative ? whole.substring(1) : whole;
    final StringBuffer grouped = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) grouped.write(',');
      grouped.write(digits[i]);
    }
    return '₱${negative ? '-' : ''}${grouped.toString()}.${parts.last}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _NebulaPalette.background(context),
      body: Stack(
        children: [
          const _HomeBackdrop(),
          SafeArea(
            bottom: false,
            child: FutureBuilder<Map<String, dynamic>?>(
              future: _sessionFuture,
              builder: (context, snapUser) {
                if (snapUser.connectionState == ConnectionState.waiting) {
                  return const _HomeSkeleton();
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
                    subtitle: 'Please login again to load your dashboard.',
                    icon: Icons.login_rounded,
                  );
                }

                final accountNo = (user['account_no'] ?? '').toString().trim();
                _activeAccountNo = accountNo;

                final fullName = (user['name'] ?? 'User').toString();
                final displayName = _firstName(fullName);
                final address = (user['address'] ?? '').toString();

                if (_billFuture == null ||
                    _usageFuture == null ||
                    _historyFuture == null) {
                  _loadAll(accountNo);
                }

                return RefreshIndicator(
                  color: _NebulaPalette.primary(context),
                  backgroundColor: _NebulaPalette.surface(context),
                  onRefresh: () => _refresh(accountNo),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    padding: const EdgeInsets.fromLTRB(18, 15, 18, 28),
                    children: [
                      _TopHeader(
                        displayName: displayName,
                        accountNo: accountNo,
                        onHelp: _openQuickHelp,
                        onCopyAccount: () => _copyToClipboard(
                          accountNo,
                          'Account number copied',
                        ),
                      ),
                      const SizedBox(height: 16),
                      FutureBuilder<Map<String, dynamic>>(
                        future: _billFuture,
                        builder: (context, snapBill) {
                          if (snapBill.connectionState ==
                              ConnectionState.waiting) {
                            return const _SkeletonPanel(height: 312);
                          }

                          if (snapBill.hasError) {
                            return _ErrorGlassCard(
                              title: 'Failed to load current bill',
                              message: snapBill.error
                                  .toString()
                                  .replaceFirst('Exception: ', ''),
                              onRetry: () {
                                setState(() {
                                  _billFuture = BillingService.getCurrentBill(
                                    accountNo: accountNo,
                                  );
                                });
                              },
                            );
                          }

                          final data = snapBill.data ?? <String, dynamic>{};
                          final bill = data['bill'];

                          if (bill == null) {
                            return const _EmptyStateCard(
                              icon: Icons.receipt_long_rounded,
                              title: 'No current bill found',
                              subtitle:
                              'No current bill is available yet. Billing information updates automatically; contact your billing administrator if a bill is missing.',
                            );
                          }

                          final billingMonth =
                          (bill['billing_month'] ?? '').toString();
                          final dueDate = (bill['due_date'] ?? '').toString();
                          final amountRaw =
                          (bill['total_amount_due'] ?? 0).toString();
                          final String status = _normaliseBillStatus(
                            bill['payment_status'],
                          );
                          final kwh = (bill['kwh_used'] ?? '').toString();
                          final billId = _extractBillId(bill);

                          final formattedBillingMonth =
                          _HomeDateTools.formatBillingMonth(billingMonth);
                          final formattedDueDate =
                          _HomeDateTools.formatMonthDayYear(dueDate);
                          final int? daysRemaining = BillPaymentDeadline.daysUntilDue(dueDate);
                          final String dueBadgeText = status == 'PAID'
                              ? 'Paid'
                              : _dueBadgeText(dueDate);
                          final String statusNote = _statusSummary(status, dueDate);

                          // Prefer the verified Hostinger clock for precise
                          // overdue days; NEVER use the phone's manual clock.
                          // A positive server-provided flag may be displayed
                          // only when clock sync is temporarily unavailable.
                          // Neither source is allowed to open online payment.
                          final bool apiSaysOverdue =
                              bill['is_overdue'] == true ||
                                  bill['is_overdue'] == 1 ||
                                  bill['is_overdue']?.toString() == '1';
                          final int? daysOverdue = status != 'PAID' &&
                              daysRemaining != null && daysRemaining < 0
                              ? -daysRemaining
                              : null;
                          final bool isOverdue = status != 'PAID' &&
                              (daysOverdue != null ||
                                  (daysRemaining == null &&
                                      apiSaysOverdue &&
                                      BillPaymentDeadline.parseDueDate(dueDate) != null));
                          final bool officePaymentRequired = isOverdue ||
                              (status != 'PAID' &&
                                  BillPaymentDeadline.isOfficePaymentRequired(dueDate));
                          // Checkout eligibility still uses the verified date
                          // and is always rechecked by the PHP payment API.
                          final bool canPayOnline = status != 'PAID' &&
                              BillPaymentDeadline.canStartOnlinePayment(dueDate);

                          final statusColor = status == 'PAID'
                              ? _NebulaPalette.success(context)
                              : isOverdue
                              ? _NebulaPalette.danger(context)
                              : _NebulaPalette.warning(context);

                          void openBill() {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => BillDetailsScreen(
                                  nickname: displayName.isEmpty
                                      ? 'My Account'
                                      : displayName,
                                  accountNo: accountNo,
                                  address: address,
                                  month: billingMonth.isEmpty
                                      ? 'Current bill'
                                      : billingMonth,
                                  amount: double.tryParse(amountRaw) ?? 0,
                                  dueDate: dueDate,
                                  status: status,
                                  billId: billId,
                                ),
                              ),
                            );
                          }

                          void openPay() async {
                            if (status == 'PAID') {
                              _showSoon(
                                context,
                                'This bill has already been paid.',
                              );
                              return;
                            }

                            // A bill may cross its deadline while Home is
                            // open. Recheck server time at the moment Pay Now
                            // is pressed; the PHP checkout API also checks it.
                            await BillPaymentDeadline.syncServerTime(force: true);
                            // This closure captures the FutureBuilder's context,
                            // so check both the State and that BuildContext.
                            if (!mounted || !context.mounted) return;
                            setState(() {
                              _lastClockVerified = BillPaymentDeadline.serverClockVerified;
                              _lastManilaDay = BillPaymentDeadline.verifiedManilaToday;
                            });

                            if (BillPaymentDeadline.isOfficePaymentRequired(dueDate)) {
                              _showSoon(context, BillPaymentDeadline.officeAction);
                              return;
                            }

                            if (!BillPaymentDeadline.canStartOnlinePayment(dueDate)) {
                              _showSoon(context,
                                  'Payment date verification is temporarily unavailable. Please check your internet connection.');
                              return;
                            }

                            if (billId == null) {
                              _showSoon(
                                context,
                                'Bill ID is unavailable. Please reopen the bill and try again.',
                              );
                              return;
                            }

                            final paymentAmount =
                                double.tryParse(amountRaw) ?? 0;

                            if (paymentAmount <= 0) {
                              _showSoon(
                                context,
                                'The bill does not have a valid payable amount.',
                              );
                              return;
                            }

                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => PaymentMethodScreen(
                                  billId: billId,
                                  billMonth: billingMonth.isEmpty
                                      ? 'Current bill'
                                      : billingMonth,
                                  amount: paymentAmount,
                                  dueDate: dueDate,
                                ),
                              ),
                            );

                            if (!mounted) return;
                            await _refresh(accountNo);
                          }

                          void openReminder() {
                            _showSoon(
                              context,
                              'Bill reminders are delivered through KuryentePay notifications when notification permission is enabled on your device.',
                            );
                          }

                          return Column(
                            children: [
                              _CurrentBillHero(
                                amount: _formatPeso(amountRaw),
                                billingMonth: formattedBillingMonth,
                                dueDate: formattedDueDate,
                                rawDueDate: dueDate,
                                dueBadgeText: dueBadgeText,
                                statusText: status,
                                statusColor: statusColor,
                                statusNote: statusNote,
                                officePaymentRequired: officePaymentRequired,
                                daysOverdue: daysOverdue,
                                canPayOnline: canPayOnline,
                                kwhText: kwh.isEmpty ? '—' : '$kwh kWh',
                                onPay: openPay,
                                onViewBill: openBill,
                                onRemind: openReminder,
                              ),
                              // The overdue action now lives IN the hero,
                              // instead of duplicating the full office notice.
                              if (canPayOnline &&
                                  _isDueSoon(dueDate, days: 3)) ...[
                                const SizedBox(height: 12),
                                _DueSoonCard(
                                  dueDate: dueDate,
                                  onPay: openPay,
                                ),
                              ],
                              // The newest bill can be PAID while a previous
                              // month's separate bill is still overdue. Do not
                              // hide those historical obligations from Home.
                              FutureBuilder<Map<String, dynamic>>(
                                future: _historyFuture,
                                builder: (context, snapHistory) {
                                  // Failure to load optional history must
                                  // never block the current-bill card.
                                  if (!snapHistory.hasData || snapHistory.hasError) {
                                    return const SizedBox.shrink();
                                  }
                                  final dynamic rawItems =
                                      snapHistory.data?['bills'] ??
                                          snapHistory.data?['items'];
                                  if (rawItems is! List) {
                                    return const SizedBox.shrink();
                                  }
                                  final List<Map> otherOverdueBills = rawItems
                                      .whereType<Map>()
                                      .where((item) {
                                    final int? oldId = _extractBillId(item);
                                    if (oldId != null && oldId == billId) {
                                      return false;
                                    }
                                    final rawStatus = (item['payment_status'] ?? '')
                                        .toString().trim().toUpperCase();
                                    if (rawStatus == 'PAID' ||
                                        rawStatus == 'PENDING' ||
                                        rawStatus == 'PROCESSING' ||
                                        rawStatus == 'VERIFYING') {
                                      return false;
                                    }
                                    final remaining =
                                    BillPaymentDeadline.daysUntilDue(
                                      (item['due_date'] ?? '').toString(),
                                    );
                                    return remaining != null && remaining < 0;
                                  })
                                      .toList();
                                  if (otherOverdueBills.isEmpty) {
                                    return const SizedBox.shrink();
                                  }
                                  otherOverdueBills.sort((a, b) {
                                    final first = BillPaymentDeadline.parseDueDate(
                                      (a['due_date'] ?? '').toString(),
                                    );
                                    final second = BillPaymentDeadline.parseDueDate(
                                      (b['due_date'] ?? '').toString(),
                                    );
                                    if (first == null || second == null) return 0;
                                    return first.compareTo(second);
                                  });
                                  final Map oldest = otherOverdueBills.first;
                                  final int? oldestId = _extractBillId(oldest);
                                  final int oldestDays = -(BillPaymentDeadline
                                      .daysUntilDue(
                                      (oldest['due_date'] ?? '').toString()) ??
                                      0);
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 12),
                                    child: _PreviousOverdueBillsBanner(
                                      count: otherOverdueBills.length,
                                      oldestDays: oldestDays,
                                      onViewBill: oldestId == null || oldestId <= 0
                                          ? null
                                          : () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => BillDetailsScreen(
                                              nickname: displayName.isEmpty
                                                  ? 'My Account'
                                                  : displayName,
                                              accountNo: accountNo,
                                              address: address,
                                              month: (oldest['billing_month'] ?? '')
                                                  .toString(),
                                              amount: double.tryParse(
                                                (oldest['total_amount_due'] ?? 0)
                                                    .toString(),
                                              ) ??
                                                  0,
                                              dueDate: (oldest['due_date'] ?? '')
                                                  .toString(),
                                              status: 'UNPAID',
                                              billId: oldestId,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  );
                                },
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 18),
                      const _SectionHeader(
                        title: 'Usage Overview',
                        subtitle: 'Billing and energy trends',
                      ),
                      const SizedBox(height: 10),
                      FutureBuilder<Map<String, dynamic>>(
                        future: _usageFuture,
                        builder: (context, snapUsage) {
                          if (snapUsage.connectionState ==
                              ConnectionState.waiting) {
                            return const _SkeletonPanel(height: 392);
                          }

                          if (snapUsage.hasError) {
                            return _ErrorGlassCard(
                              title: 'Failed to load usage chart',
                              message: snapUsage.error
                                  .toString()
                                  .replaceFirst('Exception: ', ''),
                              onRetry: () {
                                setState(() {
                                  _usageFuture = UsageService.getUsageSummary(
                                    accountNo: accountNo,
                                  );
                                });
                              },
                            );
                          }

                          final data = snapUsage.data ?? <String, dynamic>{};
                          final items = (data['items'] as List?) ?? const [];

                          if (items.isEmpty) {
                            return const _EmptyStateCard(
                              icon: Icons.bar_chart_rounded,
                              title: 'No usage data yet',
                              subtitle:
                              'Usage history will appear here as billing records become available for your account.',
                            );
                          }

                          return _UsageOverviewCard(items: items);
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

class _NebulaPalette {
  // Presentation-only colors. No change to AppTheme, APIs or calculation logic.
  static bool _isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color background(BuildContext context) =>
      _isDark(context) ? const Color(0xFF0A1622) : const Color(0xFFF4F7F9);

  static Color surface(BuildContext context) =>
      _isDark(context) ? const Color(0xFF112535) : const Color(0xFFFFFFFF);

  static Color surfaceSoft(BuildContext context) =>
      _isDark(context) ? const Color(0xFF162D3F) : const Color(0xFFF7F9FB);

  static Color border(BuildContext context) =>
      _isDark(context) ? const Color(0xFF294355) : const Color(0xFFE1E8ED);

  static Color primary(BuildContext context) =>
      _isDark(context) ? const Color(0xFF6CE1CD) : const Color(0xFF087F79);

  static Color info(BuildContext context) =>
      _isDark(context) ? const Color(0xFF70DCCB) : const Color(0xFF087F79);

  static Color gold(BuildContext context) =>
      _isDark(context) ? const Color(0xFFF6D483) : const Color(0xFFB6802E);

  static Color success(BuildContext context) =>
      _isDark(context) ? const Color(0xFF75D5AD) : const Color(0xFF138A60);

  static Color warning(BuildContext context) =>
      _isDark(context) ? const Color(0xFFF5D188) : const Color(0xFFAD721F);

  static Color danger(BuildContext context) =>
      _isDark(context) ? const Color(0xFFFF9194) : const Color(0xFFCB4856);

  static Color secondaryText(BuildContext context) =>
      _isDark(context) ? const Color(0xFFB6C9D5) : const Color(0xFF647789);
}

class _HomeBackdrop extends StatelessWidget {
  const _HomeBackdrop();

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
                ? const [Color(0xFF0C1B26), Color(0xFF0C1B26)]
                : const [Color(0xFFF4F7FA), Color(0xFFF4F7FA)],
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
    this.borderRadius = 20,
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
        borderRadius: BorderRadius.circular(borderRadius),
        color: _NebulaPalette.surface(context),
        border: Border.all(color: _NebulaPalette.border(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.12 : 0.035),
            blurRadius: 16,
            offset: const Offset(0, 5),
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
                accent: _NebulaPalette.primary(context),
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
                  color: _NebulaPalette.secondaryText(context),
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
    required this.displayName,
    required this.accountNo,
    required this.onHelp,
    required this.onCopyAccount,
  });

  final String displayName;
  final String accountNo;
  final VoidCallback onHelp;
  final VoidCallback onCopyAccount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final String name = displayName.trim().isEmpty ? 'there' : displayName.trim();
    final Color headingColor = theme.colorScheme.onSurface;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: const Color(0xFF102F3E),
              ),
              child: const Icon(
                Icons.bolt_rounded,
                color: Color(0xFFF6D483),
                size: 27,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'KuryentePay',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: headingColor,
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    'Electric Bill Inquiry & Payment',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: _NebulaPalette.secondaryText(context),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            _HeaderActionButton(
              icon: Icons.help_outline_rounded,
              tooltip: 'Help with your account',
              onTap: onHelp,
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          'Good day, $name',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.headlineSmall?.copyWith(
            color: headingColor,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.8,
            height: 1.16,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Your bills, payment details, and energy use at a glance.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: _NebulaPalette.secondaryText(context),
            fontWeight: FontWeight.w500,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 17),
        LayoutBuilder(
          builder: (context, constraints) {
            final bool stacked = constraints.maxWidth < 340;
            final account = _AccountNumberPill(
              accountNo: accountNo,
              onCopy: onCopyAccount,
            );
            final date = _HeaderDatePill(label: _HomeDateTools.todayLabel());
            if (stacked) {
              return Column(
                children: [
                  account,
                  const SizedBox(height: 8),
                  date,
                ],
              );
            }
            return Row(
              children: [
                Expanded(flex: 6, child: account),
                const SizedBox(width: 8),
                Expanded(flex: 4, child: date),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _HeaderActionButton extends StatelessWidget {
  const _HeaderActionButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(13),
          child: Ink(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              color: _NebulaPalette.surface(context),
              border: Border.all(color: _NebulaPalette.border(context)),
            ),
            child: Icon(
              icon,
              color: _NebulaPalette.primary(context),
              size: 21,
            ),
          ),
        ),
      ),
    );
  }
}

class _AccountNumberPill extends StatelessWidget {
  const _AccountNumberPill({
    required this.accountNo,
    required this.onCopy,
  });

  final String accountNo;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final hasAccount = accountNo.trim().isNotEmpty;
    return Material(
      color: _NebulaPalette.surface(context),
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: hasAccount ? onCopy : null,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          height: 66,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: _NebulaPalette.border(context)),
          ),
          child: Row(
            children: [
              Icon(
                Icons.badge_outlined,
                color: _NebulaPalette.primary(context),
                size: 21,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'ACCOUNT NUMBER',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: _NebulaPalette.secondaryText(context),
                        fontWeight: FontWeight.w700,
                        fontSize: 9,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 3),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        hasAccount ? accountNo : 'Not available',
                        maxLines: 1,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.w800,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (hasAccount)
                Icon(
                  Icons.copy_rounded,
                  color: _NebulaPalette.secondaryText(context),
                  size: 15,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderDatePill extends StatelessWidget {
  const _HeaderDatePill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 66,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        color: _NebulaPalette.surface(context),
        border: Border.all(color: _NebulaPalette.border(context)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.calendar_today_outlined,
            color: _NebulaPalette.primary(context),
            size: 17,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                label,
                maxLines: 1,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                  fontSize: 11.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CurrentBillHero extends StatelessWidget {
  const _CurrentBillHero({
    required this.amount,
    required this.billingMonth,
    required this.dueDate,
    required this.rawDueDate,
    required this.dueBadgeText,
    required this.statusText,
    required this.statusColor,
    required this.statusNote,
    required this.officePaymentRequired,
    required this.daysOverdue,
    required this.canPayOnline,
    required this.kwhText,
    required this.onPay,
    required this.onViewBill,
    required this.onRemind,
  });

  final String amount;
  final String billingMonth;
  final String dueDate;
  final String rawDueDate;
  final String dueBadgeText;
  final String statusText;
  final Color statusColor;
  final String statusNote;
  final bool officePaymentRequired;
  final int? daysOverdue;
  final bool canPayOnline;
  final String kwhText;
  final VoidCallback onPay;
  final VoidCallback onViewBill;
  final VoidCallback onRemind;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isPaid = statusText == 'PAID';
    final bool isOverdue = !isPaid &&
        (officePaymentRequired ||
            (daysOverdue != null && daysOverdue! > 0) ||
            dueBadgeText.toLowerCase().contains('overdue'));
    final int? daysUntilDue = _HomeDateTools.daysUntil(rawDueDate);
    final bool showsDueReminder = canPayOnline &&
        daysUntilDue != null &&
        daysUntilDue >= 0 && daysUntilDue <= 3;

    final Color badgeColor = isPaid
        ? const Color(0xFF9DE9CD)
        : isOverdue || officePaymentRequired
        ? const Color(0xFFFFB0B5)
        : const Color(0xFFF6D483);
    final String badgeLabel = isPaid
        ? 'Paid'
        : officePaymentRequired || isOverdue
        ? 'Overdue'
        : dueBadgeText == 'Due today'
        ? 'Due Today'
        : dueBadgeText == 'Due tomorrow'
        ? 'Due Tomorrow'
        : canPayOnline ? 'Unpaid' : 'Unavailable';

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: const Color(0xFF102F3E),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF102F3E).withValues(alpha: 0.14),
            blurRadius: 22,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4, width: double.infinity,
                child: ColoredBox(color: Color(0xFF39BCA8))),
            Padding(
              padding: const EdgeInsets.fromLTRB(19, 19, 19, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 41,
                        width: 41,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: const Icon(Icons.receipt_long_rounded,
                            color: Color(0xFF9DE9CD), size: 23),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Current Electric Bill',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(billingMonth,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: const Color(0xFFC6D8DD),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(color: badgeColor.withValues(alpha: 0.35)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(isPaid ? Icons.check_circle_rounded
                                : isOverdue || officePaymentRequired
                                ? Icons.error_outline_rounded
                                : Icons.schedule_rounded,
                                size: 13, color: badgeColor),
                            const SizedBox(width: 4),
                            Text(badgeLabel,
                              style: TextStyle(color: badgeColor,
                                  fontWeight: FontWeight.w800, fontSize: 10.5),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(isOverdue
                      ? 'Original Bill Amount (Excludes Late Charges)'
                      : 'Total Amount Due',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: const Color(0xFFC6D8DD),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 5),
                  SizedBox(
                    width: double.infinity,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(amount,
                        style: theme.textTheme.headlineLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1.2,
                        ),
                      ),
                    ),
                  ),
                  if (isOverdue) ...[
                    const SizedBox(height: 15),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFB5BE).withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: const Color(0xFFFFB5BE).withValues(alpha: 0.35),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline_rounded,
                                  color: Color(0xFFFFB5BE), size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  daysOverdue == null
                                      ? 'OVERDUE BILL'
                                      : '${daysOverdue!} DAY${daysOverdue == 1 ? '' : 'S'} OVERDUE',
                                  style: const TextStyle(
                                    color: Color(0xFFFFCED3),
                                    fontWeight: FontWeight.w900,
                                    fontSize: 14,
                                    letterSpacing: 0.35,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 7),
                          const Text(
                            'Online payment is closed. Proceed to the billing office for settlement.',
                            style: TextStyle(
                              color: Color(0xFFF3E8E9),
                              fontSize: 12.5,
                              height: 1.4,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 5),
                          const Text(
                            'Late charges, if applicable, are confirmed by the office and are not included in the original amount above.',
                            style: TextStyle(
                              color: Color(0xFFDCCBCF),
                              fontSize: 11.5,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else if (!showsDueReminder) ...[
                    const SizedBox(height: 7),
                    Text(statusNote,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: const Color(0xFFCFDFE2),
                        height: 1.35,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: _HeroInfoCapsule(
                          icon: Icons.event_rounded,
                          label: 'Due Date',
                          value: dueDate,
                          accent: const Color(0xFFF6D483),
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: _HeroInfoCapsule(
                          icon: Icons.bolt_rounded,
                          label: 'Energy Used',
                          value: kwhText,
                          accent: const Color(0xFF9DE9CD),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _BillActionButton(
                    icon: isPaid ? Icons.verified_rounded
                        : !canPayOnline ? Icons.lock_outline_rounded
                        : Icons.account_balance_wallet_rounded,
                    label: isPaid ? 'Payment Complete'
                        : officePaymentRequired ? 'Online Payment Unavailable'
                        : !canPayOnline
                        ? (BillPaymentDeadline.parseDueDate(rawDueDate) == null
                        ? 'Bill Due Date Unavailable'
                        : 'Checking Payment Availability')
                        : 'PAY ELECTRIC BILL',
                    accent: const Color(0xFF9DE9CD),
                    onTap: canPayOnline ? onPay : null,
                    filled: true,
                  ),
                  const SizedBox(height: 9),
                  Row(
                    children: [
                      Expanded(
                        child: _BillActionButton(
                          icon: Icons.description_outlined,
                          label: 'View Bill',
                          accent: Colors.white,
                          onTap: onViewBill,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _BillActionButton(
                          icon: Icons.notifications_none_rounded,
                          label: 'Bill Alerts',
                          accent: Colors.white,
                          onTap: onRemind,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Independent, separately payable historical overdue bills.
/// No balances are summed here: older legacy statement totals may already
/// include carried debts, and this notice must never double-charge them.
class _PreviousOverdueBillsBanner extends StatelessWidget {
  const _PreviousOverdueBillsBanner({
    required this.count,
    required this.oldestDays,
    this.onViewBill,
  });

  final int count;
  final int oldestDays;
  final VoidCallback? onViewBill;

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final Color accent = dark
        ? const Color(0xFFFFB5BE)
        : const Color(0xFFB42335);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(15, 14, 15, 13),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF32242B) : const Color(0xFFFFF4F5),
        border: Border.all(
          color: dark ? const Color(0xFF704753) : const Color(0xFFF2C8CE),
        ),
        borderRadius: BorderRadius.circular(17),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.receipt_long_outlined, color: accent, size: 21),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  '$count OTHER OVERDUE BILL${count == 1 ? '' : 'S'}',
                  style: TextStyle(
                    color: accent,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            'The oldest previous bill is $oldestDays day${oldestDays == 1 ? '' : 's'} overdue. '
                'Each bill remains separate; review its details for office settlement.',
            style: TextStyle(
              color: dark ? const Color(0xFFE7D5D9) : const Color(0xFF64434C),
              height: 1.4,
              fontSize: 12.5,
            ),
          ),
          if (onViewBill != null) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: onViewBill,
              icon: const Icon(Icons.open_in_new_rounded, size: 16),
              label: const Text('VIEW OLDEST OVERDUE BILL'),
              style: TextButton.styleFrom(
                foregroundColor: accent,
                padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HeroInfoCapsule extends StatelessWidget {
  const _HeroInfoCapsule({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 75),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, color: accent, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: const Color(0xFFD1E0E3),
                    fontWeight: FontWeight.w600,
                    fontSize: 10.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          SizedBox(
            width: double.infinity,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value,
                maxLines: 1,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BillActionButton extends StatelessWidget {
  const _BillActionButton({
    required this.icon,
    required this.label,
    required this.accent,
    required this.onTap,
    this.filled = false,
  });

  final IconData icon;
  final String label;
  final Color accent;
  final VoidCallback? onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final bool disabled = onTap == null;
    final Color foreground = disabled
        ? Colors.white.withValues(alpha: 0.78)
        : Colors.white;

    return SizedBox(
      width: double.infinity,
      height: 48,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 9),
            decoration: BoxDecoration(
              color: disabled
                  ? Colors.white.withValues(alpha: 0.12)
                  : filled
                  ? const Color(0xFF087F79)
                  : Colors.white.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: filled && !disabled
                    ? const Color(0xFF269E93)
                    : accent.withValues(alpha: disabled ? 0.14 : 0.25),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: foreground, size: 18),
                const SizedBox(width: 7),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(label.toUpperCase(),
                      maxLines: 1,
                      style: TextStyle(
                        color: foreground,
                        fontWeight: FontWeight.w800,
                        fontSize: filled ? 12.5 : 11.5,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 4,
          height: 33,
          decoration: BoxDecoration(
            color: _NebulaPalette.primary(context),
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: _NebulaPalette.secondaryText(context),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

enum _UsageChartMode {
  amount,
  usage,
}

class _UsageOverviewCard extends StatefulWidget {
  const _UsageOverviewCard({
    required this.items,
  });

  final List items;

  @override
  State<_UsageOverviewCard> createState() => _UsageOverviewCardState();

  static const List<String> _shortMonths = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static const List<String> _longMonths = <String>[
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

  static int? _monthSortKey(String raw) {
    final String value = raw.trim();
    final RegExpMatch? match =
    RegExp(r'^(\d{4})-(\d{2})$').firstMatch(value);

    if (match == null) return null;

    final int? year = int.tryParse(match.group(1) ?? '');
    final int? month = int.tryParse(match.group(2) ?? '');

    if (year == null ||
        month == null ||
        year < 2000 ||
        year > 2100 ||
        month < 1 ||
        month > 12) {
      return null;
    }

    return (year * 100) + month;
  }

  static String _shortMonth(String raw) {
    final int? key = _monthSortKey(raw);
    if (key == null) return 'Cycle';

    final int month = key % 100;
    return _shortMonths[month - 1];
  }

  static String _fullMonth(String raw) {
    final int? key = _monthSortKey(raw);
    if (key == null) return 'Billing cycle';

    final int year = key ~/ 100;
    final int month = key % 100;
    return '${_longMonths[month - 1]} $year';
  }
}

class _UsageOverviewCardState extends State<_UsageOverviewCard> {
  _UsageChartMode _mode = _UsageChartMode.amount;
  int _cycleRange = 6;

  List<_UsagePoint> _parseItems() {
    final List<_UsagePoint> parsedSource =
    widget.items.map<_UsagePoint>((dynamic raw) {
      final Map map =
      raw is Map ? raw : const <String, dynamic>{};

      final String month =
      (map['billing_month'] ?? '').toString().trim();

      final dynamic amountRaw =
          map['amount'] ?? map['total_amount_due'] ?? 0;

      final double amount = amountRaw is num
          ? amountRaw.toDouble()
          : double.tryParse(amountRaw.toString()) ?? 0.0;

      final dynamic kwhRaw = map['kwh_used'] ?? 0;

      final double kwh = kwhRaw is num
          ? kwhRaw.toDouble()
          : double.tryParse(kwhRaw.toString()) ?? 0.0;

      return _UsagePoint(
        month: month,
        amount: amount,
        kwh: kwh,
      );
    }).toList();

    final bool allMonthsValid = parsedSource.every(
          (_UsagePoint point) =>
      _UsageOverviewCard._monthSortKey(point.month) != null,
    );

    if (allMonthsValid) {
      parsedSource.sort(
            (_UsagePoint a, _UsagePoint b) =>
            _UsageOverviewCard._monthSortKey(a.month)!
                .compareTo(
              _UsageOverviewCard._monthSortKey(b.month)!,
            ),
      );
    }

    final int requestedRange =
    _cycleRange == 3 ? 3 : 6;

    if (parsedSource.length <= requestedRange) {
      return parsedSource;
    }

    return parsedSource.sublist(
      parsedSource.length - requestedRange,
    );
  }

  double? _percentageChange(
      double latest,
      double previous,
      ) {
    if (previous.abs() < 0.000001) {
      return null;
    }

    return ((latest - previous) / previous) * 100;
  }

  double _average(
      List<_UsagePoint> items,
      double Function(_UsagePoint point) selector,
      ) {
    if (items.isEmpty) return 0;

    final double total = items.fold<double>(
      0,
          (double sum, _UsagePoint point) => sum + selector(point),
    );

    return total / items.length;
  }

  @override
  Widget build(BuildContext context) {
    final List<_UsagePoint> parsed = _parseItems();

    if (parsed.isEmpty) {
      return const _EmptyStateCard(
        icon: Icons.show_chart_rounded,
        title: 'No trend data available',
        subtitle:
        'Billing and usage trends will appear when recorded cycles are available.',
      );
    }

    final _UsagePoint latest = parsed.last;
    final _UsagePoint? previous =
    parsed.length >= 2 ? parsed[parsed.length - 2] : null;

    final _UsagePoint highestAmountPoint =
    parsed.fold<_UsagePoint>(
      parsed.first,
          (_UsagePoint previousPoint, _UsagePoint item) =>
      item.amount > previousPoint.amount
          ? item
          : previousPoint,
    );

    final _UsagePoint highestKwhPoint =
    parsed.fold<_UsagePoint>(
      parsed.first,
          (_UsagePoint previousPoint, _UsagePoint item) =>
      item.kwh > previousPoint.kwh
          ? item
          : previousPoint,
    );

    final double averageAmount = _average(
      parsed,
          (_UsagePoint point) => point.amount,
    );

    final double averageKwh = _average(
      parsed,
          (_UsagePoint point) => point.kwh,
    );

    final bool showingAmount =
        _mode == _UsageChartMode.amount;

    final ThemeData theme = Theme.of(context);

    final double latestValue =
    showingAmount ? latest.amount : latest.kwh;

    final double? previousValue = previous == null
        ? null
        : showingAmount
        ? previous.amount
        : previous.kwh;

    final double? percentChange = previousValue == null
        ? null
        : _percentageChange(
      latestValue,
      previousValue,
    );

    return _GlassShell(
      padding: const EdgeInsets.all(16),
      borderRadius: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _IconBubble(
                icon: Icons.insights_rounded,
                accent: _NebulaPalette.primary(context),
                size: 40,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Billing & Usage Trends',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Explore your recent billing cycles',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(
                        color:
                        _NebulaPalette.secondaryText(
                          context,
                        ),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  borderRadius:
                  BorderRadius.circular(999),
                  color: _NebulaPalette.primary(context)
                      .withValues(alpha: 0.08),
                  border: Border.all(
                    color:
                    _NebulaPalette.primary(context)
                        .withValues(alpha: 0.18),
                  ),
                ),
                child: Text(
                  '${parsed.length} cycle${parsed.length == 1 ? '' : 's'}',
                  style: TextStyle(
                    color:
                    _NebulaPalette.primary(context),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _ChartModeSelector(
            selectedMode: _mode,
            onChanged: (_UsageChartMode value) {
              setState(() {
                _mode = value;
              });
            },
          ),
          if (widget.items.length > 3) ...[
            const SizedBox(height: 9),
            _CycleRangeSelector(
              selectedRange: _cycleRange,
              canShowSix: widget.items.length > 3,
              onChanged: (int value) {
                setState(() {
                  _cycleRange = value;
                });
              },
            ),
          ],
          if (previous != null) ...[
            const SizedBox(height: 10),
            _MetricTrendBanner(
              mode: _mode,
              latest: latest,
              previous: previous,
              percentChange: percentChange,
            ),
          ],
          const SizedBox(height: 12),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: _PremiumTrendChart(
              key: ValueKey<String>(
                '${_mode.name}-$_cycleRange',
              ),
              points: parsed,
              mode: _mode,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ChartSummaryCard(
                  label: 'Latest',
                  value: showingAmount
                      ? '₱ ${latest.amount.toStringAsFixed(2)}'
                      : '${latest.kwh.toStringAsFixed(0)} kWh',
                  subtitle:
                  _UsageOverviewCard._fullMonth(
                    latest.month,
                  ),
                  icon: Icons.bolt_rounded,
                  accent:
                  _NebulaPalette.primary(context),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ChartSummaryCard(
                  label: 'Average',
                  value: showingAmount
                      ? '₱ ${averageAmount.toStringAsFixed(2)}'
                      : '${averageKwh.toStringAsFixed(0)} kWh',
                  subtitle:
                  'Last ${parsed.length} cycle${parsed.length == 1 ? '' : 's'}',
                  icon: Icons.analytics_outlined,
                  accent: _NebulaPalette.primary(context),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ChartSummaryCard(
                  label: 'Highest',
                  value: showingAmount
                      ? '₱ ${highestAmountPoint.amount.toStringAsFixed(2)}'
                      : '${highestKwhPoint.kwh.toStringAsFixed(0)} kWh',
                  subtitle:
                  _UsageOverviewCard._shortMonth(
                    showingAmount
                        ? highestAmountPoint.month
                        : highestKwhPoint.month,
                  ),
                  icon: Icons.trending_up_rounded,
                  accent: _NebulaPalette.gold(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.touch_app_rounded,
                size: 15,
                color:
                _NebulaPalette.secondaryText(context),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Tap or drag across the chart for exact values. Analytics use recorded billing data only.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(
                    color:
                    _NebulaPalette.secondaryText(
                      context,
                    ),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChartModeSelector extends StatelessWidget {
  const _ChartModeSelector({
    required this.selectedMode,
    required this.onChanged,
  });

  final _UsageChartMode selectedMode;
  final ValueChanged<_UsageChartMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _NebulaPalette.surfaceSoft(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _NebulaPalette.border(context),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ChartModeButton(
              label: 'Bill amount',
              icon: Icons.payments_outlined,
              selected: selectedMode == _UsageChartMode.amount,
              onTap: () => onChanged(_UsageChartMode.amount),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _ChartModeButton(
              label: 'Energy usage',
              icon: Icons.bolt_rounded,
              selected: selectedMode == _UsageChartMode.usage,
              onTap: () => onChanged(_UsageChartMode.usage),
            ),
          ),
        ],
      ),
    );
  }
}

class _CycleRangeSelector extends StatelessWidget {
  const _CycleRangeSelector({
    required this.selectedRange,
    required this.canShowSix,
    required this.onChanged,
  });

  final int selectedRange;
  final bool canShowSix;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          'View range',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(
            color:
            _NebulaPalette.secondaryText(context),
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        const Spacer(),
        _RangeChip(
          label: '3 cycles',
          selected: selectedRange == 3,
          onTap: () => onChanged(3),
        ),
        const SizedBox(width: 6),
        _RangeChip(
          label: '6 cycles',
          selected: selectedRange == 6,
          onTap: canShowSix
              ? () => onChanged(6)
              : null,
        ),
      ],
    );
  }
}

class _RangeChip extends StatelessWidget {
  const _RangeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Color accent =
    _NebulaPalette.primary(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 7,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: selected
                ? accent.withValues(alpha: 0.13)
                : _NebulaPalette.surfaceSoft(context),
            border: Border.all(
              color: selected
                  ? accent.withValues(alpha: 0.28)
                  : _NebulaPalette.border(context),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected
                  ? accent
                  : _NebulaPalette.secondaryText(
                context,
              ),
              fontSize: 10.5,
              fontWeight:
              selected ? FontWeight.w900 : FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _ChartModeButton extends StatelessWidget {
  const _ChartModeButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color accent = _NebulaPalette.primary(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 42,
          padding: const EdgeInsets.symmetric(
            horizontal: 9,
          ),
          decoration: BoxDecoration(
            color: selected ? accent.withValues(alpha: 0.13) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? accent.withValues(alpha: 0.22) : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected
                    ? accent
                    : _NebulaPalette.secondaryText(
                  context,
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: TextStyle(
                      color: selected
                          ? accent
                          : _NebulaPalette.secondaryText(context),
                      fontSize: 11.5,
                      fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                    ),
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

class _MetricTrendBanner extends StatelessWidget {
  const _MetricTrendBanner({
    required this.mode,
    required this.latest,
    required this.previous,
    required this.percentChange,
  });

  final _UsageChartMode mode;
  final _UsagePoint latest;
  final _UsagePoint previous;
  final double? percentChange;

  @override
  Widget build(BuildContext context) {
    final bool showingAmount =
        mode == _UsageChartMode.amount;

    final double latestValue =
    showingAmount ? latest.amount : latest.kwh;
    final double previousValue =
    showingAmount ? previous.amount : previous.kwh;
    final double difference =
        latestValue - previousValue;

    final bool increased = difference > 0.009;
    final bool decreased = difference < -0.009;

    final Color accent = decreased
        ? _NebulaPalette.success(context)
        : increased
        ? _NebulaPalette.warning(context)
        : _NebulaPalette.info(context);

    final IconData icon = decreased
        ? Icons.trending_down_rounded
        : increased
        ? Icons.trending_up_rounded
        : Icons.trending_flat_rounded;

    final String metricName =
    showingAmount ? 'Bill amount' : 'Energy usage';

    final String differenceText = showingAmount
        ? '${difference >= 0 ? '+' : '-'}₱${difference.abs().toStringAsFixed(2)}'
        : '${difference >= 0 ? '+' : '-'}${difference.abs().toStringAsFixed(0)} kWh';

    final String percentageText =
    percentChange == null
        ? ''
        : ' (${percentChange! >= 0 ? '+' : ''}${percentChange!.toStringAsFixed(1)}%)';

    final String previousMonth =
    _UsageOverviewCard._shortMonth(
      previous.month,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        12,
        10,
        12,
        10,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(
              alpha: Theme.of(context).brightness ==
                  Brightness.dark
                  ? 0.17
                  : 0.09,
            ),
            accent.withValues(
              alpha: Theme.of(context).brightness ==
                  Brightness.dark
                  ? 0.07
                  : 0.035,
            ),
          ],
        ),
        border: Border.all(
          color: accent.withValues(alpha: 0.20),
        ),
      ),
      child: Row(
        children: [
          _IconBubble(
            icon: icon,
            accent: accent,
            size: 36,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  '$metricName vs $previousMonth',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(
                    color: _NebulaPalette
                        .secondaryText(context),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$differenceText$percentageText',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(
                    color: accent,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          Text(
            decreased
                ? 'Lower'
                : increased
                ? 'Higher'
                : 'Stable',
            style: TextStyle(
              color: accent,
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumTrendChart extends StatelessWidget {
  const _PremiumTrendChart({
    super.key,
    required this.points,
    required this.mode,
  });

  final List<_UsagePoint> points;
  final _UsageChartMode mode;

  double _valueFor(_UsagePoint point) {
    return mode == _UsageChartMode.amount ? point.amount : point.kwh;
  }

  double _chartMaximum() {
    final double maximum = points.map(_valueFor).fold<double>(
      0,
          (double previous, double value) =>
      value > previous ? value : previous,
    );

    if (maximum <= 0) return 10;
    return maximum * 1.22;
  }

  double _axisInterval(double maximum) {
    if (maximum <= 0) return 1;

    final double raw = maximum / 4;
    final double exponent =
    (math.log(raw) / math.ln10).floorToDouble();
    final double magnitude =
    math.pow(10, exponent).toDouble();
    final double normalized = raw / magnitude;

    final double niceFactor;
    if (normalized <= 1) {
      niceFactor = 1;
    } else if (normalized <= 2) {
      niceFactor = 2;
    } else if (normalized <= 5) {
      niceFactor = 5;
    } else {
      niceFactor = 10;
    }

    return niceFactor * magnitude;
  }

  String _axisValue(double value) {
    if (mode == _UsageChartMode.amount) {
      if (value >= 1000) {
        final double thousands = value / 1000;
        return '₱${thousands.toStringAsFixed(
          thousands >= 10 ? 0 : 1,
        )}k';
      }

      return '₱${value.toStringAsFixed(0)}';
    }

    return value.toStringAsFixed(0);
  }

  String _tooltipValue(double value) {
    if (mode == _UsageChartMode.amount) {
      return '₱ ${value.toStringAsFixed(2)}';
    }

    return '${value.toStringAsFixed(0)} kWh';
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final Color lineColor = mode == _UsageChartMode.amount
        ? _NebulaPalette.gold(context)
        : _NebulaPalette.primary(context);

    final List<FlSpot> spots = points
        .asMap()
        .entries
        .map(
          (MapEntry<int, _UsagePoint> entry) => FlSpot(
        entry.key.toDouble(),
        _valueFor(entry.value),
      ),
    )
        .toList();

    final double maximum = _chartMaximum();
    final double interval = _axisInterval(maximum);

    return Container(
      height: 258,
      padding: const EdgeInsets.fromLTRB(
        8,
        16,
        12,
        8,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [Color(0xFF112535), Color(0xFF112535)]
              : const [Color(0xFFFFFFFF), Color(0xFFFFFFFF)],
        ),
        border: Border.all(
          color: _NebulaPalette.border(context),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:
            isDark ? 0.18 : 0.05,
            ),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: (points.length - 1).toDouble(),
          minY: 0,
          maxY: maximum,
          clipData: const FlClipData.all(),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: interval,
            getDrawingHorizontalLine: (double value) => FlLine(
              color: _NebulaPalette.border(context).withValues(alpha: 0.55),
              strokeWidth: 1,
              dashArray: const [5, 5],
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 46,
                interval: interval,
                getTitlesWidget: (
                    double value,
                    TitleMeta meta,
                    ) {
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    space: 7,
                    child: Text(
                      _axisValue(value),
                      style: TextStyle(
                        color: _NebulaPalette.secondaryText(context),
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: 1,
                getTitlesWidget: (
                    double value,
                    TitleMeta meta,
                    ) {
                  final int index = value.round();

                  if (index < 0 || index >= points.length) {
                    return const SizedBox.shrink();
                  }

                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    space: 8,
                    child: Text(
                      _UsageOverviewCard._shortMonth(
                        points[index].month,
                      ),
                      style: TextStyle(
                        color: index == points.length - 1
                            ? lineColor
                            : _NebulaPalette.secondaryText(context),
                        fontSize: 10,
                        fontWeight: index == points.length - 1
                            ? FontWeight.w900
                            : FontWeight.w700,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            enabled: true,
            handleBuiltInTouches: true,
            touchTooltipData: LineTouchTooltipData(
              tooltipBgColor: _NebulaPalette.surface(context),
              tooltipRoundedRadius: 12,
              tooltipPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
              ),
              fitInsideHorizontally: true,
              fitInsideVertically: true,
              getTooltipItems: (
                  List<LineBarSpot> touchedSpots,
                  ) {
                return touchedSpots.map<LineTooltipItem?>(
                      (LineBarSpot spot) {
                    final int index = spot.x.round();
                    final String month = _UsageOverviewCard._fullMonth(
                      points[index].month,
                    );

                    return LineTooltipItem(
                      '$month\n${_tooltipValue(spot.y)}',
                      TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                        height: 1.35,
                      ),
                    );
                  },
                ).toList();
              },
            ),
            getTouchedSpotIndicator: (
                LineChartBarData barData,
                List<int> spotIndexes,
                ) {
              return spotIndexes
                  .map(
                    (int index) => TouchedSpotIndicatorData(
                  FlLine(
                    color: lineColor.withValues(alpha: 0.45),
                    strokeWidth: 1.5,
                    dashArray: const [4, 4],
                  ),
                  FlDotData(
                    show: true,
                    getDotPainter: (
                        FlSpot spot,
                        double percent,
                        LineChartBarData bar,
                        int index,
                        ) {
                      return FlDotCirclePainter(
                        radius: 5,
                        color: lineColor,
                        strokeWidth: 3,
                        strokeColor: _NebulaPalette.surface(context),
                      );
                    },
                  ),
                ),
              )
                  .toList();
            },
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.28,
              color: lineColor,
              barWidth: 3.5,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                checkToShowDot: (
                    FlSpot spot,
                    LineChartBarData barData,
                    ) {
                  return true;
                },
                getDotPainter: (
                    FlSpot spot,
                    double percent,
                    LineChartBarData bar,
                    int index,
                    ) {
                  final bool isLatest =
                      index == points.length - 1;

                  return FlDotCirclePainter(
                    radius: isLatest ? 5 : 3,
                    color: lineColor,
                    strokeWidth: isLatest ? 3 : 2,
                    strokeColor:
                    _NebulaPalette.surface(context),
                  );
                },
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    lineColor.withValues(alpha: 0.24),
                    lineColor.withValues(alpha: 0.01),
                  ],
                ),
              ),
            ),
          ],
        ),
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      ),
    );
  }
}

class _ChartSummaryCard extends StatelessWidget {
  const _ChartSummaryCard({
    required this.label,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.accent,
  });

  final String label;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final bool isDark =
        Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        9,
        10,
        9,
        9,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(
              alpha: isDark ? 0.13 : 0.065,
            ),
            _NebulaPalette.surfaceSoft(context)
                .withValues(
              alpha: isDark ? 0.94 : 0.82,
            ),
          ],
        ),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: accent.withValues(alpha: 0.16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 15,
            color: accent,
          ),
          const SizedBox(height: 5),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(
              color:
              _NebulaPalette.secondaryText(
                context,
              ),
              fontSize: 9.8,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          SizedBox(
            width: double.infinity,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.center,
              child: Text(
                value,
                maxLines: 1,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(
                  color: accent,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(
              color:
              _NebulaPalette.secondaryText(
                context,
              ),
              fontSize: 9.2,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// A small, calm reminder for bills approaching their due date.
// This is presentation-only; the checked payment action comes from HomeScreen.
class _DueSoonCard extends StatelessWidget {
  const _DueSoonCard({
    required this.dueDate,
    required this.onPay,
  });

  final String dueDate;
  final VoidCallback onPay;

  @override
  Widget build(BuildContext context) {
    final int? days = _HomeDateTools.daysUntil(dueDate);
    if (days == null ||
        days < 0 ||
        days > 3 ||
        !BillPaymentDeadline.canStartOnlinePayment(dueDate)) {
      return const SizedBox.shrink();
    }

    // Always use the existing verified PH-date and payment-gating logic.
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final String formattedDue =
    _HomeDateTools.formatMonthDayYear(dueDate).toUpperCase();
    final String heading = days == 0
        ? 'YOUR BILL IS DUE TODAY'
        : days == 1
        ? 'YOUR BILL IS DUE TOMORROW'
        : 'YOUR BILL IS DUE IN $days DAYS';
    final String note = days == 0
        ? 'Last day to pay online.'
        : 'Pay ahead to avoid missing the deadline.';

    const Color deepNavy = Color(0xFF102F3E);
    const Color teal = Color(0xFF087F79);
    final Color cardColor = isDark
        ? const Color(0xFF1B3843)
        : const Color(0xFFEAF7F5);
    final Color headingColor = isDark ? const Color(0xFFF4FCFB) : deepNavy;
    final Color supportingColor = isDark
        ? const Color(0xFFD1E6E3)
        : const Color(0xFF466B73);
    final Color iconBackground = isDark
        ? const Color(0xFF28515C)
        : const Color(0xFFD4EEE9);
    final Color iconColor = isDark ? const Color(0xFF8AE3D5) : teal;

    Widget paymentButton() {
      return Material(
        color: deepNavy,
        borderRadius: BorderRadius.circular(11),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPay,
          borderRadius: BorderRadius.circular(11),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Text(
              'PAY NOW',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.15,
              ),
            ),
          ),
        ),
      );
    }

    final Widget reminderText = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: iconBackground,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.notifications_active_outlined,
            size: 21,
            color: iconColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                heading,
                style: TextStyle(
                  color: headingColor,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  height: 1.25,
                  letterSpacing: 0.1,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                formattedDue,
                style: TextStyle(
                  color: headingColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                note,
                style: TextStyle(
                  color: supportingColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? const Color(0xFF37616A)
              : const Color(0xFFCAEBE5),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Keep the smaller reminder readable on narrow Android screens.
          // A larger text-scale factor also gets a stacked button layout.
          final bool stackAction =
              constraints.maxWidth < 360 ||
                  MediaQuery.textScalerOf(context).scale(1.0) > 1.2;
          if (stackAction) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                reminderText,
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: paymentButton(),
                ),
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: reminderText),
              const SizedBox(width: 12),
              paymentButton(),
            ],
          );
        },
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.36),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: isDark ? 0.22 : 0.14),
            accent.withValues(alpha: isDark ? 0.08 : 0.06),
          ],
        ),
        border: Border.all(
          color: accent.withValues(alpha: 0.24),
        ),
      ),
      child: Icon(
        icon,
        color: accent,
        size: size * 0.45,
      ),
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  const _EmptyStateCard({
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
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _IconBubble(
              icon: icon,
              accent: _NebulaPalette.primary(context),
              size: 46,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: _NebulaPalette.secondaryText(context),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorGlassCard extends StatelessWidget {
  const _ErrorGlassCard({
    required this.title,
    required this.message,
    required this.onRetry,
  });

  final String title;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _GlassShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _IconBubble(
                icon: Icons.cloud_off_rounded,
                accent: Theme.of(context).colorScheme.error,
                size: 42,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: _NebulaPalette.secondaryText(context),
              fontWeight: FontWeight.w600,
            ),
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

class _QuickHelpSheet extends StatelessWidget {
  const _QuickHelpSheet();

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, bottom + 16),
      child: _GlassShell(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        borderRadius: 30,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: _NebulaPalette.border(context),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _IconBubble(
                  icon: Icons.auto_awesome_rounded,
                  accent: _NebulaPalette.primary(context),
                  size: 42,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Quick help',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Use this dashboard to review your current bill, open full bill details, check recent usage, and view payment or reminder information.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: _NebulaPalette.secondaryText(context),
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            const _HelpItem(
              icon: Icons.payment_rounded,
              title: 'Pay bill',
              subtitle:
              'Opens the payment method screen for your current cycle. Pay online before or on the due date; settle at the office starting the following day.',
            ),
            const SizedBox(height: 10),
            const _HelpItem(
              icon: Icons.receipt_long_rounded,
              title: 'View bill',
              subtitle:
              'Shows the detailed bill summary, amount due, and payment status.',
            ),
            const SizedBox(height: 10),
            const _HelpItem(
              icon: Icons.notifications_active_rounded,
              title: 'Remind',
              subtitle:
              'Explains how KuryentePay bill reminders are delivered through device notifications.',
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Got it'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HelpItem extends StatelessWidget {
  const _HelpItem({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _IconBubble(
          icon: icon,
          accent: _NebulaPalette.primary(context),
          size: 38,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: _NebulaPalette.secondaryText(context),
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: const [
        _SkeletonPanel(height: 98),
        SizedBox(height: 16),
        _SkeletonPanel(height: 312),
        SizedBox(height: 18),
        _SkeletonPanel(height: 392),
      ],
    );
  }
}

class _SkeletonPanel extends StatelessWidget {
  const _SkeletonPanel({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return _GlassShell(
      padding: EdgeInsets.zero,
      borderRadius: 26,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          color: isDark
              ? Colors.white.withValues(alpha: 0.035)
              : Colors.white.withValues(alpha: 0.40),
        ),
      ),
    );
  }
}

class _UsagePoint {
  const _UsagePoint({
    required this.month,
    required this.amount,
    required this.kwh,
  });

  final String month;
  final double amount;
  final double kwh;
}

class _HomeDateTools {
  static const List<String> _longMonths = [
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

  static DateTime? parseLoose(String raw) {
    final String value = raw.trim();
    if (value.isEmpty) return null;

    try {
      return DateTime.parse(value);
    } catch (_) {}

    try {
      return DateTime.parse(value.replaceFirst(' ', 'T'));
    } catch (_) {}

    return null;
  }

  static int? daysUntil(String raw) {
    // Calendar DATE from MySQL, not a time instant in the phone timezone.
    return BillPaymentDeadline.daysUntilDue(raw);
  }

  static String todayLabel() {
    final DateTime? today = BillPaymentDeadline.verifiedManilaToday;
    if (today == null) return 'Verifying PH date...';
    return '${_longMonths[today.month - 1].toUpperCase()} ${today.day}, ${today.year}';
  }

  static String formatBillingMonth(String raw) {
    final String value = raw.trim();
    if (value.isEmpty) return 'Current bill';

    final RegExpMatch? yearMonth =
    RegExp(r'^(\d{4})-(\d{2})$').firstMatch(value);

    if (yearMonth != null) {
      final int? month =
      int.tryParse(yearMonth.group(2) ?? '');
      final int? year =
      int.tryParse(yearMonth.group(1) ?? '');

      if (month != null &&
          month >= 1 &&
          month <= 12 &&
          year != null &&
          year >= 2000 &&
          year <= 2100) {
        return '${_longMonths[month - 1]} $year';
      }

      return 'Current bill';
    }

    final DateTime? parsed = parseLoose(value);
    if (parsed != null &&
        parsed.year >= 2000 &&
        parsed.year <= 2100) {
      return '${_longMonths[parsed.month - 1]} ${parsed.year}';
    }

    return 'Current bill';
  }

  static String formatMonthDayYear(String raw) {
    final DateTime? parsed = BillPaymentDeadline.parseDueDate(raw);
    if (parsed == null) return 'Due date unavailable';

    return '${_longMonths[parsed.month - 1].toUpperCase()} '
        '${parsed.day}, ${parsed.year}';
  }
}
