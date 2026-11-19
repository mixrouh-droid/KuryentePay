// PROFILE PREMIUM REVISION: secure logout, responsive account cards, accurate status wording, and hosted-safe settings copy
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/services/session_service.dart';
import '../../../main.dart';
import '../../auth/screens/login_screen.dart';
import '../../privacy/screens/privacy_policy_screen.dart';
import '../../settings/screens/settings_screen.dart';
import '../../support/screens/help_support_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Future<Map<String, dynamic>?> _sessionFuture;
  bool _profileRefreshInProgress = false;

  static const List<_OfficeContact> _officeContacts = [
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

  @override
  void initState() {
    super.initState();
    _sessionFuture = SessionService.loadUser();
  }

  Future<void> _refreshProfile() async {
    if (_profileRefreshInProgress || !mounted) return;

    _profileRefreshInProgress = true;

    setState(() {
      _sessionFuture = SessionService.loadUser();
    });

    try {
      await _sessionFuture;
    } finally {
      _profileRefreshInProgress = false;
    }
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const SettingsScreen(),
      ),
    );
  }

  void _openSupport() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const HelpSupportScreen(),
      ),
    );
  }

  void _openPrivacy() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const PrivacyPolicyScreen(),
      ),
    );
  }

  Future<void> _copyValue(
      String value,
      String message,
      ) async {
    await Clipboard.setData(
      ClipboardData(text: value),
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _confirmLogout() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          icon: const Icon(Icons.logout_rounded),
          title: const Text('Log Out of KuryentePay?'),
          content: const Text(
            'You will return to the login screen. Your billing records will remain secure.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Log out'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    try {
      await SessionService.clear();
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'KuryentePay could not securely end your session. Please try again.',
          ),
        ),
      );
      return;
    }

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const LoginScreen(),
      ),
          (route) => false,
    );
  }

  String _initials(String name) {
    final String cleaned = name.trim();
    if (cleaned.isEmpty) return 'KP';

    final List<String> parts =
    cleaned.split(RegExp(r'\s+'));

    if (parts.length == 1) {
      return parts.first
          .substring(0, 1)
          .toUpperCase();
    }

    return '${parts.first.substring(0, 1)}'
        '${parts.last.substring(0, 1)}'
        .toUpperCase();
  }

  String _accountStatusLabel(String raw) {
    switch (raw.trim().toUpperCase()) {
      case 'ACTIVE':
        return 'Active consumer account';
      case 'PENDING':
        return 'Account approval pending';
      case 'REJECTED':
        return 'Account access restricted';
      case 'INACTIVE':
      case 'DISABLED':
        return 'Account currently inactive';
      default:
        return 'KuryentePay consumer account';
    }
  }

  String _modeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'System';
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _ProfilePalette.background(context),
      body: Stack(
        children: [
          const _ProfileBackdrop(),
          SafeArea(
            bottom: false,
            child: FutureBuilder<Map<String, dynamic>?>(
              future: _sessionFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const _ProfileSkeleton();
                }

                if (snapshot.hasError) {
                  return _CenteredState(
                    icon: Icons.person_off_rounded,
                    title: 'Profile unavailable',
                    subtitle: snapshot.error
                        .toString()
                        .replaceFirst('Exception: ', ''),
                    actionLabel: 'Try again',
                    onAction: _refreshProfile,
                  );
                }

                final Map<String, dynamic>? user =
                    snapshot.data;

                if (user == null) {
                  return _CenteredState(
                    icon: Icons.login_rounded,
                    title: 'No account session',
                    subtitle:
                    'Please log in again to view your account.',
                    actionLabel: 'Back to login',
                    onAction: () {
                      Navigator.of(context)
                          .pushAndRemoveUntil(
                        MaterialPageRoute(
                          builder: (_) =>
                          const LoginScreen(),
                        ),
                            (route) => false,
                      );
                    },
                  );
                }

                final String fullName =
                (user['name'] ?? 'My Account')
                    .toString()
                    .trim();

                final String accountNo =
                (user['account_no'] ?? '')
                    .toString()
                    .trim();

                final String address =
                (user['address'] ?? '')
                    .toString()
                    .trim();

                final String phone =
                (user['phone'] ?? '')
                    .toString()
                    .trim();

                final String accountStatus =
                (user['status'] ??
                    user['account_status'] ??
                    '')
                    .toString()
                    .trim()
                    .toUpperCase();

                // The login API includes the Meter S/N only after Admin
                // verification. Never display a consumer-submitted number
                // as a trusted meter assignment.
                final String meterSerialNo =
                (user['meter_serial_no'] ?? '')
                    .toString()
                    .trim();
                final String meterVerificationStatus =
                (user['meter_verification_status'] ?? '')
                    .toString()
                    .trim()
                    .toUpperCase();

                final ThemeMode currentMode =
                    themeController.mode;

                return RefreshIndicator(
                  color: _ProfilePalette.primary(context),
                  backgroundColor:
                  _ProfilePalette.surface(context),
                  onRefresh: _refreshProfile,
                  child: ListView(
                    physics:
                    const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    padding: const EdgeInsets.fromLTRB(
                      16,
                      8,
                      16,
                      28,
                    ),
                    children: [
                      const _ProfilePageHeader(),
                      const SizedBox(height: 18),
                      _ProfileHero(
                        fullName: fullName.isEmpty
                            ? 'My Account'
                            : fullName,
                        initials: _initials(fullName),
                        accountNo: accountNo,
                        accountStatus: accountStatus,
                        accountStatusLabel:
                        _accountStatusLabel(accountStatus),
                        onSettings: _openSettings,
                        onCopyAccount: accountNo.isEmpty
                            ? null
                            : () => _copyValue(
                          accountNo,
                          'Account number copied.',
                        ),
                      ),
                      const SizedBox(height: 14),
                      const _SectionHeading(
                        title: 'Account Information',
                        subtitle: 'Your registered consumer details',
                      ),
                      const SizedBox(height: 8),
                      _AccountDetailsCard(
                        accountNo: accountNo,
                        phone: phone,
                        address: address,
                        meterSerialNo: meterSerialNo,
                        meterVerificationStatus: meterVerificationStatus,
                        onCopyAccount: accountNo.isEmpty
                            ? null
                            : () => _copyValue(
                          accountNo,
                          'Account number copied.',
                        ),
                        onCopyPhone: phone.isEmpty
                            ? null
                            : () => _copyValue(
                          phone,
                          'Mobile number copied.',
                        ),
                        onCopyMeter: meterVerificationStatus == 'VERIFIED' &&
                            meterSerialNo.isNotEmpty
                            ? () => _copyValue(
                          meterSerialNo,
                          'Meter S/N copied.',
                        )
                            : null,
                      ),
                      const SizedBox(height: 14),
                      const _SectionHeading(
                        title: 'Appearance',
                        subtitle: 'Personalize your viewing experience',
                      ),
                      const SizedBox(height: 8),
                      _AppearanceCard(
                        currentMode: currentMode,
                        modeLabel:
                        _modeLabel(currentMode),
                        onChanged: (ThemeMode mode) {
                          setState(() {
                            themeController.setMode(mode);
                          });
                        },
                      ),
                      const SizedBox(height: 14),
                      const _SectionHeading(
                        title: 'Settings & Support',
                        subtitle: 'Everything you need to manage your app',
                      ),
                      const SizedBox(height: 8),
                      _MenuCard(
                        children: [
                          _ProfileMenuTile(
                            icon: Icons.tune_rounded,
                            accent: _ProfilePalette.primary(
                              context,
                            ),
                            title: 'App Settings',
                            subtitle:
                            'Notifications, security, and app preferences',
                            onTap: _openSettings,
                          ),
                          _ProfileMenuTile(
                            icon:
                            Icons.support_agent_rounded,
                            accent: _ProfilePalette.primary(
                              context,
                            ),
                            title: 'Help & Support',
                            subtitle:
                            'Get assistance with your account',
                            onTap: _openSupport,
                          ),
                          _ProfileMenuTile(
                            icon:
                            Icons.privacy_tip_rounded,
                            accent: _ProfilePalette.primary(
                              context,
                            ),
                            title: 'Privacy Policy',
                            subtitle:
                            'Learn how your information is handled',
                            onTap: _openPrivacy,
                            showDivider: false,
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      const _SectionHeading(
                        title: 'Local Office Directory',
                        subtitle: 'Reference contacts • verify before use',
                      ),
                      const SizedBox(height: 8),
                      _OfficeContactsCard(
                        contacts: _officeContacts,
                        onCopy: (contact) {
                          _copyValue(
                            contact.phone,
                            '${contact.name} number copied.',
                          );
                        },
                        onOpenHelp: _openSupport,
                      ),
                      const SizedBox(height: 12),
                      const _SecurityNotice(),
                      const SizedBox(height: 12),
                      _LogoutTile(
                        onTap: _confirmLogout,
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

class _ProfilePageHeader extends StatelessWidget {
  const _ProfilePageHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          height: 46,
          width: 46,
          decoration: BoxDecoration(
            color: _ProfilePalette.primary(context).withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: _ProfilePalette.primary(context).withValues(alpha: 0.16)),
          ),
          child: Icon(Icons.electric_bolt_rounded,
              color: _ProfilePalette.primary(context), size: 25),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('KuryentePay',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: _ProfilePalette.primary(context),
                    fontWeight: FontWeight.w800,
                  )),
              const SizedBox(height: 2),
              Text('My Profile',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: _ProfilePalette.text(context),
                    fontSize: 23, fontWeight: FontWeight.w800,
                  )),
            ],
          ),
        ),
      ],
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

class _ProfilePalette {
  static bool _isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color background(BuildContext context) =>
      _isDark(context) ? const Color(0xFF0C191D) : const Color(0xFFF4F7FA);

  static Color surface(BuildContext context) =>
      _isDark(context) ? const Color(0xFF15292E) : Colors.white;

  static Color surfaceAlt(BuildContext context) =>
      _isDark(context) ? const Color(0xFF1C3338) : const Color(0xFFF1F7F7);

  static Color border(BuildContext context) =>
      _isDark(context) ? const Color(0xFF2C474C) : const Color(0xFFDCE6EA);

  static Color primary(BuildContext context) =>
      _isDark(context) ? const Color(0xFF66D8C6) : const Color(0xFF087F79);

  static Color info(BuildContext context) => primary(context);

  static Color gold(BuildContext context) =>
      _isDark(context) ? const Color(0xFFF6D483) : const Color(0xFFB88B37);

  static Color danger(BuildContext context) =>
      _isDark(context) ? const Color(0xFFFFA3A8) : const Color(0xFFBD4651);

  static Color text(BuildContext context) =>
      _isDark(context) ? const Color(0xFFF1F8F8) : const Color(0xFF173347);

  static Color secondaryText(BuildContext context) =>
      _isDark(context) ? const Color(0xFFB7CFD0) : const Color(0xFF647983);
}

class _ProfileBackdrop extends StatelessWidget {
  const _ProfileBackdrop();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(color: _ProfilePalette.background(context)),
    );
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({
    required this.fullName,
    required this.initials,
    required this.accountNo,
    required this.accountStatus,
    required this.accountStatusLabel,
    required this.onSettings,
    required this.onCopyAccount,
  });

  final String fullName;
  final String initials;
  final String accountNo;
  final String accountStatus;
  final String accountStatusLabel;
  final VoidCallback onSettings;
  final VoidCallback? onCopyAccount;

  Color _statusAccent() {
    switch (accountStatus.trim().toUpperCase()) {
      case 'ACTIVE':
        return const Color(0xFF9DE9CD);
      case 'PENDING':
        return const Color(0xFFF6D483);
      case 'REJECTED':
      case 'INACTIVE':
      case 'DISABLED':
        return const Color(0xFFFFB4BA);
      default:
        return const Color(0xFFC5D7DF);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accountValue = accountNo.isEmpty ? 'Not available' : accountNo;
    final statusColor = _statusAccent();

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF102F3E),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: const Color(0xFF102F3E).withValues(alpha: 0.13),
              blurRadius: 24, offset: const Offset(0, 12)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(height: 4, color: const Color(0xFF49BFAE)),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 17, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.verified_user_outlined,
                        size: 18, color: Color(0xFFF6D483)),
                    const SizedBox(width: 8),
                    Expanded(child: Text('Consumer Account',
                        style: theme.textTheme.labelLarge?.copyWith(
                            color: const Color(0xFFD7EBEC),
                            fontWeight: FontWeight.w800))),
                    Tooltip(
                      message: 'App Settings',
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: onSettings,
                          borderRadius: BorderRadius.circular(12),
                          child: Ink(
                            width: 38, height: 38,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.settings_outlined,
                                color: Colors.white, size: 20),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 290;
                    final avatar = Container(
                      height: 62, width: 62,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFF20756F),
                        borderRadius: BorderRadius.circular(19),
                        border: Border.all(color: const Color(0xFF78D6C3).withValues(alpha: 0.48)),
                      ),
                      child: Text(initials,
                          style: theme.textTheme.titleLarge?.copyWith(
                              color: Colors.white,
                              fontSize: 21, fontWeight: FontWeight.w800)),
                    );
                    final nameAndStatus = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(fullName, maxLines: 3, overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleLarge?.copyWith(
                                color: Colors.white, fontWeight: FontWeight.w800,
                                fontSize: 20, height: 1.18)),
                        const SizedBox(height: 9),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: statusColor.withValues(alpha: 0.30)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(height: 7, width: 7,
                                  decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
                              const SizedBox(width: 7),
                              Flexible(child: Text(accountStatusLabel,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                      color: statusColor, fontWeight: FontWeight.w800))),
                            ],
                          ),
                        ),
                      ],
                    );
                    return compact
                        ? Column(crossAxisAlignment: CrossAxisAlignment.start,
                        children: [avatar, const SizedBox(height: 12), nameAndStatus])
                        : Row(crossAxisAlignment: CrossAxisAlignment.start,
                        children: [avatar, const SizedBox(width: 13), Expanded(child: nameAndStatus)]);
                  },
                ),
                const SizedBox(height: 18),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onCopyAccount,
                    borderRadius: BorderRadius.circular(15),
                    child: Ink(
                      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.09),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.credit_card_rounded,
                              size: 21, color: Color(0xFF9DE9CD)),
                          const SizedBox(width: 10),
                          Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Account Number',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                      color: const Color(0xFFC5D7DF))),
                              const SizedBox(height: 3),
                              Text(accountValue, maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                      color: Colors.white, fontWeight: FontWeight.w800)),
                            ],
                          )),
                          if (onCopyAccount != null)
                            const Icon(Icons.copy_rounded,
                                color: Color(0xFF9DE9CD), size: 18),
                        ],
                      ),
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

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Container(width: 4, height: 21,
              decoration: BoxDecoration(color: _ProfilePalette.primary(context),
                  borderRadius: BorderRadius.circular(4))),
          const SizedBox(width: 9),
          Expanded(child: Text(title,
              style: theme.textTheme.titleMedium?.copyWith(
                  color: _ProfilePalette.text(context), fontWeight: FontWeight.w800,
                  fontSize: 16))),
        ]),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(left: 13),
          child: Text(subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                  color: _ProfilePalette.secondaryText(context), fontSize: 11.5)),
        ),
      ],
    );
  }
}

