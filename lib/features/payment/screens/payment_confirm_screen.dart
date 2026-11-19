// PAYMENT CONFIRM PREMIUM REVISION: backend-verified payment state, duplicate-payment protection, safer navigation, responsive review UI, and session-backed display details
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/services/payment_service.dart';
import '../../../core/services/bill_payment_deadline.dart';
import '../../../shared/widgets/office_payment_notice.dart';
import '../../../core/services/session_service.dart';

class PaymentConfirmScreen extends StatefulWidget {
  const PaymentConfirmScreen({
    super.key,
    required this.method,
    required this.billMonth,
    required this.amount,
    required this.billId,
    this.accountNo = '',
    this.dueDate = '',
    this.serviceAddress = '',
  });

  final String method;
  final String billMonth;
  final double amount;

  /// Internal backend identifier. It is required for payment creation but is
  /// intentionally not displayed to the consumer.
  final int billId;

  final String accountNo;
  final String dueDate;
  final String serviceAddress;

  @override
  State<PaymentConfirmScreen> createState() =>
      _PaymentConfirmScreenState();
}

class _PaymentConfirmScreenState
    extends State<PaymentConfirmScreen>
    with WidgetsBindingObserver {
  bool _loading = false;
  bool _detailsConfirmed = false;
  bool _awaitingVerification = false;
  bool _checkingPaymentStatus = false;
  bool _paymentConfirmed = false;
  bool _allowPop = false;
  Timer? _manilaDayTimer;
  DateTime _lastManilaDay = BillPaymentDeadline.manilaToday();
  bool _lastClockVerified = BillPaymentDeadline.serverClockVerified;
  bool _clockRequestRunning = false;

  String _activeAccountNo = '';
  String _paymentReference = '';
  String _displayAccountNo = '';
  String _displayServiceAddress = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_syncClockAndRebuild());
    _manilaDayTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      final DateTime date = BillPaymentDeadline.manilaToday();
      final bool verified = BillPaymentDeadline.serverClockVerified;
      if (mounted &&
          (!date.isAtSameMomentAs(_lastManilaDay) ||
              verified != _lastClockVerified)) {
        setState(() {
          _lastManilaDay = date;
          _lastClockVerified = verified;
        });
      }
      if (!verified) unawaited(_syncClockAndRebuild(force: true));
    });
    _displayAccountNo = widget.accountNo.trim();
    _displayServiceAddress = widget.serviceAddress.trim();
    unawaited(_loadDisplayDetails());
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
          _lastManilaDay = BillPaymentDeadline.manilaToday();
          _lastClockVerified = BillPaymentDeadline.serverClockVerified;
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

  Future<void> _loadDisplayDetails() async {
    try {
      final Map<String, dynamic>? user =
      await SessionService.loadUser();

      if (!mounted || user == null) return;

      final String sessionAccountNo =
      (user['account_no'] ?? '').toString().trim();
      final String sessionServiceAddress =
      (user['service_address'] ?? user['address'] ?? '')
          .toString()
          .trim();

      if (_displayAccountNo.isEmpty ||
          _displayServiceAddress.isEmpty) {
        setState(() {
          if (_displayAccountNo.isEmpty) {
            _displayAccountNo = sessionAccountNo;
          }
          if (_displayServiceAddress.isEmpty) {
            _displayServiceAddress = sessionServiceAddress;
          }
        });
      }
    } catch (_) {
      // Payment can still continue because _confirmPay resolves the session
      // again before creating checkout. This is display-only fallback data.
    }
  }

  Future<void> _handleBack() async {
    if (_loading) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please wait while the secure checkout is being prepared.',
          ),
        ),
      );
      return;
    }

    if (!_awaitingVerification && !_checkingPaymentStatus) {
      if (mounted) Navigator.of(context).pop();
      return;
    }

    final bool? leave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          icon: const Icon(Icons.schedule_rounded),
          title: const Text('Payment Verification Pending'),
          content: const Text(
            'You may leave this screen, but do not start another payment for the same bill. '
                'KuryentePay will show the verified payment status when you return.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Stay Here'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Leave Screen'),
            ),
          ],
        );
      },
    );

    if (leave == true && mounted) {
      setState(() => _allowPop = true);
      await Future<void>.delayed(Duration.zero);
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_syncClockAndRebuild(force: true));
    }
    if (state == AppLifecycleState.resumed &&
        _awaitingVerification &&
        !_checkingPaymentStatus) {
      unawaited(_verifyPaymentStatus());
    }
  }

  Future<void> _verifyPaymentStatus() async {
    if (_activeAccountNo.isEmpty || _checkingPaymentStatus) {
      return;
    }

    _checkingPaymentStatus = true;

    if (mounted) {
      setState(() {});
    }

    try {
      // Give the PayMongo webhook a short time to reach Hostinger,
      // then refresh the real bill state from the backend.
      for (int attempt = 0; attempt < 6; attempt++) {
        if (attempt > 0) {
          await Future<void>.delayed(
            const Duration(seconds: 2),
          );
        }

        final String? status =
        await PaymentService.getBillStatus(
          accountNo: _activeAccountNo,
        );

        if (status == 'PAID') {
          if (!mounted) return;

          setState(() {
            _awaitingVerification = false;
            _paymentConfirmed = true;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _paymentReference.isEmpty
                    ? 'Payment confirmed. Your bill is now marked Paid.'
                    : 'Payment confirmed. Reference: $_paymentReference',
              ),
              duration: const Duration(seconds: 5),
            ),
          );

          return;
        }
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Payment is still being verified. Do not pay again. Use Check status after a moment if the update has not appeared yet.',
          ),
          duration: Duration(seconds: 5),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      debugPrint(
        'Payment status refresh failed: ${error.runtimeType}',
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to refresh the payment status right now. '
                'Check your internet connection and try again shortly.',
          ),
        ),
      );
    } finally {
      _checkingPaymentStatus = false;

      if (mounted) {
        setState(() {});
      }
    }
  }

  String _friendlyPaymentError(Object error) {
    final String raw =
    error.toString().replaceFirst('Exception: ', '').trim();
    final String lower = raw.toLowerCase();

    if (lower.contains('proceed to ileco office') ||
        lower.contains('online payment unavailable') ||
        lower.contains('deadline has been reached') ||
        lower.contains('due date has been reached')) {
      return '${BillPaymentDeadline.title}. ${BillPaymentDeadline.officeAction}';
    }

    if (lower.contains('session') ||
        lower.contains('log in') ||
        lower.contains('login')) {
      return 'Your session has ended. Please sign in again.';
    }

    if (lower.contains('already paid') ||
        lower.contains('bill is paid') ||
        lower.contains('paid bill')) {
      return 'This bill appears to be already paid. '
          'Check the current payment status before starting another payment.';
    }

    if (lower.contains('pending') ||
        lower.contains('processing') ||
        lower.contains('in progress')) {
      return 'A payment for this bill is already being processed. '
          'Do not pay again while verification is pending.';
    }

    if (lower.contains('socket') ||
        lower.contains('network') ||
        lower.contains('connection') ||
        lower.contains('timeout') ||
        lower.contains('failed host lookup')) {
      return 'Unable to connect to KuryentePay. '
          'Check your internet connection and try again.';
    }

    if (lower.contains('checkout') ||
        lower.contains('link') ||
        lower.contains('url')) {
      return 'Unable to open the secure PayMongo checkout right now. '
          'Please try again.';
    }

    return 'Payment could not be started. Please try again. '
        'If you already completed a payment, check its status first.';
  }

  Future<void> _confirmPay() async {
    if (_loading ||
        !_detailsConfirmed ||
        _awaitingVerification ||
        _checkingPaymentStatus ||
        _paymentConfirmed) {
      return;
    }

    // Recheck the official server date before a brand-new checkout.
    if (!BillPaymentDeadline.serverClockVerified) {
      await _syncClockAndRebuild(force: true);
      if (!mounted) return;
    }

    if (BillPaymentDeadline.isOfficePaymentRequired(widget.dueDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(BillPaymentDeadline.officeAction)),
      );
      return;
    }
    if (!BillPaymentDeadline.canStartOnlinePayment(widget.dueDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(
          'Unable to verify the payment deadline. Check your internet connection; the app will retry automatically.',
        )),
      );
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() => _loading = true);

    try {
      final Map<String, dynamic>? user =
      await SessionService.loadUser();

      final String sessionAccountNo =
      (user?['account_no'] ?? '').toString().trim();

      final String accountNo =
      widget.accountNo.trim().isNotEmpty
          ? widget.accountNo.trim()
          : sessionAccountNo;

      if (accountNo.isEmpty) {
        throw Exception(
          'No account session. Please log in again.',
        );
      }

      // Guard again after loading the session, in case the day changed while
      // the user was on this screen. PHP independently enforces the cutoff.
      if (!BillPaymentDeadline.canStartOnlinePayment(widget.dueDate)) {
        throw Exception(BillPaymentDeadline.officeAction);
      }

      final Map<String, dynamic> response =
      await PaymentService.createPayMongoPayment(
        accountNo: accountNo,
        billId: widget.billId,
      );

      // A checkout response could arrive just after midnight in Manila.
      // Never launch it if this bill has passed its online deadline.
      if (!BillPaymentDeadline.canStartOnlinePayment(widget.dueDate)) {
        throw Exception(BillPaymentDeadline.officeAction);
      }

      final String checkoutLink =
      PaymentService.getCheckoutUrl(response);

      final Uri? checkoutUri =
      Uri.tryParse(checkoutLink);

      if (checkoutUri == null ||
          checkoutUri.scheme.toLowerCase() != 'https' ||
          checkoutUri.host.isEmpty) {
        throw Exception(
          'Invalid PayMongo checkout link.',
        );
      }

      final dynamic paymentData = response['payment'];
      final String reference =
      paymentData is Map
          ? (paymentData['reference_no'] ?? '')
          .toString()
          .trim()
          : '';

      if (mounted) {
        setState(() {
          _awaitingVerification = true;
          _paymentConfirmed = false;
          _activeAccountNo = accountNo;
          _displayAccountNo = accountNo;
          if (_displayServiceAddress.isEmpty) {
            _displayServiceAddress =
                (user?['service_address'] ?? user?['address'] ?? '')
                    .toString()
                    .trim();
          }
          _paymentReference = reference;
        });
      }

      final bool opened = await launchUrl(
        checkoutUri,
        mode: LaunchMode.externalApplication,
      );

      if (!opened) {
        if (mounted) {
          setState(() {
            _awaitingVerification = false;
          });
        }

        throw Exception(
          'Unable to open the PayMongo checkout.',
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'PayMongo checkout opened. Complete your payment, then return to KuryentePay. '
                'Do not start another payment while verification is pending.',
          ),
          duration: Duration(seconds: 5),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      debugPrint(
        'Payment checkout start failed: ${error.runtimeType}',
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_friendlyPaymentError(error)),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const double convenienceFee = 0.00;
    final double total = widget.amount + convenienceFee;
    final bool activeVerification =
        _awaitingVerification || _checkingPaymentStatus || _paymentConfirmed;
    final bool officeRequired = !activeVerification &&
        BillPaymentDeadline.isOfficePaymentRequired(widget.dueDate);
    final bool paymentDateValid =
    BillPaymentDeadline.canStartOnlinePayment(widget.dueDate);

    return PopScope(
      canPop: _allowPop ||
          (!_loading &&
              !_awaitingVerification &&
              !_checkingPaymentStatus),
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) {
          unawaited(_handleBack());
        }
      },
      child: Scaffold(
        backgroundColor: _ConfirmPalette.background(context),
        body: Stack(
          children: [
            const _ConfirmBackdrop(),
            SafeArea(
              bottom: false,
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  16,
                  8,
                  16,
                  118,
                ),
                children: [
                  _ConfirmHeader(
                    onBack: _handleBack,
                  ),
                  const SizedBox(height: 14),
                  _PaymentHero(
                    amount: total,
                    method: widget.method,
                  ),
                  const SizedBox(height: 16),
                  const _SectionHeading(
                    title: 'Bill Details',
                    subtitle: 'Confirm the account and billing information',
                  ),
                  const SizedBox(height: 8),
                  _PaymentDetailsCard(
                    accountNo: _displayAccountNo,
                    billMonth: widget.billMonth,
                    dueDate: BillPaymentDeadline.friendlyDueDate(widget.dueDate),
                    serviceAddress: _displayServiceAddress,
                  ),
                  const SizedBox(height: 16),
                  const _SectionHeading(
                    title: 'Payment Summary',
                    subtitle: 'Review the total before continuing',
                  ),
                  const SizedBox(height: 8),
                  _AmountSummaryCard(
                    billAmount: widget.amount,
                    convenienceFee: convenienceFee,
                    total: total,
                  ),
                  const SizedBox(height: 12),
                  if (officeRequired) ...[
                    OfficePaymentNotice(
                      dueDate: widget.dueDate,
                    ),
                  ] else if (!paymentDateValid && !activeVerification) ...[
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'Online payment is waiting for deadline verification. Check your connection. If the bill due date is missing, contact your billing administrator.',
                        ),
                      ),
                    ),
                  ] else ...[
                    _PayMongoNotice(
                      awaitingVerification: _awaitingVerification,
                      checkingStatus: _checkingPaymentStatus,
                      paymentConfirmed: _paymentConfirmed,
                      onCheckStatus: _awaitingVerification &&
                          !_checkingPaymentStatus
                          ? _verifyPaymentStatus
                          : null,
                    ),
                    const SizedBox(height: 12),
                    _ConfirmationCard(
                      value: _detailsConfirmed,
                      onChanged: _loading ||
                          _awaitingVerification ||
                          _checkingPaymentStatus ||
                          _paymentConfirmed ||
                          !paymentDateValid
                          ? null
                          : (bool? value) {
                        setState(() => _detailsConfirmed = value ?? false);
                      },
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: officeRequired
            ? SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: FilledButton.icon(
              onPressed: null,
              icon: const Icon(Icons.lock_outline_rounded),
              label: const Text('Online Payment Unavailable'),
            ),
          ),
        )
            : _ConfirmBottomBar(
          amount: total,
          enabled: _detailsConfirmed &&
              paymentDateValid &&
              !_loading &&
              !_awaitingVerification &&
              !_checkingPaymentStatus &&
              !_paymentConfirmed,
          loading: _loading,
          awaitingVerification: _awaitingVerification,
          checkingStatus: _checkingPaymentStatus,
          paymentConfirmed: _paymentConfirmed,
          onContinue: _confirmPay,
        ),
      ),
    );
  }
}

