// KuryentePay — Privacy Policy presentation refresh.
// UI-only screen: no network calls, payment handling, or persistence changes.
// This in-app information notice must be reviewed before external deployment.
import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  // Preserve the eight topics and expandable reading format from the
  // existing screen. Wording no longer implies an ILECO partnership.
  static const List<_PolicySection> _sections = [
    _PolicySection(
      icon: Icons.person_outline_rounded,
      title: 'Information We May Collect',
      summary: 'Account, billing, transaction, and basic device information.',
      details: [
        'Consumer name, account number, service address, and registered mobile number.',
        'Login and session information used to keep the correct consumer account signed in.',
        'Billing records, payment references, transaction status, and reminder information.',
        'Basic device and app information needed for access, troubleshooting, and service reliability.',
      ],
    ),
    _PolicySection(
      icon: Icons.manage_accounts_outlined,
      title: 'How Information Is Used',
      summary: 'Information supports bill inquiry and account-related features.',
      details: [
        'Display current and previous electricity bills.',
        'Show payment history, transaction status, and payment references.',
        'Provide bill reminders, payment updates, and account-related notices.',
        'Support account verification, troubleshooting, and service improvement.',
        'Support billing, payment, notification, and necessary administrative functions.',
      ],
    ),
    _PolicySection(
      icon: Icons.account_balance_wallet_outlined,
      title: 'Payments & Third-Party Services',
      summary: 'Online checkout is provided through PayMongo.',
      details: [
        'KuryentePay uses PayMongo Hosted Checkout for supported online payments.',
        'Sensitive wallet or banking credentials are entered with the payment provider rather than directly into KuryentePay.',
        'Closing or returning from a checkout page does not, by itself, mean a bill has been paid.',
        'A payment is shown as successful only after the backend verifies the payment result and updates the linked bill.',
      ],
    ),
    _PolicySection(
      icon: Icons.notifications_none_rounded,
      title: 'Notifications & Reminders',
      summary: 'Billing, payment, and important account updates.',
      details: [
        'The app may provide alerts about new bills, approaching due dates, payment results, and account notices.',
        'A verified successful payment may create a Payment Successful alert with related transaction information.',
        'Push notification permission can be managed in the Android device settings.',
        'Disabling device notifications does not remove billing or transaction records.',
      ],
    ),
    _PolicySection(
      icon: Icons.shield_outlined,
      title: 'Security & Account Protection',
      summary: 'Precautions for protecting access and account data.',
      details: [
        'Passwords should be protected with secure hashing and should never be stored as plain text.',
        'Normal online access should use secure HTTPS connections.',
        'Account access should be limited to authorized consumers, staff, and necessary service providers.',
        'Never share passwords, verification codes, or suspicious payment links.',
      ],
    ),
    _PolicySection(
      icon: Icons.hub_outlined,
      title: 'Sharing of Information',
      summary: 'Access should be limited to necessary, authorized purposes.',
      details: [
        'Authorized system administrators or staff may need access to account information to perform their assigned functions.',
        'Payment, messaging, and hosting providers may process information necessary for the services they provide.',
        'Information may need to be disclosed in response to valid legal requirements.',
        'Support or project reviewers should receive only the access and information necessary for their authorized tasks.',
      ],
    ),
    _PolicySection(
      icon: Icons.inventory_2_outlined,
      title: 'Storage & Retention',
      summary: 'Record retention should match legitimate operational needs.',
      details: [
        'Billing and payment records may need to be retained for account history, reconciliation, and audit purposes.',
        'Temporary technical records should be limited to what is necessary for troubleshooting, security, and service reliability.',
        'Session and technical-log retention practices should be reviewed and defined before real-world deployment.',
      ],
    ),
    _PolicySection(
      icon: Icons.tune_rounded,
      title: 'Your Choices & Responsibilities',
      summary: 'Review account details and protect your sign-in information.',
      details: [
        'Review the account number and service address displayed in My Profile.',
        'Report incorrect personal, billing, or payment information to the authorized system administrator or appropriate billing office.',
        'Manage push notification permission through the device settings.',
        'Sign out after using the app on a shared or borrowed device.',
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = _PrivacyColors.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
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
            child: InkWell(
              borderRadius: BorderRadius.circular(13),
              onTap: () => Navigator.of(context).pop(),
              child: Icon(Icons.arrow_back_rounded, color: colors.text, size: 21),
            ),
          ),
        ),
        titleSpacing: 12,
        title: Text(
          'Privacy Policy',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: colors.text,
            letterSpacing: -0.4,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            const _PrivacyHero(),
            const SizedBox(height: 16),
            const _PrivacyEssentials(),
            const SizedBox(height: 26),
            const _SectionHeader(
              title: 'Privacy Information',
              subtitle: 'Explore how account information is handled',
            ),
            const SizedBox(height: 12),
            for (int i = 0; i < _sections.length; i++) ...[
              _PolicyTopicCard(section: _sections[i], number: i + 1),
              if (i != _sections.length - 1) const SizedBox(height: 10),
            ],
            const SizedBox(height: 26),
            const _SectionHeader(
              title: 'Important Reminders',
              subtitle: 'Keep your account and payments protected',
            ),
            const SizedBox(height: 12),
            const _ImportantReminders(),
            const SizedBox(height: 16),
            const _ReviewNotice(),
          ],
        ),
      ),
    );
  }
}

