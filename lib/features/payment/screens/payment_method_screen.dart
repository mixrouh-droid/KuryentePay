// KuryentePay UI refresh: presentation-only, existing payment and date guards preserved.
import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/services/bill_payment_deadline.dart';
import '../../../shared/widgets/office_payment_notice.dart';
import 'payment_confirm_screen.dart';

class PaymentMethodScreen extends StatefulWidget {
  const PaymentMethodScreen({
    super.key,
    required this.billId,
    required this.billMonth,
    required this.amount,
    this.dueDate = '',
  });

  final int billId;
  final String billMonth;
  final double amount;
  final String dueDate;

  @override
  State<PaymentMethodScreen> createState() => _PaymentMethodScreenState();
}

class _PaymentMethodScreenState extends State<PaymentMethodScreen>
    with WidgetsBindingObserver {
  int get billId => widget.billId;
  String get billMonth => widget.billMonth;
  double get amount => widget.amount;
  String get dueDate => widget.dueDate;

  Timer? _dayTimer;
  DateTime _lastDay = BillPaymentDeadline.manilaToday();
  bool _lastVerified = BillPaymentDeadline.serverClockVerified;
  bool _clockRequestRunning = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_syncClockAndRebuild());
    _dayTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      final DateTime now = BillPaymentDeadline.manilaToday();
      final bool verified = BillPaymentDeadline.serverClockVerified;
      if (mounted &&
          (!now.isAtSameMomentAs(_lastDay) || verified != _lastVerified)) {
        setState(() {
          _lastDay = now;
          _lastVerified = verified;
        });
      }
      if (!verified) unawaited(_syncClockAndRebuild(force: true));
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
          _lastDay = BillPaymentDeadline.manilaToday();
          _lastVerified = BillPaymentDeadline.serverClockVerified;
        });
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_syncClockAndRebuild(force: true));
    }
  }

  @override
  void dispose() {
    _dayTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  String _safeBillingMonth(String raw) {
    final String value = raw.trim();
    if (value.isEmpty) return 'Current bill';

    final RegExp isoMonth = RegExp(r'^(\d{4})-(\d{2})$');
    final RegExpMatch? match = isoMonth.firstMatch(value);

    if (match != null) {
      final int? year = int.tryParse(match.group(1)!);
      final int? month = int.tryParse(match.group(2)!);

      if (year == null ||
          month == null ||
          year < 2000 ||
          year > 2100 ||
          month < 1 ||
          month > 12) {
        return 'Current bill';
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

      return '${months[month - 1]} $year';
    }

    final RegExp trailingYear = RegExp(r'(\d{4})$');
    final RegExpMatch? yearMatch = trailingYear.firstMatch(value);

    if (yearMatch != null) {
      final int? year = int.tryParse(yearMatch.group(1)!);
      if (year == null || year < 2000 || year > 2100) {
        return 'Current bill';
      }
    }

    return value;
  }

  @override
  Widget build(BuildContext context) {
    final String displayBillMonth = _safeBillingMonth(billMonth);
    final bool officeRequired =
    BillPaymentDeadline.isOfficePaymentRequired(dueDate);
    final bool onlinePaymentAllowed =
    BillPaymentDeadline.canStartOnlinePayment(dueDate);
    return Scaffold(
      backgroundColor: _PayPalette.background(context),
      body: Stack(
        children: [
          const _PayBackdrop(),
          SafeArea(
            bottom: false,
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 32),
              children: [
                _TopHeader(
                  onBack: () => Navigator.of(context).pop(),
                ),
                const SizedBox(height: 20),
                _HeroBillCard(
                  billMonth: displayBillMonth,
                  amount: amount,
                ),
                const SizedBox(height: 16),
                if (officeRequired) ...[
                  OfficePaymentNotice(
                    dueDate: dueDate,
                  ),
                ] else if (!onlinePaymentAllowed) ...[
                  const _PaymentUnavailableNotice(),
                ],
                if (onlinePaymentAllowed) ...[
                  const _SectionHeader(
                    title: 'Available Payment Method',
                    subtitle: 'Powered by PayMongo',
                  ),
                  const SizedBox(height: 10),
                  _MethodTile(
                    title: 'QR Ph',
                    subtitle:
                    'Pay using a supported banking or e-wallet app.',
                    accent: _PayPalette.info(context),
                    mainIcon: Icons.qr_code_2_rounded,
                    miniIcon: Icons.lock_rounded,
                    onTap: () {
                      if (!BillPaymentDeadline.canStartOnlinePayment(dueDate)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              BillPaymentDeadline.isOfficePaymentRequired(dueDate)
                                  ? BillPaymentDeadline.officeAction
                                  : 'The payment date could not be verified. Check your internet connection and try again.',
                            ),
                          ),
                        );
                        return;
                      }
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => PaymentConfirmScreen(
                            method: 'PayMongo QR Ph',
                            billMonth: displayBillMonth,
                            amount: amount,
                            billId: billId,
                            dueDate: dueDate,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  _InfoNoticeCard(
                    accent: _PayPalette.primary(context),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PayPalette {
  static const Color navy = Color(0xFF102F3E);
  static const Color deepNavy = Color(0xFF0B2634);
  static const Color teal = Color(0xFF087F79);
  static const Color mint = Color(0xFF6CE1CD);
  static const Color gold = Color(0xFFF6D483);

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color background(BuildContext context) =>
      isDark(context) ? const Color(0xFF091A24) : const Color(0xFFF4F7FA);

  static Color surface(BuildContext context) =>
      isDark(context) ? const Color(0xFF132B38) : Colors.white;

  static Color subtle(BuildContext context) =>
      isDark(context) ? const Color(0xFF1C3745) : const Color(0xFFF1F6F7);

  static Color border(BuildContext context) =>
      isDark(context) ? const Color(0xFF2D4754) : const Color(0xFFDFE8EC);

  static Color text(BuildContext context) =>
      isDark(context) ? const Color(0xFFF1F7F9) : const Color(0xFF173347);

  static Color muted(BuildContext context) =>
      isDark(context) ? const Color(0xFFBED0D8) : const Color(0xFF617989);

  static Color primary(BuildContext context) =>
      isDark(context) ? mint : teal;

  static Color info(BuildContext context) => primary(context);

  static Color success(BuildContext context) =>
      isDark(context) ? const Color(0xFF75D5AD) : const Color(0xFF138A60);
}

class _PayBackdrop extends StatelessWidget {
  const _PayBackdrop();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ColoredBox(
        color: _PayPalette.background(context),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _TopHeader extends StatelessWidget {
  const _TopHeader({required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Material(
          color: _PayPalette.surface(context),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
            side: BorderSide(color: _PayPalette.border(context)),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(13),
            onTap: onBack,
            child: SizedBox(
              height: 43,
              width: 43,
              child: Icon(Icons.arrow_back_rounded,
                  size: 20, color: _PayPalette.text(context)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Payment Method',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: _PayPalette.text(context),
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.35,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'KuryentePay · Secure Checkout',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: _PayPalette.muted(context),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Tooltip(
          message: 'Secure Checkout',
          child: Container(
            height: 39,
            width: 39,
            decoration: BoxDecoration(
              color: _PayPalette.primary(context).withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _PayPalette.primary(context).withValues(alpha: 0.18),
              ),
            ),
            child: Icon(
              Icons.verified_user_outlined,
              size: 19,
              color: _PayPalette.primary(context),
            ),
          ),
        ),
      ],
    );
  }
}

class _HeroBillCard extends StatelessWidget {
  const _HeroBillCard({required this.billMonth, required this.amount});
  final String billMonth;
  final double amount;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(19, 19, 19, 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_PayPalette.navy, _PayPalette.deepNavy],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF2E5965)),
        boxShadow: [
          BoxShadow(
            color: _PayPalette.deepNavy.withValues(alpha: 0.14),
            blurRadius: 24,
            offset: const Offset(0, 9),
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
                  color: Colors.white.withValues(alpha: 0.11),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.bolt_rounded,
                  size: 22,
                  color: _PayPalette.gold,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'KuryentePay',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                    letterSpacing: -0.25,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 9, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C514F),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  'Electric Bill',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: const Color(0xFFC4F4E8),
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 23),
          Text(
            'Total Amount Due',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: const Color(0xFFC5D7DF),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '₱${_displayAmount(amount)}',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                color: Colors.white,
                fontSize: 37,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.9,
                height: 1.1,
              ),
            ),
          ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 13),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.075),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.11),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_month_outlined,
                    size: 17, color: Color(0xFF9ADFD2)),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'Billing Month',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFFC5D7DF),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 9),
                Flexible(
                  child: Text(
                    billMonth,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
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

  // Presentation formatting only; does not change any payment amount.
  static String _displayAmount(double value) {
    final String fixed = value.toStringAsFixed(2);
    final List<String> parts = fixed.split('.');
    final String whole = parts.first.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (_) => ',',
    );
    return '$whole.${parts.last}';
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: _PayPalette.text(context),
                fontSize: 16.5,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.15,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              subtitle,
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: _PayPalette.muted(context),
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MethodTile extends StatelessWidget {
  const _MethodTile({
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.mainIcon,
    required this.miniIcon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final Color accent;
  final IconData mainIcon;
  final IconData miniIcon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _PayPalette.surface(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(19),
        side: BorderSide(color: _PayPalette.border(context)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(19),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    height: 52,
                    width: 52,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: accent.withValues(alpha: 0.18),
                      ),
                    ),
                    child: Icon(mainIcon, color: accent, size: 25),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: _PayPalette.text(context),
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'PayMongo · QR Ph',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: _PayPalette.muted(context),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded,
                      size: 23, color: _PayPalette.primary(context)),
                ],
              ),
              const SizedBox(height: 13),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: _PayPalette.muted(context),
                  fontSize: 12.5,
                  height: 1.38,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 11),
                decoration: BoxDecoration(
                  color: _PayPalette.subtle(context),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(miniIcon,
                        size: 15, color: _PayPalette.success(context)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Continue to Payment Review',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: _PayPalette.text(context),
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Icon(Icons.arrow_forward_rounded,
                        color: _PayPalette.primary(context), size: 17),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoNoticeCard extends StatelessWidget {
  const _InfoNoticeCard({required this.accent});
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.065),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.14)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_outlined, size: 20, color: accent),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Before You Continue',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: _PayPalette.text(context),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Review your bill before checkout. Your payment status updates only after the transaction is confirmed.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: _PayPalette.muted(context),
                    fontSize: 11.5,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
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

class _PaymentUnavailableNotice extends StatelessWidget {
  const _PaymentUnavailableNotice();

  @override
  Widget build(BuildContext context) {
    final Color accent = _PayPalette.primary(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _PayPalette.surface(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _PayPalette.border(context)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: accent, size: 21),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              'Online payment is temporarily unavailable while we verify the date. '
                  'Check your internet connection. If your bill has no due date, contact your billing administrator.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: _PayPalette.text(context),
                fontSize: 12,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