class _AccountDetailsCard extends StatelessWidget {
  const _AccountDetailsCard({
    required this.accountNo,
    required this.phone,
    required this.address,
    required this.meterSerialNo,
    required this.meterVerificationStatus,
    required this.onCopyAccount,
    required this.onCopyPhone,
    required this.onCopyMeter,
  });

  final String accountNo;
  final String phone;
  final String address;
  final String meterSerialNo;
  final String meterVerificationStatus;
  final VoidCallback? onCopyAccount;
  final VoidCallback? onCopyPhone;
  final VoidCallback? onCopyMeter;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _InformationRow(
            icon: Icons.badge_rounded,
            accent:
            _ProfilePalette.primary(context),
            label: 'Account Number',
            value: accountNo.isEmpty
                ? 'Not available'
                : accountNo,
            trailingIcon:
            Icons.copy_rounded,
            onTrailingTap: onCopyAccount,
          ),
          _CardDivider(),
          _MeterDetailsRow(
            meterSerialNo: meterSerialNo,
            verificationStatus: meterVerificationStatus,
            onCopy: onCopyMeter,
          ),
          _CardDivider(),
          _InformationRow(
            icon: Icons.phone_android_rounded,
            accent: _ProfilePalette.primary(context),
            label: 'Mobile Number',
            value: phone.isEmpty
                ? 'Not available'
                : phone,
            trailingIcon:
            Icons.copy_rounded,
            onTrailingTap: onCopyPhone,
          ),
          _CardDivider(),
          _InformationRow(
            icon: Icons.home_work_rounded,
            accent: _ProfilePalette.primary(context),
            label: 'Service Address',
            value: address.isEmpty
                ? 'Not available'
                : address,
            maxLines: 3,
          ),
        ],
      ),
    );
  }
}


