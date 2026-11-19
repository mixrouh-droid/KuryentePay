// ALERTS PROFESSIONAL UI REVISION: flatter hierarchy, consistent typography, simpler filters, cleaner alert cards, and preserved notification behavior
import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/services/notification_service.dart';
import '../../../core/services/session_service.dart';
import '../../bills/screens/bill_details_screen.dart';
import '../../transactions/screens/transaction_history_screen.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen>
    with WidgetsBindingObserver {
  final List<_FilterItem> _filters = const <_FilterItem>[
    _FilterItem('All', Icons.all_inbox_rounded),
    _FilterItem('Bills', Icons.receipt_long_rounded),
    _FilterItem(
      'Payments',
      Icons.account_balance_wallet_rounded,
    ),
    _FilterItem('System', Icons.campaign_rounded),
  ];

  final Set<int> _archivedIds = <int>{};

  List<_AlertItem> _items = <_AlertItem>[];

  int _selectedFilter = 0;
  int _unreadCount = 0;

  bool _unreadOnly = false;
  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _isMarkingAllRead = false;

  String? _errorMessage;
  Timer? _autoRefreshTimer;
  DateTime? _lastUpdatedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_loadNotifications());
    _autoRefreshTimer = Timer.periodic(
      const Duration(seconds: 20),
          (_) => unawaited(
        _loadNotifications(
          showInitialLoader: false,
          showRefreshState: false,
        ),
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(
        _loadNotifications(
          showInitialLoader: false,
          showRefreshState: false,
        ),
      );
    }
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _loadNotifications({
    bool showInitialLoader = true,
    bool showRefreshState = true,
  }) async {
    if (showInitialLoader && mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    } else if (showRefreshState && mounted) {
      setState(() {
        _isRefreshing = true;
        _errorMessage = null;
      });
    }

    try {
      final NotificationPageResult result =
      await NotificationService.fetchNotifications(
        page: 1,
        limit: 100,
      );

      final List<_AlertItem> loadedItems =
      result.notifications
          .where(
            (AppNotification notification) =>
        !_archivedIds.contains(notification.id),
      )
          .map(_AlertItem.fromNotification)
          .toList()
        ..sort(
              (_AlertItem a, _AlertItem b) {
            final DateTime aTime =
                a.eventTime ?? DateTime.fromMillisecondsSinceEpoch(0);
            final DateTime bTime =
                b.eventTime ?? DateTime.fromMillisecondsSinceEpoch(0);
            return bTime.compareTo(aTime);
          },
        );

      if (!mounted) {
        return;
      }

      setState(() {
        _items = loadedItems;
        _unreadCount = result.unreadCount;
        _lastUpdatedAt = DateTime.now();
        _errorMessage = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = _cleanError(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    }
  }

  Future<void> _markAllRead() async {
    if (_isMarkingAllRead) {
      return;
    }

    final bool hasUnread =
        _unreadCount > 0 ||
            _items.any((_AlertItem item) => item.unread);

    if (!hasUnread) {
      _showMessage(
        'All notifications are already read.',
      );
      return;
    }

    setState(() => _isMarkingAllRead = true);

    try {
      final NotificationUpdateResult result =
      await NotificationService.markAllAsRead();

      if (!mounted) {
        return;
      }

      setState(() {
        for (final _AlertItem item in _items) {
          item.unread = false;
        }

        _unreadCount = result.unreadCount;
      });

      _showMessage(
        result.message.trim().isEmpty
            ? 'All notifications marked as read.'
            : result.message,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(
        _cleanError(error),
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _isMarkingAllRead = false);
      }
    }
  }

  void _openAlert(_AlertItem item) {
    final bool wasUnread = item.unread;

    if (wasUnread) {
      setState(() {
        item.unread = false;

        if (_unreadCount > 0) {
          _unreadCount--;
        }
      });

      unawaited(
        _saveReadStatus(
          item,
          restoreWhenFailed: true,
        ),
      );
    }

    final bool canViewPayment =
        item.isPaymentNotification && (item.paymentId ?? 0) > 0;
    final bool canViewBill =
        !item.isPaymentNotification &&
            item.category == 'Bills' &&
            (item.billId ?? 0) > 0;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) => _AlertDetailsSheet(
        item: item,
        onViewBill: canViewBill
            ? () {
          Navigator.of(sheetContext).pop();
          unawaited(_openBillFromAlert(item));
        }
            : null,
        onViewPayment: canViewPayment
            ? () {
          Navigator.of(sheetContext).pop();
          unawaited(_openPaymentFromAlert(item));
        }
            : null,
      ),
    );
  }

  Future<void> _openPaymentFromAlert(_AlertItem item) async {
    final int? paymentId = item.paymentId;

    if (paymentId == null || paymentId <= 0) {
      _showMessage('This alert is not linked to a payment record.');
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TransactionHistoryScreen(
          initialPaymentId: paymentId,
        ),
      ),
    );
  }

  Future<void> _openBillFromAlert(_AlertItem item) async {
    final int? billId = item.billId;

    if (billId == null || billId <= 0) {
      _showMessage('This alert is not linked to a bill record.');
      return;
    }

    try {
      final Map<String, dynamic>? user =
      await SessionService.loadUser();
      final String sessionAccountNo =
          await SessionService.loadAccountNumber() ?? '';

      if (!mounted) {
        return;
      }

      final String accountNo = sessionAccountNo.isNotEmpty
          ? sessionAccountNo
          : item.billAccountNo;

      if (accountNo.isEmpty) {
        _showMessage(
          'Your active account could not be verified. Please sign in again.',
          isError: true,
        );
        return;
      }

      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => BillDetailsScreen(
            nickname: _sessionDisplayName(user),
            accountNo: accountNo,
            address: _sessionAddress(user),
            month: item.billingMonth.isEmpty
                ? 'Bill'
                : item.billingMonth,
            amount: item.billAmount,
            dueDate: item.billDueDate,
            status: item.billStatusForNavigation,
            billId: billId,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(
        _cleanError(error),
        isError: true,
      );
    }
  }

  String _sessionDisplayName(Map<String, dynamic>? user) {
    final String existingName = _sessionText(
      user,
      const <String>['name', 'full_name', 'display_name', 'nickname'],
    );

    if (existingName.isNotEmpty) {
      return existingName;
    }

    final String firstName = _sessionText(
      user,
      const <String>['first_name', 'firstName'],
    );
    final String middleName = _sessionText(
      user,
      const <String>['middle_name', 'middleName'],
    );
    final String lastName = _sessionText(
      user,
      const <String>['last_name', 'lastName'],
    );
    final String extension = _sessionText(
      user,
      const <String>['name_extension', 'nameExtension'],
    );

    final String combined = <String>[
      firstName,
      middleName,
      lastName,
      extension,
    ].where((String value) => value.isNotEmpty).join(' ');

    return combined.isEmpty ? 'My Account' : combined;
  }

  String _sessionAddress(Map<String, dynamic>? user) {
    final String existingAddress = _sessionText(
      user,
      const <String>['address', 'service_address', 'serviceAddress'],
    );

    if (existingAddress.isNotEmpty) {
      return existingAddress;
    }

    final List<String> parts = <String>[
      _sessionText(
        user,
        const <String>['house_street', 'houseStreet'],
      ),
      _sessionText(user, const <String>['barangay']),
      _sessionText(user, const <String>['municipality']),
      _sessionText(user, const <String>['province']),
    ].where((String value) => value.isNotEmpty).toList(growable: false);

    return parts.join(', ');
  }

  String _sessionText(
      Map<String, dynamic>? user,
      List<String> keys,
      ) {
    if (user == null) {
      return '';
    }

    for (final String key in keys) {
      final String value = user[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) {
        return value;
      }
    }

    final dynamic nested = user['account'];
    if (nested is Map) {
      for (final String key in keys) {
        final String value = nested[key]?.toString().trim() ?? '';
        if (value.isNotEmpty) {
          return value;
        }
      }
    }

    return '';
  }

  Future<void> _saveReadStatus(
      _AlertItem item, {
        required bool restoreWhenFailed,
      }) async {
    try {
      final NotificationUpdateResult result =
      await NotificationService.markAsRead(
        notificationId: item.id,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _unreadCount = result.unreadCount;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      if (
      restoreWhenFailed &&
          _items.contains(item) &&
          !item.unread
      ) {
        setState(() {
          item.unread = true;
          _unreadCount++;
        });
      }

      _showMessage(
        _cleanError(error),
        isError: true,
      );
    }
  }

  void _archiveAlert(_AlertItem item) {
    final bool wasUnread = item.unread;

    setState(() {
      _archivedIds.add(item.id);
      _items.remove(item);

      if (wasUnread && _unreadCount > 0) {
        _unreadCount--;
      }
    });

    if (wasUnread) {
      unawaited(
        _saveReadStatus(
          item,
          restoreWhenFailed: false,
        ),
      );
    }

    _showMessage('Notification hidden from this view.');
  }

  void _showMessage(
      String message, {
        bool isError = false,
      }) {
    if (!mounted) {
      return;
    }

    final Color? background = isError
        ? _AlertsPalette.danger(context)
        : null;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: background,
        ),
      );
  }

  String _cleanError(Object error) {
    return error
        .toString()
        .replaceFirst(RegExp(r'^Exception:\s*'), '')
        .trim();
  }

  @override
  Widget build(BuildContext context) {
    final String selectedCategory =
        _filters[_selectedFilter].label;

    final List<_AlertItem> visible =
    _items.where((_AlertItem item) {
      final bool categoryMatches =
          selectedCategory == 'All' ||
              item.category == selectedCategory;

      final bool unreadMatches =
          !_unreadOnly || item.unread;

      return categoryMatches && unreadMatches;
    }).toList();

    final Map<String, List<_AlertItem>> grouped =
    <String, List<_AlertItem>>{};

    for (final _AlertItem item in visible) {
      grouped.putIfAbsent(
        item.section,
            () => <_AlertItem>[],
      );
      grouped[item.section]!.add(item);
    }

    final List<String> sections = <String>[
      if (grouped.containsKey('Today')) 'Today',
      if (grouped.containsKey('Yesterday')) 'Yesterday',
      if (grouped.containsKey('Earlier')) 'Earlier',
    ];

    return Scaffold(
      backgroundColor: _AlertsPalette.background(context),
      body: Stack(
        children: <Widget>[
          const _AlertsBackdrop(),
          SafeArea(
            bottom: false,
            child: RefreshIndicator(
              color: _AlertsPalette.primary(context),
              backgroundColor:
              _AlertsPalette.surface(context),
              onRefresh: () => _loadNotifications(
                showInitialLoader: false,
              ),
              child: ListView(
                physics:
                const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding:
                const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: <Widget>[
                  _AlertsHeader(
                    unreadCount: _unreadCount,
                    isRefreshing: _isRefreshing,
                    isMarkingAllRead: _isMarkingAllRead,
                    lastUpdatedAt: _lastUpdatedAt,
                    onRefresh: _isLoading || _isRefreshing
                        ? null
                        : () => _loadNotifications(
                      showInitialLoader: false,
                    ),
                    onMarkAllRead: (_unreadCount > 0 ||
                        _items.any((_AlertItem item) => item.unread)) &&
                        !_isMarkingAllRead
                        ? _markAllRead
                        : null,
                  ),
                  if (_errorMessage != null &&
                      _items.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 12),
                    _AlertsInlineError(
                      message: _errorMessage!,
                      onRetry: () => _loadNotifications(
                        showInitialLoader: false,
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  if (_isLoading)
                    const _AlertsLoadingState()
                  else if (
                  _errorMessage != null &&
                      _items.isEmpty
                  )
                    _AlertsErrorState(
                      message: _errorMessage!,
                      onRetry: () => _loadNotifications(),
                    )
                  else ...<Widget>[
                      _AlertsToolbar(
                        filters: _filters,
                        selectedIndex: _selectedFilter,
                        unreadOnly: _unreadOnly,
                        onFilterChanged: (int index) {
                          setState(
                                () => _selectedFilter = index,
                          );
                        },
                        onUnreadChanged: (bool value) {
                          setState(
                                () => _unreadOnly = value,
                          );
                        },
                      ),
                      if (_isRefreshing) ...<Widget>[
                        const SizedBox(height: 10),
                        const LinearProgressIndicator(
                          minHeight: 2,
                        ),
                      ],
                      const SizedBox(height: 16),
                      if (visible.isEmpty)
                        _EmptyState(
                          title: _unreadOnly
                              ? 'No unread notifications'
                              : 'No notifications',
                          subtitle: _unreadOnly
                              ? 'You have read all matching notifications.'
                              : 'There are no alerts in this category.',
                        )
                      else
                        ...sections.expand(
                              (String section) {
                            final List<_AlertItem> items =
                            grouped[section]!;

                            return <Widget>[
                              _SectionHeader(
                                title: section,
                                count: items.length,
                              ),
                              const SizedBox(height: 8),
                              ...items.map(
                                    (_AlertItem item) => Padding(
                                  padding:
                                  const EdgeInsets.only(
                                    bottom: 10,
                                  ),
                                  child: Dismissible(
                                    key: ValueKey<int>(item.id),
                                    direction:
                                    DismissDirection
                                        .endToStart,
                                    onDismissed: (_) =>
                                        _archiveAlert(item),
                                    background: Container(
                                      alignment:
                                      Alignment.centerRight,
                                      padding:
                                      const EdgeInsets.only(
                                        right: 20,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                        _AlertsPalette.danger(
                                          context,
                                        ),
                                        borderRadius:
                                        BorderRadius.circular(
                                          18,
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.archive_rounded,
                                        color: Colors.white,
                                      ),
                                    ),
                                    child: _AlertCard(
                                      item: item,
                                      onTap: () =>
                                          _openAlert(item),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                            ];
                          },
                        ),
                    ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }


}

class _FilterItem {
  const _FilterItem(this.label, this.icon);

  final String label;
  final IconData icon;
}

class _AlertItem {
  _AlertItem({
    required this.id,
    required this.section,
    required this.category,
    required this.type,
    required this.title,
    required this.message,
    required this.time,
    required this.exactTime,
    required this.eventTime,
    required this.unread,
    required this.icon,
    required this.actionLabel,
    this.billId,
    this.paymentId,
    this.paymentReference,
    this.paymentAmount,
    this.currency,
    this.provider,
    this.paymentChannel,
    this.paymentStatus,
    this.billPaymentStatus,
    this.payload = const <String, dynamic>{},
    this.backendConfirmedPayment = false,
  });

  factory _AlertItem.fromNotification(
      AppNotification notification,
      ) {
    final String type =
    notification.notificationType
        .trim()
        .toUpperCase();

    final DateTime? eventTime =
        notification.visibleFrom ??
            notification.createdAt;

    return _AlertItem(
      id: notification.id,
      section: _sectionFor(eventTime),
      category: _categoryFor(type),
      type: type,
      title: notification.title,
      message: notification.message,
      time: _timeLabel(eventTime),
      exactTime: _exactTimeLabel(eventTime),
      eventTime: eventTime?.toLocal(),
      unread: !notification.isRead,
      icon: _iconFor(type),
      actionLabel: _actionFor(type),
      billId: notification.billId,
      paymentId: notification.paymentId,
      paymentReference: notification.paymentReference,
      paymentAmount: notification.paymentAmount,
      currency: notification.currency,
      provider: notification.provider,
      paymentChannel: notification.paymentChannel,
      paymentStatus: notification.paymentStatus,
      billPaymentStatus: notification.billPaymentStatus,
      payload: Map<String, dynamic>.from(notification.payload),
      backendConfirmedPayment:
      notification.isBackendConfirmedPayment,
    );
  }

  final int id;
  final String section;
  final String category;
  final String type;
  final String title;
  final String message;
  final String time;
  final String exactTime;
  final DateTime? eventTime;
  bool unread;
  final IconData icon;
  final String actionLabel;
  final int? billId;
  final int? paymentId;
  final String? paymentReference;
  final double? paymentAmount;
  final String? currency;
  final String? provider;
  final String? paymentChannel;
  final String? paymentStatus;
  final String? billPaymentStatus;
  final Map<String, dynamic> payload;
  final bool backendConfirmedPayment;

  // Brand-safe presentation only. The original backend notification is not
  // modified, re-saved, or used as an altered payment/billing identifier.
  String get displayTitle => _displayBranding(title);
  String get displayMessage => _displayBranding(message);

  static String _displayBranding(String source) {
    return source
        .replaceAll(RegExp(r'ILECO[\s_-]*PAY', caseSensitive: false), 'KuryentePay')
        .replaceAll(RegExp(r'ILECO[\s_-]*(III|3)', caseSensitive: false),
        'your electric cooperative');
  }

  String get billAccountNo =>
      payload['account_no']?.toString().trim() ?? '';

  String get billingMonth =>
      payload['billing_month']?.toString().trim() ?? '';

  String get billDueDate =>
      payload['due_date']?.toString().trim() ?? '';

  double get billAmount {
    final dynamic raw =
        payload['total_amount_due'] ?? payload['amount'] ?? paymentAmount;

    if (raw is num) {
      return raw.toDouble();
    }

    return double.tryParse(raw?.toString().trim() ?? '') ?? 0;
  }

  String get billStatusForNavigation {
    final String backendStatus =
        billPaymentStatus?.trim().toUpperCase() ?? '';

    if (backendStatus.isNotEmpty) {
      return backendStatus;
    }

    if (isPaymentSuccess) {
      return 'PAID';
    }

    if (type == 'PAST_DUE' || type == 'OVERDUE') {
      return 'OVERDUE';
    }

    return 'UNPAID';
  }

  bool get isPaymentSuccess => type == 'PAYMENT_SUCCESS';

  bool get isPaymentFailure => type == 'PAYMENT_FAILED';

  bool get isPaymentNotification =>
      isPaymentSuccess || isPaymentFailure;

  bool get isOfficePayment {
    final String providerText = provider?.trim().toUpperCase() ?? '';
    final String channelText = paymentChannel?.trim().toUpperCase() ?? '';

    return providerText == 'ILECO' ||
        channelText == 'OFFICE' ||
        channelText == 'OVER_THE_COUNTER';
  }

  String get formattedPaymentAmount {
    final double? amount = paymentAmount;

    if (amount == null) {
      return '';
    }

    final String code =
    (currency == null || currency!.trim().isEmpty)
        ? 'PHP'
        : currency!.trim().toUpperCase();

    final String symbol = code == 'PHP' ? '₱' : '$code ';

    return '$symbol${amount.toStringAsFixed(2)}';
  }

  String get paymentMethodLabel {
    final String providerText =
        provider?.trim().toUpperCase() ?? '';
    final String channelText =
        paymentChannel?.trim().toUpperCase() ?? '';

    if (providerText == 'ILECO' || channelText == 'OFFICE') {
      return 'Office Payment';
    }

    String providerLabel = providerText;
    if (providerText == 'PAYMONGO') {
      providerLabel = 'PayMongo';
    }

    String channelLabel = channelText;
    if (channelText == 'QRPH') {
      channelLabel = 'QR Ph';
    } else if (channelText == 'OVER_THE_COUNTER') {
      channelLabel = 'Office Payment';
    }

    if (providerLabel.isNotEmpty && channelLabel.isNotEmpty) {
      return '$providerLabel • $channelLabel';
    }

    return providerLabel.isNotEmpty
        ? providerLabel
        : channelLabel;
  }

  static String _categoryFor(String type) {
    if (
    type.contains('PAYMENT') ||
        type.contains('RECEIPT')
    ) {
      return 'Payments';
    }

    if (
    type.contains('BILL') ||
        type.contains('DUE') ||
        type.contains('OVERDUE')
    ) {
      return 'Bills';
    }

    return 'System';
  }

  static IconData _iconFor(String type) {
    switch (type) {
      case 'BILL_AVAILABLE':
        return Icons.receipt_long_rounded;
      case 'DUE_REMINDER':
      case 'DUE_SOON':
        return Icons.schedule_rounded;
      case 'PAST_DUE':
      case 'OVERDUE':
        return Icons.warning_amber_rounded;
      case 'PAYMENT_SUCCESS':
        return Icons.verified_rounded;
      case 'PAYMENT_FAILED':
        return Icons.error_outline_rounded;
      case 'ACCOUNT_APPROVED':
        return Icons.how_to_reg_rounded;
      case 'ACCOUNT_REJECTED':
        return Icons.person_off_rounded;
      default:
        return Icons.notifications_active_rounded;
    }
  }

  static String _actionFor(String type) {
    switch (type) {
      case 'SYSTEM':
      case 'GENERAL':
        return 'View notice';
      default:
        return 'View details';
    }
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

  static String _sectionFor(DateTime? value) {
    if (value == null) {
      return 'Earlier';
    }

    final DateTime local = value.toLocal();
    final DateTime now = DateTime.now();
    final DateTime today =
    DateTime(now.year, now.month, now.day);
    final DateTime eventDay =
    DateTime(local.year, local.month, local.day);
    final int dayDifference =
        today.difference(eventDay).inDays;

    if (dayDifference == 0) {
      return 'Today';
    }

    if (dayDifference == 1) {
      return 'Yesterday';
    }

    return 'Earlier';
  }

  static String _timeLabel(DateTime? value) {
    if (value == null) {
      return '';
    }

    final DateTime local = value.toLocal();
    final Duration difference =
    DateTime.now().difference(local);

    if (difference.isNegative) {
      return 'Scheduled';
    }

    if (difference.inMinutes < 1) {
      return 'Just now';
    }

    if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    }

    if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    }

    if (difference.inDays == 1) {
      return 'Yesterday';
    }

    if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    }

    return '${_monthNames[local.month - 1]} '
        '${local.day}, ${local.year}';
  }

  static String _exactTimeLabel(DateTime? value) {
    if (value == null) {
      return 'Time unavailable';
    }

    final DateTime local = value.toLocal();
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

}

// Presentation-only components for the KuryentePay Notifications screen.
// The notification API, read/unread operations, routes and refresh lifecycle
// are intentionally retained in the stateful screen above.
class _AlertsLoadingState extends StatelessWidget {
  const _AlertsLoadingState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 38),
      decoration: _AlertsPalette.cardDecoration(context),
      child: Column(
        children: <Widget>[
          SizedBox(
            height: 34,
            width: 34,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: _AlertsPalette.primary(context),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Loading Notifications',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Checking your latest account updates.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: _AlertsPalette.secondaryText(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertsErrorState extends StatelessWidget {
  const _AlertsErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 26, 20, 25),
      decoration: _AlertsPalette.cardDecoration(context),
      child: Column(
        children: <Widget>[
          _IconBubble(
            icon: Icons.wifi_off_rounded,
            accent: _AlertsPalette.danger(context),
            size: 60,
          ),
          const SizedBox(height: 15),
          Text(
            'Unable to Load Notifications',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: _AlertsPalette.secondaryText(context),
              fontSize: 12.5,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: onRetry,
            style: _AlertsPalette.primaryButtonStyle(context),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Try Again'),
          ),
        ],
      ),
    );
  }
}

class _AlertsInlineError extends StatelessWidget {
  const _AlertsInlineError({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final Color danger = _AlertsPalette.danger(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: danger.withValues(alpha: 0.075),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: danger.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.error_outline_rounded, color: danger, size: 21),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            onPressed: onRetry,
            tooltip: 'Retry',
            color: _AlertsPalette.primary(context),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
    );
  }
}

class _AlertsPalette {
  static Color accentForType(BuildContext context, String type) {
    switch (type) {
      case 'PAYMENT_SUCCESS':
      case 'ACCOUNT_APPROVED':
        return success(context);
      case 'DUE_REMINDER':
      case 'DUE_SOON':
        return warning(context);
      case 'PAST_DUE':
      case 'OVERDUE':
      case 'PAYMENT_FAILED':
      case 'ACCOUNT_REJECTED':
        return danger(context);
      default:
        return primary(context);
    }
  }

  static String typeLabel(String type) {
    switch (type) {
      case 'PAYMENT_SUCCESS': return 'Payment Confirmed';
      case 'PAYMENT_FAILED': return 'Payment Unsuccessful';
      case 'BILL_AVAILABLE': return 'New Bill';
      case 'DUE_REMINDER':
      case 'DUE_SOON': return 'Due Reminder';
      case 'PAST_DUE':
      case 'OVERDUE': return 'Overdue Notice';
      case 'ACCOUNT_APPROVED': return 'Account Approved';
      case 'ACCOUNT_REJECTED': return 'Account Rejected';
      case 'SYSTEM':
      case 'GENERAL': return 'System Notice';
      default: return 'Account Update';
    }
  }

  static const Color navy = Color(0xFF102F3E);
  static const Color teal = Color(0xFF087F79);
  static const Color gold = Color(0xFFF6D483);

  static bool _isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color background(BuildContext context) =>
      _isDark(context) ? const Color(0xFF081B24) : const Color(0xFFF4F7FA);

  static Color surface(BuildContext context) =>
      _isDark(context) ? const Color(0xFF142D36) : Colors.white;

  static Color border(BuildContext context) =>
      _isDark(context) ? const Color(0xFF34515A) : const Color(0xFFDCE6EA);

  static Color primary(BuildContext context) =>
      _isDark(context) ? const Color(0xFF68D7C6) : teal;

  // Informational notices use teal, not an unrelated blue accent.
  static Color info(BuildContext context) => primary(context);

  static Color success(BuildContext context) =>
      _isDark(context) ? const Color(0xFF82DCB3) : const Color(0xFF177F5B);

  static Color warning(BuildContext context) =>
      _isDark(context) ? const Color(0xFFF6D483) : const Color(0xFFA87515);

  static Color danger(BuildContext context) =>
      _isDark(context) ? const Color(0xFFFFA4A9) : const Color(0xFFBF404B);

  static Color secondaryText(BuildContext context) =>
      _isDark(context) ? const Color(0xFFB8CDD2) : const Color(0xFF607781);

  static Color heading(BuildContext context) =>
      _isDark(context) ? const Color(0xFFF3FBFA) : const Color(0xFF173347);

  static BoxDecoration cardDecoration(BuildContext context, {
    double radius = 20,
    Color? borderColor,
  }) =>
      BoxDecoration(
        color: surface(context),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor ?? border(context)),
        boxShadow: _isDark(context)
            ? null
            : const <BoxShadow>[
          BoxShadow(
            color: Color(0x090E3641),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      );

  static ButtonStyle primaryButtonStyle(BuildContext context) =>
      FilledButton.styleFrom(
        backgroundColor: teal,
        foregroundColor: Colors.white,
        disabledBackgroundColor: teal.withValues(alpha: 0.35),
        disabledForegroundColor: Colors.white70,
        textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w800,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 19, vertical: 13),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(13),
        ),
      );
}

class _AlertsBackdrop extends StatelessWidget {
  const _AlertsBackdrop();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: _AlertsPalette.background(context),
      ),
    );
  }
}

class _AlertsHeader extends StatelessWidget {
  const _AlertsHeader({
    required this.unreadCount,
    required this.isRefreshing,
    required this.isMarkingAllRead,
    required this.lastUpdatedAt,
    required this.onRefresh,
    required this.onMarkAllRead,
  });

  final int unreadCount;
  final bool isRefreshing;
  final bool isMarkingAllRead;
  final DateTime? lastUpdatedAt;
  final VoidCallback? onRefresh;
  final VoidCallback? onMarkAllRead;

  String _updatedLabel(DateTime? value) {
    if (value == null) return 'Ready to sync';
    final DateTime local = value.toLocal();
    final int hour12 = local.hour == 0
        ? 12
        : local.hour > 12
        ? local.hour - 12
        : local.hour;
    final String minute = local.minute.toString().padLeft(2, '0');
    final String period = local.hour >= 12 ? 'PM' : 'AM';
    return 'Updated $hour12:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool hasUnread = unreadCount > 0;
    final String unreadLabel = unreadCount == 1
        ? '1 Unread Notification'
        : '$unreadCount Unread Notifications';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 8, 2, 18),
          child: Row(
            children: <Widget>[
              Container(
                width: 43,
                height: 43,
                decoration: BoxDecoration(
                  color: _AlertsPalette.primary(context)
                      .withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.notifications_active_rounded,
                  color: _AlertsPalette.primary(context),
                  size: 23,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'KuryentePay',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: _AlertsPalette.primary(context),
                        fontWeight: FontWeight.w800,
                        fontSize: 11.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Notifications',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: _AlertsPalette.heading(context),
                        fontSize: 23,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ],
                ),
              ),
              _AlertsHeaderAction(
                icon: Icons.refresh_rounded,
                label: 'Refresh',
                loading: isRefreshing,
                onPressed: onRefresh,
              ),
            ],
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 19, 18, 18),
          decoration: BoxDecoration(
            color: _AlertsPalette.navy,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Container(
                    width: 39,
                    height: 39,
                    decoration: BoxDecoration(
                      color: const Color(0xFF254C53),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.mark_email_unread_rounded,
                      color: _AlertsPalette.gold,
                      size: 21,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF244E51),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Icon(Icons.sync_rounded,
                            color: Color(0xFF9DE9D2), size: 13),
                        const SizedBox(width: 5),
                        Text(
                          _updatedLabel(lastUpdatedAt),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: const Color(0xFFD5E9E7),
                            fontWeight: FontWeight.w600,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              Text(
                hasUnread ? unreadLabel : 'All Caught Up',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                hasUnread
                    ? 'New activity from your electric billing account.'
                    : 'You have no unread account updates.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: const Color(0xFFC6D9DC),
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 39,
                child: OutlinedButton.icon(
                  onPressed: isMarkingAllRead ? null : onMarkAllRead,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    disabledForegroundColor: Colors.white54,
                    side: const BorderSide(color: Color(0xFF528083)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(11),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 13),
                  ),
                  icon: isMarkingAllRead
                      ? const SizedBox(
                    height: 15,
                    width: 15,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : const Icon(Icons.done_all_rounded, size: 17),
                  label: Text(
                    'Mark All as Read',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AlertsHeaderAction extends StatelessWidget {
  const _AlertsHeaderAction({
    required this.icon,
    required this.label,
    required this.loading,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final bool loading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Material(
        color: _AlertsPalette.surface(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(13),
          side: BorderSide(color: _AlertsPalette.border(context)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(13),
          onTap: loading ? null : onPressed,
          child: SizedBox(
            height: 42,
            width: 42,
            child: Center(
              child: loading
                  ? SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _AlertsPalette.primary(context),
                ),
              )
                  : Icon(
                icon,
                size: 21,
                color: onPressed == null
                    ? _AlertsPalette.secondaryText(context)
                    : _AlertsPalette.primary(context),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AlertsToolbar extends StatelessWidget {
  const _AlertsToolbar({
    required this.filters,
    required this.selectedIndex,
    required this.unreadOnly,
    required this.onFilterChanged,
    required this.onUnreadChanged,
  });

  final List<_FilterItem> filters;
  final int selectedIndex;
  final bool unreadOnly;
  final ValueChanged<int> onFilterChanged;
  final ValueChanged<bool> onUnreadChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(13, 15, 13, 10),
      decoration: _AlertsPalette.cardDecoration(context, radius: 19),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.tune_rounded,
                  size: 18, color: _AlertsPalette.primary(context)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Filter Notifications',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          SizedBox(
            height: 39,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: filters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 7),
              itemBuilder: (context, index) => _FilterChip(
                label: filters[index].label,
                icon: filters[index].icon,
                selected: selectedIndex == index,
                onTap: () => onFilterChanged(index),
              ),
            ),
          ),
          const SizedBox(height: 9),
          Divider(height: 1, color: _AlertsPalette.border(context)),
          const SizedBox(height: 4),
          Row(
            children: <Widget>[
              Icon(Icons.markunread_rounded,
                  size: 17, color: _AlertsPalette.primary(context)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Unread Only',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: _AlertsPalette.heading(context),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
              Switch.adaptive(
                value: unreadOnly,
                activeColor: _AlertsPalette.primary(context),
                onChanged: onUnreadChanged,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
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
    final Color active = _AlertsPalette.primary(context);
    final Color idle = _AlertsPalette.secondaryText(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: selected ? active : _AlertsPalette.background(context),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: selected ? active : _AlertsPalette.border(context),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: 16, color: selected ? Colors.white : idle),
              const SizedBox(width: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: selected ? Colors.white : _AlertsPalette.heading(context),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(3, 10, 3, 5),
      child: Row(
        children: <Widget>[
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              color: _AlertsPalette.primary(context),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: _AlertsPalette.primary(context).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(
              '$count',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: _AlertsPalette.primary(context),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({required this.item, required this.onTap});

  final _AlertItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color accent = item.isPaymentSuccess && !item.backendConfirmedPayment
        ? _AlertsPalette.primary(context)
        : _AlertsPalette.accentForType(context, item.type);
    final bool unread = item.unread;
    final String paymentMeta = <String>[
      if (item.formattedPaymentAmount.isNotEmpty)
        item.formattedPaymentAmount,
      if (item.paymentMethodLabel.isNotEmpty)
        item.paymentMethodLabel,
    ].join('  ·  ');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(19),
        onTap: onTap,
        child: Ink(
          decoration: _AlertsPalette.cardDecoration(
            context,
            radius: 19,
            borderColor: unread
                ? _AlertsPalette.primary(context).withValues(alpha: 0.50)
                : null,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(19),
            child: Stack(
              children: <Widget>[
                if (unread)
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: 4,
                      color: _AlertsPalette.primary(context),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 15, 15, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          _IconBubble(icon: item.icon, accent: accent, size: 46),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Row(
                                  children: <Widget>[
                                    Expanded(
                                      child: Text(
                                        item.category,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall
                                            ?.copyWith(
                                          color: accent,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      item.time,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: _AlertsPalette.secondaryText(context),
                                        fontSize: 10.5,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  item.displayTitle,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(
                                    color: _AlertsPalette.heading(context),
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w800,
                                    height: 1.25,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  item.displayMessage,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                    color: _AlertsPalette.secondaryText(context),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    height: 1.45,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (item.isPaymentNotification && paymentMeta.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
                          decoration: BoxDecoration(
                            color: _AlertsPalette.primary(context)
                                .withValues(alpha: 0.07),
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: Row(
                            children: <Widget>[
                              Icon(
                                item.isOfficePayment
                                    ? Icons.account_balance_rounded
                                    : Icons.wallet_rounded,
                                color: _AlertsPalette.primary(context),
                                size: 17,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  paymentMeta,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                    color: _AlertsPalette.heading(context),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 13),
                      Divider(height: 1, color: _AlertsPalette.border(context)),
                      const SizedBox(height: 11),
                      Row(
                        children: <Widget>[
                          if (unread) ...<Widget>[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                              decoration: BoxDecoration(
                                color: _AlertsPalette.primary(context)
                                    .withValues(alpha: 0.11),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'New',
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: _AlertsPalette.primary(context),
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Expanded(
                            child: Text(
                              item.isPaymentSuccess && !item.backendConfirmedPayment
                                  ? 'Payment Update'
                                  : _AlertsPalette.typeLabel(item.type),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: accent,
                                fontWeight: FontWeight.w800,
                                fontSize: 10.5,
                              ),
                            ),
                          ),
                          Text(
                            item.actionLabel == 'View notice'
                                ? 'View Notice'
                                : 'View Details',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: _AlertsPalette.primary(context),
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(width: 3),
                          Icon(Icons.arrow_forward_ios_rounded,
                              size: 12, color: _AlertsPalette.primary(context)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IconBubble extends StatelessWidget {
  const _IconBubble({
    required this.icon,
    required this.accent,
    this.size = 42,
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
        borderRadius: BorderRadius.circular(size * 0.30),
        color: accent.withValues(alpha: 0.11),
      ),
      child: Icon(icon, color: accent, size: size * 0.48),
    );
  }
}

class _AlertDetailsSheet extends StatelessWidget {
  const _AlertDetailsSheet({
    required this.item,
    this.onViewBill,
    this.onViewPayment,
  });

  final _AlertItem item;
  final VoidCallback? onViewBill;
  final VoidCallback? onViewPayment;

  @override
  Widget build(BuildContext context) {
    final Color accent = item.isPaymentSuccess && !item.backendConfirmedPayment
        ? _AlertsPalette.primary(context)
        : _AlertsPalette.accentForType(context, item.type);
    final double maxHeight = MediaQuery.sizeOf(context).height * 0.86;
    final double bottomPadding = MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(12, 0, 12, bottomPadding + 12),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Container(
          decoration: BoxDecoration(
            color: _AlertsPalette.surface(context),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: _AlertsPalette.border(context)),
          ),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Center(
                  child: Container(
                    width: 39,
                    height: 4,
                    decoration: BoxDecoration(
                      color: _AlertsPalette.border(context),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _AlertsPalette.navy,
                    borderRadius: BorderRadius.circular(19),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Container(
                            width: 41,
                            height: 41,
                            decoration: BoxDecoration(
                              color: const Color(0xFF244F55),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(item.icon, color: _AlertsPalette.gold, size: 22),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'KuryentePay',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF224C50),
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: Text(
                              item.category,
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: const Color(0xFFB9EADC),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        item.displayTitle,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Notification Details',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: _AlertsPalette.heading(context),
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  item.displayMessage,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: _AlertsPalette.secondaryText(context),
                    fontWeight: FontWeight.w500,
                    height: 1.5,
                  ),
                ),
                if (item.isPaymentNotification) ...<Widget>[
                  const SizedBox(height: 16),
                  _PaymentDetailsPanel(item: item, accent: accent),
                ],
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                  decoration: BoxDecoration(
                    color: _AlertsPalette.background(context),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: <Widget>[
                      Icon(Icons.schedule_rounded,
                          size: 17, color: _AlertsPalette.primary(context)),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          item.exactTime,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: _AlertsPalette.secondaryText(context),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 17),
                if (onViewBill != null) ...<Widget>[
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: onViewBill,
                      style: _AlertsPalette.primaryButtonStyle(context),
                      icon: const Icon(Icons.receipt_long_rounded, size: 19),
                      label: const Text('View Bill'),
                    ),
                  ),
                  const SizedBox(height: 9),
                ],
                if (onViewPayment != null) ...<Widget>[
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: onViewPayment,
                      style: _AlertsPalette.primaryButtonStyle(context),
                      icon: const Icon(Icons.wallet_rounded, size: 19),
                      label: const Text('View Payment'),
                    ),
                  ),
                  const SizedBox(height: 9),
                ],
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _AlertsPalette.primary(context),
                      side: BorderSide(color: _AlertsPalette.border(context)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PaymentDetailsPanel extends StatelessWidget {
  const _PaymentDetailsPanel({
    required this.item,
    required this.accent,
  });

  final _AlertItem item;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final bool failed = item.isPaymentFailure;
    final bool confirmed = item.isPaymentSuccess && item.backendConfirmedPayment;

    final List<_PaymentDetailRow> rows = <_PaymentDetailRow>[
      if (item.formattedPaymentAmount.isNotEmpty)
        _PaymentDetailRow(
          label: failed ? 'Amount Attempted' : 'Payment Amount',
          value: item.formattedPaymentAmount,
        ),
      if (item.paymentMethodLabel.isNotEmpty)
        _PaymentDetailRow(
          label: 'Payment Method',
          value: item.paymentMethodLabel,
        ),
      if ((item.paymentReference ?? '').trim().isNotEmpty)
        _PaymentDetailRow(
          label: 'Reference',
          value: item.paymentReference!.trim(),
        ),
      if ((item.billPaymentStatus ?? '').trim().isNotEmpty)
        _PaymentDetailRow(
          label: 'Bill Status',
          value: item.billPaymentStatus!.trim().toUpperCase(),
        ),
      if ((item.paymentStatus ?? '').trim().isNotEmpty)
        _PaymentDetailRow(
          label: 'Transaction Status',
          value: item.paymentStatus!.trim().toUpperCase(),
        ),
    ];

    if (rows.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.065),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: accent.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                failed
                    ? Icons.error_outline_rounded
                    : confirmed
                    ? Icons.verified_rounded
                    : Icons.info_outline_rounded,
                size: 19,
                color: accent,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  failed
                      ? 'Unsuccessful Payment'
                      : confirmed
                      ? 'Verified Payment'
                      : 'Payment Information',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...rows.map(
                (_PaymentDetailRow row) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final bool compact = constraints.maxWidth < 295;
                  final Widget label = Text(
                    row.label,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: _AlertsPalette.secondaryText(context),
                      fontWeight: FontWeight.w600,
                      fontSize: 11.5,
                    ),
                  );
                  final Widget value = Text(
                    row.value,
                    textAlign: compact ? TextAlign.left : TextAlign.right,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: _AlertsPalette.heading(context),
                      fontWeight: FontWeight.w800,
                      fontSize: 11.5,
                    ),
                  );
                  if (compact) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[label, const SizedBox(height: 3), value],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      SizedBox(width: 115, child: label),
                      const SizedBox(width: 8),
                      Expanded(child: value),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentDetailRow {
  const _PaymentDetailRow({required this.label, required this.value});

  final String label;
  final String value;
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(22, 30, 22, 30),
        decoration: _AlertsPalette.cardDecoration(context),
        child: Column(
          children: <Widget>[
            _IconBubble(
              icon: Icons.notifications_none_rounded,
              accent: _AlertsPalette.primary(context),
              size: 61,
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: _AlertsPalette.secondaryText(context),
                fontWeight: FontWeight.w500,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
