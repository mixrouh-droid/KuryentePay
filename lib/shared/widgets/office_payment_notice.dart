import 'package:flutter/material.dart';

import '../../core/services/bill_payment_deadline.dart';

/// Reusable consumer notice for an unpaid bill that is already past due.
///
/// This widget does NOT calculate penalties or assume an official grace
/// period. It only shows the verified overdue status and directs the
/// consumer to authorized billing staff for settlement.
class OfficePaymentNotice extends StatelessWidget {
  const OfficePaymentNotice({
    super.key,
    this.dueDate = '',
  });

  /// Bill due date in YYYY-MM-DD format.
  ///
  /// Optional so older call sites remain safe until they are updated
  /// to pass the bill's actual due date.
  final String dueDate;

  int? _daysOverdue() {
    final String cleaned = dueDate.trim();

    if (cleaned.isEmpty) {
      return null;
    }

    final int? daysUntilDue =
    BillPaymentDeadline.daysUntilDue(cleaned);

    if (daysUntilDue == null || daysUntilDue >= 0) {
      return null;
    }

    return daysUntilDue.abs();
  }

  String _formattedDueDate() {
    final DateTime? parsed =
    BillPaymentDeadline.parseDueDate(dueDate);

    if (parsed == null) {
      return 'Unavailable';
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

    return '${months[parsed.month - 1]} '
        '${parsed.day}, ${parsed.year}';
  }

  String _overdueLabel(int? daysOverdue) {
    if (daysOverdue == null) {
      return 'Past due';
    }

    if (daysOverdue == 1) {
      return '1 day past due';
    }

    return '$daysOverdue days past due';
  }

  String _overdueDescription(int? daysOverdue) {
    if (daysOverdue == null) {
      return 'This bill has passed its online payment deadline.';
    }

    final String dayWord =
    daysOverdue == 1 ? 'day' : 'days';

    return 'This bill is $daysOverdue $dayWord overdue. '
        'Online payment is no longer available for this billing cycle.';
  }

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final int? daysOverdue = _daysOverdue();
    final String formattedDueDate = _formattedDueDate();
    final TextTheme typography = Theme.of(context).textTheme;

    // KuryentePay visual tokens. Status red communicates the overdue state;
    // teal is reserved for the informational next step.
    final Color navy = dark
        ? const Color(0xFFEAF3F4)
        : const Color(0xFF102F3E);
    final Color muted = dark
        ? const Color(0xFFB6CDD0)
        : const Color(0xFF567078);
    final Color teal = dark
        ? const Color(0xFF73D5C6)
        : const Color(0xFF087F79);
    final Color danger = dark
        ? const Color(0xFFFFA7A7)
        : const Color(0xFFC43B46);
    final Color surface = dark
        ? const Color(0xFF152A32)
        : const Color(0xFFFFFFFF);
    final Color outline = dark
        ? const Color(0xFF35505A)
        : const Color(0xFFDCE6EA);
    final Color detailSurface = dark
        ? const Color(0xFF203842)
        : const Color(0xFFF4F7FA);
    final Color actionSurface = dark
        ? const Color(0xFF173B3D)
        : const Color(0xFFE9F5F2);

    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: outline),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.10 : 0.045),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Accent line matches the app's cards without making the whole
          // notice red or visually competing with the main bill summary.
          Container(height: 4, color: teal),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: danger.withValues(alpha: dark ? 0.15 : 0.09),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.error_outline_rounded,
                        color: danger,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Overdue Bill',
                            style: typography.labelMedium?.copyWith(
                              color: danger,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Office Payment Required',
                            style: typography.titleMedium?.copyWith(
                              color: navy,
                              fontWeight: FontWeight.w800,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  _overdueDescription(daysOverdue),
                  style: typography.bodyMedium?.copyWith(
                    color: muted,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: _NoticeInfoTile(
                        icon: Icons.calendar_month_outlined,
                        title: 'Due Date',
                        value: formattedDueDate,
                        surface: detailSurface,
                        labelColor: muted,
                        valueColor: navy,
                        iconColor: teal,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _NoticeInfoTile(
                        icon: Icons.schedule_outlined,
                        title: 'Payment Status',
                        value: _overdueLabel(daysOverdue),
                        surface: detailSurface,
                        labelColor: muted,
                        valueColor: danger,
                        iconColor: danger,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: actionSurface,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.all(13),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Icon(
                        Icons.account_balance_outlined,
                        color: teal,
                        size: 21,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'Next Step',
                              style: typography.labelLarge?.copyWith(
                                color: navy,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Contact your authorized billing administrator '
                                  'for office settlement instructions.',
                              style: typography.bodySmall?.copyWith(
                                color: muted,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 13),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(Icons.info_outline_rounded, size: 17, color: muted),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Any applicable late charges will be confirmed by '
                            'the billing administrator. You can still view, '
                            'save, and print your bill.',
                        style: typography.bodySmall?.copyWith(
                          color: muted,
                          height: 1.4,
                        ),
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
}

/// Small non-interactive facts displayed in the shared overdue notice.
/// Kept local to this file so callers and routes remain unchanged.
class _NoticeInfoTile extends StatelessWidget {
  const _NoticeInfoTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.surface,
    required this.labelColor,
    required this.valueColor,
    required this.iconColor,
  });

  final IconData icon;
  final String title;
  final String value;
  final Color surface;
  final Color labelColor;
  final Color valueColor;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final TextTheme typography = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: typography.labelSmall?.copyWith(
                    color: labelColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            softWrap: true,
            style: typography.bodyMedium?.copyWith(
              color: valueColor,
              fontWeight: FontWeight.w800,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}