// Presentation-only design tokens for this screen.
// Font comes from the existing AppTheme (Manrope). No added dependencies.
class _ConfirmPalette {
  static const Color navy = Color(0xFF102F3E);
  static const Color navyDeep = Color(0xFF0B2634);
  static const Color teal = Color(0xFF087F79);
  static const Color mint = Color(0xFF6CE1CD);
  static const Color goldLight = Color(0xFFF6D483);

  static bool _isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color background(BuildContext context) =>
      _isDark(context) ? const Color(0xFF091A24) : const Color(0xFFF4F7FA);

  static Color surface(BuildContext context) =>
      _isDark(context) ? const Color(0xFF132B38) : Colors.white;

  static Color subtleSurface(BuildContext context) => _isDark(context)
      ? const Color(0xFF1C3745)
      : const Color(0xFFF5F8F9);

  static Color border(BuildContext context) =>
      _isDark(context) ? const Color(0xFF2D4754) : const Color(0xFFDFE8EC);

  static Color text(BuildContext context) =>
      _isDark(context) ? const Color(0xFFF1F7F9) : const Color(0xFF173347);

  static Color secondaryText(BuildContext context) =>
      _isDark(context) ? const Color(0xFFBED0D8) : const Color(0xFF617989);

  static Color primary(BuildContext context) =>
      _isDark(context) ? mint : teal;

