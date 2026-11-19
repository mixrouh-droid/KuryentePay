// KuryentePay Help & Support — presentation redesign.
// Preserve the original reference-contact Copy/Call handlers and navigation.
// This screen does not provide a live help desk or official cooperative support.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  static const List<_OfficeContact> _offices = [
    _OfficeContact(
      name: 'Sara Area Office',
      phone: '0919-069-7391',
      icon: Icons.location_city_rounded,
    ),
    _OfficeContact(
      name: 'Pani-an Area Office',
      phone: '0919-069-7396',
      icon: Icons.apartment_rounded,
    ),
    _OfficeContact(
      name: 'Natividad Area Office',
      phone: '0919-069-7403',
      icon: Icons.business_rounded,
    ),
  ];

  Future<void> _copyNumber(
      BuildContext context,
      _OfficeContact office,
      ) async {
    await Clipboard.setData(
      ClipboardData(text: office.phone),
    );

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${office.name} number copied.'),
      ),
    );
  }

  Future<void> _callNumber(
      BuildContext context,
      _OfficeContact office,
      ) async {
    final String cleanPhone =
    office.phone.replaceAll(RegExp(r'[^0-9+]'), '');

    if (cleanPhone.isEmpty) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No valid phone number is available.'),
        ),
      );
      return;
    }

    final Uri phoneUri = Uri(
      scheme: 'tel',
      path: cleanPhone,
    );

    try {
      final bool opened = await launchUrl(
        phoneUri,
        mode: LaunchMode.externalApplication,
      );

      if (!opened && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Unable to open the phone app for ${office.name}.',
            ),
          ),
        );
      }
    } catch (_) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to start a call to ${office.name}.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = _HelpColors.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: colors.background,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        leadingWidth: 64,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16, top: 6, bottom: 6),
          child: Material(
            color: colors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(13),
              side: BorderSide(color: colors.border),
            ),
            child: IconButton(
              tooltip: 'Back',
              padding: EdgeInsets.zero,
              onPressed: () => Navigator.of(context).pop(),
              icon: Icon(Icons.arrow_back_rounded, color: colors.text),
            ),
          ),
        ),
        title: Text(
          'Help & Support',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: colors.text,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            const _HelpHero(),
            const SizedBox(height: 26),
            const _HelpSectionHeading(
              title: 'Frequently Asked Questions',
              subtitle: 'Useful guidance for your account',
            ),
            const SizedBox(height: 12),
            const _HelpCategoryLabel(
              icon: Icons.receipt_long_rounded,
              title: 'Bills & Payments',
            ),
            const SizedBox(height: 10),
            const _FaqGroup(items: [
              _FaqItem(
                icon: Icons.receipt_long_rounded,
                question: 'How do I view my electric bill?',
                answer:
                'Open Home and select the current bill, or tap View Bill. Previous billing records are available in Billing History.',
              ),
              _FaqItem(
                icon: Icons.qr_code_rounded,
                question: 'How do I pay my current bill?',
                answer:
                'Open your current bill, choose Pay Electric Bill, review the details, and continue to PayMongo QR Ph when online payment is available. Return to KuryentePay to check the verified payment status. Do not pay again while verification is in progress.',
              ),
              _FaqItem(
                icon: Icons.verified_outlined,
                question: 'How do I know my payment was confirmed?',
                answer:
                'A payment is confirmed only after the backend verifies the provider result. Your bill should display Paid, and Transaction History should show the confirmed payment with its reference details.',
              ),
              _FaqItem(
                icon: Icons.hourglass_top_rounded,
                question: 'Why is my payment still in progress?',
                answer:
                'Payment verification may take time. Return to the app and refresh your bill or Transaction History. Do not start another payment while the original transaction is pending or being verified.',
              ),
            ]),
            const SizedBox(height: 18),
            const _HelpCategoryLabel(
              icon: Icons.manage_accounts_outlined,
              title: 'Account & App Access',
            ),
            const SizedBox(height: 10),
            const _FaqGroup(items: [
              _FaqItem(
                icon: Icons.notifications_active_outlined,
                question: 'What notifications can I receive?',
                answer:
                'In-app notifications may include new bills, due-date reminders, overdue notices, verified payments, and account updates. Opening an unread notification marks it as read.',
              ),
              _FaqItem(
                icon: Icons.wifi_off_rounded,
                question: 'What if my information does not load?',
                answer:
                'Check your internet connection, pull down to refresh, then reopen KuryentePay if needed. If the problem continues, ask your account administrator to verify your account and service availability.',
              ),
              _FaqItem(
                icon: Icons.lock_reset_rounded,
                question: 'What if I forgot my password?',
                answer:
                'Follow the available account-recovery guidance or contact the administrator responsible for your KuryentePay test account for verification and reset assistance. Never share your existing password or payment verification details.',
              ),
            ]),
            const SizedBox(height: 26),
            const _HelpSectionHeading(
              title: 'Troubleshooting',
              subtitle: 'Simple checks before asking for help',
            ),
            const SizedBox(height: 12),
            const _TroubleshootingPanel(),
            const SizedBox(height: 24),
            const _HelpSectionHeading(
              title: 'Reference Contacts',
              subtitle: 'Older directory information',
            ),
            const SizedBox(height: 12),
            _ReferenceContactsPanel(
              offices: _offices,
              onCopy: (office) => _copyNumber(context, office),
              onCall: (office) => _callNumber(context, office),
            ),
            const SizedBox(height: 18),
            const _SecurityNote(),
            const SizedBox(height: 18),
            Center(
              child: Text(
                'KuryentePay · Independent Academic Project',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.muted,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OfficeContact {
  const _OfficeContact({
    required this.name,
    required this.phone,
    required this.icon,
  });

  final String name;
  final String phone;
  final IconData icon;
}

class _FaqItem {
  const _FaqItem({
    required this.icon,
    required this.question,
    required this.answer,
  });

  final IconData icon;
  final String question;
  final String answer;
}

class _HelpColors {
  const _HelpColors({
    required this.background,
    required this.surface,
    required this.softSurface,
    required this.border,
    required this.text,
    required this.muted,
    required this.teal,
    required this.warning,
  });

  static const navy = Color(0xFF102F3E);
  static const tealBase = Color(0xFF087F79);
  static const gold = Color(0xFFF6D483);

  final Color background;
  final Color surface;
  final Color softSurface;
  final Color border;
  final Color text;
  final Color muted;
  final Color teal;
  final Color warning;

  static _HelpColors of(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return _HelpColors(
      background: dark ? const Color(0xFF081A21) : const Color(0xFFF4F7FA),
      surface: dark ? const Color(0xFF122B34) : Colors.white,
      softSurface: dark ? const Color(0xFF183842) : const Color(0xFFEDF5F4),
      border: dark ? const Color(0xFF33515B) : const Color(0xFFDCE6EA),
      text: dark ? const Color(0xFFF2F8F8) : const Color(0xFF173347),
      muted: dark ? const Color(0xFFB4CCD1) : const Color(0xFF617781),
      teal: dark ? const Color(0xFF70DACA) : tealBase,
      warning: dark ? gold : const Color(0xFF9A6823),
    );
  }
}

class _HelpHero extends StatelessWidget {
  const _HelpHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _HelpColors.navy,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: _HelpColors.navy.withValues(alpha: 0.13),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(height: 4, color: _HelpColors.tealBase),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: const Icon(
                        Icons.support_agent_rounded,
                        color: _HelpColors.gold,
                        size: 27,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'KuryentePay',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 20,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: Colors.white.withValues(alpha: 0.10),
                      ),
                      child: const Text(
                        'Help Center',
                        style: TextStyle(
                          color: Color(0xFFE2F4F1),
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  'How Can We Help?',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                    height: 1.12,
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  'Find clear answers about billing, online payments, and your account.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFFCEE1E4),
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: const [
                    _HeroChip(icon: Icons.receipt_long_rounded, label: 'Bills'),
                    _HeroChip(icon: Icons.verified_outlined, label: 'Payments'),
                    _HeroChip(icon: Icons.person_outline_rounded, label: 'Account'),
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

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFF9DE9CD), size: 14),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(
                  color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _HelpSectionHeading extends StatelessWidget {
  const _HelpSectionHeading({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = _HelpColors.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 4,
          height: 36,
          margin: const EdgeInsets.only(top: 2),
          decoration: BoxDecoration(
            color: colors.teal,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: colors.text, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.muted, fontSize: 11.5)),
            ],
          ),
        ),
      ],
    );
  }
}

class _HelpCategoryLabel extends StatelessWidget {
  const _HelpCategoryLabel({required this.icon, required this.title});
  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final colors = _HelpColors.of(context);
    return Row(
      children: [
        Icon(icon, color: colors.teal, size: 18),
        const SizedBox(width: 8),
        Text(title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800, color: colors.text)),
      ],
    );
  }
}