class _PolicySection {
  const _PolicySection({
    required this.icon,
    required this.title,
    required this.summary,
    required this.details,
  });

  final IconData icon;
  final String title;
  final String summary;
  final List<String> details;
}

class _PrivacyColors {
  const _PrivacyColors({
    required this.background,
    required this.surface,
    required this.surfaceSoft,
    required this.text,
    required this.secondary,
    required this.border,
  });

  static const Color navy = Color(0xFF102F3E);
  static const Color teal = Color(0xFF087F79);
  static const Color gold = Color(0xFFF6D483);
  static const Color mint = Color(0xFF9DE9CD);

  final Color background;
  final Color surface;
  final Color surfaceSoft;
  final Color text;
  final Color secondary;
  final Color border;

  static _PrivacyColors of(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    if (dark) {
      return const _PrivacyColors(
        background: Color(0xFF091B22),
        surface: Color(0xFF122A32),
        surfaceSoft: Color(0xFF183640),
        text: Color(0xFFF1F8F8),
        secondary: Color(0xFFB6CBCE),
        border: Color(0xFF31505A),
      );
    }
    return const _PrivacyColors(
      background: Color(0xFFF4F7FA),
      surface: Colors.white,
      surfaceSoft: Color(0xFFF3F8F8),
      text: Color(0xFF173347),
      secondary: Color(0xFF647C87),
      border: Color(0xFFDCE6EA),
    );
  }
}

class _PrivacyHero extends StatelessWidget {
  const _PrivacyHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _PrivacyColors.navy,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x18102F3E),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(height: 4, color: _PrivacyColors.teal),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.privacy_tip_outlined,
                        color: _PrivacyColors.gold,
                        size: 25,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'KuryentePay',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _PrivacyColors.mint.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: const Text(
                        'Privacy',
                        style: TextStyle(
                          color: _PrivacyColors.mint,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Text(
                  'Understand Your Data',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Learn what information supports your electric bill inquiry, payment, and account features.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFFD1E4E6),
                    fontWeight: FontWeight.w500,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 19),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.white.withValues(alpha: 0.09),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.shield_outlined, size: 18, color: _PrivacyColors.mint),
                      SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          'Independent Academic Application',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
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

class _PrivacyEssentials extends StatelessWidget {
  const _PrivacyEssentials();

  @override
  Widget build(BuildContext context) {
    final colors = _PrivacyColors.of(context);
    return _PrivacySurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'At a Glance',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: colors.text,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 13),
          const _GlanceRow(
            icon: Icons.receipt_long_outlined,
            title: 'Billing Records',
            description: 'Used to display electric bills and account history',
          ),
          _ThinDivider(color: colors.border),
          const _GlanceRow(
            icon: Icons.qr_code_rounded,
            title: 'Payment Processing',
            description: 'QR Ph checkout is handled by PayMongo',
          ),
          _ThinDivider(color: colors.border),
          const _GlanceRow(
            icon: Icons.notifications_none_rounded,
            title: 'Account Alerts',
            description: 'Updates about bills, payments, and account activity',
          ),
        ],
      ),
    );
  }
}