  static Color info(BuildContext context) =>
      _isDark(context) ? mint : teal;

  static Color gold(BuildContext context) =>
      _isDark(context) ? goldLight : const Color(0xFFAF7624);

  static Color success(BuildContext context) =>
      _isDark(context) ? const Color(0xFF75D5AD) : const Color(0xFF138A60);
}

class _ConfirmBackdrop extends StatelessWidget {
  const _ConfirmBackdrop();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _ConfirmPalette.background(context),
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _ConfirmHeader extends StatelessWidget {
  const _ConfirmHeader({required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _HeaderButton(icon: Icons.arrow_back_rounded, onTap: onBack),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Payment Review',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: _ConfirmPalette.text(context),
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
                  color: _ConfirmPalette.secondaryText(context),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        const _SecureBadge(),
      ],
    );
  }
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _ConfirmPalette.surface(context),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: _ConfirmPalette.border(context)),
        borderRadius: BorderRadius.circular(13),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: SizedBox(
          height: 43,
          width: 43,
          child: Icon(icon, color: _ConfirmPalette.text(context), size: 20),
        ),
      ),
    );
  }
}

class _SecureBadge extends StatelessWidget {
  const _SecureBadge();

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Secure Checkout',
      child: Container(
        height: 39,
        width: 39,
        decoration: BoxDecoration(
          color: _ConfirmPalette.primary(context).withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _ConfirmPalette.primary(context).withValues(alpha: 0.18),
          ),
        ),
        child: Icon(
          Icons.verified_user_outlined,
          size: 19,
          color: _ConfirmPalette.primary(context),
        ),
      ),
    );
  }
}

