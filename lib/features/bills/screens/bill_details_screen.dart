// KuryentePay Electric Bill UI: brand-consistent presentation; protected API/payment/PDF logic kept intact
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/config/api_config.dart';
import '../../../core/services/bill_payment_deadline.dart';
import '../../../shared/widgets/office_payment_notice.dart';
import '../../../core/theme/app_theme.dart';
import '../../payment/screens/payment_confirm_screen.dart';

class BillDetailsScreen extends StatefulWidget {
  const BillDetailsScreen({
    super.key,
    required this.nickname,
    required this.accountNo,
    required this.address,
    required this.month,
    required this.amount,
    required this.dueDate,
    required this.status,
    this.billId,
    this.generationCharge,
    this.transmissionCharge,
    this.distributionCharge,
    this.systemLossCharge,
    this.taxesAndUniversalCharges,
    this.previousBalance,
    this.adjustments,
    this.penaltiesAndOtherCharges,
  });

  final String nickname;
  final String accountNo;
  final String address;
  final String month;
  final double amount;
  final String dueDate;
  final String status;
  final int? billId;

  /// Retained for compatibility with older callers.
  ///
  /// The screen loads the official saved invoice snapshot from the API
  /// instead of estimating or combining these values.
  final double? generationCharge;
  final double? transmissionCharge;
  final double? distributionCharge;
  final double? systemLossCharge;
  final double? taxesAndUniversalCharges;
  final double? previousBalance;
  final double? adjustments;
  final double? penaltiesAndOtherCharges;

  @override
  State<BillDetailsScreen> createState() => _BillDetailsScreenState();
}

