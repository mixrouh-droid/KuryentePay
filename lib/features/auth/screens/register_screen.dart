// REGISTRATION FINAL POLISH: cleaner copy, consistent capitalization, flatter review rows, preserved validation and approval flow
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/services/auth_service.dart';
import '../../../core/theme/app_theme.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  int _step = 0;

  final String _utility = 'Local Electric Cooperative';
  final String _province = 'Iloilo';

  bool _acceptedPolicy = false;
  bool _hidePass = true;
  bool _hideConfirm = true;
  bool _loading = false;
  bool _confirmedInformation = false;
  bool _meterUnknown = false;

  final _accountCtrl = TextEditingController();

  final _firstNameCtrl = TextEditingController();
  final _middleNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _nameExtCtrl = TextEditingController();

  final _houseStreetCtrl = TextEditingController();
  final _meterSerialCtrl = TextEditingController();
  String _selectedMunicipality = 'Estancia';
  String? _selectedBarangay;

  final _mobileCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  static const Map<String, List<String>> _municipalityBarangays = {
    'Ajuy': [
      'Adcadarao',
      'Agbobolo',
      'Badiangan',
      'Barrido',
      'Bato Biasong',
      'Bay-Ang',
      'Central',
      'Culasi',
      'Lanjagan',
      'Luca',
      'Malayu-an',
      'Mangorococoro',
      'Nasidman',
      'Pantalan Nabaye',
      'Pedada',
      'Pili',
      'Pinantan Diel',
      'Pinantan Elizalde',
      'Pinay Espinosa',
      'Poblacion',
      'Progreso',
      'Punta Buri',
      'San Antonio',
      'Sto. Rosario',
      'Tagubanhan',
      'Taguhangin',
      'Tanduyan',
      'Tipacla',
      'Tubogan',
      'Bucana Bunglas',
      'Rojas',
      'Puente Bunglas',
      'Silagon',
    ],
    'Anilao': [
      'Agbatuan',
      'Badiang',
      'Balabag',
      'Balunos',
      'Cag-An',
      'Camiros',
      'Danngula-an',
      'Guipis',
      'Manganese',
      'Medina',
      'Mostro',
      'Palaypay',
      'Pantalan',
      'Poblacion',
      'Sambag Culob',
      'San Carlos',
      'San Juan Crisostomo',
      'Sta. Rita',
      'Sto. Rosario',
      'Serallo',
      'Vista Alegre',
    ],
    'Balasan': [
      'Aranjuez',
      'Bacolod',
      'Balanti-an',
      'Batuan',
      'Cabalic',
      'Camambugan',
      'Dolores',
      'Gimamanay',
      'Ipil',
      'Kinalkalan',
      'Lawis',
      'Malapoc',
      'Mamhut Norte',
      'Mamhut Sur',
      'Maya',
      'Pani-an',
      'Poblacion Norte',
      'Tingui-an',
    ],
    'Banate': [
      'Merced',
      'Bariga',
      'Bobon',
      'Carmelo',
      'Dela Paz',
      'Juanico',
      'Magdalo',
      'Managopaya',
      'Libertad',
      'Alacaygan',
      'Belen',
      'Fuentes',
      'Dugwakan',
      'Poblacion',
      'Zana Zur',
      'Bularan',
      'San Salvador',
      'Talokgangan',
    ],
    'Barotac Viejo': [
      'Bugnay',
      'California',
      'Dela Peña',
      'La Fortuna',
      'Lipata',
      'San Antonio',
      'San Geronimo',
      'San Lucas',
      'San Miguel',
      'Ugasan',
      'Natividad',
      'Sto. Domingo',
      'Del Pilar',
      'Gen. Luna',
      'Nueva Invencion',
      'Nueva Sevilla',
      'Poblacion',
      'Puerto Princesa',
      'San Fernando',
      'San Francisco',
      'San Juan',
      'San Roque',
      'Santiago',
      'Sto. Tomas',
      'Vista Alegre',
    ],
    'Batad': [
      'Alapasco',
      'Alinsolong',
      'Banban',
      'Batad-Viejo',
      'Binon-an',
      'Bolhog',
      'Bulak Norte',
      'Bulak Sur',
      'Cabagohan',
      'Calangan',
      'Caw-I',
      'Drancalan',
      'Embarcadero',
      'Hamod',
      'Malico',
      'Nangka',
      'Pasayan',
      'Poblacion',
      'Quiasan Florte',
      'Quiasan Lopez',
      'Salong',
      'Santa Ana',
      'Tanao',
      'Tapi-an',
    ],
    'Carles': [
      'Abong',
      'Bancal',
      'Barosbos',
      'Bolo',
      'Cabilao Grande',
      'Cabilao Pequeño',
      'Cabaguana',
      'Cawayan',
      'Dayhagan',
      'Guinticgan',
      'Poblacion',
      'Tarong',
      'Tupaz',
      'Binuluangan',
      'Pantalan',
      'Tabugon',
    ],
    'Concepcion': [
      'Calamigan',
      'Aglosong',
      'Bacjawan Norte',
      'Agnaga',
      'Bacjawan Sur',
      'Batiti',
      'Igbon',
      'Jamul-awon',
      'Lo-ong',
      'Macalbang',
      'Nino',
      'Nipa',
      'Plandico',
      'Poblacion',
      'Tamis-ac',
    ],
    'Estancia': [
      'Malbog',
      'Calapdan',
      'Daan Banwa',
      'Jolog',
      'Lumbia',
      'Lonoy',
      'Sta. Ana',
      'Tanza',
      'Botongon',
      'Pob. Zone 1',
      'Pob. Zone 2',
      'Pob. Zone 3',
      'Bayuyan',
      'Bulaqueña',
      'Cano-an',
      'Daculan',
      'Gogo',
      'Loguingot',
      'Pa-on',
      'San Roque',
      'Tabuan',
      'Tacbuyan',
      'Villa Pani-an',
    ],
    'Lemery': [
      'Agpipili',
      'Alcantara',
      'Almeñana',
      'Anabo',
      'Bankal',
      'Buenavista',
      'Cabantohan',
      'Capinahan',
      'Dalipe',
      'Dapdapan',
      'Gerongan',
      'Imbaulan',
      'Layog Bato',
      'Marapal',
      'Milan',
      'Nagsulang',
      'Nasapahan',
      'Omio',
      'Pacuan',
      'Pob. Northwest Zone',
      'Pob. Southeast Zone',
      'Pontoc',
      'San Antonio',
      'San Diego',
      'San Jose',
      'Sepanton',
      'Sincua',
      'Tabunan',
      'Tugas',
      'Velasco',
      'Yawyawan',
    ],
    'San Dionisio': [
      'Agdaliran',
      'Amayaong',
      'Bagacay',
      'Batuan',
      'Bondulan',
      'Borongon',
      'Canas',
      'Cubay',
      'Cudionan',
      'Dugman',
      'Had. Conchita',
      'Madanlog',
      'Manduawak',
      'Moto',
      'Nipa',
      'Odiongan',
      'Pangi',
      'Pase',
      'Poblacion',
      'San Nicolas',
      'Santos',
      'Siempreviva',
      'Sua',
      'Tamangi',
      'Tiabas',
      'Tuble',
    ],
    'San Rafael': [
      'Aripdip',
      'Bagay',
      'Calaigang',
      'Ilongbukid',
      'Poblacion',
      'Poscolon',
      'San Andres',
      'San Dionisio',
      'San Florentino',
    ],
    'Sara': [
      'Alibayog',
      'Apelo',
      'Arante',
      'Bagaygay',
      'Improgo',
      'Labigan',
      'Preciosa',
      'San Luis',
      'Tentay',
      'Villa Hermosa',
      'Apologista',
      'Bakabak',
      'Crespo',
      'Ferraris',
      'Gildore',
      'Lanciola',
      'Padios',
      'Pob. Ilawod',
      'Salcedo',
      'Zerrudo',
      'Antonio Yusay/Pasig',
      'Aspera',
      'Ardemil',
      'Bato',
      'Del Castillo',
      'Domingo',
      'Juaneza',
      'Latawan',
      'Malapaya',
      'Muyco',
      'Pob. Ilaya',
      'Pob. Market Tady',
      'Anoring',
      'Aldeguer',
      'Aposaga',
      'Castor',
      'Devera',
      'Pabriaga',
      'Posadas',
      'Batitao',
    ],
  };

  @override
  void dispose() {
    _accountCtrl.dispose();
    _firstNameCtrl.dispose();
    _middleNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _nameExtCtrl.dispose();
    _houseStreetCtrl.dispose();
    _meterSerialCtrl.dispose();
    _mobileCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  String _stepTitle(int i) {
    switch (i) {
      case 0:
        return 'Account';
      case 1:
        return 'Terms';
      case 2:
        return 'Personal Info';
      case 3:
        return 'Address';
      case 4:
        return 'Security';
      case 5:
        return 'Review';
      default:
        return '';
    }
  }

  String _buildFullName() {
    final parts = <String>[
      _firstNameCtrl.text.trim(),
      _middleNameCtrl.text.trim(),
      _lastNameCtrl.text.trim(),
      _nameExtCtrl.text.trim(),
    ].where((e) => e.isNotEmpty).toList();

    return parts.join(' ');
  }

  String _buildFullAddress() {
    final parts = <String>[
      _houseStreetCtrl.text.trim(),
      _selectedBarangay ?? '',
      _selectedMunicipality,
      _province,
    ].where((e) => e.isNotEmpty).toList();

    return parts.join(', ');
  }

  bool _hasNumber(String value) => RegExp(r'\d').hasMatch(value);

  bool _hasLetter(String value) => RegExp(r'[A-Za-z]').hasMatch(value);

  bool _passwordStrongEnough() {
    final String pass = _passCtrl.text;
    return pass.length >= 8 && _hasNumber(pass) && _hasLetter(pass);
  }

  String _friendlyRegistrationError(Object error) {
    final raw = error.toString().replaceFirst('Exception: ', '').trim();
    final lower = raw.toLowerCase();

    if (lower.contains('already') ||
        lower.contains('duplicate') ||
        lower.contains('exists')) {
      return 'This account number may already be registered. Please check the number or contact the KuryentePay system administrator.';
    }

    if (lower.contains('socket') ||
        lower.contains('network') ||
        lower.contains('connection') ||
        lower.contains('timeout') ||
        lower.contains('failed host lookup')) {
      return 'Unable to connect to KuryentePay. Check your internet connection and try again.';
    }

    if (lower.contains('account') && lower.contains('not found')) {
      return 'The account number could not be verified. Please check the number printed on the electric bill.';
    }

    return 'Registration could not be submitted. '
        'Please review your information and try again.';
  }

  bool _canContinue() {
    switch (_step) {
      case 0:
        return RegExp(r'^\d{10}$').hasMatch(_accountCtrl.text.trim());
      case 1:
        return _acceptedPolicy;
      case 2:
        return _firstNameCtrl.text.trim().isNotEmpty &&
            _middleNameCtrl.text.trim().isNotEmpty &&
            _lastNameCtrl.text.trim().isNotEmpty;
      case 3:
        return _houseStreetCtrl.text.trim().isNotEmpty &&
            (_selectedBarangay?.trim().isNotEmpty ?? false) &&
            _selectedMunicipality.trim().isNotEmpty;
      case 4:
        final bool mobOk =
        RegExp(r'^09\d{9}$').hasMatch(_mobileCtrl.text.trim());
        final bool match = _passCtrl.text == _confirmCtrl.text;
        return mobOk && _passwordStrongEnough() && match;
      case 5:
        return _confirmedInformation;
      default:
        return false;
    }
  }

  Future<void> _finishRegistration() async {
    FocusScope.of(context).unfocus();

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Submit Registration Request?'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Check your information before submitting. '
                      'You can sign in with this account number after approval.',
                ),
                const SizedBox(height: 14),
                _DialogReviewRow(
                  label: 'Account Number',
                  value: _accountCtrl.text.trim(),
                ),
                const SizedBox(height: 4),
                const Text(
                  'PERSONAL INFORMATION',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                _DialogReviewRow(
                  label: 'First Name',
                  value: _firstNameCtrl.text.trim(),
                ),
                _DialogReviewRow(
                  label: 'Middle Name',
                  value: _middleNameCtrl.text.trim(),
                ),
                _DialogReviewRow(
                  label: 'Last Name',
                  value: _lastNameCtrl.text.trim(),
                ),
                _DialogReviewRow(
                  label: 'Name Extension',
                  value: _nameExtCtrl.text.trim(),
                ),
                const SizedBox(height: 4),
                const Text(
                  'SERVICE ADDRESS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                _DialogReviewRow(
                  label: 'Municipality',
                  value: _selectedMunicipality,
                ),
                _DialogReviewRow(
                  label: 'Barangay',
                  value: _selectedBarangay ?? '',
                ),
                _DialogReviewRow(
                  label: 'House / Street',
                  value: _houseStreetCtrl.text.trim(),
                ),
                _DialogReviewRow(
                  label: 'Province',
                  value: _province,
                ),
                _DialogReviewRow(
                  label: 'Meter S/N (Unverified)',
                  value: _meterUnknown || _meterSerialCtrl.text.trim().isEmpty
                      ? 'Not provided - Admin will verify/assign'
                      : _meterSerialCtrl.text.trim(),
                ),
                const SizedBox(height: 4),
                const Text(
                  'CONTACT',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                _DialogReviewRow(
                  label: 'Mobile Number',
                  value: _mobileCtrl.text.trim(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Go Back'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Submit Request'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() => _loading = true);

    try {
      await AuthService.register(
        accountNo: _accountCtrl.text.trim(),
        name: _buildFullName(),
        address: _buildFullAddress(),
        phone: _mobileCtrl.text.trim(),
        password: _passCtrl.text,
        firstName: _firstNameCtrl.text.trim(),
        middleName: _middleNameCtrl.text.trim(),
        lastName: _lastNameCtrl.text.trim(),
        nameExtension: _nameExtCtrl.text.trim(),
        houseStreet: _houseStreetCtrl.text.trim(),
        barangay: _selectedBarangay?.trim(),
        municipality: _selectedMunicipality.trim(),
        province: _province.trim(),
        meterSerialNo: _meterUnknown ? null : _meterSerialCtrl.text.trim(),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Registration submitted. Your account will remain pending until it is approved.',
          ),
        ),
      );

      Navigator.of(context).pop(_accountCtrl.text.trim());
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyRegistrationError(e))),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _next() {
    if (_step < 5) setState(() => _step++);
  }

  void _back() {
    if (_step > 0) {
      setState(() {
        if (_step == 5) _confirmedInformation = false;
        _step--;
      });
    }
  }

  void _showAccountNumberGuide() {
    FocusScope.of(context).unfocus();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        final double safeBottom =
            MediaQuery.of(sheetContext).padding.bottom;

        return Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            0,
            16,
            safeBottom + 16,
          ),
          child: _GlassPanel(
            padding: const EdgeInsets.fromLTRB(
              16,
              12,
              16,
              16,
            ),
            borderRadius: 30,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: _RegisterTones.border(sheetContext),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _IconTile(
                      icon: Icons.receipt_long_rounded,
                      accent: _RegisterTones.brand(sheetContext),
                      size: 48,
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
                              color: _RegisterTones.title(sheetContext),
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Use the 10-digit Account Number shown on your electricity bill.',
                            style: Theme.of(sheetContext)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                              color: _RegisterTones.secondaryText(
                                sheetContext,
                              ),
                              fontWeight: FontWeight.w700,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                const _AccountNumberGuideStep(
                  number: '1',
                  title: 'Open Your Electricity Bill',
                  message:
                  'Use your printed bill or a clear digital copy.',
                ),
                const SizedBox(height: 9),
                const _AccountNumberGuideStep(
                  number: '2',
                  title: 'Find “Account Number”',
                  message:
                  'Look for the Account Number in the consumer or service details.',
                ),
                const SizedBox(height: 9),
                const _AccountNumberGuideStep(
                  number: '3',
                  title: 'Enter All 10 Digits',
                  message:
                  'Enter the number exactly as shown.',
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: _RegisterTones.warning(sheetContext)
                        .withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _RegisterTones.warning(sheetContext)
                          .withValues(alpha: 0.22),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: _RegisterTones.warning(sheetContext),
                        size: 20,
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          'Do not use the bill number, meter serial number, or payment reference.',
                          style: Theme.of(sheetContext)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                            color: _RegisterTones.title(sheetContext),
                            fontWeight: FontWeight.w700,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 15),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    child: const Text(
                      'Close',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _RegisterTones.background(context),
      body: Stack(
        children: [
          const _RegisterBackground(),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                  child: _HeroHeader(
                    step: _step,
                    totalSteps: 6,
                    title: _stepTitle(_step),
                  ),
                ),
                Expanded(
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    padding: const EdgeInsets.fromLTRB(16, 2, 16, 12),
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        child: KeyedSubtree(
                          key: ValueKey(_step),
                          child: switch (_step) {
                            0 => _stepAccountNumber(context),
                            1 => _stepPolicy(context),
                            2 => _stepProfile(context),
                            3 => _stepAddress(context),
                            4 => _stepSecurity(context),
                            5 => _stepComplete(context),
                            _ => const SizedBox.shrink(),
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                _BottomButtons(
                  loading: _loading,
                  canContinue: _canContinue(),
                  isFirst: _step == 0,
                  isLast: _step == 5,
                  onBack: _loading
                      ? null
                      : (_step == 0
                      ? () => Navigator.of(context).pop()
                      : _back),
                  onNext: (!_canContinue() || _loading)
                      ? null
                      : () async {
                    if (_step == 5) {
                      await _finishRegistration();
                    } else {
                      _next();
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepAccountNumber(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(
          title: 'Account Number',
          subtitle: 'Step 1',
        ),
        const SizedBox(height: 8),
        _GlassPanel(
          padding: const EdgeInsets.all(14),
          borderRadius: 26,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PanelTitle(
                icon: Icons.badge_rounded,
                title: 'Enter Your Account Number',
                subtitle:
                'Use the 10-digit number shown on your electricity bill.',
                accent: _RegisterTones.brand(context),
              ),
              const SizedBox(height: 14),
              _field(
                label: 'Account Number',
                controller: _accountCtrl,
                icon: Icons.numbers_rounded,
                hint: '1010060241',
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
              ),
              const SizedBox(height: 10),
              _AccountNumberBillReminder(
                onHelp: _showAccountNumberGuide,
              ),
              const SizedBox(height: 12),
              _UtilityAutoCard(utility: _utility),
            ],
          ),
        ),
      ],
    );
  }

  Widget _stepPolicy(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(
          title: 'Privacy & Terms',
          subtitle: 'Required',
        ),
        const SizedBox(height: 8),
        _GlassPanel(
          padding: const EdgeInsets.all(14),
          borderRadius: 26,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PanelTitle(
                icon: Icons.privacy_tip_rounded,
                title: 'Review and Accept',
                subtitle:
                'Review how your information is used before continuing.',
                accent: _RegisterTones.warning(context),
              ),
              const SizedBox(height: 14),
              _PolicyBox(),
              const SizedBox(height: 12),
              InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => setState(() => _acceptedPolicy = !_acceptedPolicy),
                child: Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    color: Colors.black.withValues(alpha:
                    Theme.of(context).brightness == Brightness.dark
                        ? 0.12
                        : 0.035,
                    ),
                    border: Border.all(
                      color: _acceptedPolicy
                          ? _RegisterTones.success(context).withValues(alpha: 0.28)
                          : _RegisterTones.border(context),
                    ),
                  ),
                  child: Row(
                    children: [
                      Checkbox(
                        value: _acceptedPolicy,
                        onChanged: (v) =>
                            setState(() => _acceptedPolicy = v ?? false),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'I accept the Policy, Privacy, and Terms.',
                          style:
                          Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: _RegisterTones.title(context),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _stepProfile(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(
          title: 'Personal Information',
          subtitle: 'Consumer Details',
        ),
        const SizedBox(height: 8),
        _GlassPanel(
          padding: const EdgeInsets.all(14),
          borderRadius: 26,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PanelTitle(
                icon: Icons.person_rounded,
                title: 'Complete Name',
                subtitle:
                'First, middle, and last names are required. Name extension is optional.',
                accent: _RegisterTones.brand(context),
              ),
              const SizedBox(height: 12),
              _field(
                label: 'First Name',
                controller: _firstNameCtrl,
                icon: Icons.person_outline_rounded,
                hint: 'Juan',
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 12),
              _field(
                label: 'Middle Name',
                controller: _middleNameCtrl,
                icon: Icons.person_outline_rounded,
                hint: 'Santos',
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 12),
              _field(
                label: 'Last Name',
                controller: _lastNameCtrl,
                icon: Icons.person_outline_rounded,
                hint: 'Dela Cruz',
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 12),
              _field(
                label: 'Name Extension (Optional)',
                controller: _nameExtCtrl,
                icon: Icons.badge_outlined,
                hint: 'Jr., Sr., III',
                textCapitalization: TextCapitalization.words,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _stepAddress(BuildContext context) {
    final barangays = _municipalityBarangays[_selectedMunicipality] ?? const [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(
          title: 'Service Address',
          subtitle: 'Location',
        ),
        const SizedBox(height: 8),
        _GlassPanel(
          padding: const EdgeInsets.all(14),
          borderRadius: 26,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PanelTitle(
                icon: Icons.location_on_rounded,
                title: 'Service Location',
                subtitle:
                'Select your municipality and barangay, then enter your house or street details.',
                accent: _RegisterTones.success(context),
              ),
              const SizedBox(height: 12),
              _MunicipalityDropdown(
                value: _selectedMunicipality,
                items: _municipalityBarangays.keys.toList()..sort(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _selectedMunicipality = value;
                    _selectedBarangay = null;
                    _confirmedInformation = false;
                  });
                },
              ),
              const SizedBox(height: 12),
              _BarangayDropdown(
                key: ValueKey<String>(
                  'barangay-$_selectedMunicipality-${_selectedBarangay ?? 'none'}',
                ),
                value: _selectedBarangay,
                items: barangays,
                onChanged: (value) {
                  setState(() {
                    _selectedBarangay = value;
                    _confirmedInformation = false;
                  });
                },
              ),
              const SizedBox(height: 12),
              _field(
                label: 'House No. / Street / Purok',
                controller: _houseStreetCtrl,
                icon: Icons.home_outlined,
                hint: 'Purok 3, Rizal St.',
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 12),
              _ProvinceAutoCard(province: _province),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _GlassPanel(
          padding: const EdgeInsets.all(14),
          borderRadius: 26,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PanelTitle(
                icon: Icons.confirmation_number_outlined,
                title: 'Meter S/N (Optional)',
                subtitle: 'Meter Serial Number',
                accent: _RegisterTones.brand(context),
              ),
              const SizedBox(height: 12),
              if (!_meterUnknown) ...[
                _field(
                  label: 'Meter S/N (Optional)',
                  controller: _meterSerialCtrl,
                  icon: Icons.tag_outlined,
                  hint: 'Enter the serial number on your bill',
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(50),
                    FilteringTextInputFormatter.deny(RegExp(r'[\r\n\t]')),
                  ],
                  onChanged: (_) => setState(() {
                    _confirmedInformation = false;
                  }),
                ),
                const SizedBox(height: 10),
              ],
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: _RegisterTones.brand(context),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'You can find your Meter S/N on your existing electric bill. '
                          'If you do not know it, you can leave this field blank.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: _RegisterTones.secondaryText(context),
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                dense: true,
                activeColor: _RegisterTones.brand(context),
                title: Text(
                  'I don\'t know my Meter S/N',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: _RegisterTones.title(context),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                value: _meterUnknown,
                onChanged: (value) {
                  FocusScope.of(context).unfocus();
                  setState(() {
                    _meterUnknown = value ?? false;
                    if (_meterUnknown) _meterSerialCtrl.clear();
                    _confirmedInformation = false;
                  });
                },
              ),
              Text(
                'The System Administrator will verify or assign your '
                    'Meter S/N before billing.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: _RegisterTones.secondaryText(context),
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _stepSecurity(BuildContext context) {
    final pass = _passCtrl.text;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(
          title: 'Contact & Password',
          subtitle: 'Security',
        ),
        const SizedBox(height: 8),
        _GlassPanel(
          padding: const EdgeInsets.all(14),
          borderRadius: 26,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PanelTitle(
                icon: Icons.lock_rounded,
                title: 'Account Security',
                subtitle: 'Add your mobile number and create a secure password.',
                accent: _RegisterTones.brand(context),
              ),
              const SizedBox(height: 12),
              _field(
                label: 'Mobile Number',
                controller: _mobileCtrl,
                icon: Icons.phone_rounded,
                hint: '09XXXXXXXXX',
                keyboardType: TextInputType.phone,
                autofillHints: const <String>[
                  AutofillHints.telephoneNumber,
                ],
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(11),
                ],
              ),
              const SizedBox(height: 12),
              _field(
                label: 'Password',
                controller: _passCtrl,
                icon: Icons.lock_outline_rounded,
                hint: 'Minimum 8 characters',
                obscure: _hidePass,
                autofillHints: const <String>[
                  AutofillHints.newPassword,
                ],
                onChanged: (_) => setState(() {}),
                suffix: IconButton(
                  onPressed: () => setState(() => _hidePass = !_hidePass),
                  icon: Icon(
                    _hidePass
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              _PasswordStrengthChecklist(
                hasLength: pass.length >= 8,
                hasNumber: _hasNumber(pass),
                hasLetter: _hasLetter(pass),
              ),
              const SizedBox(height: 12),
              _field(
                label: 'Confirm Password',
                controller: _confirmCtrl,
                icon: Icons.lock_reset_rounded,
                hint: 'Re-type password',
                obscure: _hideConfirm,
                autofillHints: const <String>[
                  AutofillHints.newPassword,
                ],
                onChanged: (_) => setState(() {}),
                suffix: IconButton(
                  onPressed: () => setState(() => _hideConfirm = !_hideConfirm),
                  icon: Icon(
                    _hideConfirm
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                  ),
                ),
              ),
              if (_confirmCtrl.text.isNotEmpty) ...[
                const SizedBox(height: 8),
                _PasswordMatchHint(
                  matches: _passCtrl.text == _confirmCtrl.text,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _stepComplete(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(
          title: 'Final Review',
          subtitle: 'Check Details',
        ),
        const SizedBox(height: 8),
        _GlassPanel(
          padding: const EdgeInsets.all(16),
          borderRadius: 26,
          child: Column(
            children: [
              Container(
                height: 62,
                width: 62,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      _RegisterTones.success(context).withValues(alpha: 0.20),
                      _RegisterTones.brand(context).withValues(alpha: 0.12),
                    ],
                  ),
                  border: Border.all(
                    color: _RegisterTones.success(context).withValues(alpha: 0.24),
                  ),
                ),
                child: Icon(
                  Icons.check_circle_rounded,
                  color: _RegisterTones.success(context),
                  size: 36,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Review Your Information',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: _RegisterTones.title(context),
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              const _ApprovalNotice(),
              const SizedBox(height: 4),
              _ReviewRow(label: 'Utility', value: _utility),
              _ReviewRow(
                label: 'Account Number',
                value: _accountCtrl.text.trim(),
              ),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'PERSONAL INFORMATION',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: _RegisterTones.secondaryText(context),
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              _ReviewRow(
                label: 'First Name',
                value: _firstNameCtrl.text.trim(),
              ),
              _ReviewRow(
                label: 'Middle Name',
                value: _middleNameCtrl.text.trim(),
              ),
              _ReviewRow(
                label: 'Last Name',
                value: _lastNameCtrl.text.trim(),
              ),
              _ReviewRow(
                label: 'Name Extension',
                value: _nameExtCtrl.text.trim(),
              ),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'SERVICE ADDRESS',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: _RegisterTones.secondaryText(context),
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              _ReviewRow(
                label: 'Municipality',
                value: _selectedMunicipality,
              ),
              _ReviewRow(
                label: 'Barangay',
                value: _selectedBarangay ?? '',
              ),
              _ReviewRow(
                label: 'House / Street',
                value: _houseStreetCtrl.text.trim(),
              ),
              _ReviewRow(label: 'Province', value: _province),
              _ReviewRow(
                label: 'Meter S/N (Unverified)',
                value: _meterUnknown || _meterSerialCtrl.text.trim().isEmpty
                    ? 'Not provided - Admin will verify/assign'
                    : _meterSerialCtrl.text.trim(),
              ),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'CONTACT',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: _RegisterTones.secondaryText(context),
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              _ReviewRow(
                label: 'Mobile Number',
                value: _mobileCtrl.text.trim(),
              ),
              const SizedBox(height: 12),
              _InformationConfirmation(
                value: _confirmedInformation,
                onChanged: (value) {
                  setState(() => _confirmedInformation = value);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _field({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    bool obscure = false,
    Widget? suffix,
    List<TextInputFormatter>? inputFormatters,
    ValueChanged<String>? onChanged,
    TextCapitalization textCapitalization = TextCapitalization.none,
    Iterable<String>? autofillHints,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
      enableSuggestions: !obscure,
      autocorrect: !obscure,
      textCapitalization: textCapitalization,
      autofillHints: autofillHints,
      inputFormatters: inputFormatters,
      onChanged: (value) {
        onChanged?.call(value);
        if (onChanged == null) setState(() {});
      },
      style: TextStyle(
        color: _RegisterTones.title(context),
        fontWeight: FontWeight.w800,
        fontSize: 13,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: _RegisterTones.brand(context)),
        suffixIcon: suffix,
        filled: true,
        fillColor:
        isDark ? const Color(0xFF173A44) : const Color(0xFFF8FAFA),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: _RegisterTones.border(context)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: _RegisterTones.border(context)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: _RegisterTones.brand(context),
            width: 1.4,
          ),
        ),
      ),
    );
  }
}

class _AccountNumberBillReminder extends StatelessWidget {
  const _AccountNumberBillReminder({
    required this.onHelp,
  });

  final VoidCallback onHelp;

  @override
  Widget build(BuildContext context) {
    final Color accent = _RegisterTones.info(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(11, 9, 7, 9),
      decoration: BoxDecoration(
        color: accent.withValues(alpha:
        Theme.of(context).brightness == Brightness.dark ? 0.13 : 0.07,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accent.withValues(alpha: 0.20),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.receipt_long_outlined,
            color: accent,
            size: 19,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              'Use the 10-digit account number on your electricity bill.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: _RegisterTones.title(context),
                fontWeight: FontWeight.w700,
                height: 1.30,
              ),
            ),
          ),
          TextButton(
            onPressed: onHelp,
            child: const Text(
              'Find It',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountNumberGuideStep extends StatelessWidget {
  const _AccountNumberGuideStep({
    required this.number,
    required this.title,
    required this.message,
  });

  final String number;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final Color accent = _RegisterTones.brand(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 30,
          width: 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: accent.withValues(alpha: 0.12),
            border: Border.all(
              color: accent.withValues(alpha: 0.22),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            number,
            style: TextStyle(
              color: accent,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: _RegisterTones.title(context),
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                message,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: _RegisterTones.secondaryText(context),
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

class _RegisterTones {
  // Matches the KuryentePay Login and shared mobile design system.
  static const Color navy = Color(0xFF102F3E);
  static const Color teal = Color(0xFF087F79);
  static const Color gold = Color(0xFFF6D483);

  static bool _isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color background(BuildContext context) =>
      _isDark(context) ? const Color(0xFF0B1E28) : const Color(0xFFF4F7FA);

  static Color brand(BuildContext context) =>
      _isDark(context) ? const Color(0xFF8CE5D5) : teal;

  static Color info(BuildContext context) =>
      _isDark(context) ? const Color(0xFF8CE5D5) : teal;

  static Color success(BuildContext context) =>
      _isDark(context) ? const Color(0xFF8CE5D5) : const Color(0xFF177F5B);

  static Color warning(BuildContext context) =>
      _isDark(context) ? gold : const Color(0xFF9D741A);

  static Color title(BuildContext context) =>
      _isDark(context) ? const Color(0xFFF4FAFA) : const Color(0xFF173347);

  static Color secondaryText(BuildContext context) =>
      _isDark(context) ? const Color(0xFFCCDFE0) : const Color(0xFF526A75);

  static Color panelTop(BuildContext context) =>
      _isDark(context) ? const Color(0xFF122F3A) : Colors.white;

  static Color panelBottom(BuildContext context) =>
      _isDark(context) ? const Color(0xFF122F3A) : Colors.white;

  static Color border(BuildContext context) =>
      _isDark(context) ? const Color(0xFF315760) : const Color(0xFFDCE6EA);
}

class _RegisterBackground extends StatelessWidget {
  const _RegisterBackground();

  @override
  Widget build(BuildContext context) {
    // Flat, calm background: no competing glow layers behind form fields.
    return IgnorePointer(
      child: SizedBox.expand(
        child: ColoredBox(color: _RegisterTones.background(context)),
      ),
    );
  }
}

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({
    required this.step,
    required this.totalSteps,
    required this.title,
  });

  final int step;
  final int totalSteps;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 17, 18, 17),
      decoration: BoxDecoration(
        color: _RegisterTones.navy,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF2B565E)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF1B645F),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: const Color(0xFF4B8C83)),
                ),
                child: const Icon(
                  Icons.bolt_rounded,
                  size: 25,
                  color: _RegisterTones.gold,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'KuryentePay',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.11),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Text(
                  'Registration',
                  style: TextStyle(
                    color: Color(0xFFD6EFEB),
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Create an Account',
            style: TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.w800,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Step ${step + 1} of $totalSteps  ·  $title',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFFCADFE0),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 13),
          Row(
            children: List.generate(totalSteps, (index) {
              final bool completed = index <= step;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: index == totalSteps - 1 ? 0 : 5,
                  ),
                  child: Container(
                    height: 5,
                    decoration: BoxDecoration(
                      color: completed
                          ? const Color(0xFF8CE5D5)
                          : Colors.white.withValues(alpha: 0.19),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _UtilityAutoCard extends StatelessWidget {
  const _UtilityAutoCard({required this.utility});

  final String utility;

  @override
  Widget build(BuildContext context) {
    return _SoftInfoBox(
      icon: Icons.electric_bolt_rounded,
      title: utility,
      subtitle: 'Auto-selected',
      accent: _RegisterTones.info(context),
    );
  }
}

class _ProvinceAutoCard extends StatelessWidget {
  const _ProvinceAutoCard({required this.province});

  final String province;

  @override
  Widget build(BuildContext context) {
    return _SoftInfoBox(
      icon: Icons.map_rounded,
      title: province,
      subtitle: 'Auto-selected',
      accent: _RegisterTones.info(context),
    );
  }
}

class _SoftInfoBox extends StatelessWidget {
  const _SoftInfoBox({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      child: Row(
        children: [
          Icon(icon, color: accent, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$title • $subtitle',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: _RegisterTones.secondaryText(context),
                fontWeight: FontWeight.w700,
                height: 1.30,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.check_circle_rounded, color: accent, size: 18),
        ],
      ),
    );
  }
}

class _PolicyBox extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.black.withValues(alpha:
        Theme.of(context).brightness == Brightness.dark ? 0.12 : 0.035,
        ),
        border: Border.all(color: _RegisterTones.border(context)),
      ),
      child: Text(
        'By continuing, you allow KuryentePay to use the information you provide for account verification, billing access, payment status, notifications, and support. Never share your password, PIN, OTP, or banking credentials.',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: _RegisterTones.secondaryText(context),
          fontWeight: FontWeight.w700,
          height: 1.35,
        ),
      ),
    );
  }
}

class _MunicipalityDropdown extends StatelessWidget {
  const _MunicipalityDropdown({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return _CompactLocationPicker(
      key: ValueKey<String>('municipality-$value'),
      label: 'Municipality',
      hint: 'Select municipality',
      icon: Icons.location_city_rounded,
      value: value,
      items: items,
      onChanged: onChanged,
    );
  }
}

class _BarangayDropdown extends StatelessWidget {
  const _BarangayDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return _CompactLocationPicker(
      key: ValueKey<String>(
        'barangay-${items.length}-${items.isEmpty ? 'empty' : items.first}-${value ?? 'none'}',
      ),
      label: 'Barangay',
      hint: 'Select your barangay',
      icon: Icons.place_outlined,
      value: value,
      items: items,
      onChanged: onChanged,
    );
  }
}

class _CompactLocationPicker extends StatelessWidget {
  const _CompactLocationPicker({
    super.key,
    required this.label,
    required this.hint,
    required this.icon,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final String hint;
  final IconData icon;
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  Future<String?> _showPickerDialog(BuildContext context) {
    String query = '';

    return showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (
              BuildContext stateContext,
              void Function(void Function()) setDialogState,
              ) {
            final String normalisedQuery = query.trim().toLowerCase();
            final List<String> visibleItems = normalisedQuery.isEmpty
                ? List<String>.unmodifiable(items)
                : items
                .where(
                  (String item) =>
                  item.toLowerCase().contains(normalisedQuery),
            )
                .toList(growable: false);

            final String? selectedValue =
            value != null && items.contains(value) ? value : null;
            final double maxDialogHeight =
            (MediaQuery.sizeOf(dialogContext).height * 0.58)
                .clamp(300.0, 500.0)
                .toDouble();
            final bool showSearch = items.length > 10;

            return Dialog(
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 32,
              ),
              backgroundColor: _RegisterTones.panelTop(dialogContext),
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
                side: BorderSide(
                  color: _RegisterTones.border(dialogContext),
                ),
              ),
              child: SizedBox(
                width: 420,
                height: maxDialogHeight,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
                      child: Row(
                        children: [
                          Container(
                            height: 34,
                            width: 34,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(11),
                              color: _RegisterTones.brand(dialogContext)
                                  .withValues(alpha: 0.10),
                            ),
                            child: Icon(
                              icon,
                              size: 18,
                              color: _RegisterTones.brand(dialogContext),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Select $label',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: _RegisterTones.title(dialogContext),
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Close',
                            visualDensity: VisualDensity.compact,
                            onPressed: () =>
                                Navigator.of(dialogContext).pop(),
                            icon: Icon(
                              Icons.close_rounded,
                              size: 20,
                              color:
                              _RegisterTones.secondaryText(dialogContext),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (showSearch)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                        child: TextField(
                          autofocus: false,
                          textInputAction: TextInputAction.search,
                          style: TextStyle(
                            color: _RegisterTones.title(dialogContext),
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: 'Search $label',
                            hintStyle: TextStyle(
                              color: _RegisterTones.secondaryText(
                                dialogContext,
                              ),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                            prefixIcon: Icon(
                              Icons.search_rounded,
                              size: 19,
                              color: _RegisterTones.secondaryText(
                                dialogContext,
                              ),
                            ),
                            filled: true,
                            fillColor:
                            Theme.of(dialogContext).brightness ==
                                Brightness.dark
                                ? Colors.white.withValues(alpha: 0.04)
                                : const Color(0xFFF8FAFA),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: _RegisterTones.border(dialogContext),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: _RegisterTones.border(dialogContext),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: _RegisterTones.brand(dialogContext),
                                width: 1.2,
                              ),
                            ),
                          ),
                          onChanged: (String newValue) {
                            setDialogState(() => query = newValue);
                          },
                        ),
                      ),
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: _RegisterTones.border(dialogContext),
                    ),
                    Expanded(
                      child: visibleItems.isEmpty
                          ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'No matching $label found.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _RegisterTones.secondaryText(
                                dialogContext,
                              ),
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      )
                          : ListView.separated(
                        keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        itemCount: visibleItems.length,
                        separatorBuilder: (_, __) => Divider(
                          height: 1,
                          thickness: 0.7,
                          indent: 14,
                          endIndent: 14,
                          color: _RegisterTones.border(dialogContext)
                              .withValues(alpha: 0.65),
                        ),
                        itemBuilder: (
                            BuildContext itemContext,
                            int index,
                            ) {
                          final String item = visibleItems[index];
                          final bool selected = item == selectedValue;

                          return ListTile(
                            dense: true,
                            visualDensity: const VisualDensity(
                              horizontal: -2,
                              vertical: -2,
                            ),
                            minVerticalPadding: 4,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                            ),
                            title: Text(
                              item,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: selected
                                    ? _RegisterTones.brand(dialogContext)
                                    : _RegisterTones.title(dialogContext),
                                fontSize: 13,
                                height: 1.15,
                                fontWeight: selected
                                    ? FontWeight.w900
                                    : FontWeight.w700,
                              ),
                            ),
                            trailing: selected
                                ? Icon(
                              Icons.check_circle_rounded,
                              size: 19,
                              color: _RegisterTones.brand(
                                dialogContext,
                              ),
                            )
                                : null,
                            onTap: () =>
                                Navigator.of(dialogContext).pop(item),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final bool enabled = items.isNotEmpty;
    final bool hasValidValue =
        value != null && value!.trim().isNotEmpty && items.contains(value);
    final String displayedValue = hasValidValue ? value! : hint;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: !enabled
          ? null
          : () async {
        FocusScope.of(context).unfocus();
        final String? selected = await _showPickerDialog(context);
        if (!context.mounted) return;

        if (selected != null && selected != value) {
          onChanged(selected);
        }
      },
      child: InputDecorator(
        // Keep the field label floated above the value/hint at all times.
        // When isEmpty was true, Flutter painted the inline label ("Barangay")
        // in the same space as our manual hint ("Select your barangay"),
        // which caused the overlapping text seen on the Address step.
        isEmpty: false,
        decoration: InputDecoration(
          labelText: label,
          floatingLabelBehavior: FloatingLabelBehavior.always,
          prefixIcon: Icon(
            icon,
            color: enabled
                ? _RegisterTones.brand(context)
                : _RegisterTones.secondaryText(context),
          ),
          suffixIcon: Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 22,
            color: _RegisterTones.secondaryText(context),
          ),
          filled: true,
          fillColor: isDark
              ? Colors.white.withValues(alpha: 0.04)
              : const Color(0xFFF8FAFA),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(
              color: _RegisterTones.border(context),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(
              color: _RegisterTones.border(context),
            ),
          ),
        ),
        child: Text(
          displayedValue,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: hasValidValue
                ? _RegisterTones.title(context)
                : _RegisterTones.secondaryText(context),
            fontSize: 13,
            fontWeight: hasValidValue ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ),
    );
  }
}


class _ApprovalNotice extends StatelessWidget {
  const _ApprovalNotice();

  @override
  Widget build(BuildContext context) {
    final accent = _RegisterTones.warning(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: accent.withValues(alpha:
        Theme.of(context).brightness == Brightness.dark ? 0.13 : 0.075,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.24)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.pending_actions_rounded,
            color: accent,
            size: 20,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              'After submission, your registration will stay pending until it is reviewed and approved.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: _RegisterTones.title(context),
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InformationConfirmation extends StatelessWidget {
  const _InformationConfirmation({
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => onChanged(!value),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: value
              ? _RegisterTones.success(context).withValues(alpha:
          Theme.of(context).brightness == Brightness.dark ? 0.14 : 0.08,
          )
              : Colors.black.withValues(alpha:
          Theme.of(context).brightness == Brightness.dark
              ? 0.12
              : 0.035,
          ),
          border: Border.all(
            color: value
                ? _RegisterTones.success(context).withValues(alpha: 0.32)
                : _RegisterTones.border(context),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: value,
              onChanged: (checked) => onChanged(checked ?? false),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Text(
                  'I confirm that the information above is complete and correct.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: _RegisterTones.title(context),
                    fontWeight: FontWeight.w800,
                    height: 1.35,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DialogReviewRow extends StatelessWidget {
  const _DialogReviewRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _PasswordMatchHint extends StatelessWidget {
  const _PasswordMatchHint({
    required this.matches,
  });

  final bool matches;

  @override
  Widget build(BuildContext context) {
    final Color accent = matches
        ? _RegisterTones.success(context)
        : Theme.of(context).colorScheme.error;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: accent.withValues(alpha: 0.07),
        border: Border.all(
          color: accent.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        children: [
          Icon(
            matches
                ? Icons.check_circle_rounded
                : Icons.info_outline_rounded,
            color: accent,
            size: 17,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              matches
                  ? 'Passwords match'
                  : 'Passwords do not match yet',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(
                color: accent,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PasswordStrengthChecklist extends StatelessWidget {
  const _PasswordStrengthChecklist({
    required this.hasLength,
    required this.hasNumber,
    required this.hasLetter,
  });

  final bool hasLength;
  final bool hasNumber;
  final bool hasLetter;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _PasswordRule(text: 'At least 8 characters', met: hasLength),
        const SizedBox(height: 6),
        _PasswordRule(text: 'Contains a number', met: hasNumber),
        const SizedBox(height: 6),
        _PasswordRule(text: 'Contains letters', met: hasLetter),
      ],
    );
  }
}

class _PasswordRule extends StatelessWidget {
  const _PasswordRule({
    required this.text,
    required this.met,
  });

  final String text;
  final bool met;

  @override
  Widget build(BuildContext context) {
    final accent = met
        ? _RegisterTones.success(context)
        : _RegisterTones.secondaryText(context);

    return Row(
      children: [
        Icon(
          met
              ? Icons.check_circle_rounded
              : Icons.radio_button_unchecked_rounded,
          size: 17,
          color: accent,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: accent,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 96,
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: _RegisterTones.secondaryText(context),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  value.isEmpty ? '-' : value,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: _RegisterTones.title(context),
                    fontWeight: FontWeight.w900,
                    height: 1.30,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Divider(
            height: 1,
            thickness: 1,
            color: _RegisterTones.border(context).withValues(alpha: 0.70),
          ),
        ],
      ),
    );
  }
}

class _BottomButtons extends StatelessWidget {
  const _BottomButtons({
    required this.loading,
    required this.canContinue,
    required this.isFirst,
    required this.isLast,
    required this.onBack,
    required this.onNext,
  });

  final bool loading;
  final bool canContinue;
  final bool isFirst;
  final bool isLast;
  final VoidCallback? onBack;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        14 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: _RegisterTones.panelTop(context),
        border: Border(
          top: BorderSide(color: _RegisterTones.border(context)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 14,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _SoftButton(
              label: isFirst ? 'Back to Login' : 'Back',
              onTap: onBack,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _PrimaryButton(
              label: isLast ? 'Submit Request' : 'Continue',
              loading: loading,
              enabled: canContinue && !loading,
              onTap: onNext,
            ),
          ),
        ],
      ),
    );
  }
}

class _SoftButton extends StatelessWidget {
  const _SoftButton({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: _RegisterTones.brand(context),
          side: BorderSide(color: _RegisterTones.border(context)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.loading,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool loading;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            decoration: BoxDecoration(
              color: enabled
                  ? _RegisterTones.teal
                  : _RegisterTones.border(context),
              borderRadius: BorderRadius.circular(14),
              boxShadow: enabled
                  ? [
                BoxShadow(
                  color: _RegisterTones.teal.withValues(alpha: 0.18),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ]
                  : null,
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
                  : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: enabled
                            ? Colors.white
                            : _RegisterTones.secondaryText(context),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (enabled) ...[
                    const SizedBox(width: 7),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      size: 17,
                      color: Colors.white,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PanelTitle extends StatelessWidget {
  const _PanelTitle({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _IconTile(icon: icon, accent: accent, size: 40),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: _RegisterTones.title(context),
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: _RegisterTones.secondaryText(context),
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: _RegisterTones.title(context),
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: _RegisterTones.secondaryText(context),
            fontWeight: FontWeight.w700,
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
    this.borderRadius = 22,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: _RegisterTones.panelTop(context),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: _RegisterTones.border(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.12 : 0.035),
            blurRadius: 18,
            offset: const Offset(0, 6),
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
    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.28),
        color: accent.withValues(alpha: 0.10),
        border: Border.all(color: accent.withValues(alpha: 0.14)),
      ),
      child: Center(
        child: Icon(icon, color: accent, size: size * 0.48),
      ),
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
              blurRadius: size * 0.50,
              spreadRadius: size * 0.04,
            ),
          ],
        ),
      ),
    );
  }
}




