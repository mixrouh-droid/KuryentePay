// KuryentePay Settings — presentation-only redesign.
// Existing settings are informational; no unsupported switches or service calls added.
import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = _SettingsColors.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        leadingWidth: 66,
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
              onPressed: () => Navigator.of(context).maybePop(),
              icon: Icon(
                Icons.arrow_back_rounded,
                color: colors.text,
                size: 21,
              ),
            ),
          ),
        ),
        title: Text(
          'Settings',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: colors.text,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
          children: [
            const _SettingsBanner(),
            const SizedBox(height: 28),
            const _SectionLabel(
              title: 'App Information',
              description: 'Essential features and account guidance',
            ),
            const SizedBox(height: 13),
            const _FeatureCard(
              icon: Icons.cloud_done_outlined,
              title: 'Online Access',
              description:
              'KuryentePay connects when your device has internet access.',
              pill: 'Automatic',
              details: [
                _FeatureDetail(
                  icon: Icons.wifi_rounded,
                  text: 'No manual network setup is needed in the app.',
                ),
              ],
            ),
            const SizedBox(height: 12),
            const _FeatureCard(
              icon: Icons.notifications_active_outlined,
              title: 'Notifications',
              description:
              'Stay informed about electric bills, due dates, and payment updates.',
              pill: 'Account Alerts',
              details: [
                _FeatureDetail(
                  icon: Icons.receipt_long_outlined,
                  text: 'New electric bill and due-date reminders',
                ),
                _FeatureDetail(
                  icon: Icons.verified_outlined,
                  text: 'Backend-confirmed payment updates',
                ),
                _FeatureDetail(
                  icon: Icons.mark_email_unread_outlined,
                  text: 'Unread messages remain available in Notifications',
                ),
              ],
            ),
            const SizedBox(height: 26),
            const _SectionLabel(
              title: 'Safety & Privacy',
              description: 'Information to help protect your account',
            ),
            const SizedBox(height: 13),
            const _FeatureCard(
              icon: Icons.shield_outlined,
              title: 'Account Security',
              description:
              'Keep your KuryentePay account and payment information protected.',
              pill: 'Important',
              details: [
                _FeatureDetail(
                  icon: Icons.lock_outline_rounded,
                  text: 'Never share your account password with anyone.',
                ),
                _FeatureDetail(
                  icon: Icons.fact_check_outlined,
                  text:
                  'An electric bill is marked Paid only after its payment is confirmed.',
                ),
              ],
            ),
            const SizedBox(height: 26),
            const _SectionLabel(
              title: 'About',
              description: 'Get to know KuryentePay',
            ),
            const SizedBox(height: 13),
            const _AboutCard(),
            const SizedBox(height: 25),
            Center(
              child: Text(
                'KuryentePay • Electric Bill Inquiry and Payment',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsColors {
  const _SettingsColors({
    required this.background,
    required this.surface,
    required this.surfaceSoft,
    required this.text,
    required this.muted,
    required this.border,
  });

  static const navy = Color(0xFF102F3E);
  static const teal = Color(0xFF087F79);
  static const gold = Color(0xFFF6D483);

  final Color background;
  final Color surface;
  final Color surfaceSoft;
  final Color text;
  final Color muted;
  final Color border;

  static _SettingsColors of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark
        ? const _SettingsColors(
      background: Color(0xFF071823),
      surface: Color(0xFF112A36),
      surfaceSoft: Color(0xFF193742),
      text: Color(0xFFF5FAFB),
      muted: Color(0xFFC0D1D7),
      border: Color(0xFF2B4A55),
    )
        : const _SettingsColors(
      background: Color(0xFFF4F7FA),
      surface: Colors.white,
      surfaceSoft: Color(0xFFF0F6F6),
      text: Color(0xFF173347),
      muted: Color(0xFF617681),
      border: Color(0xFFDCE6EA),
    );
  }
}

class _SettingsBanner extends StatelessWidget {
  const _SettingsBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _SettingsColors.navy,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF38616B)),
        boxShadow: [
          BoxShadow(
            color: _SettingsColors.navy.withValues(alpha: 0.15),
            blurRadius: 22,
            offset: const Offset(0, 11),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(21),
        child: Stack(
          children: [
            Positioned(
              right: -64,
              top: -64,
              child: Container(
                width: 178,
                height: 178,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.09),
                    width: 22,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(21),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 45,
                        height: 45,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.bolt_rounded,
                          color: _SettingsColors.gold,
                          size: 27,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'KuryentePay',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.tune_rounded,
                        color: Color(0xFF9EE0D3),
                        size: 22,
                      ),
                    ],
                  ),
                  const SizedBox(height: 23),
                  Text(
                    'Your Electricity Account,\nMade Simpler.',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                      height: 1.20,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Helpful information about billing access, notifications, and account safety.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFFD2E4E7),
                      fontSize: 12.5,
                      height: 1.55,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A4B50),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          color: Color(0xFFA7E8D9),
                          size: 16,
                        ),
                        SizedBox(width: 7),
                        Text(
                          'Account & App Information',
                          style: TextStyle(
                            color: Color(0xFFE5F8F2),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
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
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final colors = _SettingsColors.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 29,
          width: 4,
          decoration: BoxDecoration(
            color: _SettingsColors.teal,
            borderRadius: BorderRadius.circular(8),
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
                  color: colors.text,
                  fontSize: 16.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                description,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.muted,
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

class _FeatureDetail {
  const _FeatureDetail({required this.icon, required this.text});

  final IconData icon;
  final String text;
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.pill,
    required this.details,
  });

  final IconData icon;
  final String title;
  final String description;
  final String pill;
  final List<_FeatureDetail> details;

  @override
  Widget build(BuildContext context) {
    final colors = _SettingsColors.of(context);
    return _SettingsSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _IconBadge(icon: icon, size: 46),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: colors.text,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.muted,
                        fontWeight: FontWeight.w500,
                        height: 1.50,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Padding(
            padding: const EdgeInsets.only(left: 59),
            child: _Pill(label: pill),
          ),
          const SizedBox(height: 18),
          Container(height: 1, color: colors.border),
          const SizedBox(height: 17),
          ...details.asMap().entries.map((entry) {
            final item = entry.value;
            return Padding(
              padding: EdgeInsets.only(top: entry.key == 0 ? 0 : 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    item.icon,
                    size: 18,
                    color: _SettingsColors.teal,
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Text(
                      item.text,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.text,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B4D4B) : const Color(0xFFE5F4F0),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: isDark ? const Color(0xFFB9F4DF) : _SettingsColors.teal,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.icon, this.size = 45});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF20544F)
            : const Color(0xFFE7F4F0),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, size: size * 0.48, color: _SettingsColors.teal),
    );
  }
}

class _SettingsSurface extends StatelessWidget {
  const _SettingsSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = _SettingsColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.12)
                : _SettingsColors.navy.withValues(alpha: 0.045),
            blurRadius: 20,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _AboutCard extends StatelessWidget {
  const _AboutCard();

  @override
  Widget build(BuildContext context) {
    final colors = _SettingsColors.of(context);
    return _SettingsSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _IconBadge(icon: Icons.bolt_rounded, size: 46),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'KuryentePay',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: colors.text,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Electric Bill Inquiry and Payment',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.muted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'View current bills, electricity usage, payment status, billing history, and account notifications in one place.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colors.text,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.surfaceSoft,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  color: _SettingsColors.teal,
                  size: 19,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'KuryentePay is an independent academic prototype for local electric cooperative billing. It is not an official cooperative application.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.muted,
                      fontWeight: FontWeight.w600,
                      height: 1.45,
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