class _PaymentHero extends StatelessWidget {
  const _PaymentHero({required this.amount, required this.method});
  final double amount;
  final String method;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(19, 19, 19, 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_ConfirmPalette.navy, _ConfirmPalette.navyDeep],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF2E5965)),
        boxShadow: [
          BoxShadow(
            color: _ConfirmPalette.navyDeep.withValues(alpha: 0.15),
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
                height: 38,
                width: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.11),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.bolt_rounded,
                  size: 22,
                  color: _ConfirmPalette.goldLight,
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
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.25,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C514F),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  'Electric Bill',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFC4F4E8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 26),
          Text(
            'Total to Pay',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xFFC5D7DF),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 5),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '₱${amount.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                color: Colors.white,
                fontSize: 37,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.8,
                height: 1.1,
              ),
            ),
          ),
          const SizedBox(height: 23),
          Divider(
            height: 1,
            color: Colors.white.withValues(alpha: 0.16),
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              const Icon(
                Icons.qr_code_2_rounded,
                size: 21,
                color: _ConfirmPalette.mint,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Payment Method',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: const Color(0xFFBED2D9),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      method,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.lock_outline_rounded,
                color: Color(0xFFB6D4D7),
                size: 17,
              ),
            ],
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: _ConfirmPalette.text(context),
            fontSize: 16.5,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.15,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: _ConfirmPalette.secondaryText(context),
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _PaymentDetailsCard extends StatelessWidget {
  const _PaymentDetailsCard({
    required this.accountNo,
    required this.billMonth,
    required this.dueDate,
    required this.serviceAddress,
  });
  final String accountNo;
  final String billMonth;
  final String dueDate;
  final String serviceAddress;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _DetailRow(
            icon: Icons.person_outline_rounded,
            label: 'Account Number',
            value: accountNo.trim().isEmpty ? 'Not available' : accountNo.trim(),
            accent: _ConfirmPalette.primary(context),
          ),
          const _CardDivider(),
          _DetailRow(
            icon: Icons.calendar_month_outlined,
            label: 'Billing Month',
            value: billMonth.trim().isEmpty ? 'Not available' : billMonth.trim(),
            accent: _ConfirmPalette.primary(context),
          ),
          const _CardDivider(),
          _DetailRow(
            icon: Icons.event_available_outlined,
            label: 'Due Date',
            value: dueDate.trim().isEmpty ? 'Not available' : dueDate.trim(),
            accent: _ConfirmPalette.gold(context),
          ),
          const _CardDivider(),
          _DetailRow(
            icon: Icons.location_on_outlined,
            label: 'Service Address',
            value: serviceAddress.trim().isEmpty
                ? 'Not available'
                : serviceAddress.trim(),
            accent: _ConfirmPalette.primary(context),
            maxLines: 3,
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
    required this.accent,
    this.maxLines = 1,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color accent;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      child: Row(
        // Long addresses should not pull the location icon downward.
        // Keep its centre aligned with the Service Address heading instead.
        crossAxisAlignment: maxLines > 1
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          _IconTile(icon: icon, accent: accent, size: 38),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: maxLines > 1 ? 9 : 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: _ConfirmPalette.secondaryText(context),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  SelectableText(
                    value,
                    maxLines: maxLines,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: _ConfirmPalette.text(context),
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      height: 1.32,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AmountSummaryCard extends StatelessWidget {
  const _AmountSummaryCard({
    required this.billAmount,
    required this.convenienceFee,
    required this.total,
  });
  final double billAmount;
  final double convenienceFee;
  final double total;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      padding: const EdgeInsets.fromLTRB(15, 15, 15, 13),
      child: Column(
        children: [
          _AmountRow(label: 'Bill Amount', value: _money(billAmount)),
          const SizedBox(height: 12),
          _AmountRow(label: 'Service Fee', value: _money(convenienceFee)),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color: _ConfirmPalette.primary(context).withValues(alpha: 0.075),
              borderRadius: BorderRadius.circular(13),
            ),
            child: _AmountRow(
              label: 'Total to Pay',
              value: _money(total),
              emphasized: true,
            ),
          ),
        ],
      ),
    );
  }

  static String _money(double value) => '₱${value.toStringAsFixed(2)}';
}

