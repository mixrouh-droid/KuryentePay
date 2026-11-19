// KuryentePay Payment Receipt: presentation-only redesign; transaction and status logic preserved.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/routes/app_router.dart';

class PaymentReceiptScreen extends StatelessWidget {
  const PaymentReceiptScreen({
    super.key,
    required this.method,
    required this.billMonth,
    required this.amount,
    required this.reference,
    this.receipt,
  });

  final String method;
  final String billMonth;
  final double amount;
  final String reference;
  final Map<String, dynamic>? receipt;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final Map<String, dynamic> r =
        receipt ?? const <String, dynamic>{};

    final String status =
    (r['status'] ?? 'PENDING').toString().trim().toUpperCase();
    final String paidAtRaw =
    (r['paid_at'] ?? '').toString().trim();
    final String accountNo =
    (r['account_no'] ?? '').toString().trim();

    final Map<String, dynamic>? bill =
    r['bill'] is Map<String, dynamic>
        ? r['bill'] as Map<String, dynamic>
        : null;

    final String billMonthX = _safeBillingMonth(
      (bill?['billing_month'] ?? billMonth).toString(),
    );
    final String dueDateRaw =
    (bill?['due_date'] ?? '').toString().trim();
    final String dueDate =
    dueDateRaw.isEmpty ? '' : _prettyDateOnly(dueDateRaw);
    final String billStatusAfter =
    (bill?['payment_status_after'] ?? '').toString().trim();

    final String methodX = _paymentMethodLabel(
      receipt: r,
      fallbackMethod: method,
    );
    final String referenceX =
    (r['reference_no'] ?? reference).toString().trim();
    final double amountX = _toDouble(r['amount']) ?? amount;

    final bool isSuccess =
        status == 'SUCCESS' || status == 'PAID';

    final bool isPending =
        status == 'PENDING' ||
            status == 'PROCESSING' ||
            status == 'VERIFYING';

    final Color statusColor = isSuccess
        ? _ReceiptTones.success(context)
        : isPending
        ? _ReceiptTones.warning(context)
        : cs.error;