// A meter assignment is trusted only when the Admin has verified it.
// Unverified registration submissions are deliberately never displayed
// as assigned meter numbers in the consumer profile.
class _MeterDetailsRow extends StatelessWidget {
  const _MeterDetailsRow({
    required this.meterSerialNo,
    required this.verificationStatus,
    required this.onCopy,
  });

  final String meterSerialNo;
  final String verificationStatus;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    final bool verified = verificationStatus == 'VERIFIED' &&
        meterSerialNo.isNotEmpty;

    final String displayValue;
    final String explanation;

    if (verified) {
      displayValue = meterSerialNo;
      explanation = 'Admin verified · Read-only';
    } else if (verificationStatus == 'PENDING_VERIFICATION') {
      displayValue = 'Pending verification';
      explanation = 'Your Meter S/N is awaiting Admin verification.';
    } else if (verificationStatus == 'NOT_ASSIGNED') {
      displayValue = 'Not assigned yet';
      explanation = 'The System Administrator will assign your Meter S/N.';
    } else {
      displayValue = 'Not available';
      explanation = 'Sign out and sign in again to refresh meter details.';
    }

    final ThemeData theme = Theme.of(context);
    final Color primary = _ProfilePalette.primary(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _IconTile(
            icon: Icons.electric_bolt_rounded,
            accent: primary,
            size: 42,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Meter S/N',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: _ProfilePalette.secondaryText(context),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    displayValue,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: _ProfilePalette.text(context),
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        verified
                            ? Icons.verified_rounded
                            : Icons.info_outline_rounded,
                        size: 14,
                        color: verified
                            ? primary
                            : _ProfilePalette.secondaryText(context),
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          explanation,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 11.5,
                            height: 1.35,
                            color: verified
                                ? primary
                                : _ProfilePalette.secondaryText(context),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (verified && onCopy != null) ...[
            const SizedBox(width: 5),
            IconButton(
              tooltip: 'Copy Meter S/N',
              visualDensity: VisualDensity.compact,
              onPressed: onCopy,
              icon: const Icon(Icons.copy_rounded, size: 18),
              color: primary,
            ),
          ],
        ],
      ),
    );
  }
}