class _AmountRow extends StatelessWidget {
  const _AmountRow({
    required this.label,
    required this.value,
    this.emphasized = false,
  });
  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: emphasized
                  ? _ConfirmPalette.text(context)
                  : _ConfirmPalette.secondaryText(context),
              fontSize: emphasized ? 13.5 : 12.5,
              fontWeight: emphasized ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: FittedBox(
            alignment: Alignment.centerRight,
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: emphasized
                    ? _ConfirmPalette.primary(context)
                    : _ConfirmPalette.text(context),
                fontSize: emphasized ? 18 : 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PayMongoNotice extends StatelessWidget {
  const _PayMongoNotice({
    required this.awaitingVerification,
    required this.checkingStatus,
    required this.paymentConfirmed,
    required this.onCheckStatus,
  });
  final bool awaitingVerification;
  final bool checkingStatus;
  final bool paymentConfirmed;
  final VoidCallback? onCheckStatus;

  @override
  Widget build(BuildContext context) {
    final Color accent = paymentConfirmed
        ? _ConfirmPalette.success(context)
        : awaitingVerification || checkingStatus
        ? _ConfirmPalette.info(context)
        : _ConfirmPalette.primary(context);

    final String title = paymentConfirmed
        ? 'Payment Confirmed'
        : checkingStatus
        ? 'Checking Payment'
        : awaitingVerification
        ? 'Verification Pending'
        : 'Secure Payment';

    final String message = paymentConfirmed
        ? 'Your payment is verified and your bill is marked Paid.'
        : checkingStatus
        ? 'Checking the latest payment status. This may take a moment.'
        : awaitingVerification
        ? 'Do not make another payment while verification is pending. '
        'You can check the status again shortly.'
        : 'You will be directed to PayMongo to complete your payment. '
        'Your bill is marked Paid only after confirmation.';

    final IconData statusIcon = paymentConfirmed
        ? Icons.verified_rounded
        : checkingStatus
        ? Icons.sync_rounded
        : awaitingVerification
        ? Icons.schedule_rounded
        : Icons.shield_outlined;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: accent.withValues(alpha: 0.19)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (checkingStatus)
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2, color: accent),
            )
          else
            Icon(statusIcon, color: accent, size: 22),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: _ConfirmPalette.text(context),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: _ConfirmPalette.secondaryText(context),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    height: 1.43,
                  ),
                ),
                if (onCheckStatus != null) ...[
                  const SizedBox(height: 7),
                  TextButton.icon(
                    onPressed: onCheckStatus,
                    icon: const Icon(Icons.refresh_rounded, size: 17),
                    label: const Text('Check Status'),
                    style: TextButton.styleFrom(
                      foregroundColor: _ConfirmPalette.primary(context),
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
                      minimumSize: const Size(0, 36),
                    ),
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

class _ConfirmationCard extends StatelessWidget {
  const _ConfirmationCard({required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool?>? onChanged;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: CheckboxListTile(
        value: value,
        onChanged: onChanged,
        activeColor: _ConfirmPalette.teal,
        checkColor: Colors.white,
        controlAffinity: ListTileControlAffinity.leading,
        contentPadding: const EdgeInsets.symmetric(horizontal: 5),
        title: Text(
          'I have reviewed my payment details.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: _ConfirmPalette.text(context),
            fontSize: 12.8,
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: Text(
          'I confirm the amount and bill information are correct.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: _ConfirmPalette.secondaryText(context),
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
            height: 1.35,
          ),
        ),
      ),
    );
  }
}

class _ConfirmBottomBar extends StatelessWidget {
  const _ConfirmBottomBar({
    required this.amount,
    required this.enabled,
    required this.loading,
    required this.awaitingVerification,
    required this.checkingStatus,
    required this.paymentConfirmed,
    required this.onContinue,
  });
  final double amount;
  final bool enabled;
  final bool loading;
  final bool awaitingVerification;
  final bool checkingStatus;
  final bool paymentConfirmed;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final double safeBottom = MediaQuery.of(context).padding.bottom;
    final String buttonText = loading
        ? 'Opening Checkout…'
        : checkingStatus
        ? 'Checking Status…'
        : paymentConfirmed
        ? 'Payment Confirmed'
        : awaitingVerification
        ? 'Verification Pending'
        : 'Continue to PayMongo';

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16, 12, 16, safeBottom + 12),
      decoration: BoxDecoration(
        color: _ConfirmPalette.surface(context),
        border: Border(top: BorderSide(color: _ConfirmPalette.border(context))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: Theme.of(context).brightness == Brightness.dark ? 0.20 : 0.055,
            ),
            blurRadius: 18,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bool compact = constraints.maxWidth < 355;
          final Widget amountLine = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Total to Pay',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: _ConfirmPalette.secondaryText(context),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '₱${amount.toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: _ConfirmPalette.text(context),
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          );

          final Widget button = SizedBox(
            height: 50,
            width: compact ? double.infinity : null,
            child: FilledButton.icon(
              onPressed: enabled ? onContinue : null,
              icon: loading || checkingStatus
                  ? const SizedBox(
                height: 17,
                width: 17,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
                  : Icon(
                paymentConfirmed
                    ? Icons.verified_rounded
                    : awaitingVerification
                    ? Icons.schedule_rounded
                    : Icons.arrow_forward_rounded,
                size: 18,
              ),
              label: Text(buttonText),
              style: FilledButton.styleFrom(
                backgroundColor: _ConfirmPalette.teal,
                foregroundColor: Colors.white,
                disabledBackgroundColor: _ConfirmPalette.border(context),
                disabledForegroundColor: _ConfirmPalette.secondaryText(context),
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: const TextStyle(
                  fontSize: 12.8,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                amountLine,
                const SizedBox(height: 10),
                button,
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: amountLine),
              const SizedBox(width: 12),
              button,
            ],
          );
        },
      ),
    );
  }
}

class _SurfaceCard extends StatelessWidget {
  const _SurfaceCard({
    required this.child,
    this.padding = const EdgeInsets.all(15),
  });
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: _ConfirmPalette.surface(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _ConfirmPalette.border(context)),
        boxShadow: [
          BoxShadow(
            color: dark
                ? Colors.black.withValues(alpha: 0.12)
                : _ConfirmPalette.navy.withValues(alpha: 0.035),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _IconTile extends StatelessWidget {
  const _IconTile({
    required this.icon,
    required this.accent,
    this.size = 38,
  });
  final IconData icon;
  final Color accent;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.095),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, size: 19, color: accent),
    );
  }
}

class _CardDivider extends StatelessWidget {
  const _CardDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 15,
      endIndent: 15,
      color: _ConfirmPalette.border(context),
    );
  }
}