class _GlanceRow extends StatelessWidget {
  const _GlanceRow({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final colors = _PrivacyColors.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PrivacyIcon(icon: icon),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 2),
              Text(
                title,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.text,
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                description,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.secondary,
                  height: 1.45,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = _PrivacyColors.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 4,
          height: 32,
          decoration: BoxDecoration(
            color: _PrivacyColors.teal,
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: colors.text,
                  fontSize: 17,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.secondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PolicyTopicCard extends StatelessWidget {
  const _PolicyTopicCard({required this.section, required this.number});

  final _PolicySection section;
  final int number;

  @override
  Widget build(BuildContext context) {
    final colors = _PrivacyColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: PageStorageKey<String>('privacy_topic_$number'),
          tilePadding: const EdgeInsets.fromLTRB(13, 5, 12, 5),
          childrenPadding: const EdgeInsets.fromLTRB(15, 0, 15, 16),
          expandedAlignment: Alignment.centerLeft,
          shape: const Border(),
          collapsedShape: const Border(),
          leading: _PrivacyIcon(icon: section.icon, size: 43),
          title: Text(
            section.title,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colors.text,
              fontWeight: FontWeight.w800,
              height: 1.25,
              fontSize: 13.5,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text(
              section.summary,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.secondary,
                height: 1.4,
                fontSize: 11.5,
              ),
            ),
          ),
          iconColor: _PrivacyColors.teal,
          collapsedIconColor: colors.secondary,
          children: [
            Divider(color: colors.border, height: 1),
            const SizedBox(height: 14),
            for (int i = 0; i < section.details.length; i++) ...[
              _DetailBullet(text: section.details[i]),
              if (i != section.details.length - 1) const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class _DetailBullet extends StatelessWidget {
  const _DetailBullet({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = _PrivacyColors.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 7,
          width: 7,
          margin: const EdgeInsets.only(top: 6),
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: _PrivacyColors.teal,
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colors.secondary,
              fontSize: 12.5,
              height: 1.52,
            ),
          ),
        ),
      ],
    );
  }
}

class _ImportantReminders extends StatelessWidget {
  const _ImportantReminders();

  @override
  Widget build(BuildContext context) {
    return const _PrivacySurface(
      child: Column(
        children: [
          _ReminderRow(
            icon: Icons.verified_user_outlined,
            title: 'Verified Payments',
            description: 'A bill is marked Paid only after its payment is confirmed by the backend.',
          ),
          _ReminderGap(),
          _ReminderRow(
            icon: Icons.notifications_none_rounded,
            title: 'Notification Permission',
            description: 'Control device push notifications in Android settings without changing billing records.',
          ),
          _ReminderGap(),
          _ReminderRow(
            icon: Icons.lock_outline_rounded,
            title: 'Account Safety',
            description: 'Keep your password and payment-verification details private.',
          ),
        ],
      ),
    );
  }
}

class _ReminderGap extends StatelessWidget {
  const _ReminderGap();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(height: 17);
  }
}

class _ReminderRow extends StatelessWidget {
  const _ReminderRow({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final colors = _PrivacyColors.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PrivacyIcon(icon: icon, size: 40),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.text,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.secondary,
                  fontSize: 12,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReviewNotice extends StatelessWidget {
  const _ReviewNotice();

  @override
  Widget build(BuildContext context) {
    final colors = _PrivacyColors.of(context);
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: colors.surfaceSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, color: _PrivacyColors.teal, size: 21),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              'KuryentePay is an independent academic prototype. This in-app notice describes its intended information-handling features and should be formally reviewed and finalized before external deployment.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.secondary,
                height: 1.5,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrivacyIcon extends StatelessWidget {
  const _PrivacyIcon({required this.icon, this.size = 42});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = _PrivacyColors.of(context);
    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? _PrivacyColors.teal.withValues(alpha: 0.25)
            : const Color(0xFFE8F5F2),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Icon(icon, size: size * 0.49, color: Theme.of(context).brightness == Brightness.dark
          ? _PrivacyColors.mint
          : _PrivacyColors.teal),
    );
  }
}

class _PrivacySurface extends StatelessWidget {
  const _PrivacySurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = _PrivacyColors.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _ThinDivider extends StatelessWidget {
  const _ThinDivider({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: Divider(color: color, height: 1),
    );
  }
}