class _InformationRow extends StatelessWidget {
  const _InformationRow({
    required this.icon,
    required this.accent,
    required this.label,
    required this.value,
    this.trailingIcon,
    this.onTrailingTap,
    this.maxLines = 1,
  });
  final IconData icon;
  final Color accent;
  final String label;
  final String value;
  final IconData? trailingIcon;
  final VoidCallback? onTrailingTap;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _IconTile(icon: icon, accent: _ProfilePalette.primary(context), size: 42),
          const SizedBox(width: 12),
          Expanded(child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.labelMedium?.copyWith(
                    color: _ProfilePalette.secondaryText(context),
                    fontSize: 11.5, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(value, maxLines: maxLines, overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                        color: _ProfilePalette.text(context),
                        fontSize: 13.5, fontWeight: FontWeight.w800, height: 1.4)),
              ],
            ),
          )),
          if (trailingIcon != null) ...[
            const SizedBox(width: 5),
            IconButton(
              tooltip: 'Copy $label',
              visualDensity: VisualDensity.compact,
              onPressed: onTrailingTap,
              icon: Icon(trailingIcon, size: 18),
              color: _ProfilePalette.primary(context),
            ),
          ],
        ],
      ),
    );
  }
}

class _AppearanceCard extends StatelessWidget {
  const _AppearanceCard({
    required this.currentMode,
    required this.modeLabel,
    required this.onChanged,
  });