    return Scaffold(
      backgroundColor: _ReceiptTones.background(context),
      body: Stack(
        children: [
          const Positioned.fill(child: _ReceiptBackground()),
          SafeArea(
            bottom: false,
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                _ReceiptHeader(isSuccess: isSuccess),
                const SizedBox(height: 14),
                _HeroReceiptCard(
                  isSuccess: isSuccess,
                  isPending: isPending,
                  status: status,
                  statusColor: statusColor,
                  amount: amountX,
                ),
                const SizedBox(height: 16),
                const _SectionTitle(
                  title: 'Transaction Details',
                  subtitle: 'Billing and payment record',
                ),
                const SizedBox(height: 9),
                _GlassPanel(
                  padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
                  borderRadius: 24,
                  child: Column(
                    children: [
                      _DetailRow(
                        label: 'Billing Month',
                        value: billMonthX.isEmpty ? '—' : billMonthX,
                      ),
                      if (dueDate.isNotEmpty)
                        _DetailRow(
                          label: 'Due Date',
                          value: dueDate,
                        ),
                      if (accountNo.isNotEmpty)
                        _DetailRow(
                          label: 'Account Number',
                          value: accountNo,
                        ),
                      _DetailRow(
                        label: 'Payment Method',
                        value: methodX,
                      ),
                      _DetailRow(
                        label: 'Reference Number',
                        value: referenceX.isEmpty ? '—' : referenceX,
                      ),
                      _DetailRow(
                        label: 'Amount',
                        value: _ReceiptCurrency.peso(amountX),
                        bold: true,
                      ),
                      if (paidAtRaw.isNotEmpty)
                        _DetailRow(
                          label: 'Paid On',
                          value: _prettyDate(paidAtRaw),
                        ),
                      if (billStatusAfter.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: _StatusChip(status: billStatusAfter),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _StatusNotice(
                  isSuccess: isSuccess,
                  isPending: isPending,
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _SecondaryActionButton(
                        icon: Icons.copy_rounded,
                        label: 'Copy Reference',
                        enabled: referenceX.isNotEmpty,
                        onTap: referenceX.isEmpty
                            ? null
                            : () => _copy(context, referenceX),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _PrimaryActionButton(
                        icon: Icons.home_rounded,
                        label: 'Return Home',
                        onTap: () {
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                              builder: (_) => const MainShell(),
                            ),
                                (route) => false,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

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

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static String _safeBillingMonth(String raw) {
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

      return '${_monthNames[month - 1]} $year';
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

  static DateTime? _parseDate(String raw) {
    final String value = raw.trim();
    if (value.isEmpty) return null;

    try {
      return DateTime.parse(
        value.contains('T') ? value : value.replaceFirst(' ', 'T'),
      );
    } catch (_) {
      return null;
    }
  }

  static String _prettyDateOnly(String raw) {
    final DateTime? parsed = _parseDate(raw);
    if (parsed == null) {
      return raw.trim().isEmpty ? '—' : raw.trim();
    }

    return '${_monthNames[parsed.month - 1]} '
        '${parsed.day}, ${parsed.year}';
  }

  static String _prettyDate(String raw) {
    final DateTime? parsed = _parseDate(raw);
    if (parsed == null) {
      return raw.trim().isEmpty ? '—' : raw.trim();
    }

    final DateTime local =
    parsed.isUtc ? parsed.toLocal() : parsed;

    final int hour12 = local.hour == 0
        ? 12
        : local.hour > 12
        ? local.hour - 12
        : local.hour;
    final String minute =
    local.minute.toString().padLeft(2, '0');
    final String period =
    local.hour >= 12 ? 'PM' : 'AM';

    return '${_monthNames[local.month - 1]} '
        '${local.day}, ${local.year} • '
        '$hour12:$minute $period';
  }

  static String _paymentMethodLabel({
    required Map<String, dynamic> receipt,
    required String fallbackMethod,
  }) {
    final String provider =
    (receipt['provider'] ?? '')
        .toString()
        .trim()
        .toUpperCase();
    final String channel =
    (receipt['payment_channel'] ?? '')
        .toString()
        .trim()
        .toUpperCase();
    final String fallback = fallbackMethod.trim();

    // Legacy office-payment records keep their original provider in storage.
    // The UI uses independent KuryentePay terminology.
    if (channel == 'OFFICE' || provider == 'ILECO') {
      return 'Office Payment';
    }

    final String providerLabel =
    provider == 'PAYMONGO' ? 'PayMongo' : provider;
    final String channelLabel =
    channel == 'QRPH' ? 'QR Ph' : channel;

    if (providerLabel.isNotEmpty && channelLabel.isNotEmpty) {
      return '$providerLabel • $channelLabel';
    }

    if (providerLabel.isNotEmpty) return providerLabel;
    if (channelLabel.isNotEmpty) return channelLabel;

    if (fallback.toUpperCase() == 'ONLINE') {
      return 'Online payment';
    }

    return fallback.isEmpty ? 'Payment' : fallback;
  }

  static String _statusLabel(String raw) {
    switch (raw.trim().toUpperCase()) {
      case 'SUCCESS':
      case 'PAID':
      case 'COMPLETED':
        return 'Paid';
      case 'PENDING':
        return 'Pending';
      case 'PROCESSING':
      case 'VERIFYING':
        return 'Processing';
      case 'FAILED':
        return 'Failed';
      case 'CANCELLED':
      case 'CANCELED':
        return 'Cancelled';
      case 'UNPAID':
        return 'Unpaid';
      default:
        final String clean =
        raw.trim().replaceAll('_', ' ').toLowerCase();

        if (clean.isEmpty) return 'Recorded';

        return clean
            .split(' ')
            .where((String part) => part.isNotEmpty)
            .map(
              (String part) =>
          '${part[0].toUpperCase()}${part.substring(1)}',
        )
            .join(' ');
    }
  }

  static Future<void> _copy(
      BuildContext context,
      String text,
      ) async {
    final String value = text.trim();
    if (value.isEmpty) return;

    await Clipboard.setData(
      ClipboardData(text: value),
    );

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Payment reference copied.'),
      ),
    );
  }

}

class _ReceiptCurrency {
  static String peso(double amount) {
    // UI formatting only: this does not change the authoritative bill amount.
    final String fixed = amount.toStringAsFixed(2);
    final List<String> parts = fixed.split('.');
    final String whole = parts[0];
    final bool negative = whole.startsWith('-');
    final String digits = negative ? whole.substring(1) : whole;
    final StringBuffer grouped = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) grouped.write(',');
      grouped.write(digits[i]);
    }
    return '₱${negative ? '-' : ''}${grouped.toString()}.${parts[1]}';
  }
}

class _ReceiptTones {
  static const Color navy = Color(0xFF102F3E);
  static const Color teal = Color(0xFF087F79);
  static const Color gold = Color(0xFFF6D483);

  static bool _isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color background(BuildContext context) =>
      _isDark(context) ? const Color(0xFF0B1B24) : const Color(0xFFF4F7FA);

  static Color surface(BuildContext context) =>
      _isDark(context) ? const Color(0xFF162C36) : Colors.white;

  static Color border(BuildContext context) =>
      _isDark(context) ? const Color(0xFF38515B) : const Color(0xFFDCE6EA);

  static Color text(BuildContext context) =>
      _isDark(context) ? const Color(0xFFF5F8F9) : const Color(0xFF173347);

  static Color secondaryText(BuildContext context) =>
      _isDark(context) ? const Color(0xFFB8CFD7) : const Color(0xFF617884);

  static Color brand(BuildContext context) =>
      _isDark(context) ? const Color(0xFF72D5C8) : teal;

  static Color success(BuildContext context) =>
      _isDark(context) ? const Color(0xFF80D9AC) : const Color(0xFF16845A);

  static Color warning(BuildContext context) =>
      _isDark(context) ? const Color(0xFFF6D483) : const Color(0xFFAE711A);
}

class _ReceiptBackground extends StatelessWidget {
  const _ReceiptBackground();

  @override
  Widget build(BuildContext context) {
    final bool dark = _ReceiptTones._isDark(context);
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: const [0, 0.46, 1],
            colors: dark
                ? const [Color(0xFF102F3E), Color(0xFF0B1B24), Color(0xFF0B1B24)]
                : const [Color(0xFFEAF4F4), Color(0xFFF4F7FA), Color(0xFFF4F7FA)],
          ),
        ),
      ),
    );
  }
}

class _ReceiptHeader extends StatelessWidget {
  const _ReceiptHeader({required this.isSuccess});

  final bool isSuccess;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          height: 46,
          width: 46,
          decoration: BoxDecoration(
            color: _ReceiptTones.navy,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.receipt_long_rounded,
              size: 23, color: _ReceiptTones.gold),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isSuccess ? 'Payment Receipt' : 'Payment Status',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: _ReceiptTones.text(context),
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'KuryentePay · Transaction Details',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: _ReceiptTones.secondaryText(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Icon(Icons.shield_outlined,
            size: 22, color: _ReceiptTones.brand(context)),
      ],
    );
  }
}

class _HeroReceiptCard extends StatelessWidget {
  const _HeroReceiptCard({
    required this.isSuccess,
    required this.isPending,
    required this.status,
    required this.statusColor,
    required this.amount,
  });

  final bool isSuccess;
  final bool isPending;
  final String status;
  final Color statusColor;
  final double amount;

  @override
  Widget build(BuildContext context) {
    final String headline = isSuccess
        ? 'Payment Confirmed'
        : isPending
        ? 'Verification Pending'
        : 'Payment Not Confirmed';
    final String message = isSuccess
        ? 'Your payment has been verified and recorded.'
        : isPending
        ? 'We are waiting for payment confirmation.'
        : 'This transaction has not been confirmed as paid.';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _ReceiptTones.navy,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _ReceiptTones.navy.withValues(alpha: 0.14),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 46,
                width: 46,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  isSuccess
                      ? Icons.check_circle_rounded
                      : isPending
                      ? Icons.schedule_rounded
                      : Icons.info_outline_rounded,
                  color: statusColor,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      headline,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      message,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFFC5D7DF),
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 23),
          Text(
            isSuccess ? 'Amount Paid' : 'Transaction Amount',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: const Color(0xFFC5D7DF),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 5),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              _ReceiptCurrency.peso(amount),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: _ReceiptTones.gold,
                fontSize: 32,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.7,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.075),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.lock_outline_rounded,
                    color: const Color(0xFFA1DFD5), size: 17),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isSuccess
                        ? 'Payment recorded successfully'
                        : isPending
                        ? 'Do not make another payment while pending'
                        : 'Check the latest status before retrying',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFFE1EFEF),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                _HeroStatusPill(
                  label: PaymentReceiptScreen._statusLabel(status),
                  color: statusColor,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroStatusPill extends StatelessWidget {
  const _HeroStatusPill({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        border: Border.all(color: color.withValues(alpha: 0.65)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});
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
            color: _ReceiptTones.text(context),
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: _ReceiptTones.secondaryText(context),
          ),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.bold = false,
  });
  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: _ReceiptTones.secondaryText(context),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 5,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: bold
                    ? _ReceiptTones.brand(context)
                    : _ReceiptTones.text(context),
                fontWeight: bold ? FontWeight.w800 : FontWeight.w700,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusNotice extends StatelessWidget {
  const _StatusNotice({required this.isSuccess, required this.isPending});
  final bool isSuccess;
  final bool isPending;

  @override
  Widget build(BuildContext context) {
    final Color accent = isSuccess
        ? _ReceiptTones.success(context)
        : isPending
        ? _ReceiptTones.warning(context)
        : Theme.of(context).colorScheme.error;
    return _GlassPanel(
      padding: const EdgeInsets.all(15),
      borderRadius: 18,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _IconTile(
            icon: isSuccess
                ? Icons.verified_user_outlined
                : isPending
                ? Icons.hourglass_top_rounded
                : Icons.info_outline_rounded,
            accent: accent,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isSuccess ? 'Payment Recorded' : 'What Happens Next',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: _ReceiptTones.text(context),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  isSuccess
                      ? 'You can find this transaction in your payment history.'
                      : isPending
                      ? 'Please wait for confirmation and check your transaction history. Avoid paying again while this transaction is pending.'
                      : 'Check your transaction history for the latest status before starting another payment.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: _ReceiptTones.secondaryText(context),
                    height: 1.5,
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

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.borderRadius = 20,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: _ReceiptTones.surface(context),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: _ReceiptTones.border(context)),
        boxShadow: [
          BoxShadow(
            color: _ReceiptTones.navy.withValues(alpha: 0.045),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _IconTile extends StatelessWidget {
  const _IconTile({required this.icon, required this.accent});
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: accent.withValues(alpha: 0.12),
      ),
      child: Icon(icon, color: accent, size: 20),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final String s = status.trim().toUpperCase();
    final bool success = s == 'SUCCESS' || s == 'PAID' || s == 'COMPLETED';
    final bool pending = s == 'PENDING' || s == 'PROCESSING' ||
        s == 'VERIFYING' || s == 'UNPAID';
    final Color color = success
        ? _ReceiptTones.success(context)
        : pending
        ? _ReceiptTones.warning(context)
        : Theme.of(context).colorScheme.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Text(
        'Bill Status: ${PaymentReceiptScreen._statusLabel(s)}',
        style: TextStyle(color: color, fontSize: 11.5,
            fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _SecondaryActionButton extends StatelessWidget {
  const _SecondaryActionButton({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: OutlinedButton.icon(
        onPressed: enabled ? onTap : null,
        icon: Icon(icon, size: 18),
        label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        style: OutlinedButton.styleFrom(
          foregroundColor: _ReceiptTones.brand(context),
          side: BorderSide(color: _ReceiptTones.border(context)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _PrimaryActionButton extends StatelessWidget {
  const _PrimaryActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 19),
        label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        style: ElevatedButton.styleFrom(
          backgroundColor: _ReceiptTones.teal,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}
