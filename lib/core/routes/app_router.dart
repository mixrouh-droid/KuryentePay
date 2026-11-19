// APP SHELL FINAL POLISH: reliable unread badge refresh, notification routing, Android back-to-home behavior, accessibility, and responsive navigation
import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import '../../features/alerts/screens/alerts_screen.dart';
import '../../features/history/screens/history_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../services/notification_navigation_service.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell>
    with WidgetsBindingObserver {
  static const int _homeTabIndex = 0;
  static const int _historyTabIndex = 1;
  static const int _alertsTabIndex = 2;
  static const int _tabCount = 4;

  int _index = _homeTabIndex;
  int _notificationUnreadCount = 0;

  // History normally opens on Bills (0). Payment notifications temporarily
  // open it on Transactions (1). The page version forces a fresh History
  // instance when a notification needs to change that initial destination.
  int _historyInitialTab = 0;
  int _historyPageVersion = 0;

  bool _badgeRequestRunning = false;
  bool _badgeRefreshQueued = false;

  Timer? _badgeRefreshTimer;
  StreamSubscription<RemoteMessage>?
  _foregroundMessageSubscription;
  StreamSubscription<RemoteMessage>?
  _openedMessageSubscription;

  List<Widget> get _pages => <Widget>[
    const HomeScreen(),
    HistoryScreen(
      key: ValueKey<int>(_historyPageVersion),
      initialTab: _historyInitialTab,
    ),
    const AlertsScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    NotificationNavigationService.pendingRequest.addListener(
      _handlePendingNotificationNavigation,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handlePendingNotificationNavigation();
      unawaited(_refreshNotificationBadge());
    });

    _foregroundMessageSubscription =
        FirebaseMessaging.onMessage.listen(
              (_) => _refreshAfterFirebaseMessage(),
          onError: (Object error) {
            debugPrint(
              'Foreground notification listener error: ${error.runtimeType}',
            );
          },
        );

    _openedMessageSubscription =
        FirebaseMessaging.onMessageOpenedApp.listen(
              (_) => _refreshAfterFirebaseMessage(),
          onError: (Object error) {
            debugPrint(
              'Opened-notification listener error: ${error.runtimeType}',
            );
          },
        );

    _badgeRefreshTimer = Timer.periodic(
      const Duration(seconds: 15),
          (_) => unawaited(_refreshNotificationBadge()),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    NotificationNavigationService.pendingRequest.removeListener(
      _handlePendingNotificationNavigation,
    );

    _badgeRefreshTimer?.cancel();
    _foregroundMessageSubscription?.cancel();
    _openedMessageSubscription?.cancel();

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(
      AppLifecycleState state,
      ) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshNotificationBadge());
      unawaited(_refreshNotificationBadgeAfterDelay(
        const Duration(milliseconds: 900),
      ));
    }
  }

  bool _isPaymentNotificationType(String type) {
    switch (type) {
      case 'PAYMENT_SUCCESS':
      case 'PAYMENT_FAILED':
      case 'PAYMENT_PENDING':
      case 'PAYMENT_PROCESSING':
        return true;
      default:
        return false;
    }
  }

  int _notificationTargetIndex(
      NotificationNavigationRequest request,
      ) {
    final String type =
    (request.notificationType ?? '').trim().toUpperCase();

    switch (type) {
    // Current-bill notifications land on Home. Home already loads the
    // authoritative current bill and provides the safe Bill Details action.
      case 'BILL_AVAILABLE':
      case 'DUE_REMINDER':
      case 'DUE_SOON':
      case 'PAST_DUE':
      case 'OVERDUE':
        return _homeTabIndex;

    // Payment notifications land on History > Transactions.
      case 'PAYMENT_SUCCESS':
      case 'PAYMENT_FAILED':
      case 'PAYMENT_PENDING':
      case 'PAYMENT_PROCESSING':
        return _historyTabIndex;

    // Account decisions remain visible in Alerts.
      case 'ACCOUNT_APPROVED':
      case 'ACCOUNT_REJECTED':
        return _alertsTabIndex;

      default:
      // Unknown/system notifications preserve the backend/request fallback,
      // which is currently the Alerts tab. Clamp explicitly so malformed
      // payloads can never select a tab outside the shell.
        if (request.tabIndex < 0) {
          return _homeTabIndex;
        }
        if (request.tabIndex >= _tabCount) {
          return _tabCount - 1;
        }
        return request.tabIndex;
    }
  }

  void _handlePendingNotificationNavigation() {
    final NotificationNavigationRequest? request =
    NotificationNavigationService.takePendingRequest();

    if (request == null || !mounted) {
      return;
    }

    final String notificationType =
    (request.notificationType ?? '').trim().toUpperCase();

    final int targetIndex =
    _notificationTargetIndex(request);

    final bool openTransactions =
    _isPaymentNotificationType(notificationType);

    if (_index != targetIndex || openTransactions) {
      setState(() {
        if (openTransactions) {
          _historyInitialTab = 1;
          _historyPageVersion++;
        }

        _index = targetIndex;
      });
    }

    debugPrint(
      'Opened notification destination tab: $targetIndex '
          'for ${notificationType.isEmpty ? 'UNKNOWN' : notificationType}',
    );

    unawaited(_refreshNotificationBadge());

    if (targetIndex == _alertsTabIndex) {
      unawaited(_refreshNotificationBadgeAfterDelay(
        const Duration(milliseconds: 700),
      ));
    }
  }

  List<_NavItemData> _buildItems() {
    return <_NavItemData>[
      const _NavItemData(
        label: 'Home',
        icon: Icons.home_outlined,
        selectedIcon: Icons.home_rounded,
      ),
      const _NavItemData(
        label: 'History',
        icon: Icons.receipt_long_outlined,
        selectedIcon: Icons.receipt_long_rounded,
      ),
      _NavItemData(
        label: 'Alerts',
        icon: Icons.notifications_none_rounded,
        selectedIcon: Icons.notifications_rounded,
        badgeCount: _notificationUnreadCount,
      ),
      const _NavItemData(
        label: 'Profile',
        icon: Icons.person_outline_rounded,
        selectedIcon: Icons.person_rounded,
      ),
    ];
  }

  Future<void> _refreshAfterFirebaseMessage() async {
    await _refreshNotificationBadge();

    await Future<void>.delayed(
      const Duration(milliseconds: 850),
    );

    await _refreshNotificationBadge();
  }

  Future<void> _refreshNotificationBadgeAfterDelay(
      Duration delay,
      ) async {
    await Future<void>.delayed(delay);

    if (!mounted) {
      return;
    }

    await _refreshNotificationBadge();
  }

  Future<void> _refreshNotificationBadge() async {
    if (_badgeRequestRunning) {
      _badgeRefreshQueued = true;
      return;
    }

    _badgeRequestRunning = true;

    try {
      final int unreadCount =
      await NotificationService.fetchUnreadCount();

      if (!mounted) {
        return;
      }

      final int safeUnreadCount = unreadCount < 0 ? 0 : unreadCount;

      if (_notificationUnreadCount != safeUnreadCount) {
        setState(() {
          _notificationUnreadCount = safeUnreadCount;
        });
      }
    } catch (error) {
      debugPrint(
        'Unable to refresh notification badge: '
            '${error.runtimeType}',
      );
    } finally {
      _badgeRequestRunning = false;

      if (_badgeRefreshQueued) {
        _badgeRefreshQueued = false;
        unawaited(_refreshNotificationBadge());
      }
    }
  }

  void _selectTab(int value) {
    if (value < 0 || value >= _tabCount) {
      return;
    }

    final int previousIndex = _index;

    final bool resetHistoryToBills =
        value == _historyTabIndex &&
            previousIndex != _historyTabIndex &&
            _historyInitialTab != 0;

    if (_index != value || resetHistoryToBills) {
      setState(() {
        if (resetHistoryToBills) {
          _historyInitialTab = 0;
          _historyPageVersion++;
        }

        _index = value;
      });
    }

    unawaited(_refreshNotificationBadge());

    // Entering or leaving Alerts commonly follows a read action.
    // A short second check keeps the shell badge closer to the server state
    // without requiring aggressive polling.
    if (value == _alertsTabIndex ||
        previousIndex == _alertsTabIndex) {
      unawaited(_refreshNotificationBadgeAfterDelay(
        const Duration(milliseconds: 650),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<_NavItemData> items = _buildItems();

    return PopScope(
      // On Android, Back from History / Alerts / Profile returns the consumer
      // to Home first. Back from Home keeps the normal system exit behavior.
      canPop: _index == _homeTabIndex,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop || _index == _homeTabIndex) {
          return;
        }
        _selectTab(_homeTabIndex);
      },
      child: Scaffold(
        extendBody: false,
        body: IndexedStack(
          index: _index,
          children: _pages,
        ),
        bottomNavigationBar: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool compact = constraints.maxWidth < 360;
            final double horizontalInset = compact ? 8 : 14;
            final double bottomInset = compact ? 8 : 10;

            return SafeArea(
              top: false,
              minimum: EdgeInsets.fromLTRB(
                horizontalInset,
                0,
                horizontalInset,
                bottomInset,
              ),
              child: _PremiumBottomNavigation(
                selectedIndex: _index,
                items: items,
                onSelected: _selectTab,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _NavItemData {
  const _NavItemData({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    this.badgeCount = 0,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final int badgeCount;
}

class _PremiumBottomNavigation extends StatelessWidget {
  const _PremiumBottomNavigation({
    required this.selectedIndex,
    required this.items,
    required this.onSelected,
  });

  final int selectedIndex;
  final List<_NavItemData> items;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final bool isDark =
        Theme.of(context).brightness == Brightness.dark;
    final double textScale =
    MediaQuery.textScalerOf(context).scale(1);
    final bool usesLargeText = textScale > 1.15;

    return Container(
      height: usesLargeText ? 80 : 72,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [
            Color(0xFF102B4B),
            Color(0xFF0A2039),
            Color(0xFF07182C),
          ]
              : const [
            Color(0xFFFFFFFF),
            Color(0xFFF8FBFF),
            Color(0xFFF0F6FD),
          ],
        ),
        border: Border.all(
          color: isDark
              ? const Color(0xFF315679).withValues(alpha: 0.82)
              : const Color(0xFFC9DBEE),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.38)
                : AppTheme.brandNavy.withValues(alpha: 0.14),
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: AppTheme.brandBlue.withValues(alpha:
            isDark ? 0.11 : 0.07,
            ),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Stack(
          children: [
            Positioned(
              top: 0,
              left: 34,
              right: 34,
              child: Container(
                height: 2,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  gradient: const LinearGradient(
                    colors: [
                      Color(0x00E0B63F),
                      AppTheme.brandGold,
                      Color(0x00E0B63F),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 7,
              ),
              child: Row(
                children: [
                  for (int index = 0;
                  index < items.length;
                  index++)
                    Expanded(
                      child: _PremiumNavDestination(
                        data: items[index],
                        selected: selectedIndex == index,
                        onTap: () => onSelected(index),
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

class _PremiumNavDestination extends StatelessWidget {
  const _PremiumNavDestination({
    required this.data,
    required this.selected,
    required this.onTap,
  });

  final _NavItemData data;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool isDark =
        Theme.of(context).brightness == Brightness.dark;

    final Color selectedTextColor = isDark
        ? const Color(0xFFFFDA72)
        : AppTheme.brandBlue;

    final Color unselectedColor = isDark
        ? const Color(0xFFB7C7D9)
        : const Color(0xFF64748B);

    final Color activeBackground = isDark
        ? const Color(0xFF173C66)
        : const Color(0xFFE5F0FF);

    final String semanticLabel =
    data.badgeCount > 0
        ? '${data.label}, ${data.badgeCount} unread notification'
        '${data.badgeCount == 1 ? '' : 's'}'
        : data.label;

    return Semantics(
      button: true,
      selected: selected,
      label: semanticLabel,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: selected
                  ? activeBackground.withValues(alpha:
              isDark ? 0.92 : 0.96,
              )
                  : Colors.transparent,
              border: Border.all(
                color: selected
                    ? selectedTextColor.withValues(alpha:
                isDark ? 0.22 : 0.16,
                )
                    : Colors.transparent,
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (selected)
                  Positioned(
                    top: 0,
                    left: 16,
                    right: 16,
                    child: Container(
                      height: 2,
                      decoration: BoxDecoration(
                        borderRadius:
                        BorderRadius.circular(999),
                        color: AppTheme.brandGold,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.brandGold
                                .withValues(alpha: 0.28),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                  ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _AnimatedNavIcon(
                      data: data,
                      selected: selected,
                      selectedColor: selectedTextColor,
                      unselectedColor: unselectedColor,
                    ),
                    const SizedBox(height: 3),
                    AnimatedDefaultTextStyle(
                      duration:
                      const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                      style: TextStyle(
                        color: selected
                            ? selectedTextColor
                            : unselectedColor,
                        fontSize: selected ? 10.8 : 10.3,
                        fontWeight: selected
                            ? FontWeight.w900
                            : FontWeight.w700,
                        letterSpacing: selected ? 0.15 : 0,
                      ),
                      child: Text(
                        data.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AnimatedNavIcon extends StatelessWidget {
  const _AnimatedNavIcon({
    required this.data,
    required this.selected,
    required this.selectedColor,
    required this.unselectedColor,
  });

  final _NavItemData data;
  final bool selected;
  final Color selectedColor;
  final Color unselectedColor;

  @override
  Widget build(BuildContext context) {
    final bool isDark =
        Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      height: 28,
      width: 34,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            height: selected ? 28 : 26,
            width: selected ? 32 : 28,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: selected
                  ? selectedColor.withValues(alpha:
              isDark ? 0.10 : 0.08,
              )
                  : Colors.transparent,
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 190),
              switchInCurve: Curves.easeOutBack,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (
                  Widget child,
                  Animation<double> animation,
                  ) {
                return ScaleTransition(
                  scale: animation,
                  child: FadeTransition(
                    opacity: animation,
                    child: child,
                  ),
                );
              },
              child: Icon(
                selected ? data.selectedIcon : data.icon,
                key: ValueKey<bool>(selected),
                color: selected
                    ? selectedColor
                    : unselectedColor,
                size: selected ? 21 : 20,
              ),
            ),
          ),
          Positioned(
            top: -2,
            right: 0,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              switchInCurve: Curves.easeOutBack,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (
                  Widget child,
                  Animation<double> animation,
                  ) {
                return ScaleTransition(
                  scale: animation,
                  child: FadeTransition(
                    opacity: animation,
                    child: child,
                  ),
                );
              },
              child: data.badgeCount > 0
                  ? _NotificationBadge(
                key: ValueKey<int>(data.badgeCount),
                count: data.badgeCount,
              )
                  : const SizedBox.shrink(
                key: ValueKey<String>('no-badge'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationBadge extends StatelessWidget {
  const _NotificationBadge({
    super.key,
    required this.count,
  });

  final int count;

  @override
  Widget build(BuildContext context) {
    final String label = count > 99 ? '99+' : '$count';

    // The parent navigation destination already announces the unread count.
    // Excluding this visual badge avoids duplicate screen-reader announcements.
    return ExcludeSemantics(
      child: Container(
        constraints: const BoxConstraints(
          minWidth: 16,
          minHeight: 16,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: 4,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFFD84B53),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: Theme.of(context).brightness ==
                Brightness.dark
                ? const Color(0xFF0A2039)
                : Colors.white,
            width: 1.5,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 8.5,
            fontWeight: FontWeight.w900,
            height: 1,
          ),
        ),
      ),
    );
  }
}