  final ThemeMode currentMode;
  final String modeLabel;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: [
              _IconTile(
                icon: Icons.palette_rounded,
                accent:
                _ProfilePalette.primary(context),
                size: 40,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Theme mode',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(
                        color: _ProfilePalette
                            .text(context),
                        fontWeight:
                        FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Currently using $modeLabel mode',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(
                        color: _ProfilePalette
                            .secondaryText(context),
                        fontSize: 11.5,
                        fontWeight:
                        FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          Row(
            children: [
              Expanded(
                child: _ThemeOption(
                  label: 'System',
                  icon:
                  Icons.phone_android_rounded,
                  selected:
                  currentMode == ThemeMode.system,
                  onTap: () =>
                      onChanged(ThemeMode.system),
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: _ThemeOption(
                  label: 'Light',
                  icon: Icons.light_mode_rounded,
                  selected:
                  currentMode == ThemeMode.light,
                  onTap: () =>
                      onChanged(ThemeMode.light),
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: _ThemeOption(
                  label: 'Dark',
                  icon: Icons.dark_mode_rounded,
                  selected:
                  currentMode == ThemeMode.dark,
                  onTap: () =>
                      onChanged(ThemeMode.dark),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
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
    final primary = _ProfilePalette.primary(context);
    final selectedBackground = _ProfilePalette._isDark(context)
        ? const Color(0xFF20504B) : const Color(0xFFE4F4F0);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          height: 62,
          decoration: BoxDecoration(
            color: selected ? selectedBackground : _ProfilePalette.surfaceAlt(context),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? primary : _ProfilePalette.border(context),
                width: selected ? 1.4 : 1),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20,
                  color: selected ? primary : _ProfilePalette.secondaryText(context)),
              const SizedBox(height: 5),
              Text(label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: selected ? primary : _ProfilePalette.secondaryText(context),
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({
    required this.children,
  });

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      padding: EdgeInsets.zero,
      child: Column(children: children),
    );
  }
}

class _ProfileMenuTile extends StatelessWidget {
  const _ProfileMenuTile({
    required this.icon,
    required this.accent,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.showDivider = true,
  });

  final IconData icon;
  final Color accent;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 13,
                vertical: 12,
              ),
              child: Row(
                children: [
                  _IconTile(
                    icon: icon,
                    accent: accent,
                    size: 40,
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                            color: _ProfilePalette
                                .text(context),
                            fontSize: 13.5,
                            fontWeight:
                            FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow:
                          TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                            color: _ProfilePalette
                                .secondaryText(
                              context,
                            ),
                            fontSize: 11.5,
                            fontWeight:
                            FontWeight.w600,
                            height: 1.25,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: _ProfilePalette
                        .secondaryText(context),
                    size: 21,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (showDivider) const _CardDivider(),
      ],
    );
  }
}

class _OfficeContactsCard extends StatelessWidget {
  const _OfficeContactsCard({
    required this.contacts,
    required this.onCopy,
    required this.onOpenHelp,
  });

  final List<_OfficeContact> contacts;
  final ValueChanged<_OfficeContact> onCopy;
  final VoidCallback onOpenHelp;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (int index = 0;
          index < contacts.length;
          index++) ...[
            _OfficeContactRow(
              contact: contacts[index],
              onCopy: () =>
                  onCopy(contacts[index]),
            ),
            if (index != contacts.length - 1)
              const _CardDivider(),
          ],
          const _CardDivider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 12, 15, 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, size: 17,
                    color: _ProfilePalette.primary(context)),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  'Reference directory only. These numbers are not verified KuryentePay support contacts.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: _ProfilePalette.secondaryText(context), height: 1.45),
                )),
              ],
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onOpenHelp,
              borderRadius:
              const BorderRadius.vertical(
                bottom: Radius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 11,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.support_agent_rounded,
                      size: 19,
                      color:
                      _ProfilePalette.primary(
                        context,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        'Open Help & Support',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(
                          color: _ProfilePalette
                              .primary(context),
                          fontSize: 12.5,
                          fontWeight:
                          FontWeight.w900,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 18,
                      color:
                      _ProfilePalette.primary(
                        context,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OfficeContactRow extends StatelessWidget {
  const _OfficeContactRow({
    required this.contact,
    required this.onCopy,
  });

  final _OfficeContact contact;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    Widget contactInfo() {
      return Row(
        children: [
          _IconTile(
            icon: contact.icon,
            accent: _ProfilePalette.primary(context),
            size: 38,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contact.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: _ProfilePalette.text(context),
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  contact.phone,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: _ProfilePalette.secondaryText(context),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    final Widget copyButton = TextButton.icon(
      onPressed: onCopy,
      icon: const Icon(
        Icons.copy_rounded,
        size: 15,
      ),
      label: const Text('Copy'),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(
          horizontal: 9,
          vertical: 7,
        ),
        textStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(13, 11, 8, 11),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          if (constraints.maxWidth < 310) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                contactInfo(),
                const SizedBox(height: 5),
                Align(
                  alignment: Alignment.centerRight,
                  child: copyButton,
                ),
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: contactInfo()),
              const SizedBox(width: 6),
              copyButton,
            ],
          );
        },
      ),
    );
  }
}

class _SecurityNotice extends StatelessWidget {
  const _SecurityNotice();

  @override
  Widget build(BuildContext context) {
    final primary = _ProfilePalette.primary(context);
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: primary.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_outlined, color: primary, size: 22),
          const SizedBox(width: 11),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Keep Your Account Secure',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: _ProfilePalette.text(context), fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text('Never share your password, payment links, or verification details with anyone.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: _ProfilePalette.secondaryText(context), height: 1.45)),
            ],
          )),
        ],
      ),
    );
  }
}