class _FaqGroup extends StatelessWidget {
  const _FaqGroup({required this.items});
  final List<_FaqItem> items;

  @override
  Widget build(BuildContext context) {
    return _HelpPanel(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            _FaqRow(item: items[i]),
            if (i < items.length - 1) const _HelpDivider(),
          ],
        ],
      ),
    );
  }
}

class _FaqRow extends StatelessWidget {
  const _FaqRow({required this.item});
  final _FaqItem item;

  @override
  Widget build(BuildContext context) {
    final colors = _HelpColors.of(context);
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.fromLTRB(14, 7, 13, 7),
        childrenPadding: const EdgeInsets.fromLTRB(17, 0, 18, 17),
        leading: _HelpIcon(icon: item.icon),
        title: Text(
          item.question,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: colors.text,
            fontSize: 13,
            fontWeight: FontWeight.w800,
            height: 1.38,
          ),
        ),
        iconColor: colors.teal,
        collapsedIconColor: colors.muted,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              item.answer,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.muted,
                fontSize: 12.5,
                height: 1.55,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TroubleshootingPanel extends StatelessWidget {
  const _TroubleshootingPanel();

  @override
  Widget build(BuildContext context) {
    return _HelpPanel(
      padding: const EdgeInsets.all(15),
      child: const Column(
        children: [
          _TroubleStep(
            number: '01',
            icon: Icons.wifi_rounded,
            title: 'Check Your Connection',
            detail: 'Confirm that Wi-Fi or mobile data is working.',
          ),
          _HelpDivider(),
          _TroubleStep(
            number: '02',
            icon: Icons.refresh_rounded,
            title: 'Refresh the Screen',
            detail: 'Pull down on the screen to load the latest available records.',
          ),
          _HelpDivider(),
          _TroubleStep(
            number: '03',
            icon: Icons.person_search_rounded,
            title: 'Review Account Information',
            detail: 'Check the account number associated with the displayed bill.',
          ),
          _HelpDivider(),
          _TroubleStep(
            number: '04',
            icon: Icons.hourglass_top_rounded,
            title: 'Wait for Verification',
            detail: 'Do not make another payment while the first is still in progress.',
          ),
          _HelpDivider(),
          _TroubleStep(
            number: '05',
            icon: Icons.contact_support_outlined,
            title: 'Contact Your Account Administrator',
            detail: 'If the problem continues, seek help using verified contact details.',
          ),
        ],
      ),
    );
  }
}

class _TroubleStep extends StatelessWidget {
  const _TroubleStep({
    required this.number,
    required this.icon,
    required this.title,
    required this.detail,
  });

