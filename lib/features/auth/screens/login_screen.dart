// LOGIN DEFENSE POLISH: concise copy, exact 10-digit validation, safer session handling, preserved approval monitoring, and existing responsive UI
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/routes/app_router.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/push_token_service.dart';
import '../../../core/services/session_service.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}


class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _accountCtrl = TextEditingController();
  final TextEditingController _passCtrl = TextEditingController();

  final FocusNode _accountFocus = FocusNode();
  final FocusNode _passFocus = FocusNode();

  bool _hidePassword = true;
  bool _loading = false;

  Timer? _approvalWatchTimer;
  String? _pendingApprovalAccountNo;
  bool _checkingApprovalStatus = false;
  bool _approvalDialogShown = false;

  String? _errorText;

  late final AnimationController _animationController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.035),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
      ),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _approvalWatchTimer?.cancel();
    _accountCtrl.dispose();
    _passCtrl.dispose();
    _accountFocus.dispose();
    _passFocus.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _pendingApprovalAccountNo != null) {
      unawaited(_checkApprovalStatus());
    }
  }

  void _startApprovalWatch(String accountNo) {
    final String normalized = accountNo.trim();

    if (!RegExp(r'^\d{10}$').hasMatch(normalized)) {
      return;
    }

    _pendingApprovalAccountNo = normalized;
    _approvalWatchTimer?.cancel();

    unawaited(_checkApprovalStatus());

    _approvalWatchTimer = Timer.periodic(
      const Duration(seconds: 15),
          (_) => unawaited(_checkApprovalStatus()),
    );
  }

  void _stopApprovalWatch() {
    _approvalWatchTimer?.cancel();
    _approvalWatchTimer = null;
    _pendingApprovalAccountNo = null;
  }

  Future<void> _checkApprovalStatus() async {
    final String? accountNo = _pendingApprovalAccountNo;

    if (!mounted ||
        accountNo == null ||
        _checkingApprovalStatus ||
        _approvalDialogShown) {
      return;
    }

    _checkingApprovalStatus = true;

    try {
      final String status =
      await AuthService.checkRegistrationStatus(
        accountNo: accountNo,
      );

      if (!mounted) return;

      if (status == 'ACTIVE') {
        _stopApprovalWatch();
        _approvalDialogShown = true;

        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext dialogContext) {
            return AlertDialog(
              icon: Icon(
                Icons.verified_rounded,
                color: _LoginPalette.primary(dialogContext),
                size: 34,
              ),
              title: const Text('Account Approved'),
              content: const Text(
                'Your KuryentePay account is now active. '
                    'Sign in using your account number and password.',
              ),
              actions: [
                FilledButton(
                  onPressed: () =>
                      Navigator.of(dialogContext).pop(),
                  child: const Text('Sign In'),
                ),
              ],
            );
          },
        );

        _approvalDialogShown = false;

        if (mounted) {
          _passFocus.requestFocus();
        }
      } else if (status == 'REJECTED' ||
          status == 'INACTIVE' ||
          status == 'UNKNOWN') {
        _stopApprovalWatch();
      }
    } catch (error) {
      debugPrint(
        'Registration approval status check failed: '
            '${error.runtimeType}',
      );
    } finally {
      _checkingApprovalStatus = false;
    }
  }

  void _setError(String? message) {
    if (!mounted) return;

    setState(() {
      _errorText = message;
    });
  }

  String _friendlyLoginError(Object error) {
    final String raw = error
        .toString()
        .replaceFirst('Exception: ', '')
        .trim();

    final String lower = raw.toLowerCase();

    if (lower.contains('pending')) {
      return 'Your registration is still pending approval. KuryentePay will check your approval status automatically while this screen is open.';
    }

    if (lower.contains('rejected')) {
      return 'Your registration was not approved. Please contact your KuryentePay system administrator for assistance.';
    }

    if (lower.contains('inactive')) {
      return 'This account is currently inactive. Please contact your KuryentePay system administrator.';
    }

    if (lower.contains('invalid') ||
        lower.contains('incorrect') ||
        lower.contains('wrong password') ||
        lower.contains('not found')) {
      return 'The account number or password is incorrect. Please check your details and try again.';
    }

    if (lower.contains('socket') ||
        lower.contains('network') ||
        lower.contains('connection') ||
        lower.contains('timeout') ||
        lower.contains('failed host lookup')) {
      return 'KuryentePay could not be reached. Please check your internet connection and try again.';
    }

    return raw.isEmpty
        ? 'Sign-in failed. Please try again.'
        : raw;
  }

  Future<void> _pasteAccountFromClipboard() async {
    final ClipboardData? data =
    await Clipboard.getData('text/plain');

    final String text = (data?.text ?? '').trim();

    if (text.isEmpty) return;

    final String digits =
    text.replaceAll(RegExp(r'[^0-9]'), '');

    if (!RegExp(r'^\d{10}$').hasMatch(digits)) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'The clipboard must contain a 10-digit account number.',
          ),
        ),
      );
      return;
    }

    _accountCtrl.text = digits;
    _accountCtrl.selection = TextSelection.collapsed(
      offset: _accountCtrl.text.length,
    );

    _passFocus.requestFocus();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Account number pasted.'),
      ),
    );
  }

  Future<void> _syncPushTokenAfterLogin(
      String accountNo,
      ) async {
    try {
      await PushTokenService.syncCurrentDevice(
        accountNoOverride: accountNo,
      );
    } catch (error) {
      debugPrint(
        'Push-token registration after login failed: '
            '${error.runtimeType}',
      );
    }
  }

  Future<void> _loginReal() async {
    FocusScope.of(context).unfocus();
    _setError(null);

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final String accountNo = _accountCtrl.text.trim();
    final String password = _passCtrl.text;

    setState(() {
      _loading = true;
    });

    try {
      final Map<String, dynamic> result =
      await AuthService.login(
        accountNo: accountNo,
        password: password,
      );

      final Map<String, dynamic>? user =
      (result['user'] as Map?)
          ?.cast<String, dynamic>();

      if (user == null || user.isEmpty) {
        throw Exception(
          'KuryentePay could not load your account session. Please try again.',
        );
      }

      // MainShell and the consumer services require the authenticated
      // session after navigation, so keep the successful session available.
      await SessionService.saveUser(user);

      TextInput.finishAutofillContext();

      // Do not delay or block login while the phone token is submitted.
      unawaited(
        _syncPushTokenAfterLogin(accountNo),
      );

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const MainShell(),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      if (error.toString().toLowerCase().contains('pending')) {
        _startApprovalWatch(accountNo);
      }

      _setError(_friendlyLoginError(error));
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _openRegister() async {
    FocusScope.of(context).unfocus();
    _setError(null);

    final String? accountNumber =
    await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const RegisterScreen(),
      ),
    );

    if (accountNumber == null ||
        accountNumber.trim().isEmpty) {
      return;
    }

    _accountCtrl.text = accountNumber.trim();
    _accountCtrl.selection = TextSelection.collapsed(
      offset: _accountCtrl.text.length,
    );

    if (!mounted) return;

    _startApprovalWatch(accountNumber);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Registration submitted. Approval status will be checked automatically while this screen is open.',
        ),
      ),
    );

    _passFocus.requestFocus();
  }

  void _showAccountNumberHelpSheet() {
    FocusScope.of(context).unfocus();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        final double bottomInset =
            MediaQuery.of(sheetContext).padding.bottom;
        final double maxHeight =
            MediaQuery.sizeOf(sheetContext).height * 0.82;

        return Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            0,
            16,
            bottomInset + 16,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: _GlassPanel(
              padding: const EdgeInsets.fromLTRB(
                16,
                12,
                16,
                16,
              ),
              borderRadius: 30,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: _LoginPalette.border(
                            sheetContext,
                          ),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 17),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _IconTile(
                          icon: Icons.receipt_long_rounded,
                          accent: _LoginPalette.primary(
                            sheetContext,
                          ),
                          size: 50,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Find Your Account Number',
                                style: Theme.of(sheetContext)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                  color: _LoginPalette.text(
                                    sheetContext,
                                  ),
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                'Your 10-digit account number is printed on your electricity bill.',
                                style: Theme.of(sheetContext)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                  color: _LoginPalette.secondaryText(
                                    sheetContext,
                                  ),
                                  fontWeight: FontWeight.w600,
                                  height: 1.40,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        color: _LoginPalette.primary(
                          sheetContext,
                        ).withValues(alpha: 0.065),
                        borderRadius: BorderRadius.circular(17),
                        border: Border.all(
                          color: _LoginPalette.primary(
                            sheetContext,
                          ).withValues(alpha: 0.15),
                        ),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _AccountHelpStep(
                            number: '1',
                            text: 'Open your printed or digital electricity bill.',
                          ),
                          SizedBox(height: 10),
                          _AccountHelpStep(
                            number: '2',
                            text: 'Look for the label “Account Number”.',
                          ),
                          SizedBox(height: 10),
                          _AccountHelpStep(
                            number: '3',
                            text: 'Enter the 10 digits exactly as shown.',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 18,
                          color: _LoginPalette.info(sheetContext),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Use your own account number and keep your password private.',
                            style: Theme.of(sheetContext)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                              color: _LoginPalette.secondaryText(
                                sheetContext,
                              ),
                              fontWeight: FontWeight.w600,
                              height: 1.38,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 17),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton(
                        onPressed: () {
                          Navigator.of(sheetContext).pop();
                        },
                        child: const Text(
                          'Close',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
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
      },
    );
  }

  void _showForgotSheet() {
    FocusScope.of(context).unfocus();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        final double bottomInset =
            MediaQuery.of(sheetContext).padding.bottom;
        final double maxHeight =
            MediaQuery.sizeOf(sheetContext).height * 0.72;

        return Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            0,
            16,
            bottomInset + 16,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: _GlassPanel(
              padding: const EdgeInsets.fromLTRB(
                16,
                12,
                16,
                16,
              ),
              borderRadius: 30,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: _LoginPalette.border(
                          sheetContext,
                        ),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(height: 17),
                    _IconTile(
                      icon: Icons.lock_reset_rounded,
                      accent: _LoginPalette.primary(
                        sheetContext,
                      ),
                      size: 50,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Password Help',
                      textAlign: TextAlign.center,
                      style: Theme.of(sheetContext)
                          .textTheme
                          .titleMedium
                          ?.copyWith(
                        color: _LoginPalette.text(
                          sheetContext,
                        ),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      'Contact your KuryentePay system administrator to verify your identity and request a password reset.',
                      textAlign: TextAlign.center,
                      style: Theme.of(sheetContext)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(
                        color: _LoginPalette.secondaryText(
                          sheetContext,
                        ),
                        fontWeight: FontWeight.w600,
                        height: 1.42,
                      ),
                    ),
                    const SizedBox(height: 17),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton(
                        onPressed: () {
                          Navigator.of(sheetContext).pop();
                        },
                        child: const Text(
                          'Close',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
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
      },
    );
  }

  String? _validateAccount(String? value) {
    final String accountNumber =
    (value ?? '').trim();

    if (accountNumber.isEmpty) {
      return 'Account number is required.';
    }

    if (!RegExp(r'^\d{10}$').hasMatch(accountNumber)) {
      return 'Enter a valid 10-digit account number.';
    }

    return null;
  }

  String? _validatePassword(String? value) {
    final String password = value ?? '';

    if (password.isEmpty) {
      return 'Password is required.';
    }

    if (password.length < 6) {
      return 'Password must be at least 6 characters.';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        backgroundColor:
        _LoginPalette.background(context),
        body: Stack(
          children: [
            const _LoginBackdrop(),
            SafeArea(
              child: LayoutBuilder(
                builder: (
                    BuildContext context,
                    BoxConstraints constraints,
                    ) {
                  return SingleChildScrollView(
                    keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior
                        .onDrag,
                    padding: const EdgeInsets.fromLTRB(
                      18,
                      12,
                      18,
                      20,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight:
                        constraints.maxHeight - 32,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints:
                          const BoxConstraints(
                            maxWidth: 430,
                          ),
                          child: FadeTransition(
                            opacity: _fadeAnimation,
                            child: SlideTransition(
                              position: _slideAnimation,
                              child: Column(
                                mainAxisAlignment:
                                MainAxisAlignment
                                    .center,
                                children: [
                                  const _BrandHeroCard(),
                                  const SizedBox(height: 13),
                                  _LoginFormCard(
                                    formKey: _formKey,
                                    accountController:
                                    _accountCtrl,
                                    passwordController:
                                    _passCtrl,
                                    accountFocus:
                                    _accountFocus,
                                    passwordFocus:
                                    _passFocus,
                                    hidePassword:
                                    _hidePassword,
                                    loading: _loading,
                                    errorText: _errorText,
                                    onTogglePassword: () {
                                      setState(() {
                                        _hidePassword =
                                        !_hidePassword;
                                      });
                                    },
                                    onForgot: _loading
                                        ? null
                                        : _showForgotSheet,
                                    onPaste: _loading
                                        ? null
                                        : _pasteAccountFromClipboard,
                                    onAccountHelp: _loading
                                        ? null
                                        : _showAccountNumberHelpSheet,
                                    onLogin: _loading
                                        ? null
                                        : _loginReal,
                                    onRegister: _loading
                                        ? null
                                        : _openRegister,
                                    validateAccount:
                                    _validateAccount,
                                    validatePassword:
                                    _validatePassword,
                                  ),
                                  const SizedBox(height: 12),
                                  const _SecurityFooter(),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoginPalette {
  static bool _isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static const Color navy = Color(0xFF102F3E);
  static const Color teal = Color(0xFF087F79);
  static const Color goldAccent = Color(0xFFF6D483);

  static Color background(BuildContext context) =>
      _isDark(context) ? const Color(0xFF0B1E28) : const Color(0xFFF4F7FA);

  static Color surface(BuildContext context) =>
      _isDark(context) ? const Color(0xFF122F3A) : Colors.white;

  static Color surfaceAlt(BuildContext context) =>
      _isDark(context) ? const Color(0xFF173A44) : const Color(0xFFF8FAFA);

  static Color border(BuildContext context) =>
      _isDark(context) ? const Color(0xFF315760) : const Color(0xFFDCE6EA);

  static Color text(BuildContext context) =>
      _isDark(context) ? const Color(0xFFF4FAFA) : const Color(0xFF173347);

  static Color secondaryText(BuildContext context) =>
      _isDark(context) ? const Color(0xFFCCDFE0) : const Color(0xFF526A75);

  static Color primary(BuildContext context) =>
      _isDark(context) ? const Color(0xFF8CE5D5) : teal;

  static Color info(BuildContext context) => primary(context);

  static Color gold(BuildContext context) =>
      _isDark(context) ? goldAccent : const Color(0xFF9D741A);

  static Color danger(BuildContext context) =>
      _isDark(context) ? const Color(0xFFFFA7A9) : const Color(0xFFBE3948);
}

class _LoginBackdrop extends StatelessWidget {
  const _LoginBackdrop();

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: isDark
                      ? const [Color(0xFF0B1E28), Color(0xFF102A33)]
                      : const [Color(0xFFF4F7FA), Color(0xFFEDF4F2)],
                ),
              ),
            ),
          ),
          Positioned(
            top: -165,
            right: -155,
            child: Container(
              width: 310,
              height: 310,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: _LoginPalette.primary(context).withValues(alpha: 0.10),
                  width: 36,
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -170,
            left: -160,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: _LoginPalette.primary(context).withValues(alpha: 0.055),
                  width: 50,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandHeroCard extends StatelessWidget {
  const _BrandHeroCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _LoginPalette.navy,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF2B565E)),
        boxShadow: [
          BoxShadow(
            color: _LoginPalette.navy.withValues(alpha: 0.16),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(height: 4, color: _LoginPalette.teal),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 19),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    _BrandLogo(),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'KuryentePay',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 21,
                          letterSpacing: -0.55,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 23),
                const Text(
                  'Your Electric Bills, Made Simple.',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 23,
                    letterSpacing: -0.65,
                    height: 1.18,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  'Check your bill, monitor payments, and stay on top of due dates—all in one place.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFFCADFE0),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    height: 1.50,
                  ),
                ),
                const SizedBox(height: 18),
                const Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _HeroFeatureChip(icon: Icons.receipt_long_outlined, label: 'Bills'),
                    _HeroFeatureChip(icon: Icons.account_balance_wallet_outlined, label: 'Payments'),
                    _HeroFeatureChip(icon: Icons.notifications_none_rounded, label: 'Alerts'),
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

class _HeroFeatureChip extends StatelessWidget {
  const _HeroFeatureChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF214652),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF385B65)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFF8CE5D5), size: 15),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFF0FBF9),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandLogo extends StatelessWidget {
  const _BrandLogo();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 49,
      width: 49,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        color: const Color(0xFF1B645F),
        border: Border.all(color: const Color(0xFF4B8C83)),
      ),
      child: const Icon(
        Icons.bolt_rounded,
        color: _LoginPalette.goldAccent,
        size: 29,
      ),
    );
  }
}

class _LoginFormCard extends StatelessWidget {
  const _LoginFormCard({
    required this.formKey,
    required this.accountController,
    required this.passwordController,
    required this.accountFocus,
    required this.passwordFocus,
    required this.hidePassword,
    required this.loading,
    required this.errorText,
    required this.onTogglePassword,
    required this.onForgot,
    required this.onPaste,
    required this.onAccountHelp,
    required this.onLogin,
    required this.onRegister,
    required this.validateAccount,
    required this.validatePassword,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController accountController;
  final TextEditingController passwordController;
  final FocusNode accountFocus;
  final FocusNode passwordFocus;
  final bool hidePassword;
  final bool loading;
  final String? errorText;
  final VoidCallback onTogglePassword;
  final VoidCallback? onForgot;
  final VoidCallback? onPaste;
  final VoidCallback? onAccountHelp;
  final VoidCallback? onLogin;
  final VoidCallback? onRegister;
  final String? Function(String?) validateAccount;
  final String? Function(String?) validatePassword;

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      padding: const EdgeInsets.all(20),
      borderRadius: 24,
      child: AutofillGroup(
        child: Form(
          key: formKey,
          autovalidateMode:
          AutovalidateMode.onUserInteraction,
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              const _SignInHeading(),
              if (errorText != null &&
                  errorText!.trim().isNotEmpty) ...[
                const SizedBox(height: 13),
                _ErrorBanner(text: errorText!),
              ],
              const SizedBox(height: 16),
              _PremiumTextField(
                controller: accountController,
                focusNode: accountFocus,
                keyboardType:
                TextInputType.number,
                textInputAction:
                TextInputAction.next,
                autofillHints: const [
                  AutofillHints.username,
                ],
                validator: validateAccount,
                labelText: 'Account number',
                hintText:
                'Enter your account number',
                icon: Icons.badge_rounded,
                suffix: IconButton(
                  tooltip: 'Paste account number',
                  onPressed: onPaste,
                  icon: const Icon(
                    Icons.content_paste_rounded,
                    size: 19,
                  ),
                ),
                onFieldSubmitted: (_) {
                  passwordFocus.requestFocus();
                },
                digitsOnly: true,
              ),
              const SizedBox(height: 7),
              _AccountNumberReminder(
                onHelp: onAccountHelp,
              ),
              const SizedBox(height: 13),
              _PremiumTextField(
                controller: passwordController,
                focusNode: passwordFocus,
                keyboardType:
                TextInputType.visiblePassword,
                textInputAction:
                TextInputAction.done,
                autofillHints: const [
                  AutofillHints.password,
                ],
                validator: validatePassword,
                labelText: 'Password',
                hintText: 'Enter your password',
                icon: Icons.lock_rounded,
                obscureText: hidePassword,
                suffix: IconButton(
                  tooltip: hidePassword
                      ? 'Show password'
                      : 'Hide password',
                  onPressed: onTogglePassword,
                  icon: Icon(
                    hidePassword
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    size: 20,
                  ),
                ),
                onFieldSubmitted: (_) {
                  onLogin?.call();
                },
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: onForgot,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 7,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Forgot Password?',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              _LoginButton(
                loading: loading,
                onTap: onLogin,
              ),
              const SizedBox(height: 11),
              _RegisterPrompt(
                onRegister: onRegister,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SignInHeading extends StatelessWidget {
  const _SignInHeading();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _IconTile(
          icon: Icons.lock_open_rounded,
          accent: _LoginPalette.primary(context),
          size: 42,
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Text(
                'Sign In',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(
                  color: _LoginPalette.text(context),
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.18,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Access your electric billing account securely.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(
                  color:
                  _LoginPalette.secondaryText(
                    context,
                  ),
                  fontWeight: FontWeight.w600,
                  height: 1.30,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AccountNumberReminder extends StatelessWidget {
  const _AccountNumberReminder({
    required this.onHelp,
  });

  final VoidCallback? onHelp;

  @override
  Widget build(BuildContext context) {
    final Color accent = _LoginPalette.info(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(11, 8, 8, 8),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: accent.withValues(alpha: 0.15),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bool compact = constraints.maxWidth < 285;

          final Widget message = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.receipt_long_outlined,
                color: accent,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Use the 10-digit account number on your electricity bill.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(
                    color: _LoginPalette.text(context),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    height: 1.32,
                  ),
                ),
              ),
            ],
          );

          final Widget help = TextButton(
            onPressed: onHelp,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 5,
              ),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Find It',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                message,
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: help,
                ),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: message),
              const SizedBox(width: 4),
              help,
            ],
          );
        },
      ),
    );
  }
}

class _AccountHelpStep extends StatelessWidget {
  const _AccountHelpStep({
    required this.number,
    required this.text,
  });

  final String number;
  final String text;

  @override
  Widget build(BuildContext context) {
    final Color accent = _LoginPalette.primary(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 24,
          width: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: accent.withValues(alpha: 0.12),
            border: Border.all(
              color: accent.withValues(alpha: 0.22),
            ),
          ),
          child: Center(
            child: Text(
              number,
              style: TextStyle(
                color: accent,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              text,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(
                color: _LoginPalette.text(context),
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PremiumTextField extends StatelessWidget {
  const _PremiumTextField({
    required this.controller,
    required this.focusNode,
    required this.keyboardType,
    required this.textInputAction,
    required this.validator,
    required this.labelText,
    required this.hintText,
    required this.icon,
    this.autofillHints,
    this.obscureText = false,
    this.suffix,
    this.onFieldSubmitted,
    this.digitsOnly = false,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final Iterable<String>? autofillHints;
  final String? Function(String?) validator;
  final String labelText;
  final String hintText;
  final IconData icon;
  final bool obscureText;
  final Widget? suffix;
  final ValueChanged<String>? onFieldSubmitted;
  final bool digitsOnly;

  @override
  Widget build(BuildContext context) {
    final bool isDark =
        Theme.of(context).brightness ==
            Brightness.dark;

    final List<TextInputFormatter> formatters = [
      if (digitsOnly)
        FilteringTextInputFormatter.digitsOnly,
      if (digitsOnly)
        LengthLimitingTextInputFormatter(10),
    ];

    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      autofillHints: autofillHints,
      inputFormatters: formatters,
      obscureText: obscureText,
      enableSuggestions: !obscureText,
      autocorrect: !obscureText,
      validator: validator,
      onFieldSubmitted: onFieldSubmitted,
      style: TextStyle(
        color: _LoginPalette.text(context),
        fontWeight: FontWeight.w800,
        fontSize: 14,
      ),
      cursorColor: _LoginPalette.primary(context),
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        prefixIcon: Icon(
          icon,
          color: _LoginPalette.primary(context),
          size: 20,
        ),
        suffixIcon: suffix,
        filled: true,
        fillColor: isDark
            ? const Color(0xFF173A44)
            : const Color(0xFFF8FAFA),
        labelStyle: TextStyle(
          color:
          _LoginPalette.secondaryText(context),
          fontWeight: FontWeight.w700,
        ),
        hintStyle: TextStyle(
          color: _LoginPalette.secondaryText(
            context,
          ).withValues(alpha: 0.76),
          fontWeight: FontWeight.w600,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 15,
        ),
        errorMaxLines: 3,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(17),
          borderSide: BorderSide(
            color: _LoginPalette.border(context),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(17),
          borderSide: BorderSide(
            color: _LoginPalette.border(context),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(17),
          borderSide: BorderSide(
            color: _LoginPalette.primary(context),
            width: 1.45,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(17),
          borderSide: BorderSide(
            color: _LoginPalette.danger(context),
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(17),
          borderSide: BorderSide(
            color: _LoginPalette.danger(context),
            width: 1.45,
          ),
        ),
      ),
    );
  }
}

class _LoginButton extends StatelessWidget {
  const _LoginButton({required this.loading, required this.onTap});

  final bool loading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: loading ? null : onTap,
          borderRadius: BorderRadius.circular(15),
          child: Ink(
            decoration: BoxDecoration(
              color: _LoginPalette.teal,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: _LoginPalette.teal.withValues(alpha: 0.22),
                  blurRadius: 16,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: Center(
              child: loading
                  ? const SizedBox(
                height: 21,
                width: 21,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
                  : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.login_rounded, color: Colors.white, size: 19),
                  SizedBox(width: 9),
                  Text(
                    'Sign In',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(width: 9),
                  Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RegisterPrompt extends StatelessWidget {
  const _RegisterPrompt({
    required this.onRegister,
  });

  final VoidCallback? onRegister;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 1),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 2,
        runSpacing: 2,
        children: [
          Text(
            'New to KuryentePay?',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: _LoginPalette.secondaryText(context),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          TextButton.icon(
            onPressed: onRegister,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 6,
              ),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            icon: const Icon(
              Icons.person_add_alt_1_rounded,
              size: 16,
            ),
            label: const Text(
              'Create Account',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SecurityFooter extends StatelessWidget {
  const _SecurityFooter();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.shield_outlined,
          size: 14,
          color: _LoginPalette.secondaryText(
            context,
          ),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            'Never share your password or payment verification details.',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(
              color:
              _LoginPalette.secondaryText(
                context,
              ),
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.borderRadius = 24,
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
        color: _LoginPalette.surface(context),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: _LoginPalette.border(context)),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.14)
                : _LoginPalette.navy.withValues(alpha: 0.055),
            blurRadius: 22,
            offset: const Offset(0, 10),
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
        BorderRadius.circular(size * 0.31),
        color: accent.withValues(alpha:
        isDark ? 0.13 : 0.075,
        ),
        border: Border.all(
          color: accent.withValues(alpha: 0.13),
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

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({
    required this.text,
  });

  final String text;

  @override
  Widget build(BuildContext context) {
    final Color error =
    _LoginPalette.danger(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: error.withValues(alpha: 0.075),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: error.withValues(alpha: 0.22),
        ),
      ),
      child: Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: error,
            size: 20,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(
                color: error,
                fontWeight: FontWeight.w800,
                height: 1.38,
              ),
            ),
          ),
        ],
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