class _LogoutTile extends StatelessWidget {
  const _LogoutTile({
    required this.onTap,
  });

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color danger =
    _ProfilePalette.danger(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius:
        BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.symmetric(
            horizontal: 13,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            color: danger.withValues(alpha: 0.07),
            borderRadius:
            BorderRadius.circular(18),
            border: Border.all(
              color: danger.withValues(alpha: 0.22),
            ),
          ),
          child: Row(
            children: [
              _IconTile(
                icon: Icons.logout_rounded,
                accent: danger,
                size: 40,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Log out',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(
                        color: danger,
                        fontSize: 13.5,
                        fontWeight:
                        FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Securely end your KuryentePay session',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(
                        color: _ProfilePalette
                            .secondaryText(context),
                        fontSize: 11.5,
                        fontWeight:
                        FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: danger,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SurfaceCard extends StatelessWidget {
  const _SurfaceCard({required this.child, this.padding = const EdgeInsets.all(14)});
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: _ProfilePalette.surface(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _ProfilePalette.border(context)),
        boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.12 : 0.035),
          blurRadius: 16, offset: const Offset(0, 7),
        )],
      ),
      child: child,
    );
  }
}

class _IconTile extends StatelessWidget {
  const _IconTile({
    required this.icon,
    required this.accent,
    this.size = 40,
  });