  final String number;
  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final colors = _HelpColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              _HelpIcon(icon: icon, size: 44),
              Positioned(
                top: -4,
                right: -5,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                  decoration: BoxDecoration(
                      color: _HelpColors.tealBase,
                      borderRadius: BorderRadius.circular(6)),
                  child: Text(number,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colors.text, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(detail,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.muted, height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReferenceContactsPanel extends StatelessWidget {
  const _ReferenceContactsPanel({
    required this.offices,
    required this.onCopy,
    required this.onCall,
  });

  final List<_OfficeContact> offices;
  final ValueChanged<_OfficeContact> onCopy;
  final ValueChanged<_OfficeContact> onCall;

  @override
  Widget build(BuildContext context) {
    final colors = _HelpColors.of(context);
    return _HelpPanel(
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: false,
          tilePadding: const EdgeInsets.fromLTRB(15, 10, 14, 10),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 15),
          leading: _HelpIcon(icon: Icons.contact_phone_outlined, size: 44),
          title: Text('View Reference Directory',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.text, fontWeight: FontWeight.w800)),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('Not verified · Not KuryentePay support',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.warning, fontSize: 11)),
          ),
          iconColor: colors.teal,
          collapsedIconColor: colors.muted,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.softSurface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded, color: colors.teal, size: 19),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'These numbers were included in an older version of the project. Their accuracy and current ownership have not been verified. They are not KuryentePay support lines. Use verified provider details for official billing inquiries.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.muted, height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 7),
            for (int i = 0; i < offices.length; i++) ...[
              _ContactRow(
                office: offices[i],
                onCopy: () => onCopy(offices[i]),
                onCall: () => onCall(offices[i]),
              ),
              if (i < offices.length - 1) const _HelpDivider(),
            ],
          ],
        ),
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.office,
    required this.onCopy,
    required this.onCall,
  });

  final _OfficeContact office;
  final VoidCallback onCopy;
  final VoidCallback onCall;

  @override
  Widget build(BuildContext context) {
    final colors = _HelpColors.of(context);
    return LayoutBuilder(builder: (context, constraints) {
      final compact = constraints.maxWidth < 370;
      final info = Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _HelpIcon(icon: office.icon, size: 42),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(office.name,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colors.text, fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(office.phone,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.muted, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      );
      final copy = _ContactButton(
        icon: Icons.copy_rounded,
        label: 'Copy',
        tooltip: 'Copy ${office.name} number',
        onTap: onCopy,
        filled: false,
      );
      final call = _ContactButton(
        icon: Icons.call_outlined,
        label: 'Call',
        tooltip: 'Call ${office.name}',
        onTap: onCall,
        filled: true,
      );
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: compact
            ? Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            info,
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: copy),
              const SizedBox(width: 9),
              Expanded(child: call),
            ]),
          ],
        )
            : Row(children: [
          Expanded(child: info),
          const SizedBox(width: 8),
          copy,
          const SizedBox(width: 8),
          call,
        ]),
      );
    });
  }
}