class _BillDetailsScreenState extends State<BillDetailsScreen>
    with WidgetsBindingObserver {
  late String _status;
  late String _month;
  late String _dueDate;
  late double _amount;
  int? _billId;

  bool _refreshing = false;
  bool _openingPayment = false;
  bool _invoiceLoading = true;
  bool _resumeRefreshInProgress = false;
  String? _invoiceError;
  _InvoiceSnapshot? _invoice;
  bool _showAllRateComponents = true;
  bool _documentWorking = false;
  Timer? _manilaDayTimer;
  DateTime _lastManilaDay = BillPaymentDeadline.manilaToday();
  bool _lastClockVerified = BillPaymentDeadline.serverClockVerified;
  bool _clockRequestRunning = false;
  int _clockRetryTicks = 0;

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
      if (!verified) {
        _clockRetryTicks++;
        if (_clockRetryTicks >= 2) {
          _clockRetryTicks = 0;
          unawaited(_syncClockAndRebuild(force: true));
        }
      } else {
        _clockRetryTicks = 0;
      }
    });

    _status = _normaliseBillStatus(widget.status);
    _month = widget.month;
    _dueDate = widget.dueDate;
    _amount = widget.amount;
    _billId = widget.billId;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInvoice(showLoading: true, showErrorMessage: false);
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
          _lastClockVerified = BillPaymentDeadline.serverClockVerified;
          _lastManilaDay = BillPaymentDeadline.manilaToday();
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_syncClockAndRebuild(force: true));
    }
    if (state == AppLifecycleState.resumed &&
        !_resumeRefreshInProgress &&
        !_refreshing) {
      unawaited(_refreshAfterAppResume());
    }
  }

  Future<void> _refreshAfterAppResume() async {
    if (!mounted || _resumeRefreshInProgress || _refreshing) {
      return;
    }

    _resumeRefreshInProgress = true;

    try {
      await _loadInvoice(
        showLoading: false,
        showErrorMessage: false,
      );
    } finally {
      _resumeRefreshInProgress = false;
    }
  }

  // OVERDUE is a derived date label, not a permanent stored payment state.
  // The API may have returned a stale is_overdue value earlier in the session.
  String get _statusUpper {
    final String raw = _normaliseBillStatus(_status);
    return raw == 'OVERDUE' ? 'UNPAID' : raw;
  }

  bool get _isPaid => _statusUpper == 'PAID';

  bool get _isPending =>
      _statusUpper == 'PENDING' ||
          _statusUpper == 'PROCESSING' ||
          _statusUpper == 'VERIFYING';

  bool get _isOverdue => !_isPaid && !_isPending &&
      (BillPaymentDeadline.daysUntilDue(_dueDate) ?? 0) < 0;

  bool get _officePaymentRequired => !_isPaid && !_isPending &&
      BillPaymentDeadline.isOfficePaymentRequired(_dueDate);

  int? get _daysBeforeDue => _isPaid || _isPending
      ? null
      : BillPaymentDeadline.daysUntilDue(_dueDate);

  String get _displayPaymentStatus {
    if (_isPaid || _isPending) return _statusUpper;
    final int? days = BillPaymentDeadline.daysUntilDue(_dueDate);
    if (days == null) return 'UNPAID';
    if (days < 0) return 'OVERDUE';
    if (days == 0) return 'DUE TODAY';
    return 'UNPAID';
  }


  bool get _hasValidBillId => (_billId ?? 0) > 0;

  bool get _hasPayableAmount => _amount > 0;

  bool get _hasCurrentInvoice =>
      !_invoiceLoading &&
          _invoice != null &&
          _invoiceError == null;

  bool get _canPay =>
      !_isPaid &&
          !_isPending &&
          !_isOverdue &&
          _hasCurrentInvoice &&
          !_refreshing &&
          _hasValidBillId &&
          _hasPayableAmount &&
          BillPaymentDeadline.canStartOnlinePayment(_dueDate) &&
          !_openingPayment;

  Color get _statusColor {
    if (_isPaid) {
      return _BillPalette.success(context);
    }

    if (_isOverdue) {
      return _BillPalette.danger(context);
    }

    return _BillPalette.gold(context);
  }

  IconData get _statusIcon {
    if (_isPaid) {
      return Icons.verified_rounded;
    }

    if (_isPending) {
      return Icons.hourglass_top_rounded;
    }

    if (_isOverdue) {
      return Icons.warning_amber_rounded;
    }

    return Icons.schedule_rounded;
  }

  String get _paymentButtonLabel {
    if (_openingPayment) return 'Opening PayMongo…';
    if (_invoiceLoading || _refreshing) return 'Checking Bill…';
    if (_invoiceError != null || _invoice == null) return 'Bill Unavailable';
    if (_isPaid) return 'Already Paid';
    if (_isPending) return 'Payment Verifying';
    if (_officePaymentRequired) return 'Office Payment Required';
    if (!BillPaymentDeadline.canStartOnlinePayment(_dueDate)) {
      return BillPaymentDeadline.parseDueDate(_dueDate) == null
          ? 'Due Date Unavailable'
          : 'Checking Availability';
    }
    if (!_hasValidBillId) return 'Payment Unavailable';
    if (!_hasPayableAmount) return 'No Payable Amount';

    if (_daysBeforeDue == 0) return 'Review Payment';
    return 'Review Payment';
  }

  Future<void> _copyText(
      String value,
      String successMessage,
      ) async {
    if (value.trim().isEmpty) return;

    await Clipboard.setData(
      ClipboardData(text: value),
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(successMessage)),
    );
  }

  Future<_InvoiceSnapshot> _requestInvoice({int? exactBillId}) async {
    await ApiConfig.init();

    final int? selectedBillId = exactBillId ?? widget.billId;
    final int? requestedBillId = (selectedBillId ?? 0) > 0
        ? selectedBillId
        : null;

    final bool exactBillRequested = requestedBillId != null;

    final Uri uri = ApiConfig.buildUri(
      exactBillRequested
          ? 'bills/bill_details.php'
          : 'current_bill.php',
      query: <String, dynamic>{
        'account_no': widget.accountNo,
        if (exactBillRequested) 'bill_id': requestedBillId,
      },
    );

    late http.Response response;

    try {
      response = await http.get(
        uri,
        headers: const <String, String>{
          'Accept': 'application/json',
          'Cache-Control': 'no-cache, no-store',
          'Pragma': 'no-cache',
        },
      ).timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw Exception(
        'KuryentePay took too long to respond. Check your connection and try again.',
      );
    } on http.ClientException catch (error) {
      debugPrint(
        'Bill request connection failed: ${error.runtimeType}',
      );
      throw Exception(
        'Unable to connect to KuryentePay. Check your connection and try again.',
      );
    }

    final String body = utf8
        .decode(
      response.bodyBytes,
      allowMalformed: true,
    )
        .trim();

    if (body.isEmpty) {
      throw Exception('KuryentePay returned an empty response. Please try again.');
    }

    final dynamic decoded;

    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw Exception(
        'KuryentePay returned unreadable billing data. Please try again.',
      );
    }

    if (decoded is! Map) {
      throw Exception('KuryentePay returned an invalid billing response. Please try again.');
    }

    final Map<String, dynamic> payload = Map<String, dynamic>.from(decoded);

    final bool requestSucceeded = response.statusCode >= 200 &&
        response.statusCode < 300 &&
        payload['success'] == true;

    if (!requestSucceeded) {
      final String message =
      (payload['message'] ?? 'Unable to load the bill invoice.')
          .toString()
          .trim();
      throw Exception(message);
    }

    final dynamic rawBill = payload['bill'];

    if (rawBill is! Map) {
      throw Exception('No bill is available for this account.');
    }

    final Map<String, dynamic> bill = Map<String, dynamic>.from(rawBill);
    final dynamic rawAccount = payload['account'];
    final Map<String, dynamic> account = rawAccount is Map
        ? Map<String, dynamic>.from(rawAccount)
        : <String, dynamic>{};
    final _InvoiceSnapshot snapshot = _InvoiceSnapshot.fromBill(
      bill,
      account: account,
    );

    if (requestedBillId != null &&
        snapshot.billId != null &&
        requestedBillId != snapshot.billId) {
      throw Exception(
        'KuryentePay returned a different bill record. Please refresh and try again.',
      );
    }

    // Home can open this screen without a bill ID. Resolve its latest bill
    // once, then request the exact saved invoice and statement references.
    // We never use this second request for a different consumer's bill.
    if (!exactBillRequested && (snapshot.billId ?? 0) > 0) {
      return _requestInvoice(exactBillId: snapshot.billId);
    }

    return snapshot;
  }

  Future<void> _loadInvoice({
    required bool showLoading,
    required bool showErrorMessage,
  }) async {
    if (_refreshing) return;

    if (mounted) {
      setState(() {
        _refreshing = true;
        if (showLoading) {
          _invoiceLoading = true;
        }
        _invoiceError = null;
      });
    }

    try {
      final _InvoiceSnapshot snapshot = await _requestInvoice();

      if (!mounted) return;

      setState(() {
        _invoice = snapshot;
        _invoiceError = null;
        _status =
        snapshot.paymentStatus.isEmpty ? _status : snapshot.paymentStatus;
        _month = snapshot.billingMonth.isEmpty ? _month : snapshot.billingMonth;
        _dueDate = snapshot.dueDate.isEmpty ? _dueDate : snapshot.dueDate;
        _amount = snapshot.totalAmountDue;
        _billId = snapshot.billId ?? _billId;
      });
    } catch (error) {
      final String message =
      error.toString().replaceFirst('Exception: ', '').trim();

      if (!mounted) return;

      setState(() {
        _invoiceError = message.isEmpty
            ? 'Unable to load the complete bill invoice.'
            : message;
      });

      if (showErrorMessage) {
        _showMessage(_invoiceError!);
      }
    } finally {
      if (mounted) {
        setState(() {
          _refreshing = false;
          _invoiceLoading = false;
        });
      }
    }
  }

  Future<void> _refreshBillStatus() async {
    await _loadInvoice(
      showLoading: false,
      showErrorMessage: true,
    );
  }

  Future<void> _refreshAfterPaymentReturn() async {
    for (int attempt = 0; attempt < 4; attempt++) {
      if (!mounted) return;

      await _loadInvoice(
        showLoading: false,
        showErrorMessage: false,
      );

      if (!mounted || _isPaid) {
        return;
      }

      if (attempt < 3) {
        await Future<void>.delayed(
          const Duration(seconds: 2),
        );
      }
    }
  }

  Future<void> _goToPay() async {
    if (_openingPayment) {
      return;
    }

    // Revalidate the latest authoritative bill state immediately before
    // opening checkout. The backend also validates this again when the
    // PayMongo checkout session is created.
    await _loadInvoice(
      showLoading: false,
      showErrorMessage: false,
    );

    if (!mounted) return;

    if (_invoiceError != null || _invoice == null) {
      _showMessage(
        'Unable to verify the latest bill status. Please check your connection and try again.',
      );
      return;
    }

    if (_isPaid) {
      _showMessage('This bill has already been paid.');
      return;
    }

    if (_isPending) {
      _showMessage(
        'Your payment is still being verified. Please wait for KuryentePay to confirm its status before paying again.',
      );
      return;
    }

    if (BillPaymentDeadline.isOfficePaymentRequired(_dueDate)) {
      _showMessage(BillPaymentDeadline.officeAction);
      return;
    }
    if (!BillPaymentDeadline.canStartOnlinePayment(_dueDate)) {
      _showMessage('Unable to confirm the Philippine date. Please check your connection; the app will retry automatically.');
      return;
    }

    final int? billId = _billId;

    if (billId == null) {
      _showMessage(
        'Payment cannot be started right now. Please reopen the bill and try again.',
      );
      return;
    }

    if (_amount <= 0) {
      _showMessage(
        'This bill does not have a valid payable amount.',
      );
      return;
    }

    setState(() => _openingPayment = true);

    try {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PaymentConfirmScreen(
            method: 'PayMongo QR Ph',
            billMonth: _formatBillingMonth(_month),
            amount: _amount,
            billId: billId,
            accountNo: widget.accountNo,
            dueDate: _dueDate,
            serviceAddress: widget.address,
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _openingPayment = false);
      }
    }

    if (!mounted) return;
    await _refreshAfterPaymentReturn();
  }

  Future<Uint8List> _buildCurrentBillPdf(_InvoiceSnapshot invoice) async {
    try {
      final PrintingInfo info = await Printing.info();
      if (info.canConvertHtml) {
        // HTML conversion is intentionally used here because the official
        // Admin bill is an HTML/CSS continuous-form invoice. This preserves
        // its real table rowspans, fixed column widths and print spacing.
        // ignore: deprecated_member_use
        return await Printing.convertHtml(
          format: PdfPageFormat.a4,
          html: _buildCurrentBillHtml(invoice),
        );
      }
    } catch (error, stackTrace) {
      debugPrint('KuryentePay HTML bill conversion failed; using PDF fallback: $error');
      debugPrintStack(stackTrace: stackTrace);
    }

    return _buildCurrentBillPdfFallback(invoice);
  }

  String _buildCurrentBillHtml(_InvoiceSnapshot invoice) {
    const HtmlEscape htmlEscape = HtmlEscape(HtmlEscapeMode.element);
    String h(String value) => htmlEscape.convert(value);

    final String accountName = invoice.consumerName.trim().isEmpty
        ? widget.nickname.trim()
        : invoice.consumerName.trim();
    final String address = invoice.consumerAddress.trim().isEmpty
        ? widget.address.trim()
        : invoice.consumerAddress.trim();
    final String accountNo = invoice.accountNo.trim().isEmpty
        ? widget.accountNo.trim()
        : invoice.accountNo.trim();
    final String billNo = invoice.billNo.trim().isEmpty ? '-' : invoice.billNo.trim();
    final List<String> fromParts = _ilecoDateParts(invoice.periodFrom);
    final List<String> toParts = _ilecoDateParts(invoice.periodTo);

    final String priorRows = invoice.statementPriorItems.map(
          (_StatementPriorBill item) => '<tr>'
          '<td>${h(item.reference)}</td>'
          '<td>${h(_formatBillingMonth(item.billingMonth))}</td>'
          '<td>${h(_ilecoDisplayDate(item.dueDate))}</td>'
          '<td class="prior-currency">&#8369; ${h(_ilecoNumber(item.amountAtIssue, decimals: 2))}</td>'
          '</tr>',
    ).join();
    final String priorAddendum = invoice.statementPriorItems.isEmpty
        ? ''
        : '''
<section class="prior-addendum-page" aria-label="Selected previous unpaid bills">
  <div class="prior-addendum-inner">
    <div class="prior-kicker">KuryentePay | BILLING STATEMENT ADDENDUM</div>
    <h2>PREVIOUS UNPAID BILLS SELECTED FOR STATEMENT</h2>
    <div class="prior-meta">
      <div><b>Account:</b> ${h(accountNo)}</div>
      <div><b>Current Bill Reference:</b> ${h(billNo)}</div>
      <div><b>Billing Month:</b> ${h(_formatBillingMonth(invoice.billingMonth))}</div>
      <div><b>Meter S/N:</b> ${h(invoice.meterSerialNo.isEmpty ? '-' : invoice.meterSerialNo)}</div>
    </div>
    <p class="prior-explainer">These balances were outstanding when this statement was issued. They are historical snapshots, not today's payment balances.</p>
    <table class="prior-addendum-table">
      <thead><tr><th>Bill Reference</th><th>Billing Month</th><th>Due Date</th><th>At Issue</th></tr></thead>
      <tbody>$priorRows</tbody>
    </table>
    <div class="prior-addendum-totals">
      <span>This bill amount due</span><b>&#8369; ${h(_ilecoNumber(invoice.totalAmountDue, decimals: 2))}</b>
      <span>Selected previous bills at issue</span><b>&#8369; ${h(_ilecoNumber(invoice.statementPreviousUnpaidAtIssue, decimals: 2))}</b>
      <strong>Combined statement view at issue</strong><strong>&#8369; ${h(_ilecoNumber(invoice.statementCombinedAtIssue, decimals: 2))}</strong>
    </div>
    <div class="prior-warning">REFERENCE ONLY: The combined amount is NOT a new charge or a single payable bill. Each older bill remains independently payable under its own reference and rules. Check its latest status before paying. This is NOT a payment receipt.</div>
  </div>
</section>''';

    final Set<String> subtotalCategories = <String>{
      'GENERATION_TRANSMISSION',
      'DISTRIBUTION_REVENUES',
      'OTHERS',
      'GOVERNMENT_REVENUES',
    };

    final StringBuffer rateRows = StringBuffer();
    bool billTotalsRendered = false;

    void writeCategoryCell(_InvoiceCategory category, int rowSpan) {
      final String code = category.code.trim().toUpperCase();
      final String label = _ilecoCategoryLabel(
        code,
        category.label,
      );
      final String mode = code == 'OTHERS' ? 'stacked' : 'stacked compact';
      final String spans = label
          .split('\n')
          .map((String part) => '<span>${h(part)}</span>')
          .join();
      rateRows.write(
        '<td class="category-cell" rowspan="$rowSpan">'
            '<div class="category-label $mode">$spans</div></td>',
      );
    }

    if (invoice.categories.isEmpty) {
      rateRows.writeln('''
<tr>
  <td class="category-cell"><div class="category-label stacked"><span>BILL</span></div></td>
  <td class="component-cell">NO SAVED CHARGE ROWS FOUND.</td>
  <td class="rate-cell">-</td>
  <td class="amount-cell">-</td>
</tr>''');
    } else {
      for (final _InvoiceCategory category in invoice.categories) {
        final String code = category.code.toUpperCase();
        final bool showSubtotal = subtotalCategories.contains(code);
        final bool includeBillTotals = code == 'COOP_OTHER_CHARGES';
        final int rowSpan = category.rows.length +
            (showSubtotal ? 1 : 0) +
            (includeBillTotals ? 2 : 0);
        bool categoryWritten = false;

        final bool isLifeline = code == 'LIFELINE_SUBSIDY_ADJUSTMENT';
        for (int lineIndex = 0; lineIndex < category.rows.length; lineIndex++) {
          final _InvoiceLine line = category.rows[lineIndex];
          final List<String> rowClasses = <String>[
            if (line.isHeading) 'heading-row',
            if (isLifeline && lineIndex == 0) 'lifeline-row',
          ];
          final String rowClass = rowClasses.isEmpty
              ? ''
              : ' class="${rowClasses.join(' ')}"';

          rateRows.write('<tr$rowClass>');
          if (!categoryWritten) {
            writeCategoryCell(category, rowSpan == 0 ? 1 : rowSpan);
            categoryWritten = true;
          }

          final String componentName = line.componentName.trim().isEmpty
              ? (line.isHeading ? 'CHARGE HEADING' : 'RATE COMPONENT')
              : line.componentName.toUpperCase();
          final String unit = line.isHeading ? '' : _ilecoRateUnitLabel(line.rateUnit);
          final String rate = line.isHeading ? '-' : _ilecoRateValue(line);
          final String amount = line.isHeading ? '-' : _ilecoAmountValue(line);

          rateRows.write(
            '<td class="component-cell"><div class="component-line">'
                '<span class="component-name">${h(componentName)}</span>'
                '${unit.isEmpty ? '' : '<span class="component-unit">${h(unit)}</span>'}'
                '</div></td>'
                '<td class="rate-cell">${h(rate)}</td>'
                '<td class="amount-cell">${h(amount)}</td>'
                '</tr>',
          );
        }

        if (showSubtotal) {
          rateRows.write('<tr class="subtotal-row">');
          if (!categoryWritten) {
            writeCategoryCell(category, rowSpan == 0 ? 1 : rowSpan);
            categoryWritten = true;
          }
          rateRows.write(
            '<td class="subtotal-label">SUB-TOTAL</td>'
                '<td class="rate-cell"></td>'
                '<td class="amount-cell">${h(_ilecoNumber(category.subtotal, decimals: 2))}</td>'
                '</tr>',
          );
        }

        if (includeBillTotals) {
          rateRows.write('<tr class="current-row">');
          if (!categoryWritten) {
            writeCategoryCell(category, rowSpan == 0 ? 2 : rowSpan);
            categoryWritten = true;
          }
          rateRows.write(
            '<td class="component-cell">Current Amount Due</td>'
                '<td class="rate-cell"></td>'
                '<td class="amount-cell">${h(_ilecoNumber(invoice.currentAmountDue, decimals: 2))}</td>'
                '</tr>',
          );
          rateRows.write(
            '<tr class="current-row">'
                '<td class="component-cell">Unpaid Bill/s</td>'
                '<td class="rate-cell"></td>'
                '<td class="amount-cell">${h(_ilecoNumber(invoice.unpaidBills, decimals: 2))}</td>'
                '</tr>',
          );
          billTotalsRendered = true;
        }
      }
    }

    if (!billTotalsRendered) {
      rateRows.write(
        '<tr class="current-row">'
            '<td class="category-cell" rowspan="2"><div class="category-label stacked compact">'
            '<span>COOP OTHER</span><span>CHARGES</span></div></td>'
            '<td class="component-cell">Current Amount Due</td>'
            '<td class="rate-cell"></td>'
            '<td class="amount-cell">${h(_ilecoNumber(invoice.currentAmountDue, decimals: 2))}</td>'
            '</tr>'
            '<tr class="current-row">'
            '<td class="component-cell">Unpaid Bill/s</td>'
            '<td class="rate-cell"></td>'
            '<td class="amount-cell">${h(_ilecoNumber(invoice.unpaidBills, decimals: 2))}</td>'
            '</tr>',
      );
    }

    return '''<!doctype html>
<html>
<head>
<meta charset="utf-8">
<style>
  @page { size: A4 portrait; margin: 13mm; }
  * { box-sizing: border-box; }
  html, body { margin: 0; padding: 0; background: #fff; }
  body {
    color: #173347;
    font-family: "Courier New", Courier, monospace;
    -webkit-print-color-adjust: exact;
    print-color-adjust: exact;
  }
  .bill-sheet {
    position: relative;
    width: 184mm;
    min-height: 258mm;
    margin: 0 auto;
    padding: 2mm 7mm;
    overflow: hidden;
    background:
      linear-gradient(rgba(255,255,255,.18), rgba(255,255,255,.18)),
      repeating-linear-gradient(0deg, rgba(16,47,62,.025) 0, rgba(16,47,62,.025) .25mm, transparent .25mm, transparent 1.1mm),
      #FAFCFD;
  }
  .bill-sheet::before, .bill-sheet::after {
    content: "";
    position: absolute;
    top: 0;
    bottom: 0;
    width: 5.5mm;
    z-index: 0;
    background:
      radial-gradient(circle at 50% 5mm, #E7EEF1 0 2.05mm, #B4C6CA 2.15mm 2.45mm, transparent 2.55mm) 0 0 / 5.5mm 10mm repeat-y,
      #F4F7FA;
  }
  .bill-sheet::before { left: 0; border-right: .25mm solid #BACDD0; }
  .bill-sheet::after { right: 0; border-left: .25mm solid #BACDD0; }
  .invoice {
    position: relative;
    z-index: 1;
    min-height: 252mm;
    border: .85mm solid #087F79;
    border-radius: 1.4mm;
    padding: 1.1mm 1.3mm;
  }
  .top-identity {
    display: grid;
    grid-template-columns: 19mm 1fr 35mm;
    align-items: start;
    min-height: 20mm;
  }
  .logo-wrap { display:flex; justify-content:center; align-items:flex-start; padding-top:.2mm; }
  .logo-wrap img { width:15.5mm; height:14.2mm; object-fit:cover; image-rendering:auto; border-radius:1.6mm; border:.25mm solid #BBD0D4; }
  .coop-copy { text-align:center; padding:.5mm 1mm 0; }
  .coop-name { color:#102F3E; font-family:Arial, sans-serif; font-size:16pt; font-weight:900; letter-spacing:.2mm; line-height:1.03; white-space:nowrap; }
  .coop-address { margin-top:.55mm; font-family:Arial, sans-serif; font-size:8.5pt; font-weight:700; letter-spacing:.15mm; }
  .coop-tin { margin-top:.4mm; font-family:Arial, sans-serif; font-size:7.8pt; font-weight:700; letter-spacing:.2mm; }
  .invoice-no { text-align:right; padding:.7mm 1mm 0 0; }
  .invoice-no .small-code { display:block; min-height:3.5mm; font:800 7.4pt Arial, sans-serif; letter-spacing:.2mm; color:#566F7B; }
  .invoice-no .no-line { margin-top:.7mm; color:#102F3E; font-family:Arial, sans-serif; font-size:8.6pt; font-weight:900; }
  .invoice-no .no-value { color:#102F3E; font-family:"Courier New", monospace; font-size:9.6pt; font-weight:900; letter-spacing:0; vertical-align:middle; display:inline-block; max-width:34mm; overflow-wrap:anywhere; word-break:break-all; line-height:1.15; }
  .billing-date { margin:-1mm 0 .55mm 2mm; font-size:8.6pt; font-weight:800; letter-spacing:.15mm; color:#000; }
  .boxed { border:.45mm solid #83A9B1; border-radius:1.8mm; overflow:hidden; }
  .account-grid { display:grid; grid-template-columns:1.05fr 1.55fr .45fr .83fr; }
  .box-head {
    min-height:4.8mm; display:flex; align-items:center; justify-content:center;
    padding:.3mm .5mm; background:#102F3E; color:#fff;
    border-right:.35mm solid #83A9B1; font:bold 7.7pt Arial, sans-serif; letter-spacing:.12mm; text-transform:uppercase; text-align:center;
  }
  .box-head:nth-child(4) { border-right:0; }
  .box-val {
    min-height:6.5mm; display:flex; align-items:center; justify-content:center;
    padding:.35mm; background:rgba(255,255,255,.32); border-top:.35mm solid #83A9B1;
    border-right:.35mm solid #83A9B1; font-size:8.8pt; font-weight:900; color:#000; text-align:center;
  }
  .box-val:nth-child(8) { border-right:0; }
  .person-row { display:grid; grid-template-columns:1fr 34mm; gap:1.4mm; margin-top:1mm; }
  .person-box { min-height:15.3mm; padding:.55mm 1.4mm .7mm; background:rgba(255,255,255,.26); }
  .person-label { color:#087F79; font:bold 7.1pt Arial, sans-serif; letter-spacing:.12mm; }
  .person-lines { margin-top:.55mm; padding-left:2.5mm; font-size:8.25pt; line-height:1.14; color:#000; font-weight:800; text-transform:uppercase; }
  .multiplier-box { display:grid; grid-template-rows:5.2mm 1fr; }
  .multiplier-head { display:flex; align-items:center; justify-content:center; background:#D9EFF2; color:#102F3E; border-bottom:.35mm solid #83A9B1; font:bold 7.6pt Arial, sans-serif; }
  .multiplier-value { display:flex; align-items:center; justify-content:center; background:rgba(255,255,255,.32); font-size:9.2pt; font-weight:900; color:#000; }
  .invoice-title { margin:.7mm 0 .4mm; text-align:center; color:#102F3E; font:bold 11.8pt Arial, sans-serif; letter-spacing:.4mm; }

  .usage-table, .rate-table { width:100%; border-spacing:0; table-layout:fixed; }
  .usage-table { border:.45mm solid #83A9B1; border-collapse:separate; overflow:hidden; border-radius:1.7mm; }
  .usage-table th, .usage-table td { border-right:.3mm solid #83A9B1; border-bottom:.3mm solid #83A9B1; text-align:center; }
  .usage-table th:last-child, .usage-table td:last-child { border-right:0; }
  .usage-table tr:last-child td { border-bottom:0; }
  .usage-table th { background:#D9EFF2; color:#102F3E; font:bold 7.1pt Arial, sans-serif; padding:.3mm .2mm; }
  .usage-table .subhead th { font-size:6.2pt; padding:.2mm .18mm; }
  .usage-table td { background:rgba(255,255,255,.32); font-size:8.1pt; padding:.35mm .2mm; color:#000; font-weight:900; }
  .usage-table .period { width:30%; }
  .usage-table .reading { width:31%; }
  .usage-table .kwh { width:18%; }
  .usage-table .demand { width:21%; }

  .rate-table { margin-top:.75mm; border:.45mm solid #83A9B1; border-collapse:separate; border-radius:1.5mm; overflow:hidden; }
  .rate-table col.cat { width:11.2%; }
  .rate-table col.component { width:50.8%; }
  .rate-table col.rate { width:18.2%; }
  .rate-table col.amount { width:19.8%; }
  .rate-table th {
    background:#087F79; color:#fff; border-right:.3mm solid #83A9B1;
    border-bottom:.3mm solid #83A9B1; padding:.38mm .28mm;
    font:bold 7.15pt Arial, sans-serif; letter-spacing:.08mm; text-align:center; text-transform:uppercase;
  }
  .rate-table th:last-child { border-right:0; }
  .rate-table td {
    height:2.8mm; border-right:.25mm solid #9BB9BE; border-bottom:.25mm solid #9BB9BE;
    background:rgba(255,255,255,.26); padding:.14mm .5mm; font-size:6.85pt; line-height:1;
    color:#000; vertical-align:middle;
  }
  .rate-table td:last-child { border-right:0; }
  .rate-table tr { break-inside:avoid; page-break-inside:avoid; }
  .rate-table tr:last-child td { border-bottom:0; }
  .category-cell {
    position:relative; padding:.2mm .35mm !important; overflow:hidden !important;
    text-align:center; background:#D9EFF2 !important; color:#102F3E !important;
    font:bold 5.6pt Arial, sans-serif !important; vertical-align:middle !important; line-height:1.08;
  }
  .category-label, .category-label.vertical, .category-label.stacked {
    width:100%; height:auto; min-height:0; display:flex; flex-direction:column; align-items:center;
    justify-content:center; gap:.12mm; padding:.25mm .1mm; writing-mode:horizontal-tb; text-orientation:mixed;
    transform:none; white-space:normal; overflow:visible; text-align:center; line-height:1.08;
    word-break:normal; overflow-wrap:normal;
  }
  .category-label span { display:block; max-width:100%; white-space:normal; text-align:center; }
  .category-label.compact { font-size:5.15pt; line-height:1.06; }
  .lifeline-row td { height:4.8mm !important; }
  .component-cell { text-transform:uppercase; }
  .component-line { display:flex; align-items:center; justify-content:space-between; gap:1.5mm; }
  .component-name { overflow:hidden; white-space:nowrap; text-overflow:ellipsis; }
  .component-unit { flex:0 0 auto; font-size:5.95pt; color:#000; }
  .rate-cell, .amount-cell { text-align:right; white-space:nowrap; padding-right:1.05mm !important; font-weight:900; }
  .heading-row td { font-weight:700; text-transform:uppercase; background:#E8F4F2; }
  .heading-row .component-cell { padding-left:5.2mm; }
  .subtotal-row td { background:#E8F4F2; font-weight:900; color:#000; }
  .subtotal-label { text-align:center; color:#102F3E !important; font-family:Arial, sans-serif; letter-spacing:.12mm; }
  .current-row td { color:#000; font-weight:900; }
  .current-row .component-cell { padding-left:4mm; text-transform:none; }

  .total-due { display:grid; grid-template-columns:61.8% 38.2%; margin-top:.65mm; border:.45mm solid #83A9B1; border-radius:1.8mm; overflow:hidden; }
  .total-label, .total-value { min-height:6.8mm; display:flex; align-items:center; }
  .total-label { justify-content:center; background:#102F3E; color:#fff; font:bold 9.6pt Arial, sans-serif; }
  .total-value { justify-content:flex-end; padding-right:4mm; background:#E7F3F1; color:#000; font:900 12.8pt "Courier New", monospace; }
  .warning-row { display:grid; grid-template-columns:59% 41%; gap:1mm; margin-top:.65mm; }
  .warning-note, .warning-green { min-height:8.6mm; padding:.7mm 1.4mm; border:.45mm solid #83A9B1; border-radius:1.6mm; font:bold 6.25pt Arial, sans-serif; line-height:1.04; letter-spacing:.12mm; }
  .warning-note { background:#E4F5F6; color:#102F3E; border-left:1.2mm solid #087F79; }
  .warning-green { background:#102F3E; color:#fff; }
  .footer-row { margin-top:.55mm; display:grid; grid-template-columns:1fr auto; gap:4mm; align-items:end; font-size:5.6pt; line-height:1.05; color:#000; }
  .footer-left strong { font-size:6.2pt; }
  .footer-right { text-align:right; font-family:Arial, sans-serif; letter-spacing:.06mm; }
  /* Step 5J-2: statement-only additional page, no yellow or gold. */
  .prior-addendum-page { break-before:page; page-break-before:always; width:184mm; min-height:258mm; margin:0 auto; padding:8mm 9mm; background:#FAFCFD; font-family:Arial, Helvetica, sans-serif; color:#102F3E; }
  .prior-addendum-inner { border:.7mm solid #087F79; border-radius:2.1mm; padding:8mm; min-height:235mm; }
  .prior-kicker { color:#087F79; font-size:9pt; font-weight:800; letter-spacing:.6mm; }
  .prior-addendum-page h2 { color:#102F3E; margin:4mm 0; font-size:14pt; line-height:1.25; }
  .prior-meta { display:grid; grid-template-columns:1fr 1fr; gap:2mm; padding:4mm; border:.25mm solid #A7C6CC; background:#F0F7F6; font-size:9pt; overflow-wrap:anywhere; }
  .prior-explainer { margin:4mm 0; color:#47646F; font-size:9pt; line-height:1.4; }
  .prior-addendum-table { width:100%; table-layout:fixed; border-collapse:collapse; font-size:8.5pt; }
  .prior-addendum-table th { background:#102F3E; color:#fff; padding:2mm 1.5mm; text-align:left; }
  .prior-addendum-table td { border-bottom:.25mm solid #D2E2E5; padding:2.2mm 1.5mm; overflow-wrap:anywhere; }
  .prior-addendum-table tr { break-inside:avoid; page-break-inside:avoid; }
  .prior-addendum-table th:last-child, .prior-currency { text-align:right; white-space:nowrap; }
  .prior-addendum-totals { display:grid; grid-template-columns:1fr auto; gap:2mm 4mm; margin-top:4mm; padding:4mm; border:.3mm solid #83A9B1; background:#E7F3F1; font-size:9pt; }
  .prior-addendum-totals strong { font-size:10pt; color:#102F3E; }
  .prior-warning { margin-top:4mm; padding:4mm; background:#F0F7F6; border-left:1mm solid #087F79; color:#294954; font-size:8pt; line-height:1.4; }
</style>
</head>
<body>
<section class="bill-sheet">
  <div class="invoice">
    <div class="top-identity">
      <div class="logo-wrap"><img alt="KuryentePay logo" src="data:image/jpeg;base64,$_kuryentePayBillLogoBase64"></div>
      <div class="coop-copy">
        <div class="coop-name">KuryentePay</div>
        <div class="coop-address">ELECTRIC BILLING &amp; PAYMENT</div>
        <div class="coop-tin">BILLING STATEMENT &bull; SAVED BILL RECORD</div>
      </div>
      <div class="invoice-no">
        <span class="small-code">BILL REFERENCE</span>
        <div class="no-line"><span class="no-value">${h(billNo)}</span></div>
      </div>
    </div>

    <div class="billing-date">Billing Date: ${h(_ilecoDisplayDate(invoice.createdAt))}</div>

    <div class="boxed account-grid">
      <div class="box-head">ACCOUNT NUMBER</div><div class="box-head">METER S/N</div><div class="box-head">TYPE</div><div class="box-head">DUE DATE</div>
      <div class="box-val">${h(accountNo)}</div><div class="box-val">${h(invoice.meterSerialNo.trim().isEmpty ? '-' : invoice.meterSerialNo.trim())}</div><div class="box-val">-</div><div class="box-val">${h(_ilecoNumericDate(invoice.dueDate))}</div>
    </div>

    <div class="person-row">
      <div class="boxed person-box">
        <div class="person-label">NAME / ADDRESS</div>
        <div class="person-lines"><div>${h(accountName)}</div><div>${h(address)}</div></div>
      </div>
      <div class="boxed multiplier-box"><div class="multiplier-head">MULTIPLIER</div><div class="multiplier-value">-</div></div>
    </div>

    <div class="invoice-title">ELECTRIC BILL STATEMENT</div>

    <table class="usage-table">
      <tr>
        <th class="period" colspan="6">PERIOD COVERED</th>
        <th class="reading" colspan="2">METER READING</th>
        <th class="kwh" rowspan="3">KWH USED</th>
        <th class="demand" rowspan="3">DEMAND KW USED</th>
      </tr>
      <tr class="subhead"><th colspan="3">FROM</th><th colspan="3">TO</th><th>PRESENT</th><th>PREVIOUS</th></tr>
      <tr class="subhead"><th>MO</th><th>DAY</th><th>YR</th><th>MO</th><th>DAY</th><th>YR</th><th></th><th></th></tr>
      <tr>
        <td>${h(fromParts[0])}</td><td>${h(fromParts[1])}</td><td>${h(fromParts[2])}</td>
        <td>${h(toParts[0])}</td><td>${h(toParts[1])}</td><td>${h(toParts[2])}</td>
        <td>${h(_ilecoNullableNumber(invoice.readingPresent, decimals: 1))}</td>
        <td>${h(_ilecoNullableNumber(invoice.readingPrevious, decimals: 1))}</td>
        <td>${h(_ilecoNullableNumber(invoice.kwhUsed, decimals: 1))}</td>
        <td>${h(_ilecoNumber(invoice.billingDemandKw ?? 0, decimals: 3))}</td>
      </tr>
    </table>

    <table class="rate-table">
      <colgroup><col class="cat"><col class="component"><col class="rate"><col class="amount"></colgroup>
      <thead><tr><th></th><th>RATE COMPONENT</th><th>RATE</th><th>AMOUNT</th></tr></thead>
      <tbody>${rateRows.toString()}</tbody>
    </table>

    <div class="total-due"><div class="total-label">${invoice.statementPriorItems.isNotEmpty ? 'THIS BILL AMOUNT DUE' : 'TOTAL AMOUNT DUE'}&nbsp;&nbsp;&#9658;&#9658;&#9658;</div><div class="total-value">&#8369; ${h(_ilecoNumber(invoice.totalAmountDue, decimals: 2))}</div></div>
    <div class="warning-row">
      <div class="warning-note">PLEASE PAY BY THE DUE DATE SHOWN. FOR OVERDUE BILLS, CONFIRM PAYMENT OPTIONS WITH THE OFFICE.</div>
      <div class="warning-green">BILLING STATEMENT ONLY. NOT A PAYMENT RECEIPT. CHECK EACH BILL STATUS BEFORE PAYMENT.</div>
    </div>
    <div class="footer-row">
      <div class="footer-left"><strong>${h(accountName.toUpperCase())}&nbsp;&nbsp;&nbsp;${h(accountNo)}</strong><br>Billing Month: ${h(invoice.billingMonth)} &nbsp; | &nbsp; Payment Status: ${h(invoice.paymentStatus)}</div>
      <div class="footer-right">SYSTEM-GENERATED BILL COPY<br>Generated via KuryentePay &nbsp; | &nbsp; Record ID ${h((invoice.billId ?? '-').toString())}</div>
    </div>
  </div>
</section>
$priorAddendum
</body>
</html>''';
  }

  Future<Uint8List> _buildCurrentBillPdfFallback(_InvoiceSnapshot invoice) async {
    final pw.Document document = pw.Document(
      title: 'Electric Bill Statement - ${invoice.accountNo}',
      author: 'KuryentePay',
      subject: 'KuryentePay electric bill statement ${invoice.billNo}',
      creator: 'KuryentePay Mobile Application',
    );

    final PdfColor green = PdfColor.fromHex('#087F79');
    final PdfColor greenDark = PdfColor.fromHex('#102F3E');
    final PdfColor greenLine = PdfColor.fromHex('#83A9B1');
    final PdfColor categoryPale = PdfColor.fromHex('#D9EFF2');
    final PdfColor greenPale = PdfColor.fromHex('#E7F3F1');
    final PdfColor headingPale = PdfColor.fromHex('#E8F4F2');
    final PdfColor subtotalPale = PdfColor.fromHex('#E8F4F2');
    final PdfColor paper = PdfColor.fromHex('#FAFCFD');
    final PdfColor aqua = PdfColor.fromHex('#D9EFF2');
    final PdfColor ink = PdfColors.black;
    final PdfColor softWhite = PdfColor.fromHex('#FAFCFD');

    final pw.MemoryImage logo = pw.MemoryImage(
      base64Decode(_kuryentePayBillLogoBase64),
    );

    final pw.Font dotMatrixFont = pw.Font.courier();
    final pw.Font dotMatrixBoldFont = pw.Font.courierBold();
    final pw.Font headingFont = pw.Font.helvetica();
    final pw.Font headingBoldFont = pw.Font.helveticaBold();

    pw.TextStyle dotStyle(
        double size, {
          bool bold = false,
          PdfColor? color,
          double? lineSpacing,
        }) {
      return pw.TextStyle(
        font: bold ? dotMatrixBoldFont : dotMatrixFont,
        fontSize: size,
        color: color ?? ink,
        lineSpacing: lineSpacing,
      );
    }

    pw.TextStyle sansStyle(
        double size, {
          bool bold = false,
          PdfColor? color,
          double? lineSpacing,
        }) {
      return pw.TextStyle(
        font: bold ? headingBoldFont : headingFont,
        fontSize: size,
        color: color ?? ink,
        lineSpacing: lineSpacing,
      );
    }

    pw.Widget accountCell(
        String text, {
          required double height,
          required bool header,
          required bool drawRight,
          required bool drawBottom,
        }) {
      return pw.Container(
        height: height,
        alignment: pw.Alignment.center,
        padding: pw.EdgeInsets.symmetric(
          horizontal: 0.5 * PdfPageFormat.mm,
          vertical: header ? 0.3 * PdfPageFormat.mm : 0.35 * PdfPageFormat.mm,
        ),
        decoration: pw.BoxDecoration(
          color: header ? greenDark : softWhite,
          border: pw.Border(
            right: drawRight
                ? pw.BorderSide(
              color: greenLine,
              width: 0.35 * PdfPageFormat.mm,
            )
                : const pw.BorderSide(width: 0),
            bottom: drawBottom
                ? pw.BorderSide(
              color: greenLine,
              width: 0.35 * PdfPageFormat.mm,
            )
                : const pw.BorderSide(width: 0),
          ),
        ),
        child: pw.Text(
          text,
          textAlign: pw.TextAlign.center,
          maxLines: 2,
          style: header
              ? sansStyle(7.7, bold: true, color: PdfColors.white)
              : dotStyle(8.8, bold: true, color: ink),
        ),
      );
    }

    pw.Widget accountRow(
        List<String> values, {
          required bool header,
        }) {
      const List<int> flexes = <int>[105, 155, 45, 83];
      final double height =
          (header ? 4.8 : 6.5) * PdfPageFormat.mm;
      return pw.Table(
        columnWidths: <int, pw.TableColumnWidth>{
          for (int index = 0; index < flexes.length; index++)
            index: pw.FlexColumnWidth(flexes[index].toDouble()),
        },
        defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
        children: <pw.TableRow>[
          pw.TableRow(
            children: <pw.Widget>[
              for (int index = 0; index < values.length; index++)
                accountCell(
                  values[index],
                  height: height,
                  header: header,
                  drawRight: index != values.length - 1,
                  drawBottom: header,
                ),
            ],
          ),
        ],
      );
    }

    pw.Widget rateRightRow({
      required String componentText,
      required String componentUnit,
      required String rateText,
      required String amountText,
      required double height,
      bool heading = false,
      bool subtotal = false,
      bool current = false,
    }) {
      final PdfColor background = subtotal
          ? subtotalPale
          : heading
          ? headingPale
          : softWhite;
      final bool emphasize = heading || subtotal || current;
      final double leftPadding = heading
          ? 5.2 * PdfPageFormat.mm
          : current
          ? 4 * PdfPageFormat.mm
          : 0.5 * PdfPageFormat.mm;

      pw.Widget componentCell() {
        pw.Widget content;

        if (subtotal) {
          content = pw.Center(
            child: pw.Text(
              componentText,
              textAlign: pw.TextAlign.center,
              maxLines: 1,
              style: sansStyle(6.85, bold: true, color: greenDark),
            ),
          );
        } else if (componentUnit.trim().isEmpty) {
          content = pw.Align(
            alignment: pw.Alignment.centerLeft,
            child: pw.Text(
              componentText,
              maxLines: 1,
              style: dotStyle(6.85, bold: emphasize, color: ink),
            ),
          );
        } else {
          // Match the web bill's .component-line flex layout directly.
          // Do not nest a pw.Table inside these very short 2.8 mm rows: the
          // PDF layout engine can clip the entire cell when the nested table
          // cannot satisfy the row height. A Row keeps both the component
          // name and its right-aligned unit visible.
          content = pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: <pw.Widget>[
              pw.Expanded(
                child: pw.Text(
                  componentText,
                  maxLines: 1,
                  style: dotStyle(6.85, bold: emphasize, color: ink),
                ),
              ),
              pw.SizedBox(width: 1.5 * PdfPageFormat.mm),
              pw.Text(
                componentUnit,
                maxLines: 1,
                textAlign: pw.TextAlign.right,
                style: dotStyle(5.95, color: ink),
              ),
            ],
          );
        }

        return pw.Container(
          height: height,
          alignment: pw.Alignment.centerLeft,
          padding: pw.EdgeInsets.fromLTRB(
            leftPadding,
            0.14 * PdfPageFormat.mm,
            0.5 * PdfPageFormat.mm,
            0.14 * PdfPageFormat.mm,
          ),
          decoration: pw.BoxDecoration(
            color: background,
            border: pw.Border(
              right: pw.BorderSide(
                color: greenLine,
                width: 0.25 * PdfPageFormat.mm,
              ),
              bottom: pw.BorderSide(
                color: greenLine,
                width: 0.25 * PdfPageFormat.mm,
              ),
            ),
          ),
          child: content,
        );
      }

      pw.Widget numericCell(
          String text, {
            required bool drawRight,
          }) {
        return pw.Container(
          height: height,
          alignment: pw.Alignment.centerRight,
          padding: pw.EdgeInsets.fromLTRB(
            0.3 * PdfPageFormat.mm,
            0.14 * PdfPageFormat.mm,
            1.05 * PdfPageFormat.mm,
            0.14 * PdfPageFormat.mm,
          ),
          decoration: pw.BoxDecoration(
            color: background,
            border: pw.Border(
              right: drawRight
                  ? pw.BorderSide(
                color: greenLine,
                width: 0.25 * PdfPageFormat.mm,
              )
                  : const pw.BorderSide(width: 0),
              bottom: pw.BorderSide(
                color: greenLine,
                width: 0.25 * PdfPageFormat.mm,
              ),
            ),
          ),
          child: pw.Text(
            text,
            maxLines: 1,
            textAlign: pw.TextAlign.right,
            style: dotStyle(6.85, bold: true, color: ink),
          ),
        );
      }

      return pw.Table(
        columnWidths: const <int, pw.TableColumnWidth>{
          0: pw.FlexColumnWidth(508),
          1: pw.FlexColumnWidth(182),
          2: pw.FlexColumnWidth(198),
        },
        defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
        children: <pw.TableRow>[
          pw.TableRow(
            children: <pw.Widget>[
              componentCell(),
              numericCell(rateText, drawRight: true),
              numericCell(amountText, drawRight: false),
            ],
          ),
        ],
      );
    }

    pw.Widget rateGroup(
        _InvoiceCategory category, {
          required bool includeBillTotals,
          required bool showSubtotal,
        }) {
      final String code = category.code.trim().toUpperCase();
      final bool isLifeline = code == 'LIFELINE_SUBSIDY_ADJUSTMENT';
      final List<pw.Widget> rightRows = <pw.Widget>[];
      double groupHeight = 0;

      for (int index = 0; index < category.rows.length; index++) {
        final _InvoiceLine line = category.rows[index];
        final double rowHeight =
            (isLifeline && index == 0 ? 4.8 : 2.8) * PdfPageFormat.mm;
        groupHeight += rowHeight;
        rightRows.add(
          rateRightRow(
            componentText: line.componentName.trim().isEmpty
                ? (line.isHeading ? 'CHARGE HEADING' : 'RATE COMPONENT')
                : line.componentName.toUpperCase(),
            componentUnit:
            line.isHeading ? '' : _ilecoRateUnitLabel(line.rateUnit),
            rateText: line.isHeading ? '-' : _ilecoRateValue(line),
            amountText: line.isHeading ? '-' : _ilecoAmountValue(line),
            height: rowHeight,
            heading: line.isHeading,
          ),
        );
      }

      if (showSubtotal) {
        final double rowHeight = 2.8 * PdfPageFormat.mm;
        groupHeight += rowHeight;
        rightRows.add(
          rateRightRow(
            componentText: 'SUB-TOTAL',
            componentUnit: '',
            rateText: '',
            amountText: _ilecoNumber(category.subtotal, decimals: 2),
            height: rowHeight,
            subtotal: true,
          ),
        );
      }

      if (includeBillTotals) {
        final List<List<String>> totalRows = <List<String>>[
          <String>[
            'Current Amount Due',
            _ilecoNumber(invoice.currentAmountDue, decimals: 2),
          ],
          <String>[
            'Unpaid Bill/s',
            _ilecoNumber(invoice.unpaidBills, decimals: 2),
          ],
        ];

        for (final List<String> row in totalRows) {
          final double rowHeight = 2.8 * PdfPageFormat.mm;
          groupHeight += rowHeight;
          rightRows.add(
            rateRightRow(
              componentText: row[0],
              componentUnit: '',
              rateText: '',
              amountText: row[1],
              height: rowHeight,
              current: true,
            ),
          );
        }
      }

      if (rightRows.isEmpty) {
        final double rowHeight = 2.8 * PdfPageFormat.mm;
        groupHeight = rowHeight;
        rightRows.add(
          rateRightRow(
            componentText: 'NO SAVED CHARGE ROWS FOUND.',
            componentUnit: '',
            rateText: '-',
            amountText: '-',
            height: rowHeight,
          ),
        );
      }

      final String label = _ilecoCategoryLabel(code, category.label);
      final bool compact = code != 'OTHERS';

      final pw.Widget categoryCell = pw.Container(
        height: groupHeight,
        alignment: pw.Alignment.center,
        padding: pw.EdgeInsets.symmetric(
          horizontal: 0.35 * PdfPageFormat.mm,
          vertical: 0.2 * PdfPageFormat.mm,
        ),
        decoration: pw.BoxDecoration(
          color: categoryPale,
          border: pw.Border(
            right: pw.BorderSide(
              color: greenLine,
              width: 0.25 * PdfPageFormat.mm,
            ),
            bottom: pw.BorderSide(
              color: greenLine,
              width: 0.25 * PdfPageFormat.mm,
            ),
          ),
        ),
        child: pw.Text(
          label,
          textAlign: pw.TextAlign.center,
          style: sansStyle(
            compact ? 5.15 : 5.6,
            bold: true,
            color: greenDark,
            lineSpacing: 0.25,
          ),
        ),
      );

      return pw.Table(
        columnWidths: const <int, pw.TableColumnWidth>{
          0: pw.FlexColumnWidth(112),
          1: pw.FlexColumnWidth(888),
        },
        defaultVerticalAlignment: pw.TableCellVerticalAlignment.top,
        children: <pw.TableRow>[
          pw.TableRow(
            children: <pw.Widget>[
              categoryCell,
              pw.Column(
                mainAxisSize: pw.MainAxisSize.min,
                children: rightRows,
              ),
            ],
          ),
        ],
      );
    }

    pw.Widget syntheticRateGroup({
      required String categoryLabel,
      required List<List<String>> rows,
    }) {
      final double rowHeight = 2.8 * PdfPageFormat.mm;
      final double groupHeight = rowHeight * rows.length;

      return pw.Table(
        columnWidths: const <int, pw.TableColumnWidth>{
          0: pw.FlexColumnWidth(112),
          1: pw.FlexColumnWidth(888),
        },
        defaultVerticalAlignment: pw.TableCellVerticalAlignment.top,
        children: <pw.TableRow>[
          pw.TableRow(
            children: <pw.Widget>[
              pw.Container(
                height: groupHeight,
                alignment: pw.Alignment.center,
                padding: pw.EdgeInsets.symmetric(
                  horizontal: 0.35 * PdfPageFormat.mm,
                  vertical: 0.2 * PdfPageFormat.mm,
                ),
                decoration: pw.BoxDecoration(
                  color: categoryPale,
                  border: pw.Border(
                    right: pw.BorderSide(
                      color: greenLine,
                      width: 0.25 * PdfPageFormat.mm,
                    ),
                    bottom: pw.BorderSide(
                      color: greenLine,
                      width: 0.25 * PdfPageFormat.mm,
                    ),
                  ),
                ),
                child: pw.Text(
                  categoryLabel,
                  textAlign: pw.TextAlign.center,
                  style: sansStyle(
                    5.15,
                    bold: true,
                    color: greenDark,
                    lineSpacing: 0.25,
                  ),
                ),
              ),
              pw.Column(
                mainAxisSize: pw.MainAxisSize.min,
                children: <pw.Widget>[
                  for (final List<String> row in rows)
                    rateRightRow(
                      componentText: row[0],
                      componentUnit: '',
                      rateText: row[1],
                      amountText: row[2],
                      height: rowHeight,
                      current: row[0] == 'Current Amount Due' ||
                          row[0] == 'Unpaid Bill/s',
                    ),
                ],
              ),
            ],
          ),
        ],
      );
    }

    final List<pw.Widget> rateGroups = <pw.Widget>[];
    final Set<String> subtotalCategories = <String>{
      'GENERATION_TRANSMISSION',
      'DISTRIBUTION_REVENUES',
      'OTHERS',
      'GOVERNMENT_REVENUES',
    };
    bool billTotalsRendered = false;

    if (invoice.categories.isEmpty) {
      rateGroups.add(
        syntheticRateGroup(
          categoryLabel: 'BILL',
          rows: const <List<String>>[
            <String>['NO SAVED CHARGE ROWS FOUND.', '-', '-'],
          ],
        ),
      );
    } else {
      for (final _InvoiceCategory category in invoice.categories) {
        final String code = category.code.trim().toUpperCase();
        final bool includeBillTotals = code == 'COOP_OTHER_CHARGES';
        rateGroups.add(
          rateGroup(
            category,
            includeBillTotals: includeBillTotals,
            showSubtotal: subtotalCategories.contains(code),
          ),
        );
        if (includeBillTotals) {
          billTotalsRendered = true;
        }
      }
    }

    if (!billTotalsRendered) {
      rateGroups.add(
        syntheticRateGroup(
          categoryLabel: 'COOP OTHER\nCHARGES',
          rows: <List<String>>[
            <String>[
              'Current Amount Due',
              '',
              _ilecoNumber(invoice.currentAmountDue, decimals: 2),
            ],
            <String>[
              'Unpaid Bill/s',
              '',
              _ilecoNumber(invoice.unpaidBills, decimals: 2),
            ],
          ],
        ),
      );
    }

    final List<String> fromParts = _ilecoDateParts(invoice.periodFrom);
    final List<String> toParts = _ilecoDateParts(invoice.periodTo);
    final String accountName = invoice.consumerName.trim().isEmpty
        ? widget.nickname.trim()
        : invoice.consumerName.trim();
    final String address = invoice.consumerAddress.trim().isEmpty
        ? widget.address.trim()
        : invoice.consumerAddress.trim();
    final String accountNo = invoice.accountNo.trim().isEmpty
        ? widget.accountNo.trim()
        : invoice.accountNo.trim();
    final String billNo = invoice.billNo.trim().isEmpty ? '-' : invoice.billNo.trim();

    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(13 * PdfPageFormat.mm),
        theme: pw.ThemeData.withFont(
          base: dotMatrixFont,
          bold: dotMatrixBoldFont,
        ),
        build: (pw.Context context) {
          return pw.Stack(
            children: <pw.Widget>[
              pw.Container(
                height: 258 * PdfPageFormat.mm,
                color: paper,
                padding: pw.EdgeInsets.fromLTRB(
                  7 * PdfPageFormat.mm,
                  2 * PdfPageFormat.mm,
                  7 * PdfPageFormat.mm,
                  2 * PdfPageFormat.mm,
                ),
                child: pw.Container(
                  height: 254 * PdfPageFormat.mm,
                  padding: pw.EdgeInsets.fromLTRB(
                    1.3 * PdfPageFormat.mm,
                    1.1 * PdfPageFormat.mm,
                    1.3 * PdfPageFormat.mm,
                    1.1 * PdfPageFormat.mm,
                  ),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(
                      color: PdfColor.fromHex('#087F79'),
                      width: 0.85 * PdfPageFormat.mm,
                    ),
                    borderRadius: pw.BorderRadius.circular(
                      1.4 * PdfPageFormat.mm,
                    ),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: <pw.Widget>[
                      pw.SizedBox(
                        height: 20 * PdfPageFormat.mm,
                        child: pw.Row(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: <pw.Widget>[
                            pw.SizedBox(
                              width: 19 * PdfPageFormat.mm,
                              child: pw.Align(
                                alignment: pw.Alignment.topCenter,
                                child: pw.Image(
                                  logo,
                                  width: 15.5 * PdfPageFormat.mm,
                                  height: 14.2 * PdfPageFormat.mm,
                                ),
                              ),
                            ),
                            pw.Expanded(
                              child: pw.Padding(
                                padding: pw.EdgeInsets.only(
                                  top: 0.5 * PdfPageFormat.mm,
                                  left: 1 * PdfPageFormat.mm,
                                  right: 1 * PdfPageFormat.mm,
                                ),
                                child: pw.Column(
                                  children: <pw.Widget>[
                                    pw.Text(
                                      'KuryentePay',
                                      textAlign: pw.TextAlign.center,
                                      maxLines: 1,
                                      style: sansStyle(
                                        13.6,
                                        bold: true,
                                        color: greenDark,
                                      ),
                                    ),
                                    pw.SizedBox(
                                      height: 0.55 * PdfPageFormat.mm,
                                    ),
                                    pw.Text(
                                      'ELECTRIC BILLING & PAYMENT',
                                      style: sansStyle(8.5, bold: true),
                                    ),
                                    pw.SizedBox(
                                      height: 0.4 * PdfPageFormat.mm,
                                    ),
                                    pw.Text(
                                      'BILLING STATEMENT - SAVED BILL RECORD',
                                      style: sansStyle(7.8, bold: true),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            pw.SizedBox(
                              width: 35 * PdfPageFormat.mm,
                              child: pw.Padding(
                                padding: pw.EdgeInsets.only(
                                  top: 0.7 * PdfPageFormat.mm,
                                  right: 1 * PdfPageFormat.mm,
                                ),
                                child: pw.Column(
                                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                                  children: <pw.Widget>[
                                    pw.SizedBox(
                                      height: 3.5 * PdfPageFormat.mm,
                                      child: pw.Text(
                                        'BILL REFERENCE',
                                        maxLines: 1,
                                        style: dotStyle(
                                          9.4,
                                          bold: true,
                                        ),
                                      ),
                                    ),
                                    pw.SizedBox(
                                      height: 0.7 * PdfPageFormat.mm,
                                    ),
                                    pw.Row(
                                      mainAxisAlignment:
                                      pw.MainAxisAlignment.end,
                                      crossAxisAlignment:
                                      pw.CrossAxisAlignment.end,
                                      children: <pw.Widget>[
                                        pw.Text(
                                          'No. ',
                                          style: sansStyle(
                                            8.6,
                                            bold: true,
                                            color: greenDark,
                                          ),
                                        ),
                                        pw.Text(
                                          billNo,
                                          style: dotStyle(
                                            10.5,
                                            bold: true,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      pw.Padding(
                        padding: pw.EdgeInsets.fromLTRB(
                          2 * PdfPageFormat.mm,
                          0,
                          0,
                          0.55 * PdfPageFormat.mm,
                        ),
                        child: pw.Text(
                          'Billing Date: ${_ilecoDisplayDate(invoice.createdAt)}',
                          style: dotStyle(8.6, bold: true),
                        ),
                      ),
                      pw.Container(
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(
                            color: greenLine,
                            width: 0.45 * PdfPageFormat.mm,
                          ),
                          borderRadius: pw.BorderRadius.circular(
                            1.8 * PdfPageFormat.mm,
                          ),
                        ),
                        child: pw.Column(
                          children: <pw.Widget>[
                            accountRow(
                              const <String>[
                                'ACCOUNT NUMBER',
                                'METER S/N',
                                'TYPE',
                                'DUE DATE',
                              ],
                              header: true,
                            ),
                            accountRow(
                              <String>[
                                accountNo,
                                invoice.meterSerialNo.trim().isEmpty
                                    ? '-'
                                    : invoice.meterSerialNo.trim(),
                                '-',
                                _ilecoNumericDate(invoice.dueDate),
                              ],
                              header: false,
                            ),
                          ],
                        ),
                      ),
                      pw.SizedBox(height: 1 * PdfPageFormat.mm),
                      pw.SizedBox(
                        height: 15.3 * PdfPageFormat.mm,
                        child: pw.Row(
                          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                          children: <pw.Widget>[
                            pw.Expanded(
                              child: pw.Container(
                                padding: pw.EdgeInsets.fromLTRB(
                                  1.4 * PdfPageFormat.mm,
                                  0.55 * PdfPageFormat.mm,
                                  1.4 * PdfPageFormat.mm,
                                  0.7 * PdfPageFormat.mm,
                                ),
                                decoration: pw.BoxDecoration(
                                  color: softWhite,
                                  border: pw.Border.all(
                                    color: greenLine,
                                    width: 0.45 * PdfPageFormat.mm,
                                  ),
                                  borderRadius: pw.BorderRadius.circular(
                                    1.8 * PdfPageFormat.mm,
                                  ),
                                ),
                                child: pw.Column(
                                  crossAxisAlignment:
                                  pw.CrossAxisAlignment.start,
                                  children: <pw.Widget>[
                                    pw.Text(
                                      'NAME / ADDRESS',
                                      style: sansStyle(
                                        7.1,
                                        bold: true,
                                        color: greenDark,
                                      ),
                                    ),
                                    pw.SizedBox(
                                      height: 0.55 * PdfPageFormat.mm,
                                    ),
                                    pw.Padding(
                                      padding: pw.EdgeInsets.only(
                                        left: 2.5 * PdfPageFormat.mm,
                                      ),
                                      child: pw.Text(
                                        '${accountName.toUpperCase()}\n${address.toUpperCase()}',
                                        maxLines: 2,
                                        style: dotStyle(
                                          8.25,
                                          bold: true,
                                          lineSpacing: 0.45,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            pw.SizedBox(width: 1.4 * PdfPageFormat.mm),
                            pw.SizedBox(
                              width: 34 * PdfPageFormat.mm,
                              child: pw.Container(
                                decoration: pw.BoxDecoration(
                                  border: pw.Border.all(
                                    color: greenLine,
                                    width: 0.45 * PdfPageFormat.mm,
                                  ),
                                  borderRadius: pw.BorderRadius.circular(
                                    1.8 * PdfPageFormat.mm,
                                  ),
                                ),
                                child: pw.Column(
                                  children: <pw.Widget>[
                                    pw.Container(
                                      height: 5.2 * PdfPageFormat.mm,
                                      alignment: pw.Alignment.center,
                                      decoration: pw.BoxDecoration(
                                        color: aqua,
                                        border: pw.Border(
                                          bottom: pw.BorderSide(
                                            color: greenLine,
                                            width: 0.35 * PdfPageFormat.mm,
                                          ),
                                        ),
                                      ),
                                      child: pw.Text(
                                        'MULTIPLIER',
                                        style: sansStyle(
                                          7.6,
                                          bold: true,
                                          color: greenDark,
                                        ),
                                      ),
                                    ),
                                    pw.Expanded(
                                      child: pw.Container(
                                        alignment: pw.Alignment.center,
                                        color: softWhite,
                                        child: pw.Text(
                                          '-',
                                          style: dotStyle(9.2, bold: true),
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
                      pw.SizedBox(height: 0.7 * PdfPageFormat.mm),
                      pw.Center(
                        child: pw.Text(
                          'ELECTRIC BILL STATEMENT',
                          style: sansStyle(
                            11.8,
                            bold: true,
                            color: green,
                          ),
                        ),
                      ),
                      pw.SizedBox(height: 0.4 * PdfPageFormat.mm),
                      _ilecoUsageSummary(
                        fromParts: fromParts,
                        toParts: toParts,
                        readingPresent: _ilecoNullableNumber(
                          invoice.readingPresent,
                          decimals: 1,
                        ),
                        readingPrevious: _ilecoNullableNumber(
                          invoice.readingPrevious,
                          decimals: 1,
                        ),
                        kwhUsed: _ilecoNullableNumber(
                          invoice.kwhUsed,
                          decimals: 1,
                        ),
                        demandKw: _ilecoNumber(
                          invoice.billingDemandKw ?? 0,
                          decimals: 3,
                        ),
                        yellow: aqua,
                        greenDark: greenDark,
                        greenLine: greenLine,
                        softWhite: softWhite,
                        ink: ink,
                      ),
                      pw.SizedBox(height: 0.75 * PdfPageFormat.mm),
                      pw.Container(
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(
                            color: greenLine,
                            width: 0.45 * PdfPageFormat.mm,
                          ),
                          borderRadius: pw.BorderRadius.circular(
                            1.5 * PdfPageFormat.mm,
                          ),
                        ),
                        child: pw.Column(
                          children: <pw.Widget>[
                            pw.SizedBox(
                              height: 4.15 * PdfPageFormat.mm,
                              child: pw.Table(
                                columnWidths: const <int, pw.TableColumnWidth>{
                                  0: pw.FlexColumnWidth(112),
                                  1: pw.FlexColumnWidth(508),
                                  2: pw.FlexColumnWidth(182),
                                  3: pw.FlexColumnWidth(198),
                                },
                                defaultVerticalAlignment:
                                pw.TableCellVerticalAlignment.middle,
                                children: <pw.TableRow>[
                                  pw.TableRow(
                                    children: <pw.Widget>[
                                      pw.Container(
                                        height: 4.15 * PdfPageFormat.mm,
                                        decoration: pw.BoxDecoration(
                                          color: green,
                                          border: pw.Border(
                                            right: pw.BorderSide(
                                              color: greenLine,
                                              width: 0.3 * PdfPageFormat.mm,
                                            ),
                                            bottom: pw.BorderSide(
                                              color: greenLine,
                                              width: 0.3 * PdfPageFormat.mm,
                                            ),
                                          ),
                                        ),
                                      ),
                                      for (final List<Object> column
                                      in <List<Object>>[
                                        <Object>[508, 'RATE COMPONENT', true],
                                        <Object>[182, 'RATE', true],
                                        <Object>[198, 'AMOUNT', false],
                                      ])
                                        pw.Container(
                                          height: 4.15 * PdfPageFormat.mm,
                                          alignment: pw.Alignment.center,
                                          decoration: pw.BoxDecoration(
                                            color: green,
                                            border: pw.Border(
                                              right: column[2] as bool
                                                  ? pw.BorderSide(
                                                color: greenLine,
                                                width: 0.3 *
                                                    PdfPageFormat.mm,
                                              )
                                                  : const pw.BorderSide(width: 0),
                                              bottom: pw.BorderSide(
                                                color: greenLine,
                                                width: 0.3 * PdfPageFormat.mm,
                                              ),
                                            ),
                                          ),
                                          child: pw.Text(
                                            column[1] as String,
                                            style: sansStyle(
                                              7.15,
                                              bold: true,
                                              color: PdfColors.white,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            ...rateGroups,
                          ],
                        ),
                      ),
                      pw.SizedBox(height: 0.65 * PdfPageFormat.mm),
                      pw.Container(
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(
                            color: greenLine,
                            width: 0.45 * PdfPageFormat.mm,
                          ),
                          borderRadius: pw.BorderRadius.circular(
                            1.8 * PdfPageFormat.mm,
                          ),
                        ),
                        child: pw.Table(
                          columnWidths: const <int, pw.TableColumnWidth>{
                            0: pw.FlexColumnWidth(618),
                            1: pw.FlexColumnWidth(382),
                          },
                          defaultVerticalAlignment:
                          pw.TableCellVerticalAlignment.middle,
                          children: <pw.TableRow>[
                            pw.TableRow(
                              children: <pw.Widget>[
                                pw.Container(
                                  height: 6.8 * PdfPageFormat.mm,
                                  alignment: pw.Alignment.center,
                                  color: greenDark,
                                  child: pw.Text(
                                    invoice.statementPriorItems.isNotEmpty
                                        ? 'THIS BILL AMOUNT DUE   >>>'
                                        : 'TOTAL AMOUNT DUE   >>>',
                                    style: sansStyle(
                                      9.6,
                                      bold: true,
                                      color: PdfColors.white,
                                    ),
                                  ),
                                ),
                                pw.Container(
                                  height: 6.8 * PdfPageFormat.mm,
                                  alignment: pw.Alignment.centerRight,
                                  padding: pw.EdgeInsets.only(
                                    right: 4 * PdfPageFormat.mm,
                                  ),
                                  color: greenPale,
                                  child: pw.Text(
                                    'PHP ${_ilecoNumber(invoice.totalAmountDue, decimals: 2)}',
                                    style: dotStyle(12.8, bold: true),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      pw.SizedBox(height: 0.65 * PdfPageFormat.mm),
                      pw.SizedBox(
                        height: 8.6 * PdfPageFormat.mm,
                        child: pw.Row(
                          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                          children: <pw.Widget>[
                            pw.Expanded(
                              flex: 59,
                              child: pw.Container(
                                padding: pw.EdgeInsets.symmetric(
                                  horizontal: 1.4 * PdfPageFormat.mm,
                                  vertical: 0.7 * PdfPageFormat.mm,
                                ),
                                decoration: pw.BoxDecoration(
                                  color: PdfColor.fromHex('#E4F5F6'),
                                  border: pw.Border.all(
                                    color: greenLine,
                                    width: 0.45 * PdfPageFormat.mm,
                                  ),
                                  borderRadius: pw.BorderRadius.circular(
                                    1.6 * PdfPageFormat.mm,
                                  ),
                                ),
                                child: pw.Text(
                                  'PLEASE PAY BY THE DUE DATE SHOWN. FOR OVERDUE BILLS, CONFIRM PAYMENT OPTIONS WITH THE OFFICE.',
                                  style: sansStyle(
                                    6.25,
                                    bold: true,
                                    color: greenDark,
                                    lineSpacing: 0.2,
                                  ),
                                ),
                              ),
                            ),
                            pw.SizedBox(width: 1 * PdfPageFormat.mm),
                            pw.Expanded(
                              flex: 41,
                              child: pw.Container(
                                padding: pw.EdgeInsets.symmetric(
                                  horizontal: 1.4 * PdfPageFormat.mm,
                                  vertical: 0.7 * PdfPageFormat.mm,
                                ),
                                decoration: pw.BoxDecoration(
                                  color: greenDark,
                                  border: pw.Border.all(
                                    color: greenLine,
                                    width: 0.45 * PdfPageFormat.mm,
                                  ),
                                  borderRadius: pw.BorderRadius.circular(
                                    1.6 * PdfPageFormat.mm,
                                  ),
                                ),
                                child: pw.Text(
                                  'BILLING STATEMENT ONLY. NOT A PAYMENT RECEIPT. CHECK EACH BILL STATUS BEFORE PAYMENT.',
                                  style: sansStyle(
                                    6.25,
                                    bold: true,
                                    color: PdfColors.white,
                                    lineSpacing: 0.2,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      pw.SizedBox(height: 0.55 * PdfPageFormat.mm),
                      pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: <pw.Widget>[
                          pw.Expanded(
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: <pw.Widget>[
                                pw.Text(
                                  '${accountName.toUpperCase()}   $accountNo',
                                  style: dotStyle(6.2, bold: true),
                                ),
                                pw.Text(
                                  'Billing Month: ${invoice.billingMonth}   |   Payment Status: ${invoice.paymentStatus}',
                                  style: dotStyle(5.6),
                                ),
                              ],
                            ),
                          ),
                          pw.Text(
                            'SYSTEM-GENERATED BILL COPY\nGenerated via KuryentePay   |   Record ID ${invoice.billId ?? '-'}',
                            textAlign: pw.TextAlign.right,
                            style: sansStyle(5.6, lineSpacing: 0.2),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              pw.Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: _ilecoTractorStrip(
                  stripColor: PdfColor.fromHex('#F4F7FA'),
                  holeColor: PdfColors.white,
                  borderColor: PdfColor.fromHex('#B4C6CA'),
                ),
              ),
              pw.Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                child: _ilecoTractorStrip(
                  stripColor: PdfColor.fromHex('#F4F7FA'),
                  holeColor: PdfColors.white,
                  borderColor: PdfColor.fromHex('#B4C6CA'),
                ),
              ),
            ],
          );
        },
      ),
    );

    if (invoice.statementPriorItems.isNotEmpty) {
      final PdfColor inkNavy = PdfColor.fromHex('#102F3E');
      final PdfColor tealAccent = PdfColor.fromHex('#087F79');
      final PdfColor mutedInk = PdfColor.fromHex('#47646F');
      final PdfColor paleAqua = PdfColor.fromHex('#E7F3F1');
      pw.Widget line(String label, String amount, {bool strong = false}) {
        return pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 4),
          child: pw.Row(
            children: <pw.Widget>[
              pw.Expanded(
                child: pw.Text(
                  label,
                  style: pw.TextStyle(
                    font: strong ? pw.Font.helveticaBold() : pw.Font.helvetica(),
                    color: inkNavy,
                    fontSize: strong ? 11 : 9,
                  ),
                ),
              ),
              pw.Text(
                amount,
                style: pw.TextStyle(
                  font: pw.Font.helveticaBold(),
                  color: inkNavy,
                  fontSize: strong ? 11 : 9,
                ),
              ),
            ],
          ),
        );
      }

      document.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.all(17 * PdfPageFormat.mm),
          theme: pw.ThemeData.withFont(
            base: pw.Font.helvetica(),
            bold: pw.Font.helveticaBold(),
          ),
          build: (pw.Context context) => <pw.Widget>[
            pw.Text(
              'KuryentePay  |  BILLING STATEMENT ADDENDUM',
              style: pw.TextStyle(
                color: tealAccent,
                font: pw.Font.helveticaBold(),
                fontSize: 10,
              ),
            ),
            pw.SizedBox(height: 12),
            pw.Text(
              'PREVIOUS UNPAID BILLS SELECTED FOR STATEMENT',
              style: pw.TextStyle(
                color: inkNavy,
                font: pw.Font.helveticaBold(),
                fontSize: 16,
              ),
            ),
            pw.SizedBox(height: 12),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(10),
              color: paleAqua,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: <pw.Widget>[
                  pw.Text('Account: $accountNo'),
                  pw.Text('Current Bill Reference: $billNo'),
                  pw.Text('Billing Month: ${_formatBillingMonth(invoice.billingMonth)}'),
                  pw.Text('Meter S/N: ${invoice.meterSerialNo.isEmpty ? '-' : invoice.meterSerialNo}'),
                ],
              ),
            ),
            pw.SizedBox(height: 12),
            pw.Text(
              'Amounts below were outstanding when this statement was issued. They are historical snapshots and may not be the balances today.',
              style: pw.TextStyle(color: mutedInk, fontSize: 9.5),
            ),
            pw.SizedBox(height: 12),
            pw.Container(
              padding: const pw.EdgeInsets.all(9),
              color: inkNavy,
              child: pw.Row(
                children: <pw.Widget>[
                  pw.Expanded(flex: 4, child: pw.Text('BILL REFERENCE', style: pw.TextStyle(color: PdfColors.white, fontSize: 8, font: pw.Font.helveticaBold()))),
                  pw.Expanded(flex: 2, child: pw.Text('MONTH / DUE', style: pw.TextStyle(color: PdfColors.white, fontSize: 8, font: pw.Font.helveticaBold()))),
                  pw.Expanded(flex: 2, child: pw.Text('AT ISSUE', textAlign: pw.TextAlign.right, style: pw.TextStyle(color: PdfColors.white, fontSize: 8, font: pw.Font.helveticaBold()))),
                ],
              ),
            ),
            for (final _StatementPriorBill item in invoice.statementPriorItems)
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 9, horizontal: 7),
                decoration: pw.BoxDecoration(
                  border: pw.Border(bottom: pw.BorderSide(color: PdfColor.fromHex('#D2E2E5'), width: 0.6)),
                ),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: <pw.Widget>[
                    pw.Expanded(flex: 4, child: pw.Text(item.reference, style: pw.TextStyle(fontSize: 9))),
                    pw.Expanded(flex: 2, child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: <pw.Widget>[
                        pw.Text(_formatBillingMonth(item.billingMonth), style: pw.TextStyle(fontSize: 8.5)),
                        pw.Text(_ilecoDisplayDate(item.dueDate), style: pw.TextStyle(fontSize: 8)),
                      ],
                    )),
                    pw.Expanded(flex: 2, child: pw.Text('PHP ${_ilecoNumber(item.amountAtIssue, decimals: 2)}', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 9))),
                  ],
                ),
              ),
            pw.SizedBox(height: 13),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              color: paleAqua,
              child: pw.Column(
                children: <pw.Widget>[
                  line('This bill amount due', 'PHP ${_ilecoNumber(invoice.totalAmountDue, decimals: 2)}'),
                  line('Selected previous bills at issue', 'PHP ${_ilecoNumber(invoice.statementPreviousUnpaidAtIssue, decimals: 2)}'),
                  pw.Divider(color: tealAccent, thickness: 0.6),
                  line('Combined statement view at issue', 'PHP ${_ilecoNumber(invoice.statementCombinedAtIssue, decimals: 2)}', strong: true),
                ],
              ),
            ),
            pw.SizedBox(height: 12),
            pw.Text(
              'REFERENCE ONLY. The combined amount is NOT a new charge or a single payable bill. Pay each bill separately using its own reference and rules; check the latest payment status before paying. This is not a payment receipt.',
              style: pw.TextStyle(color: mutedInk, fontSize: 9),
            ),
          ],
        ),
      );
    }

    return document.save();
  }

  Future<void> _saveBillAsPdf() async {
    final _InvoiceSnapshot? invoice = _invoice;

    if (!_hasCurrentInvoice || invoice == null || _documentWorking) {
      _showMessage(
        'Load the complete bill before saving a PDF copy.',
      );
      return;
    }

    setState(() => _documentWorking = true);

    try {
      final Uint8List bytes = await _buildCurrentBillPdf(invoice);

      await Printing.sharePdf(
        bytes: bytes,
        filename: _billPdfFilename(invoice),
        subject: 'KuryentePay electric bill',
      );
    } catch (error, stackTrace) {
      debugPrint('KuryentePay bill PDF save failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        _showMessage(
          'Unable to prepare the PDF right now. Please try again.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _documentWorking = false);
      }
    }
  }

  Future<void> _printBill() async {
    final _InvoiceSnapshot? invoice = _invoice;

    if (!_hasCurrentInvoice || invoice == null || _documentWorking) {
      _showMessage(
        'Load the complete bill before printing.',
      );
      return;
    }

    setState(() => _documentWorking = true);

    try {
      final Uint8List bytes = await _buildCurrentBillPdf(invoice);

      await Printing.layoutPdf(
        name: _billPdfFilename(invoice),
        onLayout: (PdfPageFormat format) async => bytes,
      );
    } catch (error, stackTrace) {
      debugPrint('KuryentePay bill print failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        _showMessage(
          'Unable to open the print dialog right now. Please try again.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _documentWorking = false);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Widget _buildInvoiceSection() {
    if (_invoiceLoading) {
      return const _InvoiceLoadingCard();
    }

    if (_invoiceError != null) {
      return _InvoiceErrorCard(
        message: _invoiceError!,
        onRetry: () {
          _loadInvoice(
            showLoading: true,
            showErrorMessage: false,
          );
        },
      );
    }

    final _InvoiceSnapshot? invoice = _invoice;

    if (invoice == null ||
        !invoice.hasChargeSnapshot ||
        invoice.categories.isEmpty) {
      return const _InvoiceEmptyCard();
    }

    return _InvoiceBreakdownCard(
      invoice: invoice,
      showAllComponents: _showAllRateComponents,
      onShowAllChanged: (bool value) {
        setState(() => _showAllRateComponents = value);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final String displayDueDate = _formatBillDate(_dueDate);
    final int? daysBeforeDue = _daysBeforeDue;

    return Scaffold(
      backgroundColor: _BillPalette.background(context),
      body: Stack(
        children: [
          const _BillBackdrop(),
          SafeArea(
            bottom: false,
            child: RefreshIndicator(
              color: _BillPalette.primary(context),
              backgroundColor: _BillPalette.surface(context),
              onRefresh: _refreshBillStatus,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.fromLTRB(
                  16,
                  8,
                  16,
                  116,
                ),
                children: [
                  _BillHeader(
                    refreshing: _refreshing,
                    onBack: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(height: 14),
                  _AmountHeroCard(
                    nickname: widget.nickname,
                    accountNo: widget.accountNo,
                    address: widget.address,
                    amount: _amount,
                    dueDate: displayDueDate,
                    status: _displayPaymentStatus,
                    statusColor: _statusColor,
                    statusIcon: _statusIcon,
                    onCopyAccount: widget.accountNo.trim().isEmpty
                        ? null
                        : () => _copyText(
                      widget.accountNo,
                      'Account number copied.',
                    ),
                  ),
                  if (_officePaymentRequired) ...[
                    const SizedBox(height: 14),
                    OfficePaymentNotice(dueDate: _dueDate),
                  ] else if (_hasCurrentInvoice &&
                      (daysBeforeDue ?? 0) > 0) ...[
                    const SizedBox(height: 14),
                    _OnlinePaymentWindowNotice(
                      daysBeforeDue: daysBeforeDue!,
                      dueDate: BillPaymentDeadline.friendlyDueDate(_dueDate),
                    ),
                  ],
                  if (_invoice != null) ...[
                    const SizedBox(height: 14),
                    const _SectionHeading(
                      title: 'Meter Readings',
                      subtitle: 'Usage and meter information',
                    ),
                    const SizedBox(height: 8),
                    _MeterSummaryCard(invoice: _invoice!),
                  ],
                  const SizedBox(height: 16),
                  _SectionHeading(
                    title: 'Charge Breakdown',
                    subtitle: (_invoice?.chargeRowCount ?? 0) > 0
                        ? '${_invoice!.chargeRowCount} charge component${_invoice!.chargeRowCount == 1 ? '' : 's'}'
                        : 'Charges and amounts',
                  ),
                  const SizedBox(height: 8),
                  _buildInvoiceSection(),
                  const SizedBox(height: 10),
                  _BreakdownTransparencyNotice(
                    hasSnapshot: _invoice?.hasChargeSnapshot == true,
                    rowCount: _invoice?.chargeRowCount ?? 0,
                  ),
                  if (_invoice != null &&
                      _invoice!.statementPriorItems.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const _SectionHeading(
                      title: 'Previous Unpaid Bills',
                      subtitle: 'Selected for this statement when issued',
                    ),
                    const SizedBox(height: 8),
                    _PriorStatementCard(invoice: _invoice!),
                  ],
                  const SizedBox(height: 16),
                  const _SectionHeading(
                    title: 'Bill Copy',
                    subtitle: 'Save a PDF copy or print this bill',
                  ),
                  const SizedBox(height: 8),
                  _BillDocumentCard(
                    enabled: _hasCurrentInvoice && !_documentWorking,
                    busy: _documentWorking,
                    onSavePdf: _saveBillAsPdf,
                    onPrint: _printBill,
                  ),
                  const SizedBox(height: 16),
                  if (!_officePaymentRequired) ...[
                    const _SectionHeading(
                      title: 'Payment Information',
                      subtitle: 'How checkout and verification work',
                    ),
                    const SizedBox(height: 8),
                    const _PaymentSafetyCard(),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _PaymentBottomBar(
        amount: _amount,
        statusLabel: _displayPaymentStatus,
        buttonLabel: _paymentButtonLabel,
        canPay: _canPay,
        loading: _openingPayment,
        onPay: _goToPay,
      ),
    );
  }
}

class _InvoiceSnapshot {
  const _InvoiceSnapshot({
    required this.billId,
    required this.billNo,
    required this.billingMonth,
    required this.periodFrom,
    required this.periodTo,
    required this.meterSerialNo,
    required this.readingPresent,
    required this.readingPrevious,
    required this.kwhUsed,
    required this.billingDemandKw,
    required this.createdAt,
    required this.dueDate,
    required this.paymentStatus,
    required this.currentAmountDue,
    required this.unpaidBills,
    required this.totalAmountDue,
    required this.consumerName,
    required this.consumerAddress,
    required this.accountNo,
    required this.hasChargeSnapshot,
    required this.chargeRowCount,
    required this.categories,
    required this.statementPriorItems,
    required this.statementPreviousUnpaidAtIssue,
    required this.statementCombinedAtIssue,
  });

  final int? billId;
  final String billNo;
  final String billingMonth;
  final String periodFrom;
  final String periodTo;
  final String meterSerialNo;
  final double? readingPresent;
  final double? readingPrevious;
  final double? kwhUsed;
  final double? billingDemandKw;
  final String createdAt;
  final String dueDate;
  final String paymentStatus;
  final double currentAmountDue;
  final double unpaidBills;
  final double totalAmountDue;
  final String consumerName;
  final String consumerAddress;
  final String accountNo;
  final bool hasChargeSnapshot;
  final int chargeRowCount;
  final List<_InvoiceCategory> categories;
  final List<_StatementPriorBill> statementPriorItems;
  final double statementPreviousUnpaidAtIssue;
  final double statementCombinedAtIssue;

  factory _InvoiceSnapshot.fromBill(
      Map<String, dynamic> bill, {
        Map<String, dynamic> account = const <String, dynamic>{},
      }) {
    final List<_InvoiceCategory> categories = <_InvoiceCategory>[];
    final dynamic rawCategories = bill['charge_categories'];

    if (rawCategories is List) {
      for (final dynamic rawCategory in rawCategories) {
        if (rawCategory is Map) {
          final _InvoiceCategory category = _InvoiceCategory.fromMap(
            Map<String, dynamic>.from(rawCategory),
          );

          if (category.hasAnyContent) {
            categories.add(category);
          }
        }
      }
    }

    // Read the saved, server-authorized statement links. These are NOT
    // today's remaining balances, and are never passed to PayMongo.
    final List<_StatementPriorBill> statementPriorItems =
    <_StatementPriorBill>[];
    final dynamic rawStatementItems = bill['statement_prior_items'];
    if (rawStatementItems is List) {
      for (final dynamic rawItem in rawStatementItems) {
        if (rawItem is! Map) {
          throw const FormatException('Invalid previous-bill statement item.');
        }
        statementPriorItems.add(
          _StatementPriorBill.fromMap(Map<String, dynamic>.from(rawItem)),
        );
      }
    }

    final int previousCents = statementPriorItems.fold<int>(
      0,
          (int total, _StatementPriorBill item) =>
      total + (item.amountAtIssue * 100).round(),
    );
    final double currentBillPayable =
        _asDouble(bill['total_amount_due']) ?? 0;
    final double previousAtIssue = previousCents / 100;
    final double combinedAtIssue =
        ((currentBillPayable * 100).round() + previousCents) / 100;

    // If totals are sent, reject a mismatch rather than displaying invented
    // amounts. Older endpoints without statement fields remain compatible.
    if (statementPriorItems.isNotEmpty) {
      final double? serverPrior =
      _asDouble(bill['statement_previous_unpaid_at_issue']);
      final double? serverCombined =
      _asDouble(bill['statement_combined_at_issue']);
      if ((serverPrior != null &&
          (serverPrior - previousAtIssue).abs() > 0.011) ||
          (serverCombined != null &&
              (serverCombined - combinedAtIssue).abs() > 0.011)) {
        throw const FormatException(
          'Saved previous-bill statement totals need review.',
        );
      }
    }

    return _InvoiceSnapshot(
      billId: _asInt(bill['id'] ?? bill['bill_id']),
      billNo: _asText(bill['bill_no']),
      billingMonth: _asText(bill['billing_month']),
      periodFrom: _asText(bill['period_from']),
      periodTo: _asText(bill['period_to']),
      meterSerialNo: _asText(bill['meter_serial_no']),
      readingPresent: _asDouble(bill['reading_present']),
      readingPrevious: _asDouble(bill['reading_previous']),
      kwhUsed: _asDouble(bill['kwh_used']),
      billingDemandKw: _asDouble(bill['billing_demand_kw']),
      createdAt: _asText(bill['created_at']),
      dueDate: _asText(bill['due_date']),
      paymentStatus: _normaliseBillStatus(
        bill['payment_status'],
        isOverdue: bill['is_overdue'] == true,
      ),
      currentAmountDue: _asDouble(bill['current_amount_due']) ??
          _asDouble(bill['total_amount_due']) ??
          0,
      unpaidBills: _asDouble(bill['unpaid_bills']) ?? 0,
      totalAmountDue: _asDouble(bill['total_amount_due']) ?? 0,
      consumerName: _asText(account['name']),
      consumerAddress: _asText(account['address']),
      accountNo: _asText(account['account_no']),
      hasChargeSnapshot:
      bill['has_charge_snapshot'] == true || categories.isNotEmpty,
      chargeRowCount: _asInt(bill['charge_row_count']) ??
          categories.fold<int>(
            0,
                (int count, _InvoiceCategory category) =>
            count + category.rows.length,
          ),
      categories: categories,
      statementPriorItems: List<_StatementPriorBill>.unmodifiable(
        statementPriorItems,
      ),
      statementPreviousUnpaidAtIssue: previousAtIssue,
      statementCombinedAtIssue: combinedAtIssue,
    );
  }
}

class _StatementPriorBill {
  const _StatementPriorBill({
    required this.billId,
    required this.reference,
    required this.billingMonth,
    required this.dueDate,
    required this.amountAtIssue,
  });

  final int billId;
  final String reference;
  final String billingMonth;
  final String dueDate;
  final double amountAtIssue;

  factory _StatementPriorBill.fromMap(Map<String, dynamic> raw) {
    final int? billId = _asInt(raw['prior_bill_id']);
    final double? amount = _asDouble(raw['prior_amount_at_issue']);
    if (billId == null || billId <= 0 || amount == null ||
        !amount.isFinite || amount < 0) {
      throw const FormatException(
        'Invalid saved previous-bill statement reference.',
      );
    }
    final String reference = _asText(raw['display_reference']).isNotEmpty
        ? _asText(raw['display_reference'])
        : (_asText(raw['bill_no']).isNotEmpty
        ? _asText(raw['bill_no'])
        : 'Bill #$billId');
    return _StatementPriorBill(
      billId: billId,
      reference: reference,
      billingMonth: _asText(raw['billing_month']),
      dueDate: _asText(raw['due_date']),
      amountAtIssue: amount,
    );
  }
}

class _InvoiceCategory {
  const _InvoiceCategory({
    required this.code,
    required this.label,
    required this.subtotal,
    required this.rows,
  });

  final String code;
  final String label;
  final double subtotal;
  final List<_InvoiceLine> rows;

  factory _InvoiceCategory.fromMap(Map<String, dynamic> map) {
    final List<_InvoiceLine> parsedRows = <_InvoiceLine>[];
    final dynamic rawRows = map['rows'];

    if (rawRows is List) {
      for (final dynamic rawRow in rawRows) {
        if (rawRow is Map) {
          parsedRows.add(
            _InvoiceLine.fromMap(
              Map<String, dynamic>.from(rawRow),
            ),
          );
        }
      }
    }

    String code = _asText(map['category']);
    if (code.isEmpty && parsedRows.isNotEmpty) {
      code = parsedRows.first.categoryCode;
    }

    return _InvoiceCategory(
      code: code,
      label: _asText(map['category_label']).isEmpty
          ? 'Other Charges'
          : _asText(map['category_label']),
      subtotal: _asDouble(map['subtotal']) ?? 0,
      rows: parsedRows,
    );
  }

  List<_InvoiceLine> rowsForDisplay({required bool showAll}) {
    if (showAll) return List<_InvoiceLine>.unmodifiable(rows);

    final bool hasAppliedCharge = rows.any(
          (_InvoiceLine line) => !line.isHeading && line.shouldShowOnMobile,
    );

    if (!hasAppliedCharge) return const <_InvoiceLine>[];

    return rows
        .where(
          (_InvoiceLine line) => line.isHeading || line.shouldShowOnMobile,
    )
        .toList(growable: false);
  }

  bool get hasAnyContent => rows.isNotEmpty || subtotal.abs() > 0.000001;
}

class _InvoiceLine {
  const _InvoiceLine({
    required this.categoryCode,
    required this.componentName,
    required this.rowType,
    required this.calculationType,
    required this.rate,
    required this.rateUnit,
    required this.rateDisplay,
    required this.amount,
    required this.isApplicable,
    required this.isHeading,
    required this.notes,
  });

  final String categoryCode;
  final String componentName;
  final String rowType;
  final String calculationType;
  final double? rate;
  final String rateUnit;
  final String rateDisplay;
  final double? amount;
  final bool isApplicable;
  final bool isHeading;
  final String notes;

  factory _InvoiceLine.fromMap(Map<String, dynamic> map) {
    return _InvoiceLine(
      categoryCode: _asText(map['category']),
      componentName: _asText(
        map['component_name'] ?? map['description'],
      ),
      rowType: _asText(map['row_type']).toUpperCase(),
      calculationType: _asText(map['calculation_type']).toUpperCase(),
      rate: _asDouble(map['rate']),
      rateUnit: _asText(map['rate_unit']),
      rateDisplay: _asText(map['rate_display']),
      amount: _asDouble(map['amount']),
      isApplicable: map['is_applicable'] != false,
      isHeading: map['is_heading'] == true,
      notes: _asText(map['notes']),
    );
  }

  String get displayRate {
    if (isHeading) return '';
    if (!isApplicable || calculationType == 'NONE') return '—';
    if (rateDisplay.trim().isNotEmpty) return rateDisplay.trim();
    if (rate == null) return '—';

    final String value = _formatNumber(rate!, maximumDecimals: 4);
    return rateUnit.trim().isEmpty ? value : '$value $rateUnit';
  }

  bool get hasUsableRate {
    if (isHeading || !isApplicable || calculationType == 'NONE') {
      return false;
    }

    if (rate != null) return true;

    final String normalised =
    rateDisplay.trim().toUpperCase().replaceAll(' ', '');

    return normalised.isNotEmpty &&
        normalised != '-' &&
        normalised != '--' &&
        normalised != '—' &&
        normalised != 'N/A' &&
        normalised != 'NA' &&
        normalised != 'NULL';
  }

  bool get hasMeaningfulAmount => amount != null && amount!.abs() > 0.000001;

  bool get shouldShowOnMobile => hasUsableRate || hasMeaningfulAmount;
}

String _normaliseBillStatus(
    dynamic value, {
      bool isOverdue = false,
    }) {
  final String status = value?.toString().trim().toUpperCase() ?? '';

  if (status == 'PAID') {
    return 'PAID';
  }

  if (status == 'PENDING' ||
      status == 'PROCESSING' ||
      status == 'VERIFYING') {
    return status;
  }

  if (status == 'OVERDUE' || isOverdue) {
    return 'OVERDUE';
  }

  return 'UNPAID';
}

String _asText(dynamic value) {
  return value?.toString().trim() ?? '';
}

double? _asDouble(dynamic value) {
  if (value == null || value.toString().trim().isEmpty) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

int? _asInt(dynamic value) {
  if (value == null || value.toString().trim().isEmpty) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

String _formatMeterReading(double value) {
  String text = value.toStringAsFixed(4);
  text = text.replaceFirst(RegExp(r'0+$'), '');
  text = text.replaceFirst(RegExp(r'\.$'), '');
  return text;
}

String _formatNumber(
    double value, {
      int maximumDecimals = 2,
      bool useGrouping = true,
    }) {
  String text = value.toStringAsFixed(maximumDecimals);

  if (text.contains('.')) {
    text = text.replaceFirst(RegExp(r'0+$'), '');
    text = text.replaceFirst(RegExp(r'\.$'), '');
  }

  final List<String> parts = text.split('.');
  final String sign = parts.first.startsWith('-') ? '-' : '';
  final String whole = parts.first.replaceFirst('-', '');
  final String displayedWhole = useGrouping
      ? whole.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
        (Match match) => ',',
  )
      : whole;

  return '$sign$displayedWhole${parts.length > 1 ? '.${parts[1]}' : ''}';
}

String _money(double value) {
  final String sign = value < 0 ? '-' : '';
  return '$sign₱${_formatNumber(value.abs(), maximumDecimals: 2)}';
}

String _billPdfFilename(_InvoiceSnapshot invoice) {
  final String source = invoice.billNo.trim().isNotEmpty
      ? invoice.billNo.trim()
      : invoice.billingMonth.trim();

  String safe = source.replaceAll(
    RegExp(r'[^A-Za-z0-9_-]+'),
    '_',
  );
  safe = safe.replaceAll(RegExp(r'_+'), '_');
  safe = safe.replaceAll(RegExp(r'^_+|_+$'), '');

  if (safe.isEmpty) {
    safe = 'Bill';
  }

  return 'KuryentePay-$safe.pdf';
}

String _ilecoNumber(double value, {required int decimals}) {
  final String sign = value < 0 ? '-' : '';
  final String fixed = value.abs().toStringAsFixed(decimals);
  final List<String> parts = fixed.split('.');
  final String whole = parts.first.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
        (Match match) => ',',
  );
  return '$sign$whole${parts.length > 1 ? '.${parts[1]}' : ''}';
}

String _ilecoNullableNumber(double? value, {required int decimals}) {
  if (value == null) return '-';
  return _ilecoNumber(value, decimals: decimals);
}

String _ilecoDisplayDate(String raw) {
  final DateTime? parsed = _parseBillDate(raw);
  if (parsed == null) return raw.trim().isEmpty ? '-' : raw.trim();
  const List<String> shortMonths = <String>[
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${shortMonths[parsed.month - 1]} ${parsed.day.toString().padLeft(2, '0')}, ${parsed.year}';
}

String _ilecoNumericDate(String raw) {
  final DateTime? parsed = _parseBillDate(raw);
  if (parsed == null) return raw.trim().isEmpty ? '-' : raw.trim();
  return '${parsed.month.toString().padLeft(2, '0')}/${parsed.day.toString().padLeft(2, '0')}/${parsed.year.toString().padLeft(4, '0')}';
}

List<String> _ilecoDateParts(String raw) {
  final DateTime? parsed = _parseBillDate(raw);
  if (parsed == null) return const <String>['-', '-', '-'];
  return <String>[
    parsed.month.toString().padLeft(2, '0'),
    parsed.day.toString().padLeft(2, '0'),
    (parsed.year % 100).toString().padLeft(2, '0'),
  ];
}

String _ilecoRateUnitLabel(String unit) {
  final String value = unit.trim();
  if (value.isEmpty) return '';
  const Map<String, String> map = <String, String>{
    'PHP/kWh': 'Php/kWh',
    'PHP/kW': 'Php/kW',
    'PHP/Cust./Mo.': 'Php/Cust./Mo.',
    'PHP/Meter./Mo.': 'Php/Meter./Mo.',
    '%': '%',
  };
  return '(${map[value] ?? value})';
}

String _ilecoRateValue(_InvoiceLine line) {
  if (!line.isApplicable || line.rate == null) return '-';
  final String value = line.rate!.toStringAsFixed(4);
  return line.rateUnit.trim() == '%' ? '$value%' : value;
}

String _ilecoAmountValue(_InvoiceLine line) {
  if (!line.isApplicable || line.amount == null) return '-';
  return _ilecoNumber(line.amount!, decimals: 2);
}

String _ilecoCategoryLabel(String code, String fallback) {
  switch (code.trim().toUpperCase()) {
    case 'GENERATION_TRANSMISSION':
      return 'GENERATION\n&\nTRANSMISSION';
    case 'DISTRIBUTION_REVENUES':
      return 'DISTRIBUTION\nREVENUES';
    case 'LIFELINE_SUBSIDY_ADJUSTMENT':
      return 'LIFELINE\nSUBSIDY\nADJUSTMENT';
    case 'OTHERS':
      return 'OTHERS';
    case 'GOVERNMENT_REVENUES':
      return 'GOVERNMENT\nREVENUES';
    case 'UNIVERSAL_CHARGES':
      return 'UNIVERSAL\nCHARGES';
    case 'COOP_OTHER_CHARGES':
      return 'COOP OTHER\nCHARGES';
    default:
      final String value = fallback.trim().isEmpty
          ? code.replaceAll('_', ' ')
          : fallback;
      return value.toUpperCase();
  }
}

pw.Widget _ilecoTractorStrip({
  required PdfColor stripColor,
  required PdfColor holeColor,
  required PdfColor borderColor,
}) {
  return pw.Container(
    width: 5.5 * PdfPageFormat.mm,
    color: stripColor,
    padding: pw.EdgeInsets.symmetric(vertical: 1.3 * PdfPageFormat.mm),
    child: pw.Column(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: List<pw.Widget>.generate(
        26,
            (int index) => pw.Container(
          width: 4.1 * PdfPageFormat.mm,
          height: 4.1 * PdfPageFormat.mm,
          decoration: pw.BoxDecoration(
            shape: pw.BoxShape.circle,
            color: holeColor,
            border: pw.Border.all(
              color: borderColor,
              width: 0.3 * PdfPageFormat.mm,
            ),
          ),
        ),
        growable: false,
      ),
    ),
  );
}

pw.Widget _ilecoUsageSummary({
  required List<String> fromParts,
  required List<String> toParts,
  required String readingPresent,
  required String readingPrevious,
  required String kwhUsed,
  required String demandKw,
  required PdfColor yellow,
  required PdfColor greenDark,
  required PdfColor greenLine,
  required PdfColor softWhite,
  required PdfColor ink,
}) {
  final pw.Font headingBoldFont = pw.Font.helveticaBold();
  final pw.Font valueBoldFont = pw.Font.courierBold();

  final double topHeaderHeight = 3.2 * PdfPageFormat.mm;
  final double subHeaderHeight = 2.7 * PdfPageFormat.mm;
  final double detailHeaderHeight = 2.7 * PdfPageFormat.mm;
  final double valueHeight = 3.8 * PdfPageFormat.mm;
  final double stackedHeaderHeight =
      topHeaderHeight + subHeaderHeight + detailHeaderHeight;

  pw.Widget box(
      String text, {
        required double height,
        required PdfColor background,
        required PdfColor color,
        double fontSize = 6.2,
        bool header = false,
        bool drawRight = true,
        bool drawBottom = true,
      }) {
    return pw.Container(
      height: height,
      alignment: pw.Alignment.center,
      padding: pw.EdgeInsets.symmetric(
        horizontal: 0.2 * PdfPageFormat.mm,
        vertical: 0.12 * PdfPageFormat.mm,
      ),
      decoration: pw.BoxDecoration(
        color: background,
        border: pw.Border(
          right: drawRight
              ? pw.BorderSide(
            color: greenLine,
            width: 0.3 * PdfPageFormat.mm,
          )
              : const pw.BorderSide(width: 0),
          bottom: drawBottom
              ? pw.BorderSide(
            color: greenLine,
            width: 0.3 * PdfPageFormat.mm,
          )
              : const pw.BorderSide(width: 0),
        ),
      ),
      child: pw.Text(
        text,
        textAlign: pw.TextAlign.center,
        maxLines: 1,
        style: pw.TextStyle(
          font: header ? headingBoldFont : valueBoldFont,
          color: color,
          fontSize: fontSize,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  pw.Widget periodHeader() {
    return pw.Column(
      children: <pw.Widget>[
        box(
          'PERIOD COVERED',
          height: topHeaderHeight,
          background: yellow,
          color: greenDark,
          fontSize: 7.1,
          header: true,
        ),
        pw.Row(
          children: <pw.Widget>[
            pw.Expanded(
              child: box(
                'FROM',
                height: subHeaderHeight,
                background: yellow,
                color: greenDark,
                fontSize: 6.2,
                header: true,
              ),
            ),
            pw.Expanded(
              child: box(
                'TO',
                height: subHeaderHeight,
                background: yellow,
                color: greenDark,
                fontSize: 6.2,
                header: true,
              ),
            ),
          ],
        ),
        pw.Row(
          children: <pw.Widget>[
            for (int index = 0; index < 6; index++)
              pw.Expanded(
                child: box(
                  const <String>['MO', 'DAY', 'YR', 'MO', 'DAY', 'YR'][index],
                  height: detailHeaderHeight,
                  background: yellow,
                  color: greenDark,
                  fontSize: 6.2,
                  header: true,
                ),
              ),
          ],
        ),
      ],
    );
  }

  pw.Widget meterHeader() {
    return pw.Column(
      children: <pw.Widget>[
        box(
          'METER READING',
          height: topHeaderHeight,
          background: yellow,
          color: greenDark,
          fontSize: 7.1,
          header: true,
        ),
        pw.Row(
          children: <pw.Widget>[
            pw.Expanded(
              child: box(
                'PRESENT',
                height: subHeaderHeight,
                background: yellow,
                color: greenDark,
                fontSize: 6.2,
                header: true,
              ),
            ),
            pw.Expanded(
              child: box(
                'PREVIOUS',
                height: subHeaderHeight,
                background: yellow,
                color: greenDark,
                fontSize: 6.2,
                header: true,
              ),
            ),
          ],
        ),
        pw.Row(
          children: <pw.Widget>[
            pw.Expanded(
              child: box(
                '',
                height: detailHeaderHeight,
                background: yellow,
                color: greenDark,
                header: true,
              ),
            ),
            pw.Expanded(
              child: box(
                '',
                height: detailHeaderHeight,
                background: yellow,
                color: greenDark,
                header: true,
              ),
            ),
          ],
        ),
      ],
    );
  }

  return pw.Container(
    decoration: pw.BoxDecoration(
      border: pw.Border.all(
        color: greenLine,
        width: 0.45 * PdfPageFormat.mm,
      ),
      borderRadius: pw.BorderRadius.circular(1.7 * PdfPageFormat.mm),
    ),
    child: pw.Column(
      children: <pw.Widget>[
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: <pw.Widget>[
            pw.Expanded(flex: 30, child: periodHeader()),
            pw.Expanded(flex: 31, child: meterHeader()),
            pw.Expanded(
              flex: 18,
              child: box(
                'KWH USED',
                height: stackedHeaderHeight,
                background: yellow,
                color: greenDark,
                fontSize: 7.1,
                header: true,
              ),
            ),
            pw.Expanded(
              flex: 21,
              child: box(
                'DEMAND KW USED',
                height: stackedHeaderHeight,
                background: yellow,
                color: greenDark,
                fontSize: 7.1,
                header: true,
                drawRight: false,
              ),
            ),
          ],
        ),
        pw.Row(
          children: <pw.Widget>[
            pw.Expanded(
              flex: 30,
              child: pw.Row(
                children: <pw.Widget>[
                  for (int index = 0;
                  index < <String>[...fromParts, ...toParts].length;
                  index++)
                    pw.Expanded(
                      child: box(
                        <String>[...fromParts, ...toParts][index],
                        height: valueHeight,
                        background: softWhite,
                        color: ink,
                        fontSize: 8.1,
                        drawBottom: false,
                      ),
                    ),
                ],
              ),
            ),
            pw.Expanded(
              flex: 31,
              child: pw.Row(
                children: <pw.Widget>[
                  pw.Expanded(
                    child: box(
                      readingPresent,
                      height: valueHeight,
                      background: softWhite,
                      color: ink,
                      fontSize: 8.1,
                      drawBottom: false,
                    ),
                  ),
                  pw.Expanded(
                    child: box(
                      readingPrevious,
                      height: valueHeight,
                      background: softWhite,
                      color: ink,
                      fontSize: 8.1,
                      drawBottom: false,
                    ),
                  ),
                ],
              ),
            ),
            pw.Expanded(
              flex: 18,
              child: box(
                kwhUsed,
                height: valueHeight,
                background: softWhite,
                color: ink,
                fontSize: 8.1,
                drawBottom: false,
              ),
            ),
            pw.Expanded(
              flex: 21,
              child: box(
                demandKw,
                height: valueHeight,
                background: softWhite,
                color: ink,
                fontSize: 8.1,
                drawRight: false,
                drawBottom: false,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

const String _kuryentePayBillLogoBase64 = '/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAQDAwMDAgQDAwMEBAQFBgoGBgUFBgwICQcKDgwPDg4MDQ0PERYTDxAVEQ0NExoTFRcYGRkZDxIbHRsYHRYYGRj/2wBDAQQEBAYFBgsGBgsYEA0QGBgYGBgYGBgYGBgYGBgYGBgYGBgYGBgYGBgYGBgYGBgYGBgYGBgYGBgYGBgYGBgYGBj/wAARCAB4AHgDASIAAhEBAxEB/8QAHQAAAAcBAQEAAAAAAAAAAAAAAAMEBQYHCAIBCf/EAEMQAAEDAwIDBQQHBAcJAAAAAAECAwQABREGBxIhMQgTQVFhFCJxoRUyQlJigZEjgrHBFyQzcqKy0TRDU2ODktLT4v/EABsBAAMBAQEBAQAAAAAAAAAAAAQFBgMHAQIA/8QANxEAAQMCBAMHAwEHBQAAAAAAAQIDEQAEBSExQRJRYQZxgZGhsdETIvDBBxQVM0LC4TJygqLx/9oADAMBAAIRAxEAPwDC4IrsGiQaMFO00uVRycYoxKCroK5aSSak+nNPSbzcGozDRWtZAAAzmjGGFPLCEDM0Fc3CWElazAFMTcZRGeE0cIivKtWxOzhpqw6fcma51WmDLZCRIgxEJccjqUniCHVKUEpXgg8A4lAEZAzTO1ojYttau/1TewlPVRYa/wBaaowV1f8AL+7umPPfwpG7jaUCVAj38tfOs2CE4eiTXphLH2DWpYOkNhXwCxcdUykZxxNQ0qGfiAa8uWktlYuQmNrT0UII/wDGtRgbu9Dfx5ZMBpR8KyuqKtP2TRC21A9KvO7Q9lOEmLc9QoPhllo/zqFzLJo25SUxbBfJiZCzhAnsIQ2T5FSVe78SCB44rN7BH0aQfEUczi3FmtCh4fFV0oYNcHFON0t0q2XN+BNYWxJYcU060sYKFA4INNqqSkRkaeoVxCa5VRRPOuzRajWK62TQzQrihWNaRXgNGoooUagc6+kV4ql8RHE4ARWj+zaxDjbmRrrJaQtFuYkXDCxkZYYW6nP7yE1nWGeFYq9NpJxt+mNe3TODD0lcVJPkpbYaT83Kd4esICjuQR5iKmsYlSQOo96bbbM1xuNI0/pGxiRdLvckKmuJU5jjdeJeeecWeSUjOVKPQAegqb3fs1X20xk/S+4VmS/jLjUaM86lJ8golOfjgVz2ZLoxYbxq69rSkOxbXEtzLh6p4lFSwPiGk056z17ImzHMOnmfOjEXT618AVCRA7+dbraabBITKjnRenLluVt3Y27FpveaXAtzS1LRGj25KkJKlcSiOMk8ySevjXV83p3eYPdJ3sva1cIJ7u2MJA+fWolZmL3q3UsayWaO5KnSlhCG0jOM+Jq6N4tHaV2d7MbdpcYiT9TXqSgPz1pClIDY4lho+ABKUkjrk+GKbNmzTwodQCpR5CepJ5Ckjt8+Hfptq07oz8NTWRbnZxMnPSXb+6868tTi1rjYKlKOSThfiSaj7MaTbtYQ4xfQ9l5BStHQ+8Oo8D6Uol3ZbfEGz+0PQ+VJ7OhUjVFrCiSpckczzJ5il904ypaUtDORuedPmA6lClOGRB2HKpnvCwE7oSyke97NEKz5q9layardwYOMVe+7ekbxM3Mu7ka1TX0pdS2FNMLUPcbSjqB+GqmuGm7nCWUyoMhhX3XW1IPzFKLxhQWTGtZYdiDK0BPEJHWo4o86LVSt+KtokFJFJFg0sXO9PEKBzFF0KBoVka2FepHMUobHOiEUqZTkitEVk4YFL4aCXBirh0syuJ2e9y7gMpK7fEgJPn30tGR+iDVb2K1uS5SEITxEmtDXzSL2muxldpkhIa+lL5AYHFyKg2HHD/CqXC8OW+J5kAd5qTxS8QX2rcHMqB8AZPoKrfb66Kt+iL88hWDKuIT8Qhv/AO6EVq56gvjNut7DkmXIWENtISVEknA5Uwaa75emIkGKkuvypTqkNp55JUEj/LWxtrtuom19jF0uiEO6qkoypR5+wJI+qP8AmEdfujl1zjOFJySJNAdpMdZwpkrcOeg9vz4k1J9rNv7ZtTYOJ/u5GppSP63J5K9nB6tIPn94j4Dl1zb2tNauX/c5uxR3CqPZ46Y/I5BdV77h+OSB+7WkVXYKe4yvKs5yajTm1+3d4uki63XTjUt99a333pEp0DnlSlE8QAHU+lDtocQtTjmpEVy/Bu2yG7wu3iTH9IGeZ59a+fLiFcfvA59akWiovtG5mm4hGe8kD5qA/lUw3pVoJ3ch1nb21+xWthtLRIcUsPODPE4niJISfAemeWcUz7cR+LfnSzJHJC2Vkf8AUKv4V+YHC6O8e812/wDe/r2pciJST6Vb9+3xuEbcC5p+jIsmKma8kBC1tr4Q4QMHJGcDyq69MTrVrbR0aeqO3cLZKSUqjzWw4UKHJSFA5wQfEehFZMtGkrvqTUoaixXXnpL2QlCSoqKlZwB4nJraGk9JM6G0Tb9LlxC5bHE9MUg5AeWQSgHx4QEpPrmvU3zzi+FRmuNduLCwtLcP2h4XARodZ9jvI5Gsz7/bPQdJSIt8sDSkWq4IUpDKjxFhxJAWjPiOaSCeeDg9M1m6SyW3SCOlfQHtNS7dD2isVscWkyll2UU+KUqwkfrwGsFXLh9oUR518X7ADaHNzPoSP0rpnY2+fftEh8yQE585SCfU00K5HpQrpXWhSQiroGgmna1Q1ypKG0JJJOMU2tIyoCtEdmnaxvXmvEuXAKRaoKPapro8EAj3R+JRwkfHPhTPDLUPufeYSMyeg/MutKsUuxbsle9WPsZsmmVbU6q1IkxbW1zBUMKeI5kJz8z4fHlSbtO68g3vaSw22yJS1bGrxJbZQjkkhpgAkefNfWrd3y1O7a9rXbdYWkxG3VIgx22OQab55A/IHn586yRvAXLftPoW3O8nFMz5qk+XG8lA+SKqG7nilYEBIPCOWRE9SeflXKsEf/iWJt3IXIKynvhJUT3SBHPU7RBLJqK4acds10tcgsTIfDIZdABKF8ZWDz/KrRjdoXc6+XNtly8oW68sAhERkFRJ9EVRsl0hLTf3GkJ/wirT7Pemn9SbuRFojl9u3oVOcSBnPB9UfmsoFLMMKnLgInLfuGZq9xuxtF2y7i5bCuEE5ia1TEFxl3SPbnF9/KQ2lMhwAJBWE++o45AZz+lVRvVvCw1Cd0XpOYFxx7k2a2f7dX3En7gP6nn0xTPuvvLHtkaXpHR8xLq3SU3G6tKz3xzzaaP/AAweqvtH060fYrXfdX6jZtNjtsy6XGSrDcaK0XXF+fIeA8T0HjTDG7ltk/TR/q9v89Nt89IPsv2LIWL+9RG6U8upHsNqKaC5cvKsqJNWps1o+7XjtANXVmC4mzWvu25tzc9yNGw0DhTh5cWTyQMqPgKlek9kWNMKRcNwbhY4z6CD7BJmF3uz5LbjhSln8JUgeZNTG7a90NbYzTDr16vpjApZjR0NWuG0PJCE8ZA+AST40mt2wYKlRvz/AMeZqsv8SBCm2AFEgp1AiYz3O3LxqxLTN0boSKqJo9vvpxTwO3l5PCsDoQyn7A/EfeP4adbNMS7Fdub7Uh6KyMqDCCpTh8EjHQnzPIdTWbLjvXcHJXsuk9M2i3vKOEFmMqdIP5ulfP4JFJHdL9oDcNaXJtq1E9HV9VV1e9lZSPRLhSAPgmjUqtWBlvuTn+eNQlx2MXdlL168Akbf0+ZI13JzO5ojf7UOqrtqQ3G+W2RDjPngjZT+y4UjAQhQyDwjHLOfOs+yVlSya0VqHancDR+39zN6Tb5dpfjLVKahye99ncSkqbcKSkcwoAcac4CiDyJrOshBCjkUBibhdIWDKdo2jaul9nHLUslFsoKCdSCDn3jekS6FeroUkOtVY0pTESC4PjW7+zI2xaezzcbgzhMi4XPuHFePA00lQH6uk1hCGvDorYnZo1Cift9fdId4PamFpucZHitPDwOgeoAbV8AfKnuEwQpB3j3H/tQfb5Lxwp76Osem/wD1mrfvtha1fZDGBBXHdD4B8RgpP8ayd2qmE27XNlsLPJEGzMox6rWtZ/lWpbDfHrZfUPJIylWClXQjxB9KpjtP7b6i1FrxO49uYE6xzVxo6zHT70FQITwOpH1QSfdV0Occjyo55wspcYVuMvMfpNcz/Z0UMX6Q4uOAEgHedx55jxqndrtq7fuhqK7wrjr2yaTRAZS6ldy5qkEqKeFtPEkHGMk55ZHLnytODsonRcW5R7B2hLIwi4xzEliI0lPfNEglBPfZxkCoLoi57b6Lu98G5e3TmqVPlAhnj5RsFXH7hUkEnKeeTjhx4043Pcbs+ulXsmy3s/lhtH/tpWwtdu8VpVB749ga7cX/AKzYCJI6AH3Ipqn7J2Zta1f0rWVeATxFpIH5/teQqebDPNaW2YlTrb3Zu2oJr8d2Yk4KYzBSkICuoQpSiojxPD5CqC19d9GX2bDc0hpT6DQ2hSXwcDvSSOH3QSBjnz8c+laY2F0rAm9n2z6hvSnHIMSROaTDbWW1SHS6k+8ocwgAc8YJJAyOdaMhFzdBBE9QSZOXOKne16nW8LCluFKSoA5RlCsjEzJjLfTelDmnReJHHdb8tCCclMdsZP7yj/KpVYdt9vW8Ou6ffu6xzLk11bqf+1OE/Ko3qHW/0S4tuywLfbwOQLEdJUP3lAq+dVHqbX18mlSJ13mPA/7tbyiP0zintxgoSJWvhHn8Vzyww6/vQAw8W09AAfT5rX8TVOktIQFNwU2CxtpGClksxz+YTgmoZqDfvRkRas3tctY+zFZWv5nA+dY3kXt5xXClzhT6cqtn+hi1WWyRZW5mvmdNXCU0l9NoYhLnS2W1DKS+kKSlokEEJKuLBGQKWJw2zSrKVH82AmqAdiEOgKv31rHUgD88ae9Vdoey3ezzrKmxTpESYyuO6pyQllXAoYPDgKwcVnvVcG1xp7UiyuyVwJTXfNJlY7xo5KVIUU4CsEHCgBkEHAORVnyNEbKsk95unqZ4/dZ0ykf5pIpq17p3Qre3UG5aO1BeriqE97I+m5W9uNkOFbgUkodXkgggg+nOvz9uhTKuBMRnv+tVmD4XZYPDdmnhCjnnM5a5k9KptdCunRhRoVNK1qyTpXTCsKFWZtnq+fpHWEG9W57u347gUM8wodCkjxBBII8iarBrqKfLc+ptYNG2TpbUDS7ErcPNlB3rfKV27Vmn0av0tzZUAZcMHK4iz4HzQfBX5HnTpprU79vkYS4EkjhWhYCkrT4pUk8iPQ1nDYzU16j7i2m322YtkzJCIygOYUFkDBB5EHPQ1IrZvjpi43d63avYGmbu3IcaVIaQpURZSsp99PNTR5c+qfhVWUs3bUPGOR+fnz51wbEuyd2h5a7JJPBBHDqNdN9tBptlpdOq9lNvdzIzkq1dzp28rGSggqiuq9PFv5j4Vlncfs86z0NLWbjaXTGJ/ZymhxtLHmlY5GtKWq+yGIbU1h9qXCc5ty4zgdaWPRaSRU9tO4K0w1RHnEPR1jC2H0haFjyKTyNAu4Q+jMfcPzf5mvrCe2b9gfp3YIjdIkeKcoP+0gdCa+acnT8lh0pWyoY8xWx9rGWLf2MbFzAcVMnqWPL9qMVYGodA7S6t4npNi+iZK+ZetigEk+rauX6EU3y9C/Ru1jWlNKXeHNTHdedbTIV7Oo94oHBCuRx6Gt8Ps0NXDbhlMHOR0O+nrTrHe1ttjFgbRtQJUU7xEKB0MHQcqzDra9IiyFpCgp5WSlHkPM1VE6a466pa1lRPU1Y2vtCatsM1+RebRObSTkyHGjwK+Ch7vzqppb3vqAUD8DmiMYuVlcnTar3s/atJZH0zPWnfSV2t9s3M05cbyEKtsa7RX5aVjiSWUvIUvI8Rwg5Fa32u3i290LutubA3jRDRd591ekN3O4QlTEuxlFSghtKUKyFhSVAcgoKTz5Vh9xQVkGpNF3B1EzaYtsnN2m8xobfdRReLc1LXHR9xC1jiCPJOcDwAqWW5xBQO9VBZMgjb8yru/wB7gTtX3SVZIzkW1uzHnIbDn1mmSslCT6hOBTiqYp3bCazk/wC2sK/wu0lb3MujBHd6R0L+9p2Mr+KTThqTVt1vujbXHl26wwGXeKSUWm1MQeNQWtscZbSCrABxnkMmiba5UUrBGUUJdW4HAdDI+fYVAHvrGhXrv1jQpOvWmiNK8ZQSoACn+2W+S+6kNtLUfQVHW3Ck9adIdxeZUClxQ+Boi2WgH7qFu0OFJCKvfbDTuo4GpoN1hW98rjvIdQoJ6FJBB+VPPae2oefui9yNM2WRFiXJZk3COEEiNIWcuHPghSiVDyyR5VUdk1pcoS0luY8kDyWaWan3N1DdGG4irk/3KOieI4qoL9opiDMfPly/JNQjdni7WJJebUng3GeevfzqO6PuuvdKzvaNM3aRCUo++hmQngc/vIJKVfmDWhNHbp6suCG2dS6IZuBPIyrW57M6fUp5oP5AVSti3A1Db3kli7SW8H7KyKubSu+uooiWw9d5CgPNw0fhN0w2nhSSroTHqJNYdp2nrj7nbNC+sni84HvVol1MiAmW0L5awfsz7espH77XEPkKi12v9ygNFxNzhPNZKQoPhBz/AHV4Pyp9PaMu30f3f0rJIx075X+tV7qTfXUEriDV1eAP4s04bxD6clxKY75/tB9agLfCVOrhq2P/ACIA/uPrRL+4t6a4m4stYB6paeBB/IGodepbN6cUu46Vt8xauq1xWws/vJwfnTRddz7/AC1qLlydVnzIqKTNYXN9RKpSiT6Clt3jdsZBTPl+tXeGYC+1BSgIPQn4FLp+koD6ipjSslg9f2D6gP0KjTC/o+QgnubbcEf3ilX+lJ3r9OWTl9R/IUiN1lrcyXT+gqdfvbNZ/lx3QP0qwtmL1AzX58R9zU40Ts3qbWM4lpj6PtjJ/rNymjDTI8eQyVq8kpGT6daJ19a2It+MK1RpCLbDbTFjd8khRQn7SvxKJUo+qseFG6V3AvdihPR41xeQy4nCkJWQD+VRm96gmzpS1vSXF5Oeaia2dcskWp4Jk0GyMRdvSXingTpE+JPWo/IaUlRyCKFFvPqWoknNCpdagTlVWgGM6Tc6MQsg0KFZJNaqE0rakKT4kV668VHOc0KFFBZiKGKBM100+Ukc6dI9zcb6KNChWzLik6Vg80lQzFLfpx/hwHFfrSJ+6OLJyo0KFELuFkZmhm7ZsHIUgclKUepohTpPjQoUEpRNGpQBRSnCa5CzmhQrImtQBShEgpRgGiHnCtXWhQr1ajEV4hAmaTnnQoUKwogV/9k=';

const List<String> _billMonthNames = <String>[
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

DateTime? _parseBillDate(String raw) {
  final String value = raw.trim();
  if (value.isEmpty) return null;

  try {
    return DateTime.parse(value);
  } catch (_) {}

  try {
    return DateTime.parse(value.replaceFirst(' ', 'T'));
  } catch (_) {}

  return null;
}

String _formatBillDate(String raw) {
  final String value = raw.trim();
  if (value.isEmpty) return 'Not available';

  final DateTime? parsed = _parseBillDate(value);
  if (parsed == null) return value;

  return '${_billMonthNames[parsed.month - 1]} '
      '${parsed.day}, ${parsed.year}';
}

String _formatBillingMonth(String raw) {
  final String value = raw.trim();
  if (value.isEmpty) return 'Bill';

  final RegExpMatch? yearMonth =
  RegExp(r'^(\d{4})-(\d{2})$').firstMatch(value);

  if (yearMonth != null) {
    final int? month = int.tryParse(yearMonth.group(2) ?? '');
    final String year = yearMonth.group(1) ?? '';

    final int? parsedYear = int.tryParse(year);

    if (month != null &&
        month >= 1 &&
        month <= 12 &&
        parsedYear != null &&
        parsedYear >= 2000 &&
        parsedYear <= 2100) {
      return '${_billMonthNames[month - 1]} $parsedYear';
    }

    return 'Bill';
  }

  final DateTime? parsed = _parseBillDate(value);
  if (parsed != null &&
      parsed.year >= 2000 &&
      parsed.year <= 2100) {
    return '${_billMonthNames[parsed.month - 1]} ${parsed.year}';
  }

  return 'Bill';
}

String _formatBillingPeriod(_InvoiceSnapshot invoice) {
  final String from = invoice.periodFrom.trim();
  final String to = invoice.periodTo.trim();

  if (from.isEmpty && to.isEmpty) {
    return 'Not available';
  }

  if (from.isEmpty) {
    return _formatBillDate(to);
  }

  if (to.isEmpty) {
    return _formatBillDate(from);
  }

  return '${_formatBillDate(from)} – ${_formatBillDate(to)}';
}

class _BillPalette {
  // Local UI tokens; technical API, billing, and PDF logic remains untouched.
  static bool _isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color background(BuildContext context) =>
      _isDark(context) ? const Color(0xFF091B27) : const Color(0xFFF4F7FA);

  static Color surface(BuildContext context) =>
      _isDark(context) ? const Color(0xFF132C37) : Colors.white;

  static Color surfaceAlt(BuildContext context) =>
      _isDark(context) ? const Color(0xFF1A3540) : const Color(0xFFF5F9F9);

  static Color border(BuildContext context) =>
      _isDark(context) ? const Color(0xFF31515A) : const Color(0xFFDCE6EA);

  static Color text(BuildContext context) =>
      _isDark(context) ? const Color(0xFFF1F8F8) : const Color(0xFF173347);

  static Color secondaryText(BuildContext context) =>
      _isDark(context) ? const Color(0xFFB8CFD1) : const Color(0xFF617682);

  static Color primary(BuildContext context) =>
      _isDark(context) ? const Color(0xFF65DECD) : const Color(0xFF087F79);

  static Color info(BuildContext context) => primary(context);

  static Color gold(BuildContext context) =>
      _isDark(context) ? const Color(0xFFF6D483) : const Color(0xFF976916);

  static Color success(BuildContext context) =>
      _isDark(context) ? const Color(0xFF91E3B9) : const Color(0xFF19875B);

  static Color danger(BuildContext context) =>
      _isDark(context) ? const Color(0xFFFFA7A7) : const Color(0xFFC14D58);
}


class _BillBackdrop extends StatelessWidget {
  const _BillBackdrop();

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned.fill(
            child: ColoredBox(color: _BillPalette.background(context)),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: 190,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: dark
                      ? const [Color(0xFF122F36), Color(0xFF091B27)]
                      : const [Color(0xFFE8F5F2), Color(0xFFF4F7FA)],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


class _BillHeader extends StatelessWidget {
  const _BillHeader({
    required this.refreshing,
    required this.onBack,
  });

  final bool refreshing;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _HeaderButton(
          icon: Icons.arrow_back_rounded,
          tooltip: 'Back',
          onTap: onBack,
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'KuryentePay',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: _BillPalette.primary(context),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Electric Bill',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: _BillPalette.text(context),
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),
        if (refreshing) ...[
          const SizedBox(width: 10),
          SizedBox(
            height: 42,
            width: 42,
            child: Center(
              child: SizedBox(
                height: 19,
                width: 19,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: _BillPalette.primary(context),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}


/// Informational only; the backend and deadline service enforce eligibility.
class _OnlinePaymentWindowNotice extends StatelessWidget {
  const _OnlinePaymentWindowNotice({
    required this.daysBeforeDue,
    required this.dueDate,
  });

  final int daysBeforeDue;
  final String dueDate;

  @override
  Widget build(BuildContext context) {
    final bool dueTomorrow = daysBeforeDue == 1;
    final Color accent = dueTomorrow
        ? _BillPalette.gold(context)
        : _BillPalette.primary(context);
    final String title = dueTomorrow
        ? 'Your bill is due tomorrow'
        : 'Payment Reminder';
    final String description = dueTomorrow
        ? 'Due $dueDate. Review your bill before the payment window closes.'
        : 'Due $dueDate. Online payment availability is checked before checkout.';

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: _BillPalette.surface(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _BillPalette.border(context)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _IconTile(
            icon: dueTomorrow
                ? Icons.notifications_active_outlined
                : Icons.notifications_none_rounded,
            accent: accent,
            size: 40,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: _BillPalette.text(context),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: _BillPalette.secondaryText(context),
                    fontSize: 11.5,
                    height: 1.4,
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


class _HeaderButton extends StatelessWidget {
  const _HeaderButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(15),
          child: Ink(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              color: _BillPalette.surface(context),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: _BillPalette.border(context)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: _BillPalette.primary(context),
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}

class _AmountHeroCard extends StatelessWidget {
  const _AmountHeroCard({
    required this.nickname,
    required this.accountNo,
    required this.address,
    required this.amount,
    required this.dueDate,
    required this.status,
    required this.statusColor,
    required this.statusIcon,
    required this.onCopyAccount,
  });

  final String nickname;
  final String accountNo;
  final String address;
  final double amount;
  final String dueDate;
  final String status;
  final Color statusColor;
  final IconData statusIcon;
  final VoidCallback? onCopyAccount;

  @override
  Widget build(BuildContext context) {
    final String safeNickname = nickname.trim().isEmpty
        ? 'Electricity Account'
        : nickname.trim();
    final String safeAccount = accountNo.trim().isEmpty
        ? 'Account unavailable'
        : accountNo.trim();
    final String safeAddress = address.trim().isEmpty
        ? 'Service address unavailable'
        : address.trim();
    final String safeDueDate = dueDate.trim().isEmpty
        ? 'Not available'
        : dueDate.trim();

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF102F3E),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF32636A)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF102F3E).withValues(alpha: 0.14),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(height: 4, color: const Color(0xFF3EC0A9)),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 42,
                      width: 42,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: const Icon(
                        Icons.receipt_long_rounded,
                        color: Color(0xFFF6D483),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Electricity Account',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: const Color(0xFFBBD5DB),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            safeNickname,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _HeroStatusBadge(
                  status: status,
                  icon: statusIcon,
                  accent: statusColor,
                ),
                const SizedBox(height: 22),
                Text(
                  'Total Amount Due',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFFBBD5DB),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _money(amount),
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: Colors.white,
                      fontSize: 38,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.25,
                    ),
                  ),
                ),
                const SizedBox(height: 17),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.075),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.10),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.event_outlined,
                        color: Color(0xFFF6D483),
                        size: 19,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Due Date',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: const Color(0xFFBBD5DB),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Flexible(
                        child: Text(
                          safeDueDate,
                          textAlign: TextAlign.right,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _CompactHeroDetails(
                  accountNo: safeAccount,
                  serviceAddress: safeAddress,
                  onCopyAccount: onCopyAccount,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


class _CompactHeroDetails extends StatelessWidget {
  const _CompactHeroDetails({
    required this.accountNo,
    required this.serviceAddress,
    required this.onCopyAccount,
  });

  final String accountNo;
  final String serviceAddress;
  final VoidCallback? onCopyAccount;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        children: [
          _CompactHeroLine(
            icon: Icons.confirmation_number_outlined,
            label: 'Account Number',
            value: accountNo,
            trailing: onCopyAccount == null
                ? null
                : Tooltip(
              message: 'Copy Account Number',
              child: InkWell(
                onTap: onCopyAccount,
                borderRadius: BorderRadius.circular(8),
                child: const Padding(
                  padding: EdgeInsets.all(5),
                  child: Icon(
                    Icons.copy_rounded,
                    size: 17,
                    color: Color(0xFFBFE6E1),
                  ),
                ),
              ),
            ),
          ),
          Divider(
            height: 23,
            color: Colors.white.withValues(alpha: 0.11),
          ),
          _CompactHeroLine(
            icon: Icons.location_on_outlined,
            label: 'Service Address',
            value: serviceAddress,
            maxLines: 3,
          ),
        ],
      ),
    );
  }
}


class _CompactHeroLine extends StatelessWidget {
  const _CompactHeroLine({
    required this.icon,
    required this.label,
    required this.value,
    this.trailing,
    this.maxLines = 1,
  });

  final IconData icon;
  final String label;
  final String value;
  final Widget? trailing;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(
            icon,
            color: const Color(0xFF80DBCA),
            size: 19,
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFFBBD5DB),
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                maxLines: maxLines,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white,
                  fontSize: 12.5,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 8),
          trailing!,
        ],
      ],
    );
  }
}


class _HeroStatusBadge extends StatelessWidget {
  const _HeroStatusBadge({
    required this.status,
    required this.icon,
    required this.accent,
  });

  final String status;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final String label = switch (status.toUpperCase().trim()) {
      'PAID' => 'Paid',
      'OVERDUE' => 'Overdue',
      'DUE TODAY' => 'Due Today',
      'PENDING' => 'Pending',
      'PROCESSING' => 'Processing',
      'VERIFYING' => 'Verifying',
      'UNPAID' => 'Unpaid',
      _ => status,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.55)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 15),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}


class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  IconData _sectionIcon() {
    final String value = title.toLowerCase();
    if (value.contains('meter')) return Icons.speed_rounded;
    if (value.contains('charge') || value.contains('breakdown')) {
      return Icons.receipt_long_rounded;
    }
    if (value.contains('document')) return Icons.picture_as_pdf_rounded;
    if (value.contains('payment')) return Icons.shield_outlined;
    return Icons.info_outline_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          height: 34,
          width: 34,
          decoration: BoxDecoration(
            color: _BillPalette.primary(context).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(
            _sectionIcon(),
            size: 17,
            color: _BillPalette.primary(context),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: _BillPalette.text(context),
                  fontSize: 16.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.15,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: _BillPalette.secondaryText(context),
                  fontSize: 11.2,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MeterSummaryCard extends StatelessWidget {
  const _MeterSummaryCard({required this.invoice});

  final _InvoiceSnapshot invoice;

  @override
  Widget build(BuildContext context) {
    final String kwh =
    invoice.kwhUsed == null ? '—' : _formatNumber(invoice.kwhUsed!);
    final String present = invoice.readingPresent == null
        ? '—'
        : _formatMeterReading(invoice.readingPresent!);
    final String previous = invoice.readingPrevious == null
        ? '—'
        : _formatMeterReading(invoice.readingPrevious!);

    return _SurfaceCard(
      padding: const EdgeInsets.all(13),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _BillPalette.primary(context).withValues(alpha: 0.11),
                  _BillPalette.info(context).withValues(alpha: 0.055),
                ],
              ),
              border: Border.all(
                color: _BillPalette.primary(context).withValues(alpha: 0.13),
              ),
            ),
            child: Row(
              children: [
                Container(
                  height: 48,
                  width: 48,
                  decoration: BoxDecoration(
                    color: _BillPalette.primary(context),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: _BillPalette.primary(context).withValues(alpha: 0.20),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.bolt_rounded,
                    color: Colors.white,
                    size: 25,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Energy Consumed',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: _BillPalette.secondaryText(context),
                          fontSize: 9.2,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.75,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '$kwh kWh',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: _BillPalette.text(context),
                          fontSize: 23,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.45,
                        ),
                      ),
                    ],
                  ),
                ),
                if (MediaQuery.sizeOf(context).width >= 360)
                  Text(
                    'This Period',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: _BillPalette.primary(context),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _ReadingValueCard(
                  label: 'Present Reading',
                  value: present,
                  icon: Icons.speed_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ReadingValueCard(
                  label: 'Previous Reading',
                  value: previous,
                  icon: Icons.history_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 4),
            decoration: BoxDecoration(
              color: _BillPalette.surfaceAlt(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _BillPalette.border(context)),
            ),
            child: Column(
              children: [
                _ReferenceLine(
                  icon: Icons.electric_meter_rounded,
                  label: 'Meter S/N',
                  value: invoice.meterSerialNo.isEmpty
                      ? '—'
                      : invoice.meterSerialNo,
                ),
                _CardDivider(),
                _ReferenceLine(
                  icon: Icons.receipt_long_rounded,
                  label: 'Bill Reference',
                  value: invoice.billNo.isEmpty ? '—' : invoice.billNo,
                ),
                _CardDivider(),
                _ReferenceLine(
                  icon: Icons.date_range_rounded,
                  label: 'Billing Period',
                  value: _formatBillingPeriod(invoice),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadingValueCard extends StatelessWidget {
  const _ReadingValueCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _BillPalette.surfaceAlt(context),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: _BillPalette.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 15,
                color: _BillPalette.primary(context),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: _BillPalette.secondaryText(context),
                    fontSize: 9.8,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: _BillPalette.text(context),
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.15,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReferenceLine extends StatelessWidget {
  const _ReferenceLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 17, color: _BillPalette.primary(context)),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: _BillPalette.secondaryText(context),
                fontSize: 11.2,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: _BillPalette.text(context),
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InvoiceLoadingCard extends StatelessWidget {
  const _InvoiceLoadingCard();

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          children: [
            CircularProgressIndicator(
              strokeWidth: 2.5,
              color: _BillPalette.primary(context),
            ),
            const SizedBox(height: 12),
            Text(
              'Loading saved rate components...',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: _BillPalette.secondaryText(context),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InvoiceErrorCard extends StatelessWidget {
  const _InvoiceErrorCard({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final Color accent = _BillPalette.danger(context);

    return _SurfaceCard(
      child: Column(
        children: [
          _IconTile(
            icon: Icons.cloud_off_rounded,
            accent: accent,
            size: 48,
          ),
          const SizedBox(height: 11),
          Text(
            'Could not load invoice details',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: _BillPalette.text(context),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: _BillPalette.secondaryText(context),
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Try Again'),
          ),
        ],
      ),
    );
  }
}

class _InvoiceEmptyCard extends StatelessWidget {
  const _InvoiceEmptyCard();

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      child: Column(
        children: [
          _IconTile(
            icon: Icons.receipt_long_outlined,
            accent: _BillPalette.gold(context),
            size: 48,
          ),
          const SizedBox(height: 11),
          Text(
            'Charge breakdown unavailable',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: _BillPalette.text(context),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Detailed charge components are unavailable for this bill. KuryentePay does not estimate missing charges.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: _BillPalette.secondaryText(context),
              height: 1.42,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _DisplayedInvoiceCategory {
  const _DisplayedInvoiceCategory({
    required this.category,
    required this.rows,
  });

  final _InvoiceCategory category;
  final List<_InvoiceLine> rows;
}

class _InvoiceBreakdownCard extends StatelessWidget {
  const _InvoiceBreakdownCard({
    required this.invoice,
    required this.showAllComponents,
    required this.onShowAllChanged,
  });

  final _InvoiceSnapshot invoice;
  final bool showAllComponents;
  final ValueChanged<bool> onShowAllChanged;

  @override
  Widget build(BuildContext context) {
    final List<_DisplayedInvoiceCategory> visibleCategories = invoice.categories
        .map(
          (_InvoiceCategory category) => _DisplayedInvoiceCategory(
        category: category,
        rows: category.rowsForDisplay(showAll: showAllComponents),
      ),
    )
        .where(
          (_DisplayedInvoiceCategory item) =>
      item.rows.isNotEmpty || item.category.subtotal.abs() > 0.000001,
    )
        .toList(growable: false);

    final int appliedCount = invoice.categories.fold<int>(
      0,
          (int count, _InvoiceCategory category) =>
      count +
          category.rows
              .where(
                (_InvoiceLine line) =>
            !line.isHeading && line.shouldShowOnMobile,
          )
              .length,
    );

    return Column(
      children: [
        _RateComponentVisibilityCard(
          showAll: showAllComponents,
          totalCount: invoice.chargeRowCount,
          appliedCount: appliedCount,
          onChanged: onShowAllChanged,
        ),
        const SizedBox(height: 10),
        for (int index = 0; index < visibleCategories.length; index++) ...[
          _InvoiceCategoryCard(
            category: visibleCategories[index].category,
            rows: visibleCategories[index].rows,
          ),
          if (index != visibleCategories.length - 1) const SizedBox(height: 10),
        ],
        const SizedBox(height: 10),
        _InvoiceTotalsCard(invoice: invoice),
      ],
    );
  }
}

class _RateComponentVisibilityCard extends StatelessWidget {
  const _RateComponentVisibilityCard({
    required this.showAll,
    required this.totalCount,
    required this.appliedCount,
    required this.onChanged,
  });

  final bool showAll;
  final int totalCount;
  final int appliedCount;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      padding: const EdgeInsets.all(13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _IconTile(
                icon: Icons.view_list_rounded,
                accent: _BillPalette.info(context),
                size: 40,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$totalCount Rate Components',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: _BillPalette.text(context),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      showAll
                          ? 'Showing the complete saved bill invoice'
                          : 'Showing only rows with a rate or amount',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: _BillPalette.secondaryText(context),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        height: 1.30,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: _BillPalette.surfaceAlt(context),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _BillPalette.border(context)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _RateViewOption(
                    selected: showAll,
                    icon: Icons.visibility_rounded,
                    label: 'All ($totalCount)',
                    onTap: () => onChanged(true),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: _RateViewOption(
                    selected: !showAll,
                    icon: Icons.filter_alt_rounded,
                    label: 'Applied ($appliedCount)',
                    onTap: () => onChanged(false),
                  ),
                ),
              ],
            ),
          ),
          if (showAll) ...[
            const SizedBox(height: 9),
            Text(
              'Rows without an applicable value are still included and shown as Rate — and Amount —.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: _BillPalette.secondaryText(context),
                fontSize: 10.2,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RateViewOption extends StatelessWidget {
  const _RateViewOption({
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color accent = _BillPalette.primary(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? accent.withValues(alpha: 0.13) : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: selected ? accent.withValues(alpha: 0.42) : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: selected ? accent : _BillPalette.secondaryText(context),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: selected
                        ? accent
                        : _BillPalette.secondaryText(context),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InvoiceCategoryCard extends StatelessWidget {
  const _InvoiceCategoryCard({
    required this.category,
    required this.rows,
  });

  final _InvoiceCategory category;
  final List<_InvoiceLine> rows;

  IconData _iconForCategory() {
    final String label = category.label.toLowerCase();
    if (label.contains('generation') || label.contains('transmission')) {
      return Icons.bolt_rounded;
    }
    if (label.contains('distribution')) return Icons.account_tree_rounded;
    if (label.contains('government') || label.contains('tax')) {
      return Icons.account_balance_rounded;
    }
    if (label.contains('universal')) return Icons.public_rounded;
    if (label.contains('coop')) return Icons.apartment_rounded;
    return Icons.receipt_long_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  _BillPalette.primary(context).withValues(alpha: 0.10),
                  _BillPalette.primary(context).withValues(alpha: 0.035),
                ],
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              border: Border(
                bottom: BorderSide(color: _BillPalette.border(context)),
              ),
            ),
            child: Row(
              children: [
                _IconTile(
                  icon: _iconForCategory(),
                  accent: _BillPalette.primary(context),
                  size: 40,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category.label,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: _BillPalette.text(context),
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${rows.where((_InvoiceLine line) => !line.isHeading).length} rate component${rows.where((_InvoiceLine line) => !line.isHeading).length == 1 ? '' : 's'}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: _BillPalette.secondaryText(context),
                          fontSize: 9.8,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: _BillPalette.surface(context),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _BillPalette.primary(context).withValues(alpha: 0.13),
                    ),
                  ),
                  child: Text(
                    _money(category.subtotal),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: _BillPalette.primary(context),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          for (int index = 0; index < rows.length; index++) ...[
            _InvoiceLineTile(line: rows[index]),
            if (index != rows.length - 1) const _CardDivider(),
          ],
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: _BillPalette.surfaceAlt(context),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(24),
              ),
              border: Border(
                top: BorderSide(color: _BillPalette.border(context)),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calculate_outlined,
                  size: 16,
                  color: _BillPalette.secondaryText(context),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    'Category Subtotal',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: _BillPalette.text(context),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  _money(category.subtotal),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: _BillPalette.primary(context),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
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

class _InvoiceLineTile extends StatelessWidget {
  const _InvoiceLineTile({required this.line});

  final _InvoiceLine line;

  @override
  Widget build(BuildContext context) {
    if (line.isHeading) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 9),
        color: _BillPalette.gold(context).withValues(alpha: 0.055),
        child: Row(
          children: [
            Container(
              height: 6,
              width: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _BillPalette.gold(context),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                line.componentName.isEmpty
                    ? 'Charge heading'
                    : line.componentName,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: _BillPalette.gold(context),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.30,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final bool hasAmount = line.amount != null;
    final bool isNegative = (line.amount ?? 0) < 0;
    final Color amountColor = isNegative
        ? _BillPalette.success(context)
        : _BillPalette.primary(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.componentName.isEmpty
                      ? 'Rate component'
                      : line.componentName,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: _BillPalette.text(context),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    height: 1.30,
                  ),
                ),
                const SizedBox(height: 7),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: _BillPalette.surfaceAlt(context),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: _BillPalette.border(context),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.sell_outlined,
                        size: 12,
                        color: _BillPalette.secondaryText(context),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Rate  ${line.displayRate}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: _BillPalette.secondaryText(context),
                          fontSize: 9.8,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (line.notes.isNotEmpty) ...[
                  const SizedBox(height: 7),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 13,
                        color: _BillPalette.secondaryText(context),
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          line.notes,
                          style:
                          Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: _BillPalette.secondaryText(context),
                            fontSize: 10.2,
                            fontStyle: FontStyle.italic,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 14),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 88),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Amount',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: _BillPalette.secondaryText(context),
                    fontSize: 8.2,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.45,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  hasAmount ? _money(line.amount!) : '—',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: amountColor,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.15,
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

class _InvoiceTotalsCard extends StatelessWidget {
  const _InvoiceTotalsCard({required this.invoice});

  final _InvoiceSnapshot invoice;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF102F3E),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF32636A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 37,
                width: 37,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.summarize_rounded,
                  color: Color(0xFFF6D483),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Bill Summary',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _TotalLine(
            label: 'Current Bill',
            amount: invoice.currentAmountDue,
          ),
          if (invoice.unpaidBills.abs() > 0.005) ...[
            const SizedBox(height: 13),
            _TotalLine(
              label: invoice.statementPriorItems.isNotEmpty
                  ? 'Balance carried into this bill'
                  : 'Previous Unpaid Bills',
              amount: invoice.unpaidBills,
            ),
          ],
          Divider(height: 27, color: Colors.white.withValues(alpha: 0.20)),
          _TotalLine(
            label: invoice.statementPriorItems.isNotEmpty
                ? 'This Bill Amount Due'
                : 'Total Amount Due',
            amount: invoice.totalAmountDue,
            prominent: true,
          ),
        ],
      ),
    );
  }
}


class _TotalLine extends StatelessWidget {
  const _TotalLine({
    required this.label,
    required this.amount,
    this.prominent = false,
  });

  final String label;
  final double amount;
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: prominent
                  ? const Color(0xFFF6D483)
                  : const Color(0xFFC0D5DA),
              fontSize: prominent ? 14 : 12,
              fontWeight: prominent ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          _money(amount),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Colors.white,
            fontSize: prominent ? 20 : 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}


// Saved statement references are informational: never used for online payment.
class _PriorStatementCard extends StatelessWidget {
  const _PriorStatementCard({required this.invoice});

  final _InvoiceSnapshot invoice;

  @override
  Widget build(BuildContext context) {
    final Color navy = _BillPalette.text(context);
    final Color teal = _BillPalette.primary(context);
    final Color muted = _BillPalette.secondaryText(context);
    return _SurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              _IconTile(
                icon: Icons.history_rounded,
                accent: teal,
                size: 38,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${invoice.statementPriorItems.length} previous bill${invoice.statementPriorItems.length == 1 ? '' : 's'} selected',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: navy,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Amounts shown were outstanding when this statement was issued. They are not necessarily the balances today.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: muted,
              fontSize: 12,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 12),
          for (final _StatementPriorBill item in invoice.statementPriorItems) ...[
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 9),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _BillPalette.surfaceAlt(context),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: _BillPalette.border(context)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    item.reference,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: navy,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    runSpacing: 4,
                    children: <Widget>[
                      Text(
                        '${_formatBillingMonth(item.billingMonth)}  |  Due ${_formatBillDate(item.dueDate)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: muted,
                          fontSize: 11.5,
                        ),
                      ),
                      Text(
                        _money(item.amountAtIssue),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: teal,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 4),
          _PriorStatementTotalLine(
            label: 'This bill amount due',
            amount: invoice.totalAmountDue,
          ),
          const SizedBox(height: 8),
          _PriorStatementTotalLine(
            label: 'Selected previous bills at issue',
            amount: invoice.statementPreviousUnpaidAtIssue,
          ),
          Divider(height: 23, color: _BillPalette.border(context)),
          _PriorStatementTotalLine(
            label: 'Combined statement view at issue',
            amount: invoice.statementCombinedAtIssue,
            emphasized: true,
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: teal.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: teal.withValues(alpha: 0.15)),
            ),
            child: Text(
              'REFERENCE ONLY. The combined amount is not a new charge or a single payable bill. Pay each bill separately using its own payment rules. Check current status before paying.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: navy,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PriorStatementTotalLine extends StatelessWidget {
  const _PriorStatementTotalLine({
    required this.label,
    required this.amount,
    this.emphasized = false,
  });

  final String label;
  final double amount;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: emphasized
                  ? _BillPalette.text(context)
                  : _BillPalette.secondaryText(context),
              fontSize: 12,
              fontWeight: emphasized ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          _money(amount),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: _BillPalette.primary(context),
            fontSize: emphasized ? 15 : 12.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _BreakdownTransparencyNotice extends StatelessWidget {
  const _BreakdownTransparencyNotice({
    required this.hasSnapshot,
    required this.rowCount,
  });

  final bool hasSnapshot;
  final int rowCount;

  @override
  Widget build(BuildContext context) {
    final Color accent = hasSnapshot
        ? _BillPalette.success(context)
        : _BillPalette.gold(context);

    final String message = hasSnapshot
        ? '$rowCount billing component${rowCount == 1 ? '' : 's'} available. Use Show all to include rows that are not applicable or do not have an amount for this bill.'
        : 'A detailed charge breakdown is unavailable for this bill. KuryentePay does not estimate missing charges.';

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: accent.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            hasSnapshot
                ? Icons.verified_user_outlined
                : Icons.info_outline_rounded,
            color: accent,
            size: 21,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: _BillPalette.text(context),
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.42,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BillDocumentCard extends StatelessWidget {
  const _BillDocumentCard({
    required this.enabled,
    required this.busy,
    required this.onSavePdf,
    required this.onPrint,
  });

  final bool enabled;
  final bool busy;
  final VoidCallback onSavePdf;
  final VoidCallback onPrint;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      padding: const EdgeInsets.all(13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _IconTile(
                icon: Icons.picture_as_pdf_rounded,
                accent: _BillPalette.primary(context),
                size: 44,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bill Copy',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: _BillPalette.text(context),
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'The PDF uses the same bill and saved charge breakdown already loaded on this screen.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: _BillPalette.secondaryText(context),
                        fontSize: 10.8,
                        fontWeight: FontWeight.w500,
                        height: 1.38,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (busy) ...[
            LinearProgressIndicator(
              minHeight: 3,
              color: _BillPalette.primary(context),
              backgroundColor:
              _BillPalette.primary(context).withValues(alpha: 0.10),
            ),
            const SizedBox(height: 10),
          ],
          LayoutBuilder(
            builder: (context, constraints) {
              final bool compact = constraints.maxWidth < 330;

              final Widget saveButton = OutlinedButton.icon(
                onPressed: enabled ? onSavePdf : null,
                icon: const Icon(
                  Icons.download_rounded,
                  size: 18,
                ),
                label: Text(
                  busy ? 'Preparing…' : 'Save PDF',
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(46),
                  side: BorderSide(
                    color: _BillPalette.primary(context)
                        .withValues(alpha: 0.38),
                  ),
                  foregroundColor: _BillPalette.primary(context),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              );

              final Widget printButton = FilledButton.icon(
                onPressed: enabled ? onPrint : null,
                icon: const Icon(
                  Icons.print_rounded,
                  size: 18,
                ),
                label: const Text('Print Bill'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(46),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              );

              if (compact) {
                return Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: saveButton,
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: printButton,
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: saveButton),
                  const SizedBox(width: 9),
                  Expanded(child: printButton),
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          Text(
            enabled
                ? 'Save PDF opens Android sharing/saving options. Print Bill opens the system print dialog.'
                : 'Wait until the complete bill invoice finishes loading.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: _BillPalette.secondaryText(context),
              fontSize: 10.2,
              fontWeight: FontWeight.w500,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentSafetyCard extends StatelessWidget {
  const _PaymentSafetyCard();

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      padding: const EdgeInsets.all(7),
      child: Column(
        children: [
          _SafetyRow(
            step: '1',
            icon: Icons.fact_check_outlined,
            title: 'Review Your Bill',
            message:
            'Confirm the account number, service address, billing month, due date, and amount shown before continuing.',
            accent: _BillPalette.primary(context),
          ),
          const _CardDivider(),
          _SafetyRow(
            step: '2',
            icon: Icons.qr_code_2_rounded,
            title: 'Pay Through PayMongo QR Ph',
            message:
            'Complete your transaction only through the secure PayMongo checkout opened by KuryentePay.',
            accent: _BillPalette.gold(context),
          ),
          const _CardDivider(),
          _SafetyRow(
            step: '3',
            icon: Icons.verified_user_outlined,
            title: 'Wait for Payment Confirmation',
            message:
            'Returning from checkout does not confirm payment. Wait for KuryentePay to verify the result before making another attempt.',
            accent: _BillPalette.success(context),
          ),
        ],
      ),
    );
  }
}

class _SafetyRow extends StatelessWidget {
  const _SafetyRow({
    required this.step,
    required this.icon,
    required this.title,
    required this.message,
    required this.accent,
  });

  final String step;
  final IconData icon;
  final String title;
  final String message;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              _IconTile(icon: icon, accent: accent, size: 42),
              Positioned(
                right: -3,
                top: -3,
                child: Container(
                  height: 17,
                  width: 17,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _BillPalette.surface(context),
                      width: 2,
                    ),
                  ),
                  child: Text(
                    step,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: _BillPalette.text(context),
                    fontSize: 12.8,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: _BillPalette.secondaryText(context),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    height: 1.38,
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

class _PaymentBottomBar extends StatelessWidget {
  const _PaymentBottomBar({
    required this.amount,
    required this.statusLabel,
    required this.buttonLabel,
    required this.canPay,
    required this.loading,
    required this.onPay,
  });

  final double amount;
  final String statusLabel;
  final String buttonLabel;
  final bool canPay;
  final bool loading;
  final VoidCallback onPay;

  @override
  Widget build(BuildContext context) {
    final double safeBottom = MediaQuery.of(context).padding.bottom;
    final bool paid = statusLabel == 'PAID';
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, safeBottom + 12),
      decoration: BoxDecoration(
        color: _BillPalette.surface(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        border: Border(top: BorderSide(color: _BillPalette.border(context))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.09),
            blurRadius: 20,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bool compact = constraints.maxWidth < 365;
          final Widget summary = Row(
            children: [
              Container(
                height: 39,
                width: 39,
                decoration: BoxDecoration(
                  color: (paid
                      ? _BillPalette.success(context)
                      : _BillPalette.primary(context))
                      .withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  paid ? Icons.verified_rounded : Icons.account_balance_wallet_outlined,
                  size: 21,
                  color: paid
                      ? _BillPalette.success(context)
                      : _BillPalette.primary(context),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      paid ? 'Amount Settled' : 'Amount to Pay',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: _BillPalette.secondaryText(context),
                        fontSize: 10.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _money(amount),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: _BillPalette.text(context),
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );

          final Widget action = SizedBox(
            height: 48,
            width: compact ? double.infinity : null,
            child: FilledButton.icon(
              onPressed: canPay ? onPay : null,
              icon: loading
                  ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : Icon(
                paid ? Icons.verified_rounded : Icons.arrow_forward_rounded,
                size: 18,
              ),
              label: Text(
                buttonLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF087F79),
                foregroundColor: Colors.white,
                disabledBackgroundColor: _BillPalette.border(context),
                disabledForegroundColor: _BillPalette.secondaryText(context),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          );

          if (compact) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                summary,
                const SizedBox(height: 10),
                action,
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: summary),
              const SizedBox(width: 10),
              action,
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
    this.padding = const EdgeInsets.all(14),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: _BillPalette.surface(context),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _BillPalette.border(context)),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.14)
                : AppTheme.brandNavy.withValues(alpha: 0.035),
            blurRadius: 14,
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
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.30),
        color: accent.withValues(alpha:
        isDark ? 0.13 : 0.07,
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
      indent: 14,
      endIndent: 14,
      color: _BillPalette.border(context),
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