  final IconData icon;
  final Color accent;
  final double size;

  @override
  Widget build(BuildContext context) {
    final bool isDark =
        Theme.of(context).brightness ==
            Brightness.dark;

    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        borderRadius:
        BorderRadius.circular(size * 0.30),
        color: accent.withValues(
          alpha: isDark ? 0.14 : 0.09,
        ),
      ),
      child: Icon(
        icon,
        color: accent,
        size: size * 0.46,
      ),
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
      indent: 13,
      endIndent: 13,
      color: _ProfilePalette.border(context),
    );
  }
}

class _CenteredState extends StatelessWidget {
  const _CenteredState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: _SurfaceCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _IconTile(
                icon: icon,
                accent:
                _ProfilePalette.primary(context),
                size: 50,
              ),
              const SizedBox(height: 13),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(
                  color:
                  _ProfilePalette.text(context),
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(
                  color: _ProfilePalette
                      .secondaryText(context),
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
              if (actionLabel != null &&
                  onAction != null) ...[
                const SizedBox(height: 13),
                FilledButton(
                  onPressed: onAction,
                  child: Text(actionLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileSkeleton extends StatelessWidget {
  const _ProfileSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        16,
        8,
        16,
        24,
      ),
      children: const [
        _SkeletonCard(height: 214),
        SizedBox(height: 14),
        _SkeletonCard(height: 190),
        SizedBox(height: 14),
        _SkeletonCard(height: 132),
        SizedBox(height: 14),
        _SkeletonCard(height: 196),
        SizedBox(height: 14),
        _SkeletonCard(height: 218),
      ],
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard({
    required this.height,
  });

  final double height;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      padding: EdgeInsets.zero,
      child: SizedBox(height: height),
    );
  }
}

class _GlowCircle extends StatelessWidget {
  const _GlowCircle({
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
              blurRadius: size * 0.52,
              spreadRadius: size * 0.05,
            ),
          ],
        ),
      ),
    );
  }
}