class _ContactButton extends StatelessWidget {
  const _ContactButton({
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.onTap,
    required this.filled,
  });
  final IconData icon;
  final String label;
  final String tooltip;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final colors = _HelpColors.of(context);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: filled ? _HelpColors.tealBase : colors.softSurface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 15, color: filled ? Colors.white : colors.teal),
                const SizedBox(width: 6),
                Text(label,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: filled ? Colors.white : colors.teal)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SecurityNote extends StatelessWidget {
  const _SecurityNote();

  @override
  Widget build(BuildContext context) {
    final colors = _HelpColors.of(context);
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: colors.softSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_outlined, color: colors.teal, size: 22),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Protect Your Account',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colors.text, fontWeight: FontWeight.w800)),
                const SizedBox(height: 5),
                Text(
                  'Never share your password, one-time code, or sensitive payment information with anyone claiming to provide support.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.muted, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HelpPanel extends StatelessWidget {
  const _HelpPanel({required this.child, this.padding = const EdgeInsets.all(15)});
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colors = _HelpColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border),
        boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 12,
            offset: const Offset(0, 4))],
      ),
      clipBehavior: Clip.antiAlias,
      padding: padding,
      child: child,
    );
  }
}

class _HelpIcon extends StatelessWidget {
  const _HelpIcon({required this.icon, this.size = 42});
  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = _HelpColors.of(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colors.softSurface,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Icon(icon, color: colors.teal, size: size * 0.48),
    );
  }
}

class _HelpDivider extends StatelessWidget {
  const _HelpDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 14,
      endIndent: 14,
      color: _HelpColors.of(context).border,
    );
  }
}
